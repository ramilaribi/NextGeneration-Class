package com.ngclass.backend.people.service;

import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.domain.User;
import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.auth.service.Privacy;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.people.domain.Parent;
import com.ngclass.backend.people.domain.Student;
import com.ngclass.backend.people.domain.StudentConsent;
import com.ngclass.backend.people.dto.StudentDtos.Consent;
import com.ngclass.backend.people.dto.StudentDtos.PrivacyInfo;
import com.ngclass.backend.people.repository.ParentRepository;
import com.ngclass.backend.people.repository.StudentConsentRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The privacy notice and the parents' agreement (mockups screens/r4/AccordParents.png, ConfidentialitePhone.png).
 * A parent accepts once, for all their children; the teacher can record an agreement signed on paper.
 */
@Service
@RequiredArgsConstructor
public class PrivacyService {
	private final UserRepository users;
	private final ParentRepository parents;
	private final StudentConsentRepository consents;
	private final StudentService students;
	private final CurrentTeacher teacher;
	private final Clock clock;

	/** What the agreement screen shows: whether it is needed, the teacher's name and the children's first names. */
	@Transactional(readOnly = true)
	public PrivacyInfo info(AuthenticatedUser principal) {
		User user = users.findById(principal.id()).orElseThrow(() -> ApiException.notFound("user_not_found"));
		if (user.getRole() != Role.PARENT) {
			return new PrivacyInfo(false, Privacy.VERSION, null, List.of());
		}
		Parent parent = parents.findByUser_Id(user.getId()).orElse(null);
		String teacherName = parent == null ? null
				: users.findById(parent.getTeacherId()).map(t -> (t.getFirstName() + " " + t.getLastName()).trim()).orElse(null);
		List<String> children = parents.findActiveChildrenOfUser(user.getId()).stream().map(c -> c.firstName()).toList();
		boolean required = user.getPrivacyVersion() == null || user.getPrivacyVersion() < Privacy.VERSION;
		return new PrivacyInfo(required, Privacy.VERSION, teacherName, children);
	}

	/** A parent accepts the notice: their space opens, and each of their children shows the agreement. */
	@Transactional
	public void accept(AuthenticatedUser principal) {
		User user = users.findById(principal.id()).orElseThrow(() -> ApiException.notFound("user_not_found"));
		if (user.getRole() != Role.PARENT) {
			return;
		}
		Instant now = clock.instant();
		user.setPrivacyVersion(Privacy.VERSION);
		user.setPrivacyAcceptedAt(now);
		String name = (user.getFirstName() + " " + user.getLastName()).trim();
		parents.findByUser_Id(user.getId()).ifPresent(parent -> {
			for (Student child : parent.getChildren()) {
				consents.save(StudentConsent.builder()
						.studentId(child.getId())
						.version(Privacy.VERSION)
						.method(StudentConsent.Method.APP)
						.givenBy(name)
						.givenAt(now)
						.recordedBy(user.getId())
						.build());
			}
		});
	}

	/** "Accord reçu sur papier": the teacher records an agreement signed on paper for one of her pupils. */
	@Transactional
	public Consent paper(UUID studentId) {
		Student student = students.require(studentId);
		StudentConsent consent = consents.save(StudentConsent.builder()
				.studentId(student.getId())
				.version(Privacy.VERSION)
				.method(StudentConsent.Method.PAPER)
				.givenAt(clock.instant())
				.recordedBy(teacher.find().orElse(null))
				.build());
		return consent(consent);
	}

	/** The agreement of each child that has one (of the current version). */
	@Transactional(readOnly = true)
	public Map<UUID, Consent> of(Collection<UUID> studentIds) {
		if (studentIds.isEmpty()) {
			return Map.of();
		}
		return consents.findByStudentIdIn(studentIds).stream()
				.filter(c -> c.getVersion() >= Privacy.VERSION)
				.sorted(Comparator.comparing(StudentConsent::getGivenAt))
				.collect(Collectors.toMap(StudentConsent::getStudentId, PrivacyService::consent, (a, b) -> b));
	}

	private static Consent consent(StudentConsent c) {
		return new Consent(c.getMethod().name(), c.getGivenBy(), c.getGivenAt());
	}
}
