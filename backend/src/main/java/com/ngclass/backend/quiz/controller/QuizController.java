package com.ngclass.backend.quiz.controller;

import com.ngclass.backend.quiz.dto.QuizDtos.PreviewRequest;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizCreate;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizResponse;
import com.ngclass.backend.quiz.dto.QuizDtos.QuizSave;
import com.ngclass.backend.quiz.dto.QuizDtos.ReviewItem;
import com.ngclass.backend.quiz.service.QuizService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The teacher's quiz builder (release 3). Publishing and archiving are ContentController's; pictures PageController's. */
@RestController
@RequestMapping("/api/v1/contents")
@PreAuthorize("hasRole('TEACHER')")
@RequiredArgsConstructor
public class QuizController {
	private final QuizService quizzes;

	@PostMapping("/quizzes")
	@ResponseStatus(HttpStatus.CREATED)
	public QuizResponse create(@Valid @RequestBody QuizCreate request) {
		return quizzes.create(request);
	}

	@GetMapping("/{id}/quiz")
	public QuizResponse quiz(@PathVariable UUID id) {
		return quizzes.quiz(id);
	}

	@PutMapping("/{id}/quiz")
	public QuizResponse save(@PathVariable UUID id, @Valid @RequestBody QuizSave request) {
		return quizzes.save(id, request);
	}

	@PostMapping("/{id}/quiz/duplicate")
	@ResponseStatus(HttpStatus.CREATED)
	public QuizResponse duplicate(@PathVariable UUID id) {
		return quizzes.duplicate(id);
	}

	@PostMapping("/{id}/quiz/preview")
	public List<ReviewItem> preview(@PathVariable UUID id, @Valid @RequestBody PreviewRequest request) {
		return quizzes.preview(id, request.answers());
	}
}
