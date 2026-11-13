package com.ngclass.backend.quiz.repository;

import com.ngclass.backend.quiz.domain.Quiz;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizRepository extends JpaRepository<Quiz, UUID> {
}
