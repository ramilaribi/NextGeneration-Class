package com.ngclass.backend.admin.service;

import com.ngclass.backend.content.storage.FileStorage;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Deletes a teacher's whole space and her account (user request 2026-11-18): her homework and evaluations,
 * announcements, groups with their sessions, contents, chapters and files, her pupils and parents with their
 * accounts, her subjects and levels. The order follows the foreign keys (cascades take the rest: attendance,
 * submissions, notifications...). One transaction: all of it goes, or nothing. The files on disk go only once
 * the database has committed, so a failure never leaves rows pointing at missing files.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class TeacherSpaceEraser {
	/** Tables whose rows belong to one teacher, in the order they can be deleted. */
	private static final List<String> OWNED = List.of(
			// Recipients, submissions, quiz attempts and their notifications follow.
			"assignments",
			"evaluations",
			"announcements",
			// Members, sessions (attendance, contents of the day), weekly rules and shares follow.
			"class_groups",
			"content_items",
			"chapters",
			"file_assets",
			// Their notes, comments, consents, grades and links to parents follow.
			"students",
			"parents",
			"subjects",
			"levels");

	private final JdbcTemplate jdbc;
	private final FileStorage storage;

	@Transactional(propagation = Propagation.MANDATORY)
	public void erase(UUID teacherId) {
		List<String> files = jdbc.queryForList("select storage_key from file_assets where teacher_id = ?", String.class, teacherId);
		// Read before their rows go: the accounts of her pupils and parents belong to her space only.
		List<UUID> accounts = jdbc.queryForList("""
				select user_id from students where teacher_id = ? and user_id is not null
				union select user_id from parents where teacher_id = ?""", UUID.class, teacherId, teacherId);
		for (String table : OWNED) {
			jdbc.update("delete from " + table + " where teacher_id = ?", teacherId);
		}
		for (UUID account : accounts) {
			jdbc.update("delete from users where id = ?", account);
		}
		jdbc.update("delete from users where id = ?", teacherId);
		TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
			@Override
			public void afterCommit() {
				for (String key : files) {
					try {
						storage.delete(key);
					} catch (RuntimeException e) {
						// The rows are gone; a file left behind is only disk space.
						log.warn("Could not delete file {} of a deleted teacher: {}", key, e.getMessage());
					}
				}
			}
		});
		log.info("Deleted teacher {}: {} accounts of pupils and parents, {} files", teacherId, accounts.size(), files.size());
	}
}
