package com.ngclass.backend.quiz.domain;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Builder.Default;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * The settings and questions of a quiz (spec 05), one per library item of type QUIZ. The questions are one
 * JSON list ({@link com.ngclass.backend.quiz.service.QuizRules} reads it), saved whole by the editor.
 */
@Entity
@Table(name = "quizzes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Quiz {
	@Id
	@Column(name = "content_item_id")
	private UUID contentItemId;

	/** Minutes; null: no timer. */
	@Column(name = "time_limit_min")
	private Integer timeLimitMin;

	@Column(nullable = false)
	@Default
	private int attemptsAllowed = 1;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 8)
	@Default
	private ScorePolicy scorePolicy = ScorePolicy.BEST;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 16)
	@Default
	private AnswersShown answersShown = AnswersShown.AFTER_DEADLINE;

	@Column(nullable = false)
	private boolean shuffle;

	@Column(nullable = false)
	private boolean mcqOnly;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb", nullable = false)
	private JsonNode questions;

	/** Set when a pupil first starts it: the questions can no longer change. */
	private Instant lockedAt;
}
