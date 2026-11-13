package com.ngclass.backend.quiz.controller;

import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.quiz.dto.QuizDtos.AnswersSave;
import com.ngclass.backend.quiz.dto.QuizDtos.AttemptPlay;
import com.ngclass.backend.quiz.dto.QuizDtos.AttemptReview;
import com.ngclass.backend.quiz.dto.QuizDtos.MyQuiz;
import com.ngclass.backend.quiz.service.QuizAttemptService;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** A quiz given as homework, taken by the pupil or by a parent for the child ([studentId], as for other homework). */
@RestController
@RequestMapping("/api/v1/me/assignments/{id}/quiz")
@PreAuthorize("hasAnyRole('STUDENT', 'PARENT')")
@RequiredArgsConstructor
public class MyQuizController {
	private final QuizAttemptService attempts;

	@GetMapping
	public MyQuiz quiz(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable UUID id, @RequestParam(required = false) UUID studentId) {
		return attempts.mine(user, id, studentId);
	}

	@PostMapping("/attempts")
	public AttemptPlay start(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable UUID id, @RequestParam(required = false) UUID studentId) {
		return attempts.start(user, id, studentId);
	}

	@PutMapping("/attempts/{attemptId}/answers")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void answers(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable UUID id, @PathVariable UUID attemptId,
			@RequestParam(required = false) UUID studentId, @Valid @RequestBody AnswersSave request) {
		attempts.saveAnswers(user, id, studentId, attemptId, request.answers());
	}

	@PostMapping("/attempts/{attemptId}/submit")
	public AttemptReview submit(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable UUID id, @PathVariable UUID attemptId,
			@RequestParam(required = false) UUID studentId) {
		return attempts.submit(user, id, studentId, attemptId);
	}

	@GetMapping("/attempts/{attemptId}")
	public AttemptReview attempt(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable UUID id, @PathVariable UUID attemptId,
			@RequestParam(required = false) UUID studentId) {
		return attempts.attempt(user, id, studentId, attemptId);
	}
}
