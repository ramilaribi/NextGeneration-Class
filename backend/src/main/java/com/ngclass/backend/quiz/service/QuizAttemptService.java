package com.ngclass.backend.quiz.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.content.domain.ContentItem;
import com.ngclass.backend.content.repository.ContentItemRepository;
import com.ngclass.backend.groups.domain.ClassGroup;
import com.ngclass.backend.groups.repository.ClassGroupRepository;
import com.ngclass.backend.notifications.service.NotificationService;
import com.ngclass.backend.people.domain.Student;
import com.ngclass.backend.people.repository.StudentRepository;
import com.ngclass.backend.people.service.FamilyAccess;
import com.ngclass.backend.quiz.domain.AnswersShown;
import com.ngclass.backend.quiz.domain.QuestionType;
import com.ngclass.backend.quiz.domain.Quiz;
import com.ngclass.backend.quiz.domain.QuizAttempt;
import com.ngclass.backend.quiz.domain.ScorePolicy;
import com.ngclass.backend.quiz.dto.QuizDtos.AttemptPlay;
import com.ngclass.backend.quiz.dto.QuizDtos.AttemptReview;
import com.ngclass.backend.quiz.dto.QuizDtos.AttemptSummary;
import com.ngclass.backend.quiz.dto.QuizDtos.MyQuiz;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizCorrection;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizCorrectionRequest;
import com.ngclass.backend.quiz.dto.QuizDtos.ReviewItem;
import com.ngclass.backend.quiz.repository.QuizAttemptRepository;
import com.ngclass.backend.quiz.repository.QuizRepository;
import com.ngclass.backend.work.domain.Assignment;
import com.ngclass.backend.work.domain.AssignmentRecipient;
import com.ngclass.backend.work.domain.HomeworkStatus;
import com.ngclass.backend.work.domain.SubmissionMode;
import com.ngclass.backend.work.repository.AssignmentRecipientRepository;
import com.ngclass.backend.work.repository.AssignmentRepository;
import com.ngclass.backend.work.service.Grades;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Quizzes given as homework (release 3, design r3/SeriesQuizPhone.png, business rules 4): the pupil (or a
 * parent for the child) starts an attempt, every answer is saved at once, the server ends the attempt when its
 * time is up, grades it, and the teacher scores the open questions in "À corriger".
 */
@Service
@RequiredArgsConstructor
public class QuizAttemptService {
	/** Business rules 4: a submission this late after the timer still counts, with what was saved. */
	static final Duration TOLERANCE = Duration.ofSeconds(30);
	static final int MAX_ANSWER = 2000;

	private final FamilyAccess family;
	private final AssignmentRepository assignments;
	private final AssignmentRecipientRepository recipients;
	private final ContentItemRepository items;
	private final QuizRepository quizzes;
	private final QuizAttemptRepository attempts;
	private final ClassGroupRepository groups;
	private final StudentRepository students;
	private final NotificationService notifications;
	private final QuizService quizService;
	private final CurrentTeacher teacher;
	private final Clock clock;

	// ── The pupil's side ──

	/** The quiz, its attempts, the one open if any. An attempt whose time is up is sent first. */
	@Transactional
	public MyQuiz mine(AuthenticatedUser user, UUID assignmentId, UUID studentId) {
		Context c = context(user, assignmentId, studentId);
		Instant now = clock.instant();
		closeIfOver(c, now);
		return myQuiz(c, now);
	}

