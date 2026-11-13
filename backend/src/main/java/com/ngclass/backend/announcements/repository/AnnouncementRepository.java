package com.ngclass.backend.announcements.repository;

import com.ngclass.backend.announcements.domain.Announcement;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AnnouncementRepository extends JpaRepository<Announcement, UUID> {
	List<Announcement> findByTeacherIdOrderByCreatedAtDesc(UUID teacherId);

	Optional<Announcement> findByIdAndTeacherId(UUID id, UUID teacherId);
}
