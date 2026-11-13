package com.ngclass.backend.content.controller;

import com.ngclass.backend.content.dto.ContentDtos.ContentItemResponse;
import com.ngclass.backend.content.dto.ContentDtos.PageRequest;
import com.ngclass.backend.content.dto.ContentDtos.PageResponse;
import com.ngclass.backend.content.dto.ContentDtos.PageSave;
import com.ngclass.backend.content.dto.ContentDtos.PictureResponse;
import com.ngclass.backend.content.service.ContentService;
import com.ngclass.backend.content.service.PageService;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** The teacher's pages written in the app (release 3). Publishing, sharing and archiving are ContentController's. */
@RestController
@RequestMapping("/api/v1/contents")
@PreAuthorize("hasRole('TEACHER')")
@RequiredArgsConstructor
public class PageController {
	private final PageService pages;

	@PostMapping("/pages")
	@ResponseStatus(HttpStatus.CREATED)
	public PageResponse create(@Valid @RequestBody PageRequest request) {
		return pages.create(request);
	}

	@GetMapping("/{id}/page")
	public PageResponse page(@PathVariable UUID id) {
		return pages.page(id);
	}

	@PutMapping("/{id}/page")
	public ContentItemResponse save(@PathVariable UUID id, @Valid @RequestBody PageSave request) {
		return pages.save(id, request);
	}

	/** One part, "file": a JPEG or PNG. */
	@PostMapping(path = "/pictures", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	@ResponseStatus(HttpStatus.CREATED)
	public PictureResponse picture(@RequestPart("file") MultipartFile file) {
		return pages.picture(ContentService.bytes(file), file.getOriginalFilename());
	}
}