	/** The open attempt, or a new one when one is left. The quiz's questions are locked from now on. */
	@Transactional
	public AttemptPlay start(AuthenticatedUser user, UUID assignmentId, UUID studentId) {
		Context c = context(user, assignmentId, studentId);
		Instant now = clock.instant();
		closeIfOver(c, now);
		List<QuizAttempt> list = attempts.findByRecipientIdOrderByAttemptNoAsc(c.recipient().getId());
		QuizAttempt open = list.stream().filter(a -> !a.isSubmitted()).findFirst().orElse(null);
		if (open != null) {
			return play(c, open);
		}
		String refused = refusal(c, list, now);
		if (refused != null) {
			throw new ApiException(HttpStatus.CONFLICT, refused);
		}
		QuizRules.requireComplete(c.quiz().getQuestions());
		List<String> order = new ArrayList<>();
		c.quiz().getQuestions().forEach(q -> order.add(q.path("id").asText()));
		if (c.quiz().isShuffle()) {
			Collections.shuffle(order);
		}
		ArrayNode orderJson = JsonNodeFactory.instance.arrayNode();
		order.forEach(orderJson::add);
		QuizAttempt attempt = attempts.saveAndFlush(QuizAttempt.builder()
				.recipientId(c.recipient().getId())
				.attemptNo(list.size() + 1)
				.startedAt(now)
				.questionOrder(orderJson)
				.answers(JsonNodeFactory.instance.objectNode())
				.startedBy(user.id())
				.build());
		if (c.quiz().getLockedAt() == null) {
			c.quiz().setLockedAt(now);
			quizzes.saveAndFlush(c.quiz());
		}
		return play(c, attempt);
	}

	/** Answers by question id, merged into what was saved. After the time is up the attempt is sent instead. */
	@Transactional(noRollbackFor = ApiException.class)
	public void saveAnswers(AuthenticatedUser user, UUID assignmentId, UUID studentId, UUID attemptId, JsonNode answers) {
		Context c = context(user, assignmentId, studentId);
		QuizAttempt attempt = attemptOf(c, attemptId);
		if (attempt.isSubmitted()) {
			throw new ApiException(HttpStatus.CONFLICT, "quiz_already_sent");
		}
		Instant now = clock.instant();
		if (over(c, attempt, now)) {
			finish(c, attempt, now, true);
			throw new ApiException(HttpStatus.CONFLICT, "quiz_time_over");
		}
		if (answers == null || !answers.isObject()) {
			throw ApiException.badRequest("quiz_invalid");
		}
		Map<String, JsonNode> byId = QuizRules.byId(c.quiz().getQuestions());
		ObjectNode saved = ((ObjectNode) attempt.getAnswers()).deepCopy();
		answers.fields().forEachRemaining(entry -> {
			JsonNode q = byId.get(entry.getKey());
			if (q != null) {
				saved.set(entry.getKey(), cleaned(q, entry.getValue()));
			}
		});
		attempt.setAnswers(saved);
		attempts.saveAndFlush(attempt);
	}

	/** Sends the attempt: graded at once, open questions wait for the teacher. Sending twice changes nothing. */
	@Transactional
	public AttemptReview submit(AuthenticatedUser user, UUID assignmentId, UUID studentId, UUID attemptId) {
		Context c = context(user, assignmentId, studentId);
		QuizAttempt attempt = attemptOf(c, attemptId);
		Instant now = clock.instant();
		if (!attempt.isSubmitted()) {
			finish(c, attempt, now, true);
		}
		return review(c, attempt, shownToPupil(c, now));
	}

	@Transactional(readOnly = true)
	public AttemptReview attempt(AuthenticatedUser user, UUID assignmentId, UUID studentId, UUID attemptId) {
		Context c = context(user, assignmentId, studentId);
		QuizAttempt attempt = attemptOf(c, attemptId);
		if (!attempt.isSubmitted()) {
			throw ApiException.notFound("attempt_not_found");
		}
		return review(c, attempt, shownToPupil(c, clock.instant()));
	}

	// ── The teacher's side ──

	/** One pupil's attempts; [attemptId] null: the one waiting for correction, or else the last one sent. */
	@Transactional(readOnly = true)
	public QuizCorrection correction(UUID assignmentId, UUID studentId, UUID attemptId) {
		Context c = teacherContext(assignmentId, studentId);
		List<QuizAttempt> sent = attempts.findByRecipientIdOrderByAttemptNoAsc(c.recipient().getId()).stream().filter(QuizAttempt::isSubmitted).toList();
		QuizAttempt shown = attemptId != null
				? sent.stream().filter(a -> a.getId().equals(attemptId)).findFirst().orElseThrow(() -> ApiException.notFound("attempt_not_found"))
				: sent.stream().filter(QuizAttempt::isNeedsManual).findFirst().orElse(sent.isEmpty() ? null : sent.getLast());
		return correctionView(c, sent, shown);
	}

