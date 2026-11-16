package com.ngclass.backend.people;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.domain.User;
import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.school.repository.LevelRepository;
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

/** Before going live: the privacy notice and the parents' agreement (mockups screens/r4/AccordParents.png, ConfidentialitePhone.png). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class PrivacyTest {
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

	private String ines;
	private String levelId;
	private String group4A;
	private String adam;
	private String adamId;
	private String mouna;
	private String linaId;

	@BeforeEach
	void cleanAndSetUp() throws Exception {
		jdbc.execute("""
				truncate student_consents, notifications, attendance, sessions, recurrence_rules, comments, private_notes,
				group_members, class_groups, parent_students, parents, students, subjects, refresh_tokens, users cascade""");
		account(Role.TEACHER, "enseignante");
		ines = token("enseignante", PASSWORD);
		levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		group4A = createGroup(ines, "4ème année · Maths", createSubject(ines, "Mathématiques"));
		JsonNode adamCreated = createStudent("Adam", List.of(group4A), true, "Mouna", "20000001");
		adamId = adamCreated.at("/student/id").asText();
		adam = firstLogin(credential(adamCreated, "STUDENT"));
		mouna = firstLogin(credential(adamCreated, "PARENT"));
		linaId = createStudent("Lina", List.of(group4A), false, "Samia", "20000002").at("/student/id").asText();
	}

	@Test
	void aParentAcceptsOnceAndOnlyThenSeesTheChildsSpace() throws Exception {
		// The space stays closed: only the profile, the notice and the language answer.
		assertThat(body(call(get("/api/v1/me"), mouna)).at("/privacyRequired").asBoolean()).isTrue();
		call(get("/api/v1/me/notifications"), mouna)
				.andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("privacy_required"));
		JsonNode info = body(call(get("/api/v1/me/privacy"), mouna).andExpect(status().isOk()));
		assertThat(info.at("/required").asBoolean()).isTrue();
		assertThat(info.at("/teacherName").asText()).isEqualTo("enseignante Test");
		assertThat(info.at("/children/0").asText()).isEqualTo("Adam");

		// A pupil has nothing to accept.
		assertThat(body(call(get("/api/v1/me"), adam)).at("/privacyRequired").asBoolean()).isFalse();
		call(get("/api/v1/me/notifications"), adam).andExpect(status().isOk());

		call(post("/api/v1/me/privacy"), mouna).andExpect(status().isNoContent());
		assertThat(body(call(get("/api/v1/me"), mouna)).at("/privacyRequired").asBoolean()).isFalse();
		call(get("/api/v1/me/notifications"), mouna).andExpect(status().isOk());

		// The teacher sees who agreed and how; Lina's parents have not answered yet.
		JsonNode rows = body(call(get("/api/v1/students"), ines).andExpect(status().isOk()));
		JsonNode adamRow = null;
		JsonNode linaRow = null;
		for (JsonNode row : rows) {
			if (row.at("/id").asText().equals(adamId)) {
				adamRow = row;
			} else if (row.at("/id").asText().equals(linaId)) {
				linaRow = row;
			}
		}
		assertThat(adamRow.at("/consent/method").asText()).isEqualTo("APP");
		assertThat(adamRow.at("/consent/givenBy").asText()).isEqualTo("Mouna Test");
		assertThat(linaRow.at("/consent").isNull()).isTrue();
	}

	@Test
	void theTeacherRecordsAnAgreementSignedOnPaperForHerPupilsOnly() throws Exception {
		JsonNode paper = body(call(post("/api/v1/students/" + linaId + "/consent"), ines).andExpect(status().isOk()));
		assertThat(paper.at("/method").asText()).isEqualTo("PAPER");
		assertThat(paper.at("/givenBy").isNull()).isTrue();
		JsonNode detail = body(call(get("/api/v1/students/" + linaId), ines).andExpect(status().isOk()));
		assertThat(detail.at("/student/consent/method").asText()).isEqualTo("PAPER");

		account(Role.TEACHER, "autre");
		call(post("/api/v1/students/" + adamId + "/consent"), token("autre", PASSWORD)).andExpect(status().isNotFound());
		call(post("/api/v1/students/" + adamId + "/consent"), adam).andExpect(status().isForbidden());
	}

	// ── Helpers ──

	private JsonNode createStudent(String firstName, List<String> groupIds, boolean login, String parentName, String phone) throws Exception {
		Map<String, Object> pupil = new HashMap<>(Map.of("firstName", firstName, "lastName", "Test", "levelId", levelId,
				"groupIds", groupIds, "createLogin", login));
		pupil.put("parents", List.of(Map.of("firstName", parentName, "lastName", "Test", "phone", phone, "relation", "mother")));
		return body(call(post("/api/v1/students").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(pupil)), ines)
				.andExpect(status().isCreated()));
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
