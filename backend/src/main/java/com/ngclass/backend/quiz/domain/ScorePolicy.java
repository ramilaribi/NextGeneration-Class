package com.ngclass.backend.quiz.domain;

/** With several attempts, the grade that counts (spec 05): the best one by default, or the last one. */
public enum ScorePolicy {
	BEST,
	LAST
}
