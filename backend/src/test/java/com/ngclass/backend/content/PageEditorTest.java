package com.ngclass.backend.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.domain.User;
import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.school.repository.LevelRepository;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Release 3, step 1: pages written in the app, like in Word (design r3/EditeurDocument.png), read by pupils and parents. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class PageEditorTest {
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
	private String maths;
	private String group4A;
	private String otherGroup;
	private String pupil;
	private String parent;
	private String adamId;

	@BeforeEach
	void cleanAndSetUp() throws Exception {
		jdbc.execute("""
				truncate content_views, content_shares, content_items, file_assets, chapters, notifications, attendance, sessions,
				recurrence_rules, comments, private_notes, group_members, class_groups, parent_students, parents, students,
				subjects, refresh_tokens, users cascade""");
		account(Role.TEACHER, "enseignante");
		ines = token("enseignante", PASSWORD);
		levelId = levels.findAllByOrderByPositionAsc().get(3).getId().toString();
		maths = createSubject(ines, "Mathématiques");
		group4A = createGroup(ines, "4ème année · Maths", maths);
		otherGroup = createGroup(ines, "4ème année · Soutien", maths);

		// Adam has his own login; Mouna follows him. Both choose their password at first login.
		Map<String, Object> adam = new HashMap<>(Map.of("firstName", "Adam", "lastName", "Gharbi", "levelId", levelId,
				"groupIds", List.of(group4A), "createLogin", true));
		adam.put("parents", List.of(Map.of("firstName", "Mouna", "lastName", "Gharbi", "phone", "20000001", "relation", "mother")));
		JsonNode created = body(call(post("/api/v1/students").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(adam)), ines)
				.andExpect(status().isCreated()));
		adamId = created.at("/student/id").asText();
		pupil = firstLogin(credential(created, "STUDENT"));
		parent = firstLogin(credential(created, "PARENT"));
	}

	@Test
	void aPageWrittenInTheAppIsSavedPublishedAndReadWithoutItsCorrige() throws Exception {
		String chapter = createChapter(ines, maths, "Les fractions");
		JsonNode created = body(call(post("/api/v1/contents/pages").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", " Série 3 : les fractions ", "subjectId", maths, "levelId", levelId, "chapterId", chapter, "tag", "SERIE"))), ines)
				.andExpect(status().isCreated()));
		String id = created.at("/item/id").asText();
		assertThat(created.at("/item/title").asText()).isEqualTo("Série 3 : les fractions");
		assertThat(created.at("/item/kind").asText()).isEqualTo("PAGE");
		assertThat(created.at("/item/status").asText()).isEqualTo("DRAFT");
		assertThat(created.at("/item/fileName").isNull()).isTrue();
		assertThat(created.at("/body").toString()).isEqualTo("[{\"insert\":\"\\n\"}]");
		assertThat(created.at("/answerBody").toString()).isEqualTo("[{\"insert\":\"\\n\"}]");

		// A picture for the page, shown through a signed link that needs no token.
		JsonNode picture = body(call(multipart("/api/v1/contents/pictures").file(new MockMultipartFile("file", "pizza.jpg", "image/jpeg", jpeg())), ines)
				.andExpect(status().isCreated()));
		String pictureId = picture.at("/id").asText();
		mvc.perform(get("/api/v1/" + picture.at("/url").asText()))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.CONTENT_TYPE, "image/jpeg"));

		// The editor saves both documents whole: text, a formula, a table, the picture, answer lines.
		List<Object> page = List.of(
				Map.of("insert", "Exercice 1", "attributes", Map.of("bold", true)),
				Map.of("insert", "\nCalcule : "),
				Map.of("insert", Map.of("formula", "3/4 + 1/2")),
				Map.of("insert", "\n"),
				Map.of("insert", Map.of("table", Map.of("rows", List.of(List.of("Fraction", "$3/5$"), List.of("", ""))))),
				Map.of("insert", "\n"),
				Map.of("insert", Map.of("picture", Map.of("id", pictureId, "size", "medium"))),
				Map.of("insert", "\n"),
				Map.of("insert", Map.of("lines", Map.of("count", 2))),
				Map.of("insert", "\nأحسب\n", "attributes", Map.of("direction", "rtl")));
		List<Object> corrige = List.of(Map.of("insert", "Réponse : 5/4\n"));
		JsonNode saved = body(call(put("/api/v1/contents/" + id + "/page").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("body", page, "answerBody", corrige))), ines)
				.andExpect(status().isOk()));
		assertThat(saved.at("/id").asText()).isEqualTo(id);
		assertThat(saved.at("/kind").asText()).isEqualTo("PAGE");

		JsonNode reopened = body(call(get("/api/v1/contents/" + id + "/page"), ines).andExpect(status().isOk()));
		assertThat(reopened.at("/body")).isEqualTo(json.valueToTree(page));
		assertThat(reopened.at("/answerBody/0/insert").asText()).isEqualTo("Réponse : 5/4\n");
		assertThat(reopened.at("/pictureUrls/" + pictureId).asText()).startsWith("files/");
		JsonNode library = body(call(get("/api/v1/contents"), ines));
		assertThat(library.at("/items/0/id").asText()).isEqualTo(id);
		assertThat(library.at("/items/0/kind").asText()).isEqualTo("PAGE");

		// A draft is nobody's but hers.
		call(put("/api/v1/contents/" + id + "/shares").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("groupIds", List.of(group4A)))), ines)
				.andExpect(status().isConflict());
		call(get("/api/v1/contents/" + id + "/view"), pupil).andExpect(status().isNotFound());

		// "Publier", then shared with 4A, like any document.
		call(put("/api/v1/contents/" + id).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Série 3 : les fractions", "subjectId", maths, "levelId", levelId, "chapterId", chapter, "tag", "SERIE", "draft", false))), ines)
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("PUBLISHED"));
		call(put("/api/v1/contents/" + id + "/shares").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("groupIds", List.of(group4A)))), ines)
				.andExpect(status().isOk());

		JsonNode cours = body(call(get("/api/v1/me/contents"), pupil).andExpect(status().isOk()));
		assertThat(cours.at("/0/kind").asText()).isEqualTo("PAGE");
		assertThat(cours.at("/0/isNew").asBoolean()).isTrue();
		String viewed = call(get("/api/v1/contents/" + id + "/view"), pupil).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		JsonNode view = json.readTree(viewed);
		assertThat(view.at("/kind").asText()).isEqualTo("PAGE");
		assertThat(view.at("/body")).isEqualTo(json.valueToTree(page));
		assertThat(view.at("/pageUrls")).isEmpty();
		assertThat(view.at("/downloadUrl").isNull()).isTrue();
		assertThat(view.at("/pictureUrls/" + pictureId).asText()).startsWith("files/");
		assertThat(viewed).doesNotContain("Réponse").doesNotContain("answerBody");
		mvc.perform(get("/api/v1/" + view.at("/pictureUrls/" + pictureId).asText())).andExpect(status().isOk());
		assertThat(body(call(get("/api/v1/me/contents"), pupil)).at("/0/isNew").asBoolean()).isFalse();

		// The parent reads it too; neither of them reaches the editor.
		JsonNode parentView = body(call(get("/api/v1/contents/" + id + "/view"), parent).andExpect(status().isOk()));
		assertThat(parentView.at("/body/0/insert").asText()).isEqualTo("Exercice 1");
		call(get("/api/v1/contents/" + id + "/page"), pupil).andExpect(status().isForbidden());
		call(get("/api/v1/contents/" + id + "/page"), parent).andExpect(status().isForbidden());
		call(put("/api/v1/contents/" + id + "/page").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("body", corrige, "answerBody", corrige))), pupil)
				.andExpect(status().isForbidden());

		// A page can be given as homework: the pupil's homework names it as a page.
		Map<String, Object> homework = new HashMap<>(Map.of("contentItemId", id, "groupId", group4A, "title", "Série 3",
				"deadlineAt", java.time.Instant.now().plus(java.time.Duration.ofDays(2)).toString(), "submissionMode", "FILE", "allowLate", true));
		String assignment = body(call(post("/api/v1/assignments").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(homework)), ines)
				.andExpect(status().isCreated())).at("/id").asText();
		JsonNode mine = body(call(get("/api/v1/me/assignments/" + assignment), pupil).andExpect(status().isOk()));
		assertThat(mine.at("/content/kind").asText()).isEqualTo("PAGE");
	}

	@Test
	void dupliquerMakesADraftCopyOfAFileOrAPageSharedWithNobody() throws Exception {
		String chapter = createChapter(ines, maths, "Les fractions");
		JsonNode file = body(upload(ines, pdf(2), "serie.pdf", meta("Série 2", chapter, "SERIE", false, List.of(group4A))).andExpect(status().isCreated()));
		JsonNode fileCopy = body(call(post("/api/v1/contents/" + file.at("/id").asText() + "/duplicate"), ines).andExpect(status().isCreated()));
		assertThat(fileCopy.at("/title").asText()).isEqualTo("Série 2 (copie)");
		assertThat(fileCopy.at("/status").asText()).isEqualTo("DRAFT");
		assertThat(fileCopy.at("/kind").asText()).isEqualTo("PDF");
		assertThat(fileCopy.at("/chapterId").asText()).isEqualTo(chapter);
		assertThat(fileCopy.at("/sharedGroupIds").size()).isZero();
		call(get("/api/v1/contents/" + fileCopy.at("/id").asText() + "/view"), ines).andExpect(status().isOk()).andExpect(jsonPath("$.pageUrls.length()").value(2));

		String page = body(call(post("/api/v1/contents/pages").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Série 3", "subjectId", maths, "levelId", levelId, "tag", "SERIE"))), ines)).at("/item/id").asText();
		List<Object> text = List.of(Map.of("insert", "Exercice 1\n"));
		List<Object> corrige = List.of(Map.of("insert", "5/4\n"));
		call(put("/api/v1/contents/" + page + "/page").contentType(MediaType.APPLICATION_JSON)
				.content(json.writeValueAsString(Map.of("body", text, "answerBody", corrige))), ines).andExpect(status().isOk());
		String pageCopy = body(call(post("/api/v1/contents/" + page + "/duplicate"), ines).andExpect(status().isCreated())).at("/id").asText();
		JsonNode copied = body(call(get("/api/v1/contents/" + pageCopy + "/page"), ines).andExpect(status().isOk()));
		assertThat(copied.at("/body/0/insert").asText()).isEqualTo("Exercice 1\n");
		assertThat(copied.at("/answerBody/0/insert").asText()).isEqualTo("5/4\n");

		// Only the teacher's own documents.
		account(Role.TEACHER, "autre");
		call(post("/api/v1/contents/" + page + "/duplicate"), token("autre", PASSWORD)).andExpect(status().isNotFound());
	}

	@Test
	void aPageKeepsOnlyDeltaOperationsAndAPictureMustBeAnImage() throws Exception {
		String id = body(call(post("/api/v1/contents/pages").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Leçon : les fractions", "subjectId", maths, "levelId", levelId, "tag", "COURS"))), ines)
				.andExpect(status().isCreated())).at("/item/id").asText();
		String url = "/api/v1/contents/" + id + "/page";
		for (String wrong : List.of(
				"{\"body\":{\"insert\":\"x\"},\"answerBody\":[{\"insert\":\"\\n\"}]}",
				"{\"body\":[],\"answerBody\":[{\"insert\":\"\\n\"}]}",
				"{\"body\":[{\"text\":\"x\"}],\"answerBody\":[{\"insert\":\"\\n\"}]}",
				"{\"body\":[\"x\"],\"answerBody\":[{\"insert\":\"\\n\"}]}")) {
			call(put(url).contentType(MediaType.APPLICATION_JSON).content(wrong), ines)
					.andExpect(status().isBadRequest())
					.andExpect(jsonPath("$.code").value("page_invalid"));
		}
		call(put(url).contentType(MediaType.APPLICATION_JSON).content("{\"body\":[{\"insert\":\"x\\n\"}]}"), ines)
				.andExpect(status().isBadRequest());
		String tooLong = "x".repeat(410_000);
		call(put(url).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("body", List.of(Map.of("insert", tooLong + "\n")), "answerBody", List.of(Map.of("insert", "\n"))))), ines)
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("page_too_long"));

		call(multipart("/api/v1/contents/pictures").file(new MockMultipartFile("file", "serie.pdf", "application/pdf", pdf(1))), ines)
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("picture_required"));

		// An uploaded file is not a page: the editor's endpoints do not open it.
		String file = body(upload(ines, pdf(1), "serie.pdf", meta("Série", null, "SERIE", true, List.of()))
				.andExpect(status().isCreated())).at("/id").asText();
		call(get("/api/v1/contents/" + file + "/page"), ines).andExpect(status().isNotFound());

		// Its title, tag and place change like any document's; archived, it leaves the library.
		call(put("/api/v1/contents/" + id).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("title", "Leçon 2", "subjectId", maths, "levelId", levelId, "tag", "AUTRE", "draft", true))), ines)
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.tag").value("AUTRE"))
				.andExpect(jsonPath("$.kind").value("PAGE"));
		call(post("/api/v1/contents/" + id + "/archive"), ines).andExpect(status().isNoContent());
		assertThat(body(call(get("/api/v1/contents"), ines)).at("/items")).hasSize(1);
	}

	private Map<String, Object> meta(String title, String chapterId, String tag, boolean draft, List<String> groupIds) {
		Map<String, Object> meta = new HashMap<>(Map.of("title", title, "subjectId", maths, "levelId", levelId, "tag", tag, "draft", draft, "groupIds", groupIds));
		if (chapterId != null) {
			meta.put("chapterId", chapterId);
		}
		return meta;
	}

	private MockHttpServletRequestBuilder multipartUpload(byte[] data, String name, Map<String, Object> meta) throws Exception {
		return multipart("/api/v1/contents")
				.file(new MockMultipartFile("file", name, "application/octet-stream", data))
				.file(new MockMultipartFile("meta", "", MediaType.APPLICATION_JSON_VALUE, json.writeValueAsBytes(meta)));
	}

	private ResultActions upload(String token, byte[] data, String name, Map<String, Object> meta) throws Exception {
		return call(multipartUpload(data, name, meta), token);
	}

	private String createChapter(String token, String subjectId, String title) throws Exception {
		return body(call(post("/api/v1/chapters").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
				Map.of("subjectId", subjectId, "levelId", levelId, "title", title))), token)
				.andExpect(status().isCreated())).at("/id").asText();
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

	private static byte[] pdf(int pages) throws Exception {
		try (PDDocument pdf = new PDDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
			for (int i = 0; i < pages; i++) {
				pdf.addPage(new PDPage(PDRectangle.A4));
			}
			pdf.save(out);
			return out.toByteArray();
		}
	}

	private static byte[] jpeg() throws Exception {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		ImageIO.write(new BufferedImage(40, 30, BufferedImage.TYPE_INT_RGB), "jpg", out);
		return out.toByteArray();
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

	/** Signs in with the temporary password and chooses a real one, as the app does. */
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