	/** Scores the open questions of one attempt (half points); once all have points, the grade counts. */
	@Transactional
	public QuizCorrection correct(UUID assignmentId, UUID studentId, UUID attemptId, QuizCorrectionRequest request) {
		Context c = teacherContext(assignmentId, studentId);
		QuizAttempt attempt = attemptOf(c, attemptId);
		if (!attempt.isSubmitted()) {
			throw new ApiException(HttpStatus.CONFLICT, "not_submitted_yet");
		}
		Map<String, JsonNode> byId = QuizRules.byId(c.quiz().getQuestions());
		ObjectNode scores = ((ObjectNode) attempt.getScores()).deepCopy();
		for (Map.Entry<String, BigDecimal> entry : request.scores().entrySet()) {
			JsonNode q = byId.get(entry.getKey());
			if (q == null || QuizRules.type(q) != QuestionType.OPEN) {
				throw ApiException.badRequest("quiz_invalid");
			}
			if (entry.getValue() == null) {
				scores.putNull(entry.getKey());
			} else {
				scores.put(entry.getKey(), Grades.checked(entry.getValue(), QuizRules.points(q)));
			}
		}
		attempt.setScores(scores);
		boolean waiting = QuizGrader.waiting(c.quiz().getQuestions(), scores);
		attempt.setNeedsManual(waiting);
		attempt.setScore(waiting ? null : QuizGrader.sum(scores));
		attempts.saveAndFlush(attempt);
		AssignmentRecipient recipient = c.recipient();
		recipient.setComment(request.comment() == null || request.comment().isBlank() ? null : request.comment().trim());
		settle(c, false);
		List<QuizAttempt> sent = attempts.findByRecipientIdOrderByAttemptNoAsc(recipient.getId()).stream().filter(QuizAttempt::isSubmitted).toList();
		return correctionView(c, sent, attempt);
	}

	// ── Shared with the homework lists ──

	/** The last attempt sent of each pupil, by recipient id: "Voir le rendu", "À corriger" and Résultats. */
	public Map<UUID, QuizAttempt> lastSent(Collection<UUID> recipientIds) {
		Map<UUID, QuizAttempt> out = new HashMap<>();
		if (recipientIds.isEmpty()) {
			return out;
		}
		for (QuizAttempt a : attempts.findByRecipientIdInOrderByAttemptNoAsc(recipientIds)) {
			if (a.isSubmitted()) {
				out.put(a.getRecipientId(), a);
			}
		}
		return out;
	}

	/** The job: sends every attempt whose time is up (the pupil may have closed the app). */
	@Transactional
	public int closeOverdue() {
		Instant now = clock.instant();
		int closed = 0;
		for (QuizAttempt attempt : attempts.findOpen(now)) {
			AssignmentRecipient recipient = recipients.findById(attempt.getRecipientId()).orElse(null);
			if (recipient == null) {
				continue;
			}
			Assignment assignment = assignments.findById(recipient.getAssignmentId()).orElseThrow();
			Quiz quiz = quizzes.findById(assignment.getContentItemId()).orElse(null);
			if (quiz == null) {
				continue;
			}
			Context c = new Context(assignment, recipient, quiz, null);
			if (over(c, attempt, now)) {
				finish(c, attempt, now, true);
				closed++;
			}
		}
		return closed;
	}

	// ── Private ──

	private record Context(Assignment assignment, AssignmentRecipient recipient, Quiz quiz, ContentItem item) {
	}

	private Context context(AuthenticatedUser user, UUID assignmentId, UUID studentId) {
		Student child = family.child(user, studentId);
		AssignmentRecipient recipient = recipients.findByAssignmentIdAndStudentId(assignmentId, child.getId())
				.orElseThrow(() -> ApiException.notFound("assignment_not_found"));
		return contextOf(assignments.findById(assignmentId).orElseThrow(), recipient);
	}

