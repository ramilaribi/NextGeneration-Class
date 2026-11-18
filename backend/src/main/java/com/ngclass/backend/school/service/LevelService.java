package com.ngclass.backend.school.service;

import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.content.repository.ChapterRepository;
import com.ngclass.backend.content.repository.ContentItemRepository;
import com.ngclass.backend.groups.repository.ClassGroupRepository;
import com.ngclass.backend.people.repository.StudentRepository;
import com.ngclass.backend.school.domain.Level;
import com.ngclass.backend.school.dto.LevelRequest;
import com.ngclass.backend.school.dto.LevelUsageItem;
import com.ngclass.backend.school.dto.ReferenceResponse.LevelItem;
import com.ngclass.backend.school.repository.LevelRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The levels a teacher works with: the six years of the primary school, shared by every space, then the
 * ones she adds herself (user request 2026-11-18), which no other teacher sees.
 */
@Service
@RequiredArgsConstructor
public class LevelService {
	/** A teacher's own levels come after the shared ones, in the order she added them. */
	private static final int FIRST_OWN_POSITION = 1000;

	private final LevelRepository levels;
	private final ClassGroupRepository groups;
	private final StudentRepository students;
	private final ChapterRepository chapters;
	private final ContentItemRepository contents;
	private final CurrentTeacher teacher;

	/** The levels of the current space (the teacher's, or the one of the signed-in pupil or parent). */
	@Transactional(readOnly = true)
	public List<Level> visible() {
		Optional<UUID> space = teacher.find();
		return space.map(levels::findVisible).orElseGet(levels::findShared);
	}

	/** A level the signed-in teacher may use; another teacher's own level does not exist for her. */
	public Level require(UUID id) {
		return levels.findVisibleById(id, teacher.id()).orElseThrow(() -> ApiException.notFound("level_not_found"));
	}

	/** Paramètres > Niveaux: every level she can choose, with what uses it in her space. */
	@Transactional(readOnly = true)
	public List<LevelUsageItem> listWithUsage() {
		UUID me = teacher.id();
		return levels.findVisible(me).stream()
				.map(level -> new LevelUsageItem(
						level.getId(),
						level.name(),
						level.isOwn(),
						groups.countByTeacherIdAndLevel_Id(me, level.getId()),
						students.countByTeacherIdAndLevel_Id(me, level.getId())))
				.toList();
	}

	@Transactional
	public LevelItem create(LevelRequest request) {
		UUID me = teacher.id();
		String nameFr = request.nameFr().trim();
		if (levels.existsVisibleName(me, nameFr)) {
			throw ApiException.badRequest("level_exists", nameFr);
		}
		List<Level> own = levels.findByTeacherIdOrderByPositionAsc(me);
		Level level = levels.save(Level.builder()
				.teacherId(me)
				.nameFr(nameFr)
				.nameAr(arabic(request))
				.position(own.isEmpty() ? FIRST_OWN_POSITION : own.getLast().getPosition() + 1)
				.build());
		return item(level);
	}

	@Transactional
	public LevelItem update(UUID id, LevelRequest request) {
		Level level = own(id);
		String nameFr = request.nameFr().trim();
		if (!level.getNameFr().equalsIgnoreCase(nameFr) && levels.existsVisibleName(level.getTeacherId(), nameFr)) {
			throw ApiException.badRequest("level_exists", nameFr);
		}
		level.setNameFr(nameFr);
		level.setNameAr(arabic(request));
		return item(level);
	}

	/** Only a level nothing uses can go: a pupil, a group or a document would lose its level. */
	@Transactional
	public void delete(UUID id) {
		Level level = own(id);
		if (groups.existsByLevel_Id(id) || students.existsByLevel_Id(id)) {
			throw new ApiException(HttpStatus.CONFLICT, "level_in_use");
		}
		if (chapters.existsByLevelId(id) || contents.existsByLevelId(id)) {
			throw new ApiException(HttpStatus.CONFLICT, "level_has_contents");
		}
		levels.delete(level);
	}

	/** One of the levels she added; a shared level cannot be changed. */
	private Level own(UUID id) {
		return levels.findByIdAndTeacherId(id, teacher.id()).orElseThrow(() -> ApiException.notFound("level_not_found"));
	}

	private static String arabic(LevelRequest request) {
		return request.nameAr() == null ? "" : request.nameAr().trim();
	}

	public static LevelItem item(Level level) {
		return new LevelItem(level.getId(), level.name(), level.isOwn());
	}
}
