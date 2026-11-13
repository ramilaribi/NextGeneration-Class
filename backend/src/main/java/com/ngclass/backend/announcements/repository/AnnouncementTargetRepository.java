package com.ngclass.backend.announcements.repository;

import com.ngclass.backend.announcements.domain.AnnouncementTarget;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AnnouncementTargetRepository extends JpaRepository<AnnouncementTarget, UUID> {
	List<AnnouncementTarget> findByAnnouncementIdInOrderByPositionAsc(Collection<UUID> announcementIds);
}
