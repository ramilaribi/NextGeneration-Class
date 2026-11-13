package com.ngclass.backend.quiz.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.content.domain.ContentItem;
import com.ngclass.backend.content.domain.ContentShare;
import com.ngclass.backend.content.domain.ContentStatus;
import com.ngclass.backend.content.domain.ContentTag;
import com.ngclass.backend.content.domain.ContentType;
import com.ngclass.backend.content.dto.ContentDtos.ContentItemResponse;
import com.ngclass.backend.content.repository.ContentItemRepository;
import com.ngclass.backend.content.repository.ContentShareRepository;
import com.ngclass.backend.content.service.ContentService;
import com.ngclass.backend.content.service.PageService;
import com.ngclass.backend.quiz.domain.AnswersShown;
import com.ngclass.backend.quiz.domain.Quiz;
import com.ngclass.backend.quiz.domain.ScorePolicy;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizCreate;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizResponse;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizSave;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizSettings;
import com.ngclass.backend.quiz.dto.QuizDtos.ReviewItem;
import com.ngclass.backend.quiz.repository.QuizRepository;
import com.ngclass.backend.work.domain.Assignment;
import com.ngclass.backend.work.repository.AssignmentRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The teacher's quiz builder (release 3, design r3/QuizEditeur.png). Like a page, the editor saves the
 * whole quiz on its own; publishing and giving as homework are the library's and the homework's.
 */
@Service
@RequiredArgsConstructor
public class QuizService {
	private final ContentService contents;
	private final ContentItemRepository items;
	private final ContentShareRepository shares;
	private final QuizRepository quizzes;
	private final AssignmentRepository assignments;
	private final PageService pages;
	private final CurrentTeacher teacher;
	private final Clock clock;

	@Transactional
	public QuizResponse create(QuizCreate request) {
		contents.placement(request.subjectId(), request.levelId(), request.chapterId());
		ContentItem item = items.saveAndFlush(ContentItem.builder()
				.teacherId(teacher.id())
				.type(ContentType.QUIZ)
				.title(request.title().trim())
				.subjectId(request.subjectId())
				.levelId(request.levelId())
				.chapterId(request.chapterId())
				.status(ContentStatus.DRAFT)
				.tag(ContentTag.AUTRE)
				.build());
		Quiz quiz = quizzes.saveAndFlush(Quiz.builder()
				.contentItemId(item.getId())
				.mcqOnly(request.mcqOnly())
				.questions(JsonNodeFactory.instance.arrayNode())
				.build());
		return response(item, quiz);
	}

	@Transactional(readOnly = true)
	public QuizResponse quiz(UUID id) {
		ContentItem item = own(id);
		return response(item, quizOf(item));
	}

	/**
	 * Settings and questions, whole. Once a pupil started it the questions stay as they are (a save that
	 * brings them unchanged is fine): "Dupliquer" makes a new version.
	 */
	@Transactional
	public QuizResponse save(UUID id, QuizSave request) {
		ContentItem item = own(id);
		Quiz quiz = quizOf(item);
		JsonNode questions = QuizRules.checkedDraft(request.questions());
		if (quiz.getLockedAt() != null && !questions.equals(quiz.getQuestions())) {
			throw new ApiException(HttpStatus.CONFLICT, "quiz_locked");
		}
		if (item.getStatus() == ContentStatus.PUBLISHED) {
			QuizRules.requireComplete(questions);
		}
		apply(quiz, request.settings());
		quiz.setQuestions(questions);
		quizzes.saveAndFlush(quiz);
		// Homework already given, nobody started yet: its grade follows the new total.
		int total = QuizRules.totalPoints(questions);
		for (Assignment assignment : assignments.findByContentItemId(id)) {
			if (total > 0 && assignment.getMaxScore() != total) {
				assignment.setMaxScore(total);
			}
		}
		item.setUpdatedAt(clock.instant());
		items.saveAndFlush(item);
		return response(item, quiz);
	}

	/** A new draft with the same settings and questions, free to change. */
	@Transactional
	public QuizResponse duplicate(UUID id) {
		ContentItem source = own(id);
		Quiz quiz = quizOf(source);
		String title = source.getTitle() + " (copie)";
		ContentItem copy = items.saveAndFlush(ContentItem.builder()
				.teacherId(source.getTeacherId())
				.type(ContentType.QUIZ)
				.title(title.length() > 160 ? title.substring(0, 160) : title)
				.subjectId(source.getSubjectId())
				.levelId(source.getLevelId())
				.chapterId(source.getChapterId())
				.status(ContentStatus.DRAFT)
				.tag(source.getTag())
				.build());
		Quiz copied = quizzes.saveAndFlush(Quiz.builder()
				.contentItemId(copy.getId())
				.timeLimitMin(quiz.getTimeLimitMin())
				.attemptsAllowed(quiz.getAttemptsAllowed())
				.scorePolicy(quiz.getScorePolicy())
				.answersShown(quiz.getAnswersShown())
				.shuffle(quiz.isShuffle())
				.mcqOnly(quiz.isMcqOnly())
				.questions(quiz.getQuestions().deepCopy())
				.build());
		return response(copy, copied);
	}