	private Context teacherContext(UUID assignmentId, UUID studentId) {
		Assignment assignment = assignments.findByIdAndTeacherId(assignmentId, teacher.id())
				.orElseThrow(() -> ApiException.notFound("assignment_not_found"));
		AssignmentRecipient recipient = recipients.findByAssignmentIdAndStudentId(assignmentId, studentId)
				.orElseThrow(() -> ApiException.notFound("student_not_found"));
		return contextOf(assignment, recipient);
	}

	private Context contextOf(Assignment assignment, AssignmentRecipient recipient) {
		if (assignment.getSubmissionMode() != SubmissionMode.QUIZ) {
			throw ApiException.notFound("assignment_not_found");
		}
		ContentItem item = items.findById(assignment.getContentItemId()).orElseThrow();
		return new Context(assignment, recipient, quizService.quizOf(item), item);
	}

	private QuizAttempt attemptOf(Context c, UUID attemptId) {
		QuizAttempt attempt = attempts.findById(attemptId).orElseThrow(() -> ApiException.notFound("attempt_not_found"));
		if (!attempt.getRecipientId().equals(c.recipient().getId())) {
			throw ApiException.notFound("attempt_not_found");
		}
		return attempt;
	}

	/** Why a new attempt cannot start, or null. */
	private static String refusal(Context c, List<QuizAttempt> list, Instant now) {
		Assignment a = c.assignment();
		if (a.getClosedAt() != null) {
			return "assignment_closed";
		}
		if (!a.getDeadlineAt().isAfter(now) && !a.isAllowLate()) {
			return "deadline_passed";
		}
		if (list.size() >= c.quiz().getAttemptsAllowed()) {
			return "quiz_no_attempt_left";
		}
		return null;
	}

	/**
	 * When a timed quiz's timer shows zero: its time limit, or the deadline if that comes first and late work
	 * is refused. Null without a time limit.
	 */
	private static Instant endsAt(Context c, QuizAttempt attempt) {
		if (c.quiz().getTimeLimitMin() == null) {
			return null;
		}
		Instant end = attempt.getStartedAt().plus(Duration.ofMinutes(c.quiz().getTimeLimitMin()));
		Assignment a = c.assignment();
		if (!a.isAllowLate() && a.getDeadlineAt().isAfter(attempt.getStartedAt()) && a.getDeadlineAt().isBefore(end)) {
			end = a.getDeadlineAt();
		}
		return end;
	}

	/** Time up (with the tolerance), past a deadline that refuses late work, or the homework closed. */
	private static boolean over(Context c, QuizAttempt attempt, Instant now) {
		Assignment a = c.assignment();
		if (a.getClosedAt() != null) {
			return true;
		}
		if (c.quiz().getTimeLimitMin() != null
				&& now.isAfter(attempt.getStartedAt().plus(Duration.ofMinutes(c.quiz().getTimeLimitMin())).plus(TOLERANCE))) {
			return true;
		}
		return !a.isAllowLate() && now.isAfter(a.getDeadlineAt().plus(TOLERANCE));
	}

	private void closeIfOver(Context c, Instant now) {
		for (QuizAttempt attempt : attempts.findByRecipientIdOrderByAttemptNoAsc(c.recipient().getId())) {
			if (!attempt.isSubmitted() && over(c, attempt, now)) {
				finish(c, attempt, now, true);
			}
		}
	}

	/** Grades and sends the attempt, then the pupil's status and kept grade follow. */
	private void finish(Context c, QuizAttempt attempt, Instant now, boolean byPupil) {
		JsonNode questions = c.quiz().getQuestions();
		ObjectNode scores = QuizGrader.scores(questions, attempt.getAnswers());
		boolean waiting = QuizGrader.waiting(questions, scores);
		attempt.setScores(scores);
		attempt.setAutoScore(QuizGrader.sum(scores));
		attempt.setNeedsManual(waiting);
		attempt.setScore(waiting ? null : QuizGrader.sum(scores));
		attempt.setSubmittedAt(now);
		attempt.setLate(now.isAfter(c.assignment().getDeadlineAt()));
		attempts.saveAndFlush(attempt);
		settle(c, byPupil);
	}

