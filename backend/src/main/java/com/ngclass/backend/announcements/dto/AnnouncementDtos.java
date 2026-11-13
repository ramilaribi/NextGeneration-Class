package com.ngclass.backend.announcements.dto;

import com.ngclass.backend.planning.dto.PlanningDtos.GroupRef;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Announcements (Release 4, spec 08). */
public final class AnnouncementDtos {
	private AnnouncementDtos() {
	}

	/** [groupIds] or [studentId], not both. [audience]: PUPILS, PARENTS or BOTH. */
	public record AnnouncementRequest(
			@NotBlank @Size(max = 120) String title,
			@NotBlank @Size(max = 2000) String body,
			@NotBlank String audience,
			List<UUID> groupIds,
			UUID studentId) {
	}

	/** A group as chosen ([group] null once it is deleted), or a pupil ([studentId]); [label] its name of the day. */
	public record TargetItem(GroupRef group, UUID studentId, String label) {
	}

	/** [recipients]: the people it reached; [read]: how many opened it. */
	public record AnnouncementItem(
			UUID id,
			String title,
			String body,
			String audience,
			List<TargetItem> targets,
			Instant createdAt,
			int recipients,
			int read) {
	}

	/** Someone who has not read it yet: a pupil, or a parent ([childFirstName] is the child). */
	public record UnreadPerson(String firstName, String lastName, boolean parent, String childFirstName) {
	}
}
