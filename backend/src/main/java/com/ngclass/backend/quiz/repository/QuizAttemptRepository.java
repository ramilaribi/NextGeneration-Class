package com.ngclass.backend.quiz.repository;

import com.ngclass.backend.quiz.domain.QuizAttempt;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuizAttemptRepository extends JpaRepository<QuizAttempt, UUID> {
	List<QuizAttempt> findByRecipientIdOrderByAttemptNoAsc(UUID recipientId);

	List<QuizAttempt> findByRecipientIdInOrderByAttemptNoAsc(Collection<UUID> recipientIds);

	/** Attempts still open that started before [startedBefore], or every open one: the job closes those whose time is up. */
	@Query("select a from QuizAttempt a where a.submittedAt is null and a.startedAt <= :now")
	List<QuizAttempt> findOpen(@Param("now") Instant now);
}
