package com.ngclass.backend.common;

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
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
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
 * Pre-production audit (docs/05-deployment/PREPROD_AUDIT.md, F1 and F2): ordinary request mistakes and
 * double clicks get a clear answer in the user's language, never a 500.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class ErrorResponsesTest {
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

	private String teacher;

	@BeforeEach
	void setUp() throws Exception {
		jdbc.execute("truncate content_shares, content_items, file_assets, chapters, subjects, refresh_tokens, users cascade");
		users.save(User.builder()
				.role(Role.TEACHER)
				.username("enseignante")
				.firstName("Ines")
				.lastName("Test")
				.passwordHash(passwordEncoder.encode(PASSWORD))
				.build());
		teacher = body(mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("login", "enseignante", "password", PASSWORD))))
				.andExpect(status().isOk())).at("/accessToken").asText();
	}

	@Test
	void requestMistakesAreTheCallersNotServerErrors() throws Exception {
		call(get("/api/v1/sessions"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("missing_parameter"))
				.andExpect(jsonPath("$.message").value("Requête incomplète."));
		call(delete("/api/v1/sessions"))
				.andExpect(status().isMethodNotAllowed())
				.andExpect(jsonPath("$.code").value("method_not_allowed"));
		call(post("/api/v1/sessions").contentType(MediaType.TEXT_PLAIN).content("x"))
				.andExpect(status().isUnsupportedMediaType())
				.andExpect(jsonPath("$.code").value("unsupported_media_type"));
		call(get("/api/v1/groups").accept(MediaType.APPLICATION_XML))
				.andExpect(status().isNotAcceptable());
		// In Arabic too.
		call(get("/api/v1/sessions").header(HttpHeaders.ACCEPT_LANGUAGE, "ar"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.message").value("طلب غير مكتمل."));
	}

	@Test
	void theSameCreateSentSixTimesAtOnceMakesOneChapterAndNoServerError() throws Exception {
		String subjectId = body(call(post("/api/v1/subjects").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("nameFr", "Mathématiques")))).andExpect(status().isCreated())).at("/id").asText();
		String levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		String chapter = json.writeValueAsString(Map.of("subjectId", subjectId, "levelId", levelId, "title", "Les fractions"));

		ExecutorService pool = Executors.newFixedThreadPool(6);
		List<Callable<Integer>> sends = new ArrayList<>();
		for (int i = 0; i < 6; i++) {
			sends.add(() -> call(post("/api/v1/chapters").contentType(MediaType.APPLICATION_JSON).content(chapter))
					.andReturn().getResponse().getStatus());
		}
		List<Integer> statuses = new ArrayList<>();
		for (Future<Integer> answer : pool.invokeAll(sends)) {
			statuses.add(answer.get());
		}
		pool.shutdown();

		assertThat(statuses).containsOnlyOnce(201);
		// The others: refused by the service (400, already exists) or, when they raced it, by the database (409).
		assertThat(statuses).allMatch(code -> code == 201 || code == 400 || code == 409);
		assertThat(jdbc.queryForObject("select count(*) from chapters", Integer.class)).isEqualTo(1);
	}

	/** A doubled quote shows as written in a message without values ("n''existe"): only {0} messages need it. */
	@Test
	void messagesWithoutValuesHaveSingleApostrophesAndBothLanguagesHaveTheSameKeys() throws Exception {
		Properties fr = properties("i18n/messages.properties");
		Properties ar = properties("i18n/messages_ar.properties");
		for (String key : fr.stringPropertyNames()) {
			String message = fr.getProperty(key);
			if (!message.contains("{")) {
				assertThat(message).as(key).doesNotContain("''");
			}
		}
		assertThat(ar.stringPropertyNames()).isEqualTo(fr.stringPropertyNames());
	}

	private static Properties properties(String path) throws Exception {
		Properties properties = new Properties();
		try (InputStream in = ErrorResponsesTest.class.getClassLoader().getResourceAsStream(path)) {
			properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
		}
		return properties;
	}

	private ResultActions call(MockHttpServletRequestBuilder request) throws Exception {
		return mvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + teacher));
	}

	private JsonNode body(ResultActions result) throws Exception {
		return json.readTree(result.andReturn().getResponse().getContentAsString());
	}
}
