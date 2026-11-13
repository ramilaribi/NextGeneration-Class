package com.ngclass.backend.content.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import com.fasterxml.jackson.databind.JsonNode;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Builder.Default;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

/**
 * A document of the library (spec 04). Without a chapter it sits in "Sans chapitre" of its subject and level.
 * An uploaded one has a [file]; a page written in the app (release 3) has a [body] instead.
 */
@Entity
@Table(name = "content_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContentItem {
	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	private UUID id;

	@Column(nullable = false)
	private UUID teacherId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	@Default
	private ContentType type = ContentType.DOCUMENT;

	@Column(nullable = false, length = 160)
	private String title;

	@Column(nullable = false)
	private UUID subjectId;

	@Column(nullable = false)
	private UUID levelId;

	private UUID chapterId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	private ContentStatus status;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	private ContentTag tag;

	/** Optional so that loading a page never needs the join (an inner join would drop every page). */
	@ManyToOne(fetch = FetchType.EAGER)
	@JoinColumn(name = "file_id")
	private FileAsset file;

	/** A page's text: the editor's document (Delta operations). */
	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb")
	private JsonNode body;

	/** A page's Corrigé, read by the teacher only. */
	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb")
	private JsonNode answerBody;

	@CreationTimestamp
	@Column(nullable = false, updatable = false)
	private Instant createdAt;

	@UpdateTimestamp
	@Column(nullable = false)
	private Instant updatedAt;

	public boolean isPage() {
		return type == ContentType.PAGE;
	}

	public boolean isQuiz() {
		return type == ContentType.QUIZ;
	}

	/** PDF, IMAGE or WORD for a file, PAGE for a page written in the app, QUIZ for a quiz. */
	public String kindName() {
		return file == null ? type.name() : file.kind().name();
	}

	/** A PDF's pages; null for a page, a quiz, an image or a Word file. */
	public Integer pageCount() {
		return file == null ? null : file.getPageCount();
	}
}
