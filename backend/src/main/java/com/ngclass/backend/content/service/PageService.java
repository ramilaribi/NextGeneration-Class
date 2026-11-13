package com.ngclass.backend.content.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.content.domain.ContentItem;
import com.ngclass.backend.content.domain.ContentShare;
import com.ngclass.backend.content.domain.ContentStatus;
import com.ngclass.backend.content.domain.ContentType;
import com.ngclass.backend.content.domain.FileAsset;
import com.ngclass.backend.content.domain.FileKind;
import com.ngclass.backend.content.dto.ContentDtos.ContentItemResponse;
import com.ngclass.backend.content.dto.ContentDtos.PageRequest;
import com.ngclass.backend.content.dto.ContentDtos.PageResponse;
import com.ngclass.backend.content.dto.ContentDtos.PageSave;
import com.ngclass.backend.content.dto.ContentDtos.PictureResponse;
import com.ngclass.backend.content.repository.ContentItemRepository;
import com.ngclass.backend.content.repository.ContentShareRepository;
import com.ngclass.backend.content.repository.FileAssetRepository;
import com.ngclass.backend.content.service.FileInspector.Inspected;
import com.ngclass.backend.content.storage.FileStorage;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Pages written in the app, like in Word (release 3, design r3/EditeurDocument.png). The editor saves both
 * documents whole, on its own; publishing, sharing and giving as homework are the library's, as for a file.
 */
@Service
@RequiredArgsConstructor
public class PageService {
	/** About 150 pages of text: far more than a série, small enough for one request. */
	static final int MAX_CHARS = 400_000;

	/** The embed that names a picture by its file id: {"insert": {"picture": {"id": "<id>", "size": "medium"}}}. */
	static final String PICTURE = "picture";

	private final ContentService contents;
	private final ContentItemRepository items;
	private final ContentShareRepository shares;
	private final FileAssetRepository files;
	private final FileStorage storage;
	private final FileInspector inspector;
	private final FileLinks links;
	private final CurrentTeacher teacher;

	@Transactional
	public PageResponse create(PageRequest request) {
		contents.placement(request.subjectId(), request.levelId(), request.chapterId());
		ContentItem item = items.saveAndFlush(ContentItem.builder()
				.teacherId(teacher.id())
				.type(ContentType.PAGE)
				.title(request.title().trim())
				.subjectId(request.subjectId())
				.levelId(request.levelId())
				.chapterId(request.chapterId())
				.status(ContentStatus.DRAFT)
				.tag(ContentService.tag(request.tag()))
				.body(empty())
				.answerBody(empty())
				.build());
		return response(item);
	}

	@Transactional(readOnly = true)
	public PageResponse page(UUID id) {
		return response(own(id));
	}

	/** Both documents, whole; the library row comes back with its new date. */
	@Transactional
	public ContentItemResponse save(UUID id, PageSave request) {
		ContentItem item = own(id);
		item.setBody(checked(request.body()));
		item.setAnswerBody(checked(request.answerBody()));
		items.saveAndFlush(item);
		return ContentService.response(item, shares.findByItemId(id).stream().map(ContentShare::getGroupId).toList());
	}

	/** A JPEG or PNG for a page (the app makes photos lighter first); the Delta then names it by id. */
	@Transactional
	public PictureResponse picture(byte[] data, String fileName) {
		Inspected inspected = inspector.inspect(data, fileName);
		if (FileKind.of(inspected.mimeType()) != FileKind.IMAGE) {
			throw ApiException.badRequest("picture_required");
		}
		FileAsset asset = files.save(FileAsset.builder()
				.teacherId(teacher.id())
				.storageKey(storage.save(data))
				.mimeType(inspected.mimeType())
				.sizeBytes(data.length)
				.originalName(ContentService.cleanName(fileName))
				.build());
		return new PictureResponse(asset.getId(), links.pictureLink(asset.getId()));
	}

	/** Signed links to the pictures these documents show, only the page's teacher's own files. */
	public Map<UUID, String> pictureUrls(ContentItem item, JsonNode... documents) {
		Set<UUID> ids = new LinkedHashSet<>();
		for (JsonNode document : documents) {
			collectPictures(document, ids);
		}
		Map<UUID, String> urls = new LinkedHashMap<>();
		if (ids.isEmpty()) {
			return urls;
		}
		for (FileAsset file : files.findAllById(ids)) {
			if (file.getTeacherId().equals(item.getTeacherId())) {
				urls.put(file.getId(), links.pictureLink(file.getId()));
			}
		}
		return urls;
	}

	private PageResponse response(ContentItem item) {
		return new PageResponse(
				ContentService.response(item, shares.findByItemId(item.getId()).stream().map(ContentShare::getGroupId).toList()),
				item.getBody(),
				item.getAnswerBody(),
				pictureUrls(item, item.getBody(), item.getAnswerBody()));
	}

	private ContentItem own(UUID id) {
		ContentItem item = contents.own(id);
		if (!item.isPage()) {
			throw ApiException.notFound("content_not_found");
		}
		return item;
	}

	/** An empty page: one empty line, as the editor starts. */
	static JsonNode empty() {
		JsonNodeFactory json = JsonNodeFactory.instance;
		return json.arrayNode().add(json.objectNode().put("insert", "\n"));
	}

	/** Delta operations only (an array of objects, each with an insert), and not too long. */
	static JsonNode checked(JsonNode document) {
		if (document == null || !document.isArray() || document.isEmpty()) {
			throw ApiException.badRequest("page_invalid");
		}
		for (JsonNode op : document) {
			if (!op.isObject() || !op.has("insert")) {
				throw ApiException.badRequest("page_invalid");
			}
		}
		if (document.toString().length() > MAX_CHARS) {
			throw ApiException.badRequest("page_too_long");
		}
		return document;
	}

	private static void collectPictures(JsonNode document, Set<UUID> ids) {
		if (document == null || !document.isArray()) {
			return;
		}
		for (JsonNode op : document) {
			JsonNode picture = op.path("insert").path(PICTURE);
			JsonNode id = picture.isObject() ? picture.path("id") : picture;
			if (id.isTextual()) {
				try {
					ids.add(UUID.fromString(id.asText()));
				} catch (IllegalArgumentException e) {
					// Not one of ours: shown as a missing picture.
				}
			}
		}
	}
}