	/**
	 * The pupil's homework status from their attempts: the last one sent waits for the teacher (SUBMITTED or
	 * LATE), or every one has its grade (CORRECTED, with the best or the last as the quiz says).
	 */
	private void settle(Context c, boolean byPupil) {
		AssignmentRecipient recipient = c.recipient();
		List<QuizAttempt> sent = attempts.findByRecipientIdOrderByAttemptNoAsc(recipient.getId()).stream().filter(QuizAttempt::isSubmitted).toList();
		if (sent.isEmpty()) {
			return;
		}
		Instant now = clock.instant();
		QuizAttempt last = sent.getLast();
		ClassGroup group = groups.findById(c.assignment().getGroupId()).orElseThrow();
		if (last.isNeedsManual()) {
			HomeworkStatus status = last.isLate() ? HomeworkStatus.LATE : HomeworkStatus.SUBMITTED;
			if (recipient.getStatus() != status) {
				recipient.setStatus(status);
				recipient.setStatusChangedAt(now);
			}
			recipients.saveAndFlush(recipient);
			if (byPupil) {
				notifications.workSubmitted(c.assignment().getTeacherId(), group, c.assignment().getId(), c.assignment().getTitle(),
						c.assignment().getDeadlineAt(), students.findById(recipient.getStudentId()).orElseThrow(), last.isLate());
			}
			return;
		}
		BigDecimal kept = kept(c.quiz().getScorePolicy(), sent);
		boolean first = recipient.getStatus() != HomeworkStatus.CORRECTED;
		recipient.setScore(kept);
		recipient.setStatus(HomeworkStatus.CORRECTED);
		recipient.setStatusChangedAt(now);
		recipient.setCorrectedAt(now);
		recipients.saveAndFlush(recipient);
		if (first) {
			notifications.homeworkCorrected(group, recipient.getStudentId(), c.assignment().getId(), c.assignment().getTitle(),
					c.assignment().getDeadlineAt());
		}
	}

	static BigDecimal kept(ScorePolicy policy, List<QuizAttempt> sent) {
		List<BigDecimal> graded = sent.stream().map(QuizAttempt::getScore).filter(Objects::nonNull).toList();
		if (graded.isEmpty()) {
			return null;
		}
		return policy == ScorePolicy.LAST ? graded.getLast() : graded.stream().max(Comparator.naturalOrder()).orElseThrow();
	}

	/** Only what this question type takes, and not too long. */
	private static JsonNode cleaned(JsonNode question, JsonNode answer) {
		ObjectNode out = JsonNodeFactory.instance.objectNode();
		if (answer == null || !answer.isObject()) {
			return out;
		}
		switch (QuizRules.type(question)) {
			case MCQ -> {
				if (answer.path("choice").isTextual()) {
					out.put("choice", answer.path("choice").asText());
				}
			}
			case TRUE_FALSE -> {
				if (answer.path("value").isBoolean()) {
					out.put("value", answer.path("value").asBoolean());
				}
			}
			case SHORT, OPEN -> out.put("text", cut(answer.path("text").asText("")));
			case BLANKS -> {
				ObjectNode blanks = out.putObject("blanks");
				for (String id : QuizRules.blanks(question).keySet()) {
					if (answer.path("blanks").path(id).isTextual()) {
						blanks.put(id, cut(answer.path("blanks").path(id).asText()));
					}
				}
			}
		}
		return out;
	}

	private static String cut(String value) {
		return value.length() > MAX_ANSWER ? value.substring(0, MAX_ANSWER) : value;
	}

	/** After sending, after the deadline (or once closed), or never, as the quiz says. */
	private static boolean shownToPupil(Context c, Instant now) {
		return switch (c.quiz().getAnswersShown()) {
			case AFTER_SUBMIT -> true;
			case AFTER_DEADLINE -> c.assignment().getClosedAt() != null || !c.assignment().getDeadlineAt().isAfter(now);
			case NEVER -> false;
		};
	}

