package com.ngclass.backend.announcements.controller;

import com.ngclass.backend.announcements.dto.AnnouncementDtos.AnnouncementItem;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.AnnouncementRequest;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.UnreadPerson;
import com.ngclass.backend.announcements.service.AnnouncementService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The teacher's announcements (Release 4). Families read them in their notifications. */
@RestController
@RequestMapping("/api/v1/announcements")
@PreAuthorize("hasRole('TEACHER')")
@RequiredArgsConstructor
public class AnnouncementController {
	private final AnnouncementService announcements;

	@GetMapping
	public List<AnnouncementItem> list() {
		return announcements.list();
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public AnnouncementItem create(@Valid @RequestBody AnnouncementRequest request) {
		return announcements.create(request);
	}

	@GetMapping("/{id}/unread")
	public List<UnreadPerson> unread(@PathVariable UUID id) {
		return announcements.unread(id);
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@PathVariable UUID id) {
		announcements.delete(id);
	}
}
