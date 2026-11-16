package com.ngclass.backend.people.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** The parents' agreement for one child: in the app by a parent, or on paper as recorded by the teacher. */
@Entity
@Table(name = "student_consents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudentConsent {
	public enum Method {
		APP,
		PAPER
	}

	@Id
	private UUID studentId;

	@Column(nullable = false)
	private int version;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private Method method;

	/** The parent who agreed in the app; null on paper. */
	@Column(length = 160)
	private String givenBy;

	@Column(nullable = false)
	private Instant givenAt;

	private UUID recordedBy;
}
