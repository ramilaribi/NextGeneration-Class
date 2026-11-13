package com.ngclass.backend.quiz.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ngclass.backend.quiz.domain.QuestionType;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Quiz scoring (business rules 4). Multiple choice and true/false: all or nothing, no negative marking. Short
 * answer: full points when the normalized answer is one of the accepted ones. Gaps: the points split equally
 * between them, rounded to a quarter point. Open questions: null, the teacher scores them.
 *
 * <p>An answer, by question id: {"choice": "c1"}, {"value": true}, {"text": "2,5"}, {"blanks": {"b1": "..."}}.
 */
public final class QuizGrader {
	private static final Pattern MARKS = Pattern.compile("\\p{M}+");
	private static final Pattern SPACES = Pattern.compile("\\s+");
	private static final Pattern DECIMAL_COMMA = Pattern.compile("(\\d)\\s*,\\s*(\\d)");
	private static final BigDecimal QUARTER = new BigDecimal("0.25");

	private QuizGrader() {
	}

	/** Lower case, accents removed, spaces trimmed and collapsed, the final full stop removed, 2,5 read as 2.5. */
	public static String normalize(String value) {
		if (value == null) {
			return "";
		}
		String out = Normalizer.normalize(value, Normalizer.Form.NFD);
		out = MARKS.matcher(out).replaceAll("");
		out = out.toLowerCase(Locale.ROOT);
		out = SPACES.matcher(out).replaceAll(" ").trim();
		while (out.endsWith(".")) {
			out = out.substring(0, out.length() - 1).trim();
		}
		out = DECIMAL_COMMA.matcher(out).replaceAll("$1.$2");
		return out;
	}

	static boolean matches(String answer, List<String> accepted) {
		String given = normalize(answer);
		if (given.isEmpty()) {
			return false;
		}
		return accepted.stream().map(QuizGrader::normalize).anyMatch(given::equals);
	}

	/** The points of one answer, or null for an open question. */
	public static BigDecimal score(JsonNode question, JsonNode answer) {
		int points = QuizRules.points(question);
		JsonNode given = answer == null ? JsonNodeFactory.instance.objectNode() : answer;
		return switch (QuizRules.type(question)) {
			case MCQ -> all(points, given.path("choice").isTextual() && given.path("choice").asText().equals(question.path("correct").asText(null)));
			case TRUE_FALSE -> all(points, given.path("value").isBoolean() && question.path("answer").isBoolean()
					&& given.path("value").asBoolean() == question.path("answer").asBoolean());
			case SHORT -> all(points, matches(given.path("text").asText(""), QuizRules.accepted(question.path("accepted"))));
			case BLANKS -> blanks(question, given.path("blanks"), points);
			case OPEN -> null;
		};
	}

	/** Each right gap gets its share; every gap right gets the whole question, whatever the rounding. */
	private static BigDecimal blanks(JsonNode question, JsonNode given, int points) {
		Map<String, List<String>> blanks = QuizRules.blanks(question);
		if (blanks.isEmpty()) {
			return BigDecimal.ZERO;
		}
		int right = 0;
		for (Map.Entry<String, List<String>> blank : blanks.entrySet()) {
			if (matches(given.path(blank.getKey()).asText(""), blank.getValue())) {
				right++;
			}
		}
		if (right == blanks.size()) {
			return BigDecimal.valueOf(points);
		}
		BigDecimal share = BigDecimal.valueOf(points).divide(BigDecimal.valueOf(blanks.size()), 4, RoundingMode.HALF_UP);
		BigDecimal quarters = share.divide(QUARTER, 0, RoundingMode.HALF_UP).multiply(QUARTER);
		return quarters.multiply(BigDecimal.valueOf(right)).min(BigDecimal.valueOf(points)).stripTrailingZeros();
	}

	private static BigDecimal all(int points, boolean right) {
		return right ? BigDecimal.valueOf(points) : BigDecimal.ZERO;
	}

	/** Each question's points (null: open, waiting for the teacher), by question id. */
	public static ObjectNode scores(JsonNode questions, JsonNode answers) {
		ObjectNode out = JsonNodeFactory.instance.objectNode();
		for (JsonNode q : questions) {
			String id = q.path("id").asText();
			BigDecimal score = score(q, answers.get(id));
			if (score == null) {
				out.putNull(id);
			} else {
				out.put(id, score);
			}
		}
		return out;
	}

	/** The sum of the points known so far. */
	public static BigDecimal sum(JsonNode scores) {
		BigDecimal total = BigDecimal.ZERO;
		for (JsonNode s : scores) {
			if (s.isNumber()) {
				total = total.add(s.decimalValue());
			}
		}
		return total;
	}

	public static boolean waiting(JsonNode questions, JsonNode scores) {
		for (JsonNode q : questions) {
			if (QuizRules.type(q) == QuestionType.OPEN && !scores.path(q.path("id").asText()).isNumber()) {
				return true;
			}
		}
		return false;
	}
}
