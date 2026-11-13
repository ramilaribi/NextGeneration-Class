package com.ngclass.backend.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.domain.User;
import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.quiz.service.QuizJobs;
import com.ngclass.backend.school.repository.LevelRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Release 3, steps 2 and 3: quizzes and QCM (spec 05, designs r3/QuizEditeur.png, SeriesQuizPhone.png),
 * built by the teacher, given as homework, taken by the pupil or a parent, graded at once, open questions in
 * "À corriger", the timer checked by the server.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class QuizTest {
	private static final String PASSWORD = "Secret2026x";

	@Container
	@ServiceConnection
	static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

	@Autowired
	private MockMvc mvc;
	@Autowired
	private ObjectMapper json;
	@Autowired
	private JdbcTemplate jdbc;
	@Autowired
	private UserRepository users;
	@Autowired
	private LevelRepository levels;
	@Autowired
	private PasswordEncoder passwordEncoder;
	@Autowired
	private QuizJobs jobs;

	private String ines;
	private String levelId;
	private String maths;
	private String group4A;
	private String adam;
	private String mouna;
	private String adamId;

	@BeforeEach
	void cleanAndSetUp() throws Exception {
		jdbc.execute("""
				truncate quiz_attempts, quizzes, submissions, assignment_recipients, assignments, content_views, content_shares, content_items,
				file_assets, chapters, notifications, attendance, sessions, recurrence_rules, comments, private_notes, group_members,
				class_groups, parent_students, parents, students, subjects, refresh_tokens, users cascade""");
		account(Role.TEACHER, "enseignante");
		ines = token("enseignante", PASSWORD);
		levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		maths = createSubject(ines, "Mathématiques");
		group4A = createGroup(ines, "4ème année · Maths", maths);
		Map<String, Object> pupil = new HashMap<>(Map.of("firstName", "Adam", "lastName", "Gharbi", "levelId", levelId,
				"groupIds", List.of(group4A), "createLogin", true));
		pupil.put("parents", List.of(Map.of("firstName", "Mouna", "lastName", "Gharbi", "phone", "20000001", "relation", "mother")));
		JsonNode created = body(call(post("/api/v1/students").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(pupil)), ines)
				.andExpect(status().isCreated()));
		adamId = created.at("/student/id").asText();
		adam = firstLogin(credential(created, "STUDENT"));
		mouna = firstLogin(credential(created, "PARENT"));
	}

	@Test
	void aQuizIsBuiltPublishedGivenTakenAndGradedAtOnce() throws Exception {
		JsonNode created = body(call(post("/api/v1/contents/quizzes").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", " Quiz : les fractions ", "subjectId", maths, "levelId", levelId, "mcqOnly", false))), ines)
				.andExpect(status().isCreated()));
		String id = created.at("/item/id").asText();
		assertThat(created.at("/item/kind").asText()).isEqualTo("QUIZ");
		assertThat(created.at("/item/title").asText()).isEqualTo("Quiz : les fractions");
		assertThat(created.at("/settings/attemptsAllowed").asInt()).isEqualTo(1);
		assertThat(created.at("/settings/scorePolicy").asText()).isEqualTo("BEST");
		assertThat(created.at("/settings/answersShown").asText()).isEqualTo("AFTER_DEADLINE");
		assertThat(created.at("/questionCount").asInt()).isZero();

		// An unfinished question is fine in a draft, not in a published quiz.
		List<Object> draft = List.of(Map.of("id", "q1", "type", "MCQ", "points", 2, "text", text("Quelle fraction est égale à 1/2 ?"),
				"choices", List.of(Map.of("id", "a", "text", "$2/4$"))));
		save(id, settings(null, 1), draft).andExpect(status().isOk());
		publish(id, false).andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("quiz_question_incomplete"));

		JsonNode saved = body(save(id, settings(null, 1), questions()).andExpect(status().isOk()));
		assertThat(saved.at("/totalPoints").asInt()).isEqualTo(6);
		assertThat(saved.at("/questionCount").asInt()).isEqualTo(4);
		assertThat(saved.at("/openCount").asInt()).isZero();
		publish(id, false).andExpect(status().isOk());

		// Never in Cours: a quiz comes as homework.
		call(put("/api/v1/contents/" + id + "/shares").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("groupIds", List.of(group4A)))), ines)
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("quiz_not_shareable"));

		// Given online only, graded out of its total.
		call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(assign(id, "FILE"))), ines)
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("quiz_mode_mismatch"));
		JsonNode homework = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(assign(id, "QUIZ"))), ines).andExpect(status().isCreated()));
		String hw = homework.at("/id").asText();
		assertThat(homework.at("/maxScore").asInt()).isEqualTo(6);
		assertThat(homework.at("/submissionMode").asText()).isEqualTo("QUIZ");

		// The pupil sees the quiz, never its answers, and cannot open it as a document.
		JsonNode quiz = body(call(get("/api/v1/me/assignments/" + hw + "/quiz"), adam).andExpect(status().isOk()));
		assertThat(quiz.at("/canStart").asBoolean()).isTrue();
		assertThat(quiz.at("/questionCount").asInt()).isEqualTo(4);
		call(get("/api/v1/contents/" + id + "/view"), adam).andExpect(status().isNotFound());

		JsonNode play = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam).andExpect(status().isOk()));
		String attempt = play.at("/id").asText();
		assertThat(play.at("/endsAt").isNull()).isTrue();
		String asSent = play.at("/questions").toString();
		assertThat(asSent).doesNotContain("\"correct\"").doesNotContain("accepted").doesNotContain("numérateur").doesNotContain("\"answer\"");
		// Starting again gives the same attempt back.
		assertThat(body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam)).at("/id").asText()).isEqualTo(attempt);

		// Locked from the first start: the questions no longer change, the settings may.
		save(id, settings(null, 1), List.of(questions().getFirst())).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("quiz_locked"));
		save(id, settings(20, 1), questions()).andExpect(status().isOk());

		// Answers saved one by one, then sent: MCQ right (2), true/false wrong (0), " 2,5. " right (2), one gap of two right (0,5).
		answers(adam, hw, attempt, Map.of("q1", Map.of("choice", "a"))).andExpect(status().isNoContent());
		answers(adam, hw, attempt, Map.of("q2", Map.of("value", false), "q3", Map.of("text", " 2,5. "))).andExpect(status().isNoContent());
		answers(adam, hw, attempt, Map.of("q4", Map.of("blanks", Map.of("b1", "Numérateur", "b2", "dividende")))).andExpect(status().isNoContent());
		JsonNode review = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + attempt + "/submit"), adam).andExpect(status().isOk()));
		assertThat(review.at("/score").decimalValue()).isEqualByComparingTo("4.5");
		assertThat(review.at("/maxScore").asInt()).isEqualTo(6);
		assertThat(review.at("/pending").asBoolean()).isFalse();
		// Answers shown after the deadline only.
		assertThat(review.at("/answersShown").asBoolean()).isFalse();
		assertThat(review.at("/items").toString()).doesNotContain("\"correct\"");
		assertThat(review.at("/items/1/right").asBoolean()).isFalse();
		assertThat(review.at("/items/3/points").decimalValue()).isEqualByComparingTo("0.5");

		// No attempt left; the grade is in the homework and in Résultats as a quiz.
		call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam)
				.andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("quiz_no_attempt_left"));
		JsonNode mine = body(call(get("/api/v1/me/assignments"), adam));
		assertThat(mine.at("/0/status").asText()).isEqualTo("CORRECTED");
		assertThat(mine.at("/0/score").decimalValue()).isEqualByComparingTo("4.5");
		JsonNode results = body(call(get("/api/v1/me/results?studentId=" + adamId), mouna).andExpect(status().isOk()));
		assertThat(results.toString()).contains("\"kind\":\"QUIZ\"");
		JsonNode detail = body(call(get("/api/v1/assignments/" + hw), ines));
		assertThat(detail.at("/recipients/0/status").asText()).isEqualTo("CORRECTED");
		assertThat(detail.at("/recipients/0/submissionId").asText()).isEqualTo(attempt);

		// After the deadline, the right answers are shown.
		jdbc.update("update assignments set deadline_at = now() - interval '1 hour'");
		JsonNode after = body(call(get("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + attempt), adam).andExpect(status().isOk()));
		assertThat(after.at("/answersShown").asBoolean()).isTrue();
		assertThat(after.at("/items/0/question/correct").asText()).isEqualTo("a");

		// The teacher sees every answer; "Dupliquer" makes a free draft with the same questions.
		JsonNode correction = body(call(get("/api/v1/assignments/" + hw + "/quiz/" + adamId), ines).andExpect(status().isOk()));
		assertThat(correction.at("/attempt/items/0/question/correct").asText()).isEqualTo("a");
		JsonNode copy = body(call(post("/api/v1/contents/" + id + "/quiz/duplicate"), ines).andExpect(status().isCreated()));
		assertThat(copy.at("/item/status").asText()).isEqualTo("DRAFT");
		assertThat(copy.at("/locked").asBoolean()).isFalse();
		assertThat(copy.at("/questionCount").asInt()).isEqualTo(4);
		assertThat(copy.at("/settings/timeLimitMin").asInt()).isEqualTo(20);
	}

	@Test
	void anOpenQuestionWaitsForTheTeacherWhoScoresIt() throws Exception {
		List<Object> list = List.of(
				Map.of("id", "q1", "type", "TRUE_FALSE", "points", 1, "text", text("3/5 > 4/7"), "answer", true),
				Map.of("id", "q2", "type", "OPEN", "points", 3, "text", text("Explique comment tu compares deux fractions.")));
		String id = publishedQuiz(settings(null, 2), list);
		String hw = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(assign(id, "QUIZ"))), ines).andExpect(status().isCreated())).at("/id").asText();

		// The parent takes it for the child.
		String attempt = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts?studentId=" + adamId), mouna).andExpect(status().isOk()))
				.at("/id").asText();
		answers(mouna, hw + "", attempt, Map.of("q1", Map.of("value", true), "q2", Map.of("text", "On met au même dénominateur.")), adamId)
				.andExpect(status().isNoContent());
		JsonNode sent = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + attempt + "/submit?studentId=" + adamId), mouna)
				.andExpect(status().isOk()));
		assertThat(sent.at("/pending").asBoolean()).isTrue();
		assertThat(sent.at("/autoScore").decimalValue()).isEqualByComparingTo("1");
		assertThat(sent.at("/score").isNull()).isTrue();

		// In "À corriger", by its attempt.
		JsonNode queue = body(call(get("/api/v1/assignments/to-correct"), ines).andExpect(status().isOk()));
		assertThat(queue.at("/0/assignment/id").asText()).isEqualTo(hw);
		assertThat(queue.at("/0/items/0/submissionId").asText()).isEqualTo(attempt);
		assertThat(body(call(get("/api/v1/me/assignments/" + hw), adam)).at("/homework/status").asText()).isEqualTo("SUBMITTED");

		// Only open questions take the teacher's points, in half points.
		call(put("/api/v1/assignments/" + hw + "/quiz/" + adamId + "/attempts/" + attempt).contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("scores", Map.of("q1", 0)))), ines)
				.andExpect(status().isBadRequest());
		call(put("/api/v1/assignments/" + hw + "/quiz/" + adamId + "/attempts/" + attempt).contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("scores", Map.of("q2", 3.5)))), ines)
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_score"));
		JsonNode corrected = body(call(put("/api/v1/assignments/" + hw + "/quiz/" + adamId + "/attempts/" + attempt).contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("scores", Map.of("q2", 2.5), "comment", "Bonne idée, explique avec un exemple."))), ines)
				.andExpect(status().isOk()));
		assertThat(corrected.at("/status").asText()).isEqualTo("CORRECTED");
		assertThat(corrected.at("/attempt/score").decimalValue()).isEqualByComparingTo("3.5");
		assertThat(body(call(get("/api/v1/assignments/to-correct"), ines)).size()).isZero();
		JsonNode mine = body(call(get("/api/v1/me/assignments/" + hw), adam));
		assertThat(mine.at("/homework/score").decimalValue()).isEqualByComparingTo("3.5");

		// A second attempt (two allowed): the best grade counts.
		String second = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam).andExpect(status().isOk())).at("/id").asText();
		answers(adam, hw, second, Map.of("q1", Map.of("value", false))).andExpect(status().isNoContent());
		call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + second + "/submit"), adam).andExpect(status().isOk());
		call(put("/api/v1/assignments/" + hw + "/quiz/" + adamId + "/attempts/" + second).contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("scores", Map.of("q2", 1)))), ines).andExpect(status().isOk());
		assertThat(body(call(get("/api/v1/me/assignments/" + hw), adam)).at("/homework/score").decimalValue()).isEqualByComparingTo("3.5");
	}

	@Test
	void theServerEndsATimedQuizWithTheAnswersSaved() throws Exception {
		String id = publishedQuiz(settings(5, 1), questions());
		String hw = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(assign(id, "QUIZ"))), ines).andExpect(status().isCreated())).at("/id").asText();
		JsonNode play = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam).andExpect(status().isOk()));
		String attempt = play.at("/id").asText();
		assertThat(Instant.parse(play.at("/endsAt").asText())).isCloseTo(Instant.parse(play.at("/startedAt").asText()).plus(5, ChronoUnit.MINUTES),
				org.assertj.core.api.Assertions.within(1, ChronoUnit.SECONDS));
		answers(adam, hw, attempt, Map.of("q1", Map.of("choice", "a"))).andExpect(status().isNoContent());

		// Six minutes later, the app closed: the job sends it.
		jdbc.update("update quiz_attempts set started_at = now() - interval '6 minutes'");
		jobs.closeOverdue();
		JsonNode quiz = body(call(get("/api/v1/me/assignments/" + hw + "/quiz"), adam));
		assertThat(quiz.at("/current").isNull()).isTrue();
		assertThat(quiz.at("/attempts/0/score").decimalValue()).isEqualByComparingTo("2");
		answers(adam, hw, attempt, Map.of("q3", Map.of("text", "2.5"))).andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("quiz_already_sent"));
	}

	@Test
	void anAnswerAfterTheTimeIsUpSendsTheQuizInstead() throws Exception {
		String id = publishedQuiz(settings(5, 1), questions());
		String hw = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(assign(id, "QUIZ"))), ines).andExpect(status().isCreated())).at("/id").asText();
		String attempt = body(call(post("/api/v1/me/assignments/" + hw + "/quiz/attempts"), adam)).at("/id").asText();
		answers(adam, hw, attempt, Map.of("q3", Map.of("text", "2.5"))).andExpect(status().isNoContent());
		jdbc.update("update quiz_attempts set started_at = now() - interval '5 minutes 31 seconds'");
		answers(adam, hw, attempt, Map.of("q1", Map.of("choice", "a"))).andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("quiz_time_over"));
		JsonNode quiz = body(call(get("/api/v1/me/assignments/" + hw + "/quiz"), adam));
		assertThat(quiz.at("/attempts/0/score").decimalValue()).isEqualByComparingTo("2");
		assertThat(quiz.at("/kept").decimalValue()).isEqualByComparingTo("2");
	}

	@Test
	void anotherTeacherNeverReachesTheQuiz() throws Exception {
		String id = publishedQuiz(settings(null, 1), questions());
		account(Role.TEACHER, "autre");
		String other = token("autre", PASSWORD);
		call(get("/api/v1/contents/" + id + "/quiz"), other).andExpect(status().isNotFound());
		save(id, settings(null, 1), questions(), other).andExpect(status().isNotFound());
		call(post("/api/v1/contents/" + id + "/quiz/duplicate"), other).andExpect(status().isNotFound());
		String hw = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(assign(id, "QUIZ"))), ines).andExpect(status().isCreated())).at("/id").asText();
		call(get("/api/v1/assignments/" + hw + "/quiz/" + adamId), other).andExpect(status().isNotFound());
	}

	// ── Helpers ──

	/** 6 points: a multiple choice (2), true or false (1), a short answer 2.5 (2), two gaps (1). */
	private static List<Object> questions() {
		return List.of(
				Map.of("id", "q1", "type", "MCQ", "points", 2, "text", text("Quelle fraction est égale à 1/2 ?"),
						"choices", List.of(Map.of("id", "a", "text", "$2/4$"), Map.of("id", "b", "text", "$2/3$"), Map.of("id", "c", "text", "$3/4$")),
						"correct", "a"),
				Map.of("id", "q2", "type", "TRUE_FALSE", "points", 1, "text", text("3/5 > 4/7"), "answer", true,
						"explanation", "$3/5 = 21/35$ et $4/7 = 20/35$"),
				Map.of("id", "q3", "type", "SHORT", "points", 2, "text", text("Calcule 1/2 + 2."), "accepted", List.of("2.5")),
				Map.of("id", "q4", "type", "BLANKS", "points", 1, "text", List.of(
						Map.of("insert", "Dans 3/4, 3 est le "),
						Map.of("insert", Map.of("blank", Map.of("id", "b1", "answers", List.of("numérateur")))),
						Map.of("insert", " et 4 le "),
						Map.of("insert", Map.of("blank", Map.of("id", "b2", "answers", List.of("dénominateur")))),
						Map.of("insert", ".\n"))));
	}

	private static List<Object> text(String value) {
		return List.of(Map.of("insert", value + "\n"));
	}

	private static Map<String, Object> settings(Integer minutes, int attempts) {
		Map<String, Object> out = new HashMap<>(Map.of("attemptsAllowed", attempts, "scorePolicy", "BEST", "answersShown", "AFTER_DEADLINE",
				"shuffle", false));
		out.put("timeLimitMin", minutes);
		return out;
	}

	private String publishedQuiz(Map<String, Object> settings, List<Object> questions) throws Exception {
		String id = body(call(post("/api/v1/contents/quizzes").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Quiz", "subjectId", maths, "levelId", levelId, "mcqOnly", false))), ines)
				.andExpect(status().isCreated())).at("/item/id").asText();
		save(id, settings, questions).andExpect(status().isOk());
		publish(id, false).andExpect(status().isOk());
		return id;
	}

	private ResultActions save(String id, Map<String, Object> settings, List<Object> questions) throws Exception {
		return save(id, settings, questions, ines);
	}

	private ResultActions save(String id, Map<String, Object> settings, List<Object> questions, String token) throws Exception {
		return call(put("/api/v1/contents/" + id + "/quiz").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("settings", settings, "questions", questions))), token);
	}

	private ResultActions publish(String id, boolean draft) throws Exception {
		return call(put("/api/v1/contents/" + id).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Quiz : les fractions", "subjectId", maths, "levelId", levelId, "tag", "AUTRE", "draft", draft))), ines);
	}

	private Map<String, Object> assign(String id, String mode) {
		return Map.of("contentItemId", id, "title", "Quiz : les fractions", "groupId", group4A,
				"deadlineAt", Instant.now().plus(2, ChronoUnit.DAYS).toString(), "submissionMode", mode, "allowLate", false);
	}

	private ResultActions answers(String token, String hw, String attempt, Map<String, Object> answers) throws Exception {
		return call(put("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + attempt + "/answers").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("answers", answers))), token);
	}

	private ResultActions answers(String token, String hw, String attempt, Map<String, Object> answers, String studentId) throws Exception {
		return call(put("/api/v1/me/assignments/" + hw + "/quiz/attempts/" + attempt + "/answers?studentId=" + studentId)
				.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("answers", answers))), token);
	}

	private String createSubject(String token, String nameFr) throws Exception {
		return body(call(post("/api/v1/subjects").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("nameFr", nameFr))), token)
				.andExpect(status().isCreated())).at("/id").asText();
	}

	private String createGroup(String token, String name, String subjectId) throws Exception {
		return body(call(post("/api/v1/groups").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("name", name, "subjectId", subjectId, "levelId", levelId))), token)
				.andExpect(status().isCreated())).at("/id").asText();
	}

	private void account(Role role, String username) {
		users.save(User.builder()
				.role(role)
				.username(username)
				.firstName(username)
				.lastName("Test")
				.passwordHash(passwordEncoder.encode(PASSWORD))
				.build());
	}

	private static JsonNode credential(JsonNode created, String role) {
		for (JsonNode credential : created.at("/credentials")) {
			if (credential.at("/role").asText().equals(role)) {
				return credential;
			}
		}
		throw new AssertionError("no login details for " + role);
	}

	private String firstLogin(JsonNode credential) throws Exception {
		String token = token(credential.at("/username").asText(), credential.at("/temporaryPassword").asText());
		call(post("/api/v1/me/password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("currentPassword", credential.at("/temporaryPassword").asText(), "newPassword", PASSWORD))), token)
				.andExpect(status().isNoContent());
		return token;
	}

	private String token(String login, String password) throws Exception {
		return body(mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("login", login, "password", password))))
				.andExpect(status().isOk())).at("/accessToken").asText();
	}

	private ResultActions call(MockHttpServletRequestBuilder request, String token) throws Exception {
		return mvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
	}

	private JsonNode body(ResultActions result) throws Exception {
		return json.readTree(result.andReturn().getResponse().getContentAsString());
	}
}
