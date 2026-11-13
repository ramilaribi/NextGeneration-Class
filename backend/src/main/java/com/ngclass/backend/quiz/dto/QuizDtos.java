package com.ngclass.backend.quiz.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.ngclass.backend.content.dto.ContentDtos.ContentItemResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Quizzes and QCM (release 3, spec 05): the teacher's builder, the pupil's attempts, the teacher's correction. */
public final class QuizDtos {
	private QuizDtos() {
	}

	// ── The builder ──

	/** [mcqOnly]: made from "Créer > QCM". */
	public record QuizCreate(
			@NotBlank @Size(max = 160) String title,
			@NotNull UUID subjectId,
			@NotNull UUID levelId,
			UUID chapterId,
			boolean mcqOnly) {
	}

	/** [timeLimitMin] null: no timer. [scorePolicy] BEST or LAST. [answersShown] AFTER_DEADLINE, AFTER_SUBMIT or NEVER. */
	public record QuizSettings(
			@Min(1) @Max(300) Integer timeLimitMin,
			@Min(1) @Max(10) int attemptsAllowed,
			@NotBlank String scorePolicy,
			@NotBlank String answersShown,
			boolean shuffle) {
	}

	/** Saved whole by the editor; [questions] is refused once the quiz is locked, unless unchanged. */
	public record QuizSave(@NotNull @Valid QuizSettings settings, @NotNull JsonNode questions) {
	}

	/**
	 * [locked]: a pupil started it, the questions no longer change. [totalPoints], [questionCount],
	 * [openCount] computed. [pictureUrls] by picture id, for the pictures inside the questions.
	 */
	public record QuizResponse(
			ContentItemResponse item,
			QuizSettings settings,
			boolean mcqOnly,
			boolean locked,
			JsonNode questions,
			int totalPoints,
			int questionCount,
			int openCount,
			Map<UUID, String> pictureUrls) {
	}

	/** "Aperçu élève": the answers given in the preview, graded but never saved. */
	public record PreviewRequest(@NotNull JsonNode answers) {
	}

	// ── The pupil's side ──

	/** [pending]: open questions waiting for the teacher. [score] out of [maxScore] once every question has points. */
	public record AttemptSummary(UUID id, int number, Instant startedAt, Instant submittedAt, boolean late, BigDecimal autoScore,
			BigDecimal score, boolean pending) {
	}

	/**
	 * The attempt being taken. [endsAt]: when the timer stops it (null without a timer); the server is the
	 * judge. [questions] in this pupil's order, without their answers.
	 */
	public record AttemptPlay(UUID id, int number, Instant startedAt, Instant endsAt, List<JsonNode> questions, JsonNode answers,
			Map<UUID, String> pictureUrls) {
	}

	/**
	 * A quiz given as homework, for the pupil or the parent. [canStart]: an attempt is left, it is open and in
	 * time. [current]: the attempt not sent yet, if any. [kept]: the grade that counts.
	 */
	public record MyQuiz(
			UUID assignmentId,
			String title,
			Instant deadlineAt,
			Integer timeLimitMin,
			int attemptsAllowed,
			String scorePolicy,
			String answersShown,
			int questionCount,
			int totalPoints,
			List<AttemptSummary> attempts,
			AttemptPlay current,
			boolean canStart,
			BigDecimal kept) {
	}

	/** Answers saved as the pupil goes, by question id; merged into what was saved before. */
	public record AnswersSave(@NotNull JsonNode answers) {
	}

	/**
	 * One question after sending. [question] without its answers unless [answersShown]; [answer] what was
	 * given; [points] null for an open question not corrected; [right] null for an open question.
	 */
	public record ReviewItem(int number, JsonNode question, JsonNode answer, BigDecimal points, int maxPoints, Boolean right) {
	}

	/** An attempt sent: its grade and each question. */
	public record AttemptReview(
			UUID id,
			int number,
			Instant submittedAt,
			boolean late,
			BigDecimal score,
			BigDecimal autoScore,
			int maxScore,
			boolean pending,
			boolean answersShown,
			List<ReviewItem> items,
			Map<UUID, String> pictureUrls) {
	}

	// ── The teacher's correction ──

	/** [scores]: the open questions' points, by question id, in half points. */
	public record QuizCorrectionRequest(@NotNull Map<String, BigDecimal> scores, @Size(max = 2000) String comment) {
	}

	/** One pupil's attempts at a quiz homework, the one shown with every answer. */
	public record QuizCorrection(
			UUID assignmentId,
			UUID studentId,
			String firstName,
			String lastName,
			String status,
			int maxScore,
			List<AttemptSummary> attempts,
			AttemptReview attempt,
			String comment) {
	}
}
