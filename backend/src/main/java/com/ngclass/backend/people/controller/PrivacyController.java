package com.ngclass.backend.people.controller;

import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.people.dto.StudentDtos.Consent;
import com.ngclass.backend.people.dto.StudentDtos.PrivacyInfo;
import com.ngclass.backend.people.service.PrivacyService;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The privacy notice and the parents' agreement. */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PrivacyController {
	private final PrivacyService privacy;

	@GetMapping("/me/privacy")
	public PrivacyInfo info(@AuthenticationPrincipal AuthenticatedUser user) {
		return privacy.info(user);
	}

	/** A parent accepts the notice (once, for all their children). Nothing to accept for the others. */
	@PostMapping("/me/privacy")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void accept(@AuthenticationPrincipal AuthenticatedUser user) {
		privacy.accept(user);
	}

	/** "Accord reçu sur papier". */
	@PostMapping("/students/{id}/consent")
	@PreAuthorize("hasRole('TEACHER')")
	public Consent paper(@PathVariable UUID id) {
		return privacy.paper(id);
	}
}
