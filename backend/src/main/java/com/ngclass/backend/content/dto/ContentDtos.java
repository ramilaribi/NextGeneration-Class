package com.ngclass.backend.content.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.ngclass.backend.common.LocalizedText;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** The library (spec 04) and the pupil's and parent's "Cours". */
public final class ContentDtos {
	private ContentDtos() {
	}

	public record ChapterRequest(@NotNull UUID subjectId, @NotNull UUID levelId, @NotBlank @Size(max = 120) String title) {
	}

	public record ChapterRename(@NotBlank @Size(max = 120) String title) {
	}

	public record ChapterItem(UUID id, UUID subjectId, UUID levelId, String title, int position, List<UUID> sharedGroupIds) {
	}

	/** The JSON part of an upload; the file is the other part. */
	public record UploadRequest(
			@NotBlank @Size(max = 160) String title,
			@NotNull UUID subjectId,
			@NotNull UUID levelId,
			UUID chapterId,
			@NotBlank String tag,
			boolean draft,
			List<UUID> groupIds) {
	}

	public record UpdateRequest(
			@NotBlank @Size(max = 160) String title,
			@NotNull UUID subjectId,
			@NotNull UUID levelId,
			UUID chapterId,
			@NotBlank String tag,
			boolean draft) {
	}

	public record ShareRequest(@NotNull List<UUID> groupIds) {
	}

	/** A page written in the app (release 3): where it sits and its tag. It starts empty, as a draft. */
	public record PageRequest(
			@NotBlank @Size(max = 160) String title,
			@NotNull UUID subjectId,
			@NotNull UUID levelId,
			UUID chapterId,
			@NotBlank String tag) {
	}

	/** What the editor saves: both documents whole (Delta operations), the page and its Corrigé. */
	public record PageSave(@NotNull JsonNode body, @NotNull JsonNode answerBody) {
	}

	/** The editor's page: its library row, both documents, and signed links to its pictures by id. */
	public record PageResponse(ContentItemResponse item, JsonNode body, JsonNode answerBody, Map<UUID, String> pictureUrls) {
	}

	/** A picture uploaded for a page: the Delta names it by [id]; [url] shows it for half an hour. */
	public record PictureResponse(UUID id, String url) {
	}

	/** [kind]: PDF, IMAGE, WORD or PAGE. [status]: DRAFT, PUBLISHED or ARCHIVED. */
	public record ContentItemResponse(
			UUID id,
			String title,
			UUID subjectId,
			UUID levelId,
			UUID chapterId,
			String tag,
			String status,
			String kind,
			String fileName,
			long sizeBytes,
			Integer pageCount,
			List<UUID> sharedGroupIds,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record LibraryResponse(List<ChapterItem> chapters, List<ContentItemResponse> items) {
	}

	public record SubjectRef(UUID id, LocalizedText name, String color, int position) {
	}

	public record ChapterRef(UUID id, String title, int position) {
	}

	/** A document in a pupil's (or parent's) Cours. [isNew]: not opened yet by this user. */
	public record MyContentItem(
			UUID id,
			String title,
			String tag,
			String kind,
			Integer pageCount,
			SubjectRef subject,
			ChapterRef chapter,
			Instant sharedAt,
			boolean isNew) {
	}

	/**
	 * What the viewer needs. Links are relative to the API base and signed: they work without the access
	 * token for half an hour. [pageUrls] is empty for a Word file, which only downloads. A page written in
	 * the app has its [body] and the links to its pictures instead, never its Corrigé.
	 */
	public record ContentViewResponse(
			UUID id,
			String title,
			LocalizedText subjectName,
			String chapterTitle,
			String kind,
			String tag,
			Integer pageCount,
			String fileName,
			long sizeBytes,
			List<String> pageUrls,
			String downloadUrl,
			JsonNode body,
			Map<UUID, String> pictureUrls) {
	}
}
