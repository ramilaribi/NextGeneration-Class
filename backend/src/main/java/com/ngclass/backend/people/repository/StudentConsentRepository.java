package com.ngclass.backend.people.repository;

import com.ngclass.backend.people.domain.StudentConsent;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StudentConsentRepository extends JpaRepository<StudentConsent, UUID> {
	List<StudentConsent> findByStudentIdIn(Collection<UUID> studentIds);
}
