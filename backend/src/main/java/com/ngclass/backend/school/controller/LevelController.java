package com.ngclass.backend.school.controller;

import com.ngclass.backend.school.dto.LevelRequest;
import com.ngclass.backend.school.dto.LevelUsageItem;
import com.ngclass.backend.school.dto.ReferenceResponse.LevelItem;
import com.ngclass.backend.school.service.LevelService;
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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Everyone reads levels through /reference; the teacher lists them with their use, adds and edits hers here. */
@RestController
@RequestMapping("/api/v1/levels")
@RequiredArgsConstructor
@PreAuthorize("hasRole('TEACHER')")
public class LevelController {
	private final LevelService levelService;

	@GetMapping
	public List<LevelUsageItem> list() {
		return levelService.listWithUsage();
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public LevelItem create(@Valid @RequestBody LevelRequest request) {
		return levelService.create(request);
	}

	@PutMapping("/{id}")
	public LevelItem update(@PathVariable UUID id, @Valid @RequestBody LevelRequest request) {
		return levelService.update(id, request);
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@PathVariable UUID id) {
		levelService.delete(id);
	}
}
