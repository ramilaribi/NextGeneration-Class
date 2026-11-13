package com.ngclass.backend.quiz.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Spec 05: a timed quiz is sent when its time is up, even if the pupil closed the app; the server checks. */
@Component
@Slf4j
@RequiredArgsConstructor
public class QuizJobs {
	private final QuizAttemptService attempts;

	@Scheduled(fixedDelayString = "PT1M", initialDelayString = "PT1M")
	public void closeOverdue() {
		int closed = attempts.closeOverdue();
		if (closed > 0) {
			log.info("{} quiz attempts sent when their time was up", closed);
		}
	}
}
