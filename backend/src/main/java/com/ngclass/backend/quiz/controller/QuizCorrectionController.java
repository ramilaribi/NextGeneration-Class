package com.ngclass.backend.quiz.controller;

import com.ngclass.backend.quiz.dto.QuizDtos.QuizCorrection;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizCorrectionRequest;
import com.ngclass.backend.quiz.service.QuizAttemptService;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** A pupil's quiz attempts for the teacher: every answer, and the open questions to score ("À corriger"). */
@RestController
@RequestMapping("/api/v1/assignments/{id}/quiz/{studentId}")
@PreAuthorize("hasRole('TEACHER')")
@RequiredArgsConstructor
public class QuizCorrectionController {
	private final QuizAttemptService attempts;

	@GetMapping
	public QuizCorrection correction(@PathVariable UUID id, @PathVariable UUID studentId, @RequestParam(required = false) UUID attemptId) {
		return attempts.correction(id, studentId, attemptId);
	}

	@PutMapping("/attempts/{attemptId}")
	public QuizCorrection correct(@PathVariable UUID id, @PathVariable UUID studentId, @PathVariable UUID attemptId,
			@Valid @RequestBody QuizCorrectionRequest request) {
		return attempts.correct(id, studentId, attemptId, request);
	}
}
