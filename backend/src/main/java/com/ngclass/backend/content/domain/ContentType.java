package com.ngclass.backend.content.domain;

/** An uploaded file (PDF, image, Word), a page written in the app (release 3, a Delta and no file), or a quiz (its own row). */
public enum ContentType {
	DOCUMENT,
	PAGE,
	QUIZ
}
