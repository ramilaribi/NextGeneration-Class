package com.ngclass.backend.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ngclass.backend.quiz.service.QuizGrader;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

/** Business rules 4: matching rules and scoring, without a database. */
class QuizGraderTest {
	private final ObjectMapper json = new ObjectMapper();

	@Test
	void shortAnswersIgnoreCaseAccentsSpacesTheFinalStopAndTheDecimalComma() {
		assertThat(QuizGrader.normalize(" 2.5. ")).isEqualTo("2.5");
		assertThat(QuizGrader.normalize("2,5")).isEqualTo("2.5");
		assertThat(QuizGrader.normalize("  Le   NUMÉRATEUR. ")).isEqualTo("le numerateur");
		assertThat(QuizGrader.normalize("Évaluer")).isEqualTo("evaluer");
	}

	@Test
	void eachQuestionTypeIsScored() throws Exception {
		JsonNode mcq = json.readTree("""
				{"id": "q1", "type": "MCQ", "points": 2, "text": [{"insert": "?\\n"}],
				 "choices": [{"id": "a", "text": "$2/4$"}, {"id": "b", "text": "$2/3$"}], "correct": "a"}""");
		assertThat(QuizGrader.score(mcq, json.readTree("{\"choice\": \"a\"}"))).isEqualByComparingTo("2");
		assertThat(QuizGrader.score(mcq, json.readTree("{\"choice\": \"b\"}"))).isEqualByComparingTo("0");
		assertThat(QuizGrader.score(mcq, null)).isEqualByComparingTo("0");

		JsonNode trueFalse = json.readTree("{\"id\": \"q2\", \"type\": \"TRUE_FALSE\", \"points\": 1, \"text\": [], \"answer\": true}");
		assertThat(QuizGrader.score(trueFalse, json.readTree("{\"value\": true}"))).isEqualByComparingTo("1");
		assertThat(QuizGrader.score(trueFalse, json.readTree("{\"value\": false}"))).isEqualByComparingTo("0");

		JsonNode shortAnswer = json.readTree("{\"id\": \"q3\", \"type\": \"SHORT\", \"points\": 2, \"text\": [], \"accepted\": [\"2.5\"]}");
		for (String given : new String[] {"2,5", "2.5", " 2.5."}) {
			assertThat(QuizGrader.score(shortAnswer, json.createObjectNode().put("text", given))).isEqualByComparingTo("2");
		}
		assertThat(QuizGrader.score(shortAnswer, json.createObjectNode().put("text", "25"))).isEqualByComparingTo("0");

		JsonNode open = json.readTree("{\"id\": \"q5\", \"type\": \"OPEN\", \"points\": 3, \"text\": []}");
		assertThat(QuizGrader.score(open, json.createObjectNode().put("text", "Parce que…"))).isNull();
	}

	@Test
	void gapsShareThePointsByQuarterAndAllRightGetsTheWholeQuestion() throws Exception {
		JsonNode blanks = json.readTree("""
				{"id": "q4", "type": "BLANKS", "points": 2, "text": [
				  {"insert": "3 est le "}, {"insert": {"blank": {"id": "b1", "answers": ["numérateur"]}}},
				  {"insert": ", 4 le "}, {"insert": {"blank": {"id": "b2", "answers": ["dénominateur"]}}},
				  {"insert": " et "}, {"insert": {"blank": {"id": "b3", "answers": ["fraction"]}}}, {"insert": "\\n"}]}""");
		assertThat(QuizGrader.score(blanks, json.readTree("{\"blanks\": {\"b1\": \"Numerateur\", \"b2\": \"denominateur\", \"b3\": \"fraction.\"}}")))
				.isEqualByComparingTo("2");
		// 2 / 3 = 0,67 rounded to 0,75 a gap.
		assertThat(QuizGrader.score(blanks, json.readTree("{\"blanks\": {\"b1\": \"numérateur\", \"b2\": \"x\"}}")))
				.isEqualByComparingTo(new BigDecimal("0.75"));
		assertThat(QuizGrader.score(blanks, json.readTree("{\"blanks\": {}}"))).isEqualByComparingTo("0");
	}
}
