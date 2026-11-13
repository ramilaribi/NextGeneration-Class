package com.ngclass.backend.work.dto;

import com.ngclass.backend.content.dto.ContentDtos.SubjectRef;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** "Résultats" of a pupil (spec 07 and 09), the same numbers for the pupil, the parents and later the teacher. */
public final class ResultsDtos {
	private ResultsDtos() {
	}

	/**
	 * A grade as given ([score] out of [maxScore]) and on /20 ([score20]). [kind]: HOMEWORK (corrected, [date] when
	 * corrected, [assignmentId]) or EVALUATION (a paper test, [date] the day it was held, [evaluationId]). An
	 * evaluation can say [absent]: no score, never counted as 0.
	 */
	public record GradeItem(
			String kind,
			UUID assignmentId,
			UUID evaluationId,
			String title,
			Instant date,
			BigDecimal score,
			int maxScore,
			BigDecimal score20,
			String comment,
			boolean absent) {
	}

	/**
	 * One subject: [average] on /20 (null before the first grade), [trend] UP, DOWN or STABLE from 4 grades (null
	 * before), homework [submitted] out of [due], [attendanceRate] in % (null before a counted session), grades
	 * latest first.
	 */
	public record SubjectResult(
			SubjectRef subject,
			BigDecimal average,
			int gradeCount,
			String trend,
			int submitted,
			int due,
			Integer attendanceRate,
			List<GradeItem> grades,
			/** The chapters covered in class this year, in the order they were first covered (Release 4). */
			List<String> chaptersSeen) {
	}

	/**
	 * One month of the school year so far ([month]: "2026-09"), all subjects: homework [submitted] out of [due] (by
	 * deadline month, the same rules as a subject's), and [attendanceRate] in % (null without a counted session).
	 */
	public record MonthProgress(String month, int submitted, int due, Integer attendanceRate) {
	}

	/** [months]: September to this month, for the "Chaque mois" chart (Release 4). */
	public record MyResults(List<SubjectResult> subjects, List<MonthProgress> months) {
	}
}
