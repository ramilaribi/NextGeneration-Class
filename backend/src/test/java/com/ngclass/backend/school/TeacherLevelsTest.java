package com.ngclass.backend.school;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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

/** A teacher adds her own levels (user request 2026-11-18); the six primary years stay shared and fixed. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class TeacherLevelsTest {
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
	private PasswordEncoder passwordEncoder;

	private String ines;
	private String salma;

	@BeforeEach
	void cleanAndSignIn() throws Exception {
		jdbc.execute("""
				truncate attendance, sessions, recurrence_rules, comments, private_notes, group_members, class_groups,
				parent_students, parents, students, refresh_tokens, users cascade""");
		jdbc.execute("delete from levels where teacher_id is not null");
		jdbc.execute("delete from subjects");
		ines = teacher("ines");
		salma = teacher("salma");
	}

	@Test
	void sheAddsRenamesAndDeletesHerOwnLevel() throws Exception {
		JsonNode shared = body(call(get("/api/v1/reference"), ines).andExpect(status().isOk())).get("levels");
		assertThat(shared).hasSize(6);
		assertThat(shared.get(0).get("own").asBoolean()).isFalse();

		String id = body(call(post("/api/v1/levels"), ines, Map.of("nameFr", " Préparatoire ", "nameAr", "التحضيري"))
				.andExpect(status().isCreated())
				.andExpect(jsonPath("$.name.fr").value("Préparatoire"))
				.andExpect(jsonPath("$.own").value(true))).get("id").asText();

		// After the six shared years, in her settings and in every list of levels.
		call(get("/api/v1/reference"), ines).andExpect(jsonPath("$.levels.length()").value(7))
				.andExpect(jsonPath("$.levels[6].id").value(id));
		call(get("/api/v1/levels"), ines).andExpect(jsonPath("$[6].own").value(true))
				.andExpect(jsonPath("$[6].groupCount").value(0))
				.andExpect(jsonPath("$[0].own").value(false));

		call(put("/api/v1/levels/" + id), ines, Map.of("nameFr", "Classe préparatoire"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.name.fr").value("Classe préparatoire"))
				.andExpect(jsonPath("$.name.ar").value(""));
		call(delete("/api/v1/levels/" + id), ines).andExpect(status().isNoContent());
		call(get("/api/v1/reference"), ines).andExpect(jsonPath("$.levels.length()").value(6));
	}

	@Test
	void namesAreUniqueAmongTheLevelsSheSees() throws Exception {
		call(post("/api/v1/levels"), ines, Map.of("nameFr", "1ère année")).andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("level_exists"));
		call(post("/api/v1/levels"), ines, Map.of("nameFr", "7ème année")).andExpect(status().isCreated());
		call(post("/api/v1/levels"), ines, Map.of("nameFr", "7ÈME ANNÉE")).andExpect(status().isBadRequest());
		// Another teacher may use the same name in her own space.
		call(post("/api/v1/levels"), salma, Map.of("nameFr", "7ème année")).andExpect(status().isCreated());
		call(post("/api/v1/levels"), ines, Map.of("nameFr", " ")).andExpect(status().isBadRequest());
	}

	@Test
	void anotherTeachersLevelDoesNotExistForHer() throws Exception {
		String id = body(call(post("/api/v1/levels"), ines, Map.of("nameFr", "Préparatoire"))).get("id").asText();
		call(get("/api/v1/reference"), salma).andExpect(jsonPath("$.levels.length()").value(6));
		call(put("/api/v1/levels/" + id), salma, Map.of("nameFr", "À moi")).andExpect(status().isNotFound());
		call(delete("/api/v1/levels/" + id), salma).andExpect(status().isNotFound());
		// Nor can she file a group under it.
		String subject = body(call(post("/api/v1/subjects"), salma, Map.of("nameFr", "Maths"))).get("id").asText();
		call(post("/api/v1/groups"), salma, Map.of("name", "Prépa", "subjectId", subject, "levelId", id))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.code").value("level_not_found"));
	}

	@Test
	void aSharedLevelCannotBeChanged() throws Exception {
		String shared = body(call(get("/api/v1/reference"), ines)).get("levels").get(0).get("id").asText();
		call(put("/api/v1/levels/" + shared), ines, Map.of("nameFr", "CP")).andExpect(status().isNotFound());
		call(delete("/api/v1/levels/" + shared), ines).andExpect(status().isNotFound());
	}

	@Test
	void aLevelInUseStays() throws Exception {
		String id = body(call(post("/api/v1/levels"), ines, Map.of("nameFr", "Préparatoire"))).get("id").asText();
		String subject = body(call(post("/api/v1/subjects"), ines, Map.of("nameFr", "Maths"))).get("id").asText();
		call(post("/api/v1/groups"), ines, Map.of("name", "Prépa", "subjectId", subject, "levelId", id))
				.andExpect(status().isCreated());
		call(get("/api/v1/levels"), ines).andExpect(jsonPath("$[6].groupCount").value(1));
		call(delete("/api/v1/levels/" + id), ines).andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("level_in_use"));
	}

	@Test
	void onlyATeacherManagesLevels() throws Exception {
		call(post("/api/v1/levels"), null, Map.of("nameFr", "Préparatoire")).andExpect(status().isUnauthorized());
	}

	private String teacher(String username) throws Exception {
		users.save(User.builder()
				.role(Role.TEACHER)
				.username(username)
				.firstName(username)
				.lastName("Test")
				.passwordHash(passwordEncoder.encode(PASSWORD))
				.mustChangePassword(false)
				.build());
		String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
						.content(json.writeValueAsString(Map.of("login", username, "password", PASSWORD))))
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		return json.readTree(body).get("accessToken").asText();
	}

	private ResultActions call(MockHttpServletRequestBuilder request, String token) throws Exception {
		return call(request, token, null);
	}

	private ResultActions call(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
		if (token != null) {
			request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
		}
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
		}
		return mvc.perform(request);
	}

	private JsonNode body(ResultActions result) throws Exception {
		return json.readTree(result.andReturn().getResponse().getContentAsString());
	}
}