	/** "Aperçu élève": the preview's answers graded, with every right answer; nothing is saved. */
	@Transactional(readOnly = true)
	public List<ReviewItem> preview(UUID id, JsonNode answers) {
		Quiz quiz = quizOf(own(id));
		JsonNode given = answers == null || !answers.isObject() ? JsonNodeFactory.instance.objectNode() : answers;
		List<ReviewItem> out = new ArrayList<>();
		int number = 0;
		for (JsonNode q : quiz.getQuestions()) {
			number++;
			JsonNode answer = given.get(q.path("id").asText());
			BigDecimal points = QuizGrader.score(q, answer);
			out.add(new ReviewItem(number, q, answer, points, QuizRules.points(q), points == null ? null : points.compareTo(BigDecimal.valueOf(QuizRules.points(q))) == 0));
		}
		return out;
	}

	// ── Shared ──

	/** The quiz of a library item; every QUIZ item has one. */
	public Quiz quizOf(ContentItem item) {
		if (item.getType() != ContentType.QUIZ) {
			throw ApiException.notFound("content_not_found");
		}
		return quizzes.findById(item.getId()).orElseThrow(() -> ApiException.notFound("content_not_found"));
	}

	/** Signed links to the pictures the questions show. */
	public Map<UUID, String> pictureUrls(ContentItem item, JsonNode questions) {
		List<JsonNode> texts = new ArrayList<>();
		for (JsonNode q : questions) {
			texts.add(q.path("text"));
		}
		return pages.pictureUrls(item, texts.toArray(JsonNode[]::new));
	}

	public static QuizSettings settings(Quiz quiz) {
		return new QuizSettings(quiz.getTimeLimitMin(), quiz.getAttemptsAllowed(), quiz.getScorePolicy().name(), quiz.getAnswersShown().name(),
				quiz.isShuffle());
	}

	// ── Private ──

	private ContentItem own(UUID id) {
		ContentItem item = contents.own(id);
		if (item.getType() != ContentType.QUIZ) {
			throw ApiException.notFound("content_not_found");
		}
		return item;
	}

	private static void apply(Quiz quiz, QuizSettings settings) {
		quiz.setTimeLimitMin(settings.timeLimitMin());
		quiz.setAttemptsAllowed(settings.attemptsAllowed());
		quiz.setScorePolicy(parse(ScorePolicy.class, settings.scorePolicy()));
		quiz.setAnswersShown(parse(AnswersShown.class, settings.answersShown()));
		quiz.setShuffle(settings.shuffle());
	}

	private static <E extends Enum<E>> E parse(Class<E> type, String value) {
		try {
			return Enum.valueOf(type, value.trim().toUpperCase(Locale.ROOT));
		} catch (IllegalArgumentException e) {
			throw ApiException.badRequest("quiz_invalid");
		}
	}

	private QuizResponse response(ContentItem item, Quiz quiz) {
		JsonNode questions = quiz.getQuestions();
		ContentItemResponse row = ContentService.response(item, shares.findByItemId(item.getId()).stream().map(ContentShare::getGroupId).toList());
		return new QuizResponse(row, settings(quiz), quiz.isMcqOnly(), quiz.getLockedAt() != null, questions,
				QuizRules.totalPoints(questions), questions.size(), QuizRules.openCount(questions), pictureUrls(item, questions));
	}

	/** A question list for a pupil: their order, no answers. */
	static List<JsonNode> forPupil(JsonNode questions, JsonNode order) {
		Map<String, JsonNode> byId = QuizRules.byId(questions);
		List<JsonNode> out = new ArrayList<>();
		for (JsonNode id : order) {
			JsonNode q = byId.get(id.asText());
			if (q != null) {
				out.add(QuizRules.forPupil(q));
			}
		}
		return out;
	}

	static ArrayNode ids(JsonNode questions) {
		ArrayNode out = JsonNodeFactory.instance.arrayNode();
		for (JsonNode q : questions) {
			out.add(q.path("id").asText());
		}
		return out;
	}

	static ObjectNode emptyAnswers() {
		return JsonNodeFactory.instance.objectNode();
	}
}