	private MyQuiz myQuiz(Context c, Instant now) {
		List<QuizAttempt> list = attempts.findByRecipientIdOrderByAttemptNoAsc(c.recipient().getId());
		QuizAttempt open = list.stream().filter(a -> !a.isSubmitted()).findFirst().orElse(null);
		JsonNode questions = c.quiz().getQuestions();
		return new MyQuiz(
				c.assignment().getId(),
				c.assignment().getTitle(),
				c.assignment().getDeadlineAt(),
				c.quiz().getTimeLimitMin(),
				c.quiz().getAttemptsAllowed(),
				c.quiz().getScorePolicy().name(),
				c.quiz().getAnswersShown().name(),
				questions.size(),
				QuizRules.totalPoints(questions),
				list.stream().filter(QuizAttempt::isSubmitted).map(QuizAttemptService::summary).toList(),
				open == null ? null : play(c, open),
				open == null && refusal(c, list, now) == null,
				c.recipient().getStatus() == HomeworkStatus.CORRECTED ? c.recipient().getScore() : null);
	}

	private AttemptPlay play(Context c, QuizAttempt attempt) {
		JsonNode questions = c.quiz().getQuestions();
		return new AttemptPlay(
				attempt.getId(),
				attempt.getAttemptNo(),
				attempt.getStartedAt(),
				endsAt(c, attempt),
				QuizService.forPupil(questions, attempt.getQuestionOrder()),
				attempt.getAnswers(),
				quizService.pictureUrls(item(c), questions));
	}

	private ContentItem item(Context c) {
		return c.item() != null ? c.item() : items.findById(c.assignment().getContentItemId()).orElseThrow();
	}

	static AttemptSummary summary(QuizAttempt a) {
		return new AttemptSummary(a.getId(), a.getAttemptNo(), a.getStartedAt(), a.getSubmittedAt(), a.isLate(), a.getAutoScore(), a.getScore(),
				a.isNeedsManual());
	}

	/** Each question in the pupil's order, with what was given and its points. */
	private AttemptReview review(Context c, QuizAttempt attempt, boolean full) {
		JsonNode questions = c.quiz().getQuestions();
		Map<String, JsonNode> byId = QuizRules.byId(questions);
		List<ReviewItem> out = new ArrayList<>();
		int number = 0;
		JsonNode scores = attempt.getScores() == null ? JsonNodeFactory.instance.objectNode() : attempt.getScores();
		for (JsonNode id : attempt.getQuestionOrder()) {
			JsonNode q = byId.get(id.asText());
			if (q == null) {
				continue;
			}
			number++;
			JsonNode s = scores.path(id.asText());
			BigDecimal points = s.isNumber() ? s.decimalValue() : null;
			int max = QuizRules.points(q);
			Boolean right = points == null ? null : points.compareTo(BigDecimal.valueOf(max)) == 0;
			out.add(new ReviewItem(number, full ? q : QuizRules.forPupil(q), attempt.getAnswers().get(id.asText()), points, max, right));
		}
		return new AttemptReview(
				attempt.getId(),
				attempt.getAttemptNo(),
				attempt.getSubmittedAt(),
				attempt.isLate(),
				attempt.getScore(),
				attempt.getAutoScore(),
				QuizRules.totalPoints(questions),
				attempt.isNeedsManual(),
				full,
				out,
				quizService.pictureUrls(item(c), questions));
	}

	private QuizCorrection correctionView(Context c, List<QuizAttempt> sent, QuizAttempt shown) {
		Student student = students.findById(c.recipient().getStudentId()).orElseThrow();
		Instant now = clock.instant();
		return new QuizCorrection(
				c.assignment().getId(),
				student.getId(),
				student.getUser().getFirstName(),
				student.getUser().getLastName(),
				c.recipient().statusAt(c.assignment(), now).name(),
				QuizRules.totalPoints(c.quiz().getQuestions()),
				sent.stream().map(QuizAttemptService::summary).toList(),
				shown == null ? null : review(c, shown, true),
				c.recipient().getComment());
	}
}
