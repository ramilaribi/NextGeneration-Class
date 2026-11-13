package com.ngclass.backend.announcements.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** What the teacher chose: a group, or one pupil, with its name of the day. */
@Entity
@Table(name = "announcement_targets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AnnouncementTarget {
	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	private UUID id;

	@Column(nullable = false)
	private UUID announcementId;

	private UUID groupId;

	private UUID studentId;

	@Column(nullable = false, length = 160)
	private String label;

	@Column(nullable = false)
	private int position;
}
