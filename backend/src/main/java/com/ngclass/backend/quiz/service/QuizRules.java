package com.ngclass.backend.quiz.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.quiz.domain.QuestionType;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * How a quiz's questions are written (spec 05), one JSON object per question:
 *
 * <pre>
 * {"id": "q1", "type": "MCQ", "points": 2, "text": [Delta], "explanation": "text with $3/5$",
 *  "choices": [{"id": "c1", "text": "$2/4$"}, ...], "correct": "c1"}          multiple choice, 2 to 6 choices
 * {"type": "TRUE_FALSE", "answer": true}                                    true or false
 * {"type": "SHORT", "accepted": ["1", "4/4", "1,0"]}                         short answer
 * {"type": "BLANKS"}: the text holds {"insert": {"blank": {"id": "b1", "answers": ["numérateur"]}}}
 * {"type": "OPEN"}                                                          corrected by the teacher
 * </pre>
 *
 * The text is the page editor's Delta (formulas, tables, pictures). A draft may be incomplete; a published
 * quiz may not ({@link #requireComplete}).
 */
public final class QuizRules {
	public static final int MAX_QUESTIONS = 100;
	public static final int MAX_POINTS = 20;
	public static final int MIN_CHOICES = 2;
	public static final int MAX_CHOICES = 6;
	static final int MAX_CHARS = 400_000;
	static final int MAX_SHORT = 200;

	/** The inline embed of a gap in a BLANKS question. */
	public static final String BLANK = "blank";

	private QuizRules() {
	}

	/** The shape only: what a draft must be to be saved (an unfinished question is fine). */
	public static JsonNode checkedDraft(JsonNode questions) {
		if (questions == null || !questions.isArray()) {
			throw ApiException.badRequest("quiz_invalid");
		}
		if (questions.size() > MAX_QUESTIONS) {
			throw ApiException.badRequest("quiz_too_many_questions", MAX_QUESTIONS);
		}
		if (questions.toString().length() > MAX_CHARS) {
			throw ApiException.badRequest("page_too_long");
		}
		Set<String> ids = new HashSet<>();
		for (JsonNode q : questions) {
			if (!q.isObject() || !q.path("id").isTextual() || q.path("id").asText().isBlank() || !ids.add(q.path("id").asText())) {
				throw ApiException.badRequest("quiz_invalid");
			}
			type(q);
			int points = q.path("points").asInt(0);
			if (!q.path("points").canConvertToInt() || points < 1 || points > MAX_POINTS) {
				throw ApiException.badRequest("quiz_invalid");
			}
			JsonNode text = q.path("text");
			if (!text.isArray()) {
				throw ApiException.badRequest("quiz_invalid");
			}
			for (JsonNode op : text) {
				if (!op.isObject() || !op.has("insert")) {
					throw ApiException.badRequest("quiz_invalid");
				}
			}
			JsonNode choices = q.path("choices");
			if (!choices.isMissingNode() && !choices.isNull()) {
				if (!choices.isArray() || choices.size() > MAX_CHOICES) {
					throw ApiException.badRequest("quiz_invalid");
				}
				Set<String> choiceIds = new HashSet<>();
				for (JsonNode c : choices) {
					if (!c.isObject() || !c.path("id").isTextual() || !choiceIds.add(c.path("id").asText()) || !c.path("text").isTextual()) {
						throw ApiException.badRequest("quiz_invalid");
					}
				}
			}
		}
		return questions;
	}

	/** What a quiz must be to be published or given: every question answerable and corrected. */
	public static void requireComplete(JsonNode questions) {
		if (questions == null || !questions.isArray() || questions.isEmpty()) {
			throw ApiException.badRequest("quiz_empty");
		}
		int number = 0;
		for (JsonNode q : questions) {
			number++;
			if (!complete(q)) {
				throw ApiException.badRequest("quiz_question_incomplete", number);
			}
		}
	}

	static boolean complete(JsonNode q) {
		if (plainText(q.path("text")).isBlank() && !hasEmbed(q.path("text"))) {
			return false;
		}
		return switch (type(q)) {
			case MCQ -> {
				JsonNode choices = q.path("choices");
				if (!choices.isArray() || choices.size() < MIN_CHOICES) {
					yield false;
				}
				boolean found = false;
				for (JsonNode c : choices) {
					if (c.path("text").asText("").isBlank()) {
						yield false;
					}
					found |= c.path("id").asText().equals(q.path("correct").asText(null));
				}
				yield found;
			}
			case TRUE_FALSE -> q.path("answer").isBoolean();
			case SHORT -> !accepted(q.path("accepted")).isEmpty();
			case BLANKS -> {
				Map<String, List<String>> blanks = blanks(q);
				yield !blanks.isEmpty() && blanks.values().stream().noneMatch(List::isEmpty);
			}
			case OPEN -> true;
		};
	}

	public static QuestionType type(JsonNode q) {
		try {
			return QuestionType.valueOf(q.path("type").asText("").toUpperCase(Locale.ROOT));
		} catch (IllegalArgumentException e) {
			throw ApiException.badRequest("quiz_invalid");
		}
	}

	public static int points(JsonNode q) {
		return q.path("points").asInt(1);
	}

	/** The quiz's total, computed, never typed (spec 05). */
	public static int totalPoints(JsonNode questions) {
		int total = 0;
		for (JsonNode q : questions) {
			total += points(q);
		}
		return total;
	}

	public static int openCount(JsonNode questions) {
		int count = 0;
		for (JsonNode q : questions) {
			if (type(q) == QuestionType.OPEN) {
				count++;
			}
		}
		return count;
	}

	public static Map<String, JsonNode> byId(JsonNode questions) {
		Map<String, JsonNode> out = new LinkedHashMap<>();
		for (JsonNode q : questions) {
			out.put(q.path("id").asText(), q);
		}
		return out;
	}

	/** Each gap of a BLANKS question, in reading order, with its accepted answers. */
	public static Map<String, List<String>> blanks(JsonNode q) {
		Map<String, List<String>> out = new LinkedHashMap<>();
		for (JsonNode op : q.path("text")) {
			JsonNode blank = op.path("insert").path(BLANK);
			if (blank.isObject() && blank.path("id").isTextual()) {
				out.put(blank.path("id").asText(), accepted(blank.path("answers")));
			}
		}
		return out;
	}

	static List<String> accepted(JsonNode list) {
		List<String> out = new ArrayList<>();
		if (list.isArray()) {
			for (JsonNode a : list) {
				String value = a.asText("").trim();
				if (!value.isEmpty()) {
					out.add(value.length() > MAX_SHORT ? value.substring(0, MAX_SHORT) : value);
				}
			}
		}
		return out;
	}

	/**
	 * The question as a pupil sees it while taking the quiz: no right choice, no accepted answer, no gap's
	 * answer, no explanation.
	 */
	public static ObjectNode forPupil(JsonNode q) {
		ObjectNode out = ((ObjectNode) q).deepCopy();
		out.remove(List.of("correct", "answer", "accepted", "explanation"));
		ArrayNode text = JsonNodeFactory.instance.arrayNode();
		for (JsonNode op : q.path("text")) {
			JsonNode blank = op.path("insert").path(BLANK);
			if (blank.isObject()) {
				ObjectNode copy = ((ObjectNode) op).deepCopy();
				((ObjectNode) copy.path("insert")).set(BLANK, JsonNodeFactory.instance.objectNode().put("id", blank.path("id").asText()));
				text.add(copy);
			} else {
				text.add(op.deepCopy());
			}
		}
		out.set("text", text);
		return out;
	}

	static String plainText(JsonNode delta) {
		StringBuilder out = new StringBuilder();
		for (JsonNode op : delta) {
			if (op.path("insert").isTextual()) {
				out.append(op.path("insert").asText());
			}
		}
		return out.toString();
	}

	private static boolean hasEmbed(JsonNode delta) {
		for (JsonNode op : delta) {
			if (op.path("insert").isObject()) {
				return true;
			}
		}
		return false;
	}
}
