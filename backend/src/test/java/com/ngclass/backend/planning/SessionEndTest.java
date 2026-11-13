package com.ngclass.backend.planning;

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
import com.ngclass.backend.school.repository.LevelRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
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
 * Release 4: the end of a session (spec 03, mockups screens/r4/FinDeSeance*.png) and the progress numbers (spec 07,
 * screens/r4/Progression*.png).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class SessionEndTest {
	private static final String PASSWORD = "Secret2026x";
	private static final ZoneId TUNIS = ZoneId.of("Africa/Tunis");

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

	private String ines;
	private String levelId;
	private String maths;
	private String group4A;
	private String adam;
	private String adamId;
	private String fractions;
	private String lire;
	private String page;

	@BeforeEach
	void cleanAndSetUp() throws Exception {
		jdbc.execute("""
				truncate session_contents, assignment_recipients, assignments, content_views, content_shares, content_items, file_assets,
				chapters, notifications, attendance, sessions, recurrence_rules, comments, private_notes, group_members, class_groups,
				parent_students, parents, students, subjects, refresh_tokens, users cascade""");
		account(Role.TEACHER, "enseignante");
		ines = token("enseignante", PASSWORD);
		levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		maths = createSubject("Mathématiques");
		String lecture = createSubject("Lecture");
		group4A = body(call(post("/api/v1/groups").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("name", "4ème année · Maths", "subjectId", maths, "levelId", levelId))), ines)
				.andExpect(status().isCreated())).at("/id").asText();
		fractions = createChapter(maths, "Les fractions");
		lire = createChapter(lecture, "Lire un conte");
		page = body(call(post("/api/v1/contents/pages").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Série 1 : les fractions", "subjectId", maths, "levelId", levelId, "chapterId", fractions, "tag", "SERIE"))), ines)
				.andExpect(status().isCreated())).at("/item/id").asText();
		Map<String, Object> pupil = new HashMap<>(Map.of("firstName", "Adam", "lastName", "Gharbi", "levelId", levelId,
				"groupIds", List.of(group4A), "createLogin", true));
		pupil.put("parents", List.of(Map.of("firstName", "Mouna", "lastName", "Gharbi", "phone", "20000001", "relation", "mother")));
		JsonNode created = body(call(post("/api/v1/students").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(pupil)), ines)
				.andExpect(status().isCreated()));
		adamId = created.at("/student/id").asText();
		for (JsonNode credential : created.at("/credentials")) {
			if (credential.at("/role").asText().equals("STUDENT")) {
				adam = firstLogin(credential);
			}
		}
	}

	@Test
	void theEndOfASessionSaysWhatWasCoveredAndTheNextOneShowsIt() throws Exception {
		LocalDate today = LocalDate.now(TUNIS);
		String done = session(today, "00:05", "00:45");
		String next = session(today.plusDays(1), "10:00", "11:30");
		call(put("/api/v1/sessions/" + done + "/attendance").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("entries", List.of(Map.of("studentId", adamId, "status", "ABSENT"))))), ines).andExpect(status().isOk());

		// A chapter of another subject, or a document that is not hers, is refused.
		end(done, Map.of("chapterId", lire)).andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("chapter_not_of_group"));
		end(done, Map.of("contentIds", List.of("00000000-0000-0000-0000-000000000001")))
				.andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("content_not_found"));

		JsonNode ended = body(end(done, Map.of("chapterId", fractions, "contentIds", List.of(page), "details", " Exercices 1 à 4. ",
				"sessionNote", "Revoir la simplification.")).andExpect(status().isOk()));
		assertThat(ended.at("/session/status").asText()).isEqualTo("DONE");
		assertThat(ended.at("/sessionNote").asText()).isEqualTo("Revoir la simplification.");
		assertThat(ended.at("/covered/chapterTitle").asText()).isEqualTo("Les fractions");
		assertThat(ended.at("/covered/details").asText()).isEqualTo("Exercices 1 à 4.");
		assertThat(ended.at("/covered/documents/0/title").asText()).isEqualTo("Série 1 : les fractions");
		assertThat(ended.at("/covered/documents/0/kind").asText()).isEqualTo("PAGE");

		// Homework given the same day shows on the next session's "Dernière séance", with the absence.
		publish();
		call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
				"contentItemId", page, "title", "Série 2 : les fractions", "groupId", group4A,
				"deadlineAt", Instant.now().plus(2, ChronoUnit.DAYS).toString(), "submissionMode", "FILE", "allowLate", false))), ines)
				.andExpect(status().isCreated());
		JsonNode previous = body(call(get("/api/v1/sessions/" + next), ines).andExpect(status().isOk())).at("/previous");
		assertThat(previous.at("/covered/chapterTitle").asText()).isEqualTo("Les fractions");
		assertThat(previous.at("/sessionNote").asText()).isEqualTo("Revoir la simplification.");
		assertThat(previous.at("/absent").asInt()).isEqualTo(1);
		assertThat(previous.at("/homework/0").asText()).isEqualTo("Série 2 : les fractions");

		// Ended again without a body: what was covered stays.
		end(done, null).andExpect(status().isOk()).andExpect(jsonPath("$.covered.chapterTitle").value("Les fractions"));
	}

	@Test
	void familiesSeeWhatWasCoveredAndTheMonthsOfTheYear() throws Exception {
		String done = session(LocalDate.now(TUNIS), "00:05", "00:45");
		call(put("/api/v1/sessions/" + done + "/attendance").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("entries", List.of(Map.of("studentId", adamId, "status", "ABSENT"))))), ines).andExpect(status().isOk());
		end(done, Map.of("chapterId", fractions, "contentIds", List.of(page), "details", "Exercices 1 à 4.")).andExpect(status().isOk());

		JsonNode covered = body(call(get("/api/v1/me/contents/covered"), adam).andExpect(status().isOk()));
		assertThat(covered.size()).isEqualTo(1);
		assertThat(covered.at("/0/chapterId").asText()).isEqualTo(fractions);
		assertThat(covered.at("/0/details").asText()).isEqualTo("Exercices 1 à 4.");
		assertThat(covered.at("/0/contentIds/0").asText()).isEqualTo(page);

		JsonNode results = body(call(get("/api/v1/me/results"), adam).andExpect(status().isOk()));
		assertThat(results.at("/subjects/0/chaptersSeen/0").asText()).isEqualTo("Les fractions");
		JsonNode months = results.at("/months");
		YearMonth now = YearMonth.now(TUNIS);
		YearMonth september = YearMonth.of(now.getMonthValue() >= 9 ? now.getYear() : now.getYear() - 1, 9);
		assertThat(months.at("/0/month").asText()).isEqualTo(september.toString());
		JsonNode last = months.get(months.size() - 1);
		assertThat(last.at("/month").asText()).isEqualTo(now.toString());
		assertThat(last.at("/attendanceRate").asInt()).isZero();
		assertThat(months.at("/0/due").asInt()).isZero();

		// The teacher's Fiche élève reads the same numbers.
		JsonNode teacher = body(call(get("/api/v1/students/" + adamId + "/results"), ines).andExpect(status().isOk()));
		assertThat(teacher.at("/subjects/0/chaptersSeen")).isEqualTo(results.at("/subjects/0/chaptersSeen"));
		assertThat(teacher.at("/months")).isEqualTo(months);
	}

	// ── Helpers ──

	private ResultActions end(String sessionId, Map<String, Object> request) throws Exception {
		MockHttpServletRequestBuilder builder = post("/api/v1/sessions/" + sessionId + "/end");
		if (request != null) {
			builder.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(request));
		}
		return call(builder, ines);
	}

	private String session(LocalDate date, String start, String end) throws Exception {
		Map<String, Object> body = new HashMap<>();
		body.put("groupId", group4A);
		body.put("date", date.toString());
		body.put("startTime", start);
		body.put("endTime", end);
		body.put("mode", "IN_PERSON");
		body.put("repeatWeekly", false);
		return body(call(post("/api/v1/sessions").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)), ines)
				.andExpect(status().isCreated())).at("/first/id").asText();
	}

	private void publish() throws Exception {
		call(put("/api/v1/contents/" + page).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Série 1 : les fractions", "subjectId", maths, "levelId", levelId, "chapterId", fractions, "tag", "SERIE", "draft", false))), ines)
				.andExpect(status().isOk());
	}

	private String createChapter(String subjectId, String title) throws Exception {
		return body(call(post("/api/v1/chapters").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("subjectId", subjectId, "levelId", levelId, "title", title))), ines)
				.andExpect(status().isCreated())).at("/id").asText();
	}

	private String createSubject(String nameFr) throws Exception {
		return body(call(post("/api/v1/subjects").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("nameFr", nameFr))), ines)
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
