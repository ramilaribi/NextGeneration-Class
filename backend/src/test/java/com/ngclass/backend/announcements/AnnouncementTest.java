package com.ngclass.backend.announcements;

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

/** Release 4: announcements (spec 08, mockups screens/r4/Annonces*.png), one-way, read through the notifications. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class AnnouncementTest {
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
	private String group4L;
	private String adam;
	private String mouna;
	private String samia;
	private String linaId;

	@BeforeEach
	void cleanAndSetUp() throws Exception {
		jdbc.execute("""
				truncate announcement_targets, announcements, notifications, attendance, sessions, recurrence_rules, comments, private_notes,
				group_members, class_groups, parent_students, parents, students, subjects, refresh_tokens, users cascade""");
		account(Role.TEACHER, "enseignante");
		ines = token("enseignante", PASSWORD);
		levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		String maths = createSubject(ines, "Mathématiques");
		String lecture = createSubject(ines, "Lecture");
		group4A = createGroup(ines, "4ème année · Maths", maths);
		group4L = createGroup(ines, "4ème année · Lecture", lecture);
		// Adam has his own login, in both groups; Lina has none, in Lecture only. Each has a parent.
		JsonNode adamCreated = createStudent("Adam", List.of(group4A, group4L), true, "Mouna", "20000001");
		adam = firstLogin(credential(adamCreated, "STUDENT"));
		mouna = firstLogin(credential(adamCreated, "PARENT"));
		JsonNode linaCreated = createStudent("Lina", List.of(group4L), false, "Samia", "20000002");
		linaId = linaCreated.at("/student/id").asText();
		samia = firstLogin(credential(linaCreated, "PARENT"));
	}

	@Test
	void anAnnouncementReachesEachPersonOnceAndCountsWhoReadIt() throws Exception {
		JsonNode sent = body(send(Map.of("title", " Sortie au musée jeudi ", "body", "Départ à 9 h.", "audience", "PARENTS",
				"groupIds", List.of(group4A, group4L))).andExpect(status().isCreated()));
		assertThat(sent.at("/title").asText()).isEqualTo("Sortie au musée jeudi");
		assertThat(sent.at("/audience").asText()).isEqualTo("PARENTS");
		assertThat(sent.at("/targets").size()).isEqualTo(2);
		assertThat(sent.at("/targets/0/group/name").asText()).isEqualTo("4ème année · Maths");
		// Mouna once (her son is in both groups), Samia once; no pupil: it is for the parents.
		assertThat(sent.at("/recipients").asInt()).isEqualTo(2);
		assertThat(sent.at("/read").asInt()).isZero();
		assertThat(body(call(get("/api/v1/me/notifications"), adam)).at("/items").toString()).doesNotContain("ANNOUNCEMENT");

		JsonNode moun = body(call(get("/api/v1/me/notifications"), mouna));
		JsonNode row = moun.at("/items/0");
		assertThat(row.at("/type").asText()).isEqualTo("ANNOUNCEMENT");
		assertThat(row.at("/title").asText()).isEqualTo("Sortie au musée jeudi");
		assertThat(row.at("/body").asText()).isEqualTo("Départ à 9 h.");
		assertThat(row.at("/childFirstName").asText()).isEqualTo("Adam");
		assertThat(row.at("/author").asText()).isEqualTo("enseignante Test");
		call(post("/api/v1/me/notifications/" + row.at("/id").asText() + "/read"), mouna).andExpect(status().is2xxSuccessful());

		JsonNode list = body(call(get("/api/v1/announcements"), ines).andExpect(status().isOk()));
		assertThat(list.at("/0/read").asInt()).isEqualTo(1);
		JsonNode unread = body(call(get("/api/v1/announcements/" + sent.at("/id").asText() + "/unread"), ines).andExpect(status().isOk()));
		assertThat(unread.size()).isEqualTo(1);
		assertThat(unread.at("/0/firstName").asText()).isEqualTo("Samia");
		assertThat(unread.at("/0/parent").asBoolean()).isTrue();
		assertThat(unread.at("/0/childFirstName").asText()).isEqualTo("Lina");

		// Read by someone: it stays as sent.
		call(delete("/api/v1/announcements/" + sent.at("/id").asText()), ines)
				.andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("announcement_already_read"));
	}

	@Test
	void pupilsParentsOrBothAndNobodyIsRefused() throws Exception {
		// Lina has no login: an announcement for her alone, to pupils, reaches nobody.
		send(Map.of("title", "Le cahier", "body", "Apporte ton cahier.", "audience", "PUPILS", "studentId", linaId))
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("announcement_nobody"));
		assertThat(body(call(get("/api/v1/announcements"), ines)).size()).isZero();

		JsonNode both = body(send(Map.of("title", "Bravo", "body", "Bravo pour le quiz !", "audience", "BOTH", "groupIds", List.of(group4A)))
				.andExpect(status().isCreated()));
		assertThat(both.at("/recipients").asInt()).isEqualTo(2);
		assertThat(body(call(get("/api/v1/me/notifications"), adam)).at("/items/0/type").asText()).isEqualTo("ANNOUNCEMENT");
		assertThat(body(call(get("/api/v1/me/notifications"), samia)).at("/items").toString()).doesNotContain("ANNOUNCEMENT");

		// Groups or one pupil, never both or neither.
		send(Map.of("title", "x", "body", "y", "audience", "BOTH", "groupIds", List.of(group4A), "studentId", linaId))
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("announcement_target_required"));
		send(Map.of("title", "x", "body", "y", "audience", "TOUS", "groupIds", List.of(group4A)))
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("announcement_invalid_audience"));

		// Unread by all: it can still be deleted, and leaves everyone's notifications.
		call(delete("/api/v1/announcements/" + both.at("/id").asText()), ines).andExpect(status().isNoContent());
		assertThat(body(call(get("/api/v1/me/notifications"), adam)).at("/items").toString()).doesNotContain("ANNOUNCEMENT");
	}

	@Test
	void anotherTeacherNeitherSeesNorUsesThem() throws Exception {
		String id = body(send(Map.of("title", "Sortie", "body", "Jeudi.", "audience", "PARENTS", "groupIds", List.of(group4A)))).at("/id").asText();
		account(Role.TEACHER, "autre");
		String other = token("autre", PASSWORD);
		assertThat(body(call(get("/api/v1/announcements"), other)).size()).isZero();
		call(get("/api/v1/announcements/" + id + "/unread"), other).andExpect(status().isNotFound());
		call(delete("/api/v1/announcements/" + id), other).andExpect(status().isNotFound());
		call(post("/api/v1/announcements").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "x", "body", "y", "audience", "PARENTS", "groupIds", List.of(group4A)))), other)
				.andExpect(status().isNotFound());
		call(get("/api/v1/announcements"), adam).andExpect(status().isForbidden());
	}

	// ── Helpers ──

	private ResultActions send(Map<String, Object> request) throws Exception {
		return call(post("/api/v1/announcements").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(request)), ines);
	}

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
