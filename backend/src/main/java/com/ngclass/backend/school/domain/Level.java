package com.ngclass.backend.school.domain;

import com.ngclass.backend.common.LocalizedText;
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

@Entity
@Table(name = "levels")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Level {
	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	private UUID id;

	/** Null for the shared levels (the six years of the primary school); a teacher's own level otherwise (V17). */
	private UUID teacherId;

	/** Unique among the levels a teacher sees (case ignored). */
	@Column(nullable = false, length = 40)
	private String nameFr;

	@Column(nullable = false, length = 60)
	private String nameAr;

	@Column(nullable = false)
	private int position;

	/** Added by a teacher, so she can rename or delete it; the shared ones are fixed. */
	public boolean isOwn() {
		return teacherId != null;
	}

	public LocalizedText name() {
		return new LocalizedText(nameFr, nameAr);
	}
}
