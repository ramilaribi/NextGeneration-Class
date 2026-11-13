package com.ngclass.backend.quiz.domain;

/** When a pupil sees the right answers (business rules 9): after the deadline by default, right after sending, or never. */
public enum AnswersShown {
	AFTER_DEADLINE,
	AFTER_SUBMIT,
	NEVER
}
