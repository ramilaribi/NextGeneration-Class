package com.ngclass.backend.quiz.domain;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * One pupil's attempt at a quiz given as homework. [answers] by question id, saved as the pupil goes;
 * [scores] by question id once sent (null for an open question until the teacher corrects it).
 */
@Entity
@Table(name = "quiz_attempts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizAttempt {
	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	private UUID id;

	@Column(nullable = false)
	private UUID recipientId;

	@Column(nullable = false)
	private int attemptNo;

	@Column(nullable = false)
	private Instant startedAt;

	private Instant submittedAt;

	@Column(name = "is_late", nullable = false)
	private boolean late;

	/** The question ids in the order this pupil sees them (shuffled when the quiz says so). */
	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb", nullable = false)
	private JsonNode questionOrder;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb", nullable = false)
	private JsonNode answers;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "jsonb")
	private JsonNode scores;

	/** The points of the questions corrected by the server. */
	@Column(precision = 6, scale = 2)
	private BigDecimal autoScore;

	/** Every question has its points: the attempt's grade, out of the quiz's total. */
	@Column(precision = 6, scale = 2)
	private BigDecimal score;

	/** Open questions wait for the teacher ("À corriger"). */
	@Column(nullable = false)
	private boolean needsManual;

	@Column(nullable = false)
	private UUID startedBy;

	public boolean isSubmitted() {
		return submittedAt != null;
	}
}
