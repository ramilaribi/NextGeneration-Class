package com.ngclass.backend.announcements.service;

import com.ngclass.backend.announcements.domain.Announcement;
import com.ngclass.backend.announcements.domain.AnnouncementTarget;
import com.ngclass.backend.announcements.domain.Audience;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.AnnouncementItem;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.AnnouncementRequest;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.TargetItem;
import com.ngclass.backend.announcements.dto.AnnouncementDtos.UnreadPerson;
import com.ngclass.backend.announcements.repository.AnnouncementRepository;
import com.ngclass.backend.announcements.repository.AnnouncementTargetRepository;
import com.ngclass.backend.auth.domain.User;
import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.auth.service.CurrentTeacher;
import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.groups.domain.ClassGroup;
import com.ngclass.backend.groups.repository.ClassGroupRepository;
import com.ngclass.backend.groups.repository.GroupMemberRepository;
import com.ngclass.backend.groups.service.GroupService;
import com.ngclass.backend.notifications.domain.Notification;
import com.ngclass.backend.notifications.repository.NotificationRepository;
import com.ngclass.backend.notifications.service.NotificationService;
import com.ngclass.backend.people.domain.Student;
import com.ngclass.backend.people.repository.StudentRepository;
import com.ngclass.backend.people.service.StudentService;
import com.ngclass.backend.planning.service.PlanningService;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Announcements (Release 4, spec 08, mockups screens/r4/Annonces*.png): the teacher writes to groups or one pupil,
 * for the pupils, their parents or both; each person receives one notification. One-way: no replies (Q9).
 */
@Service
@RequiredArgsConstructor
public class AnnouncementService {
	private final AnnouncementRepository announcements;
	private final AnnouncementTargetRepository targets;
	private final NotificationRepository notificationRows;
	private final NotificationService notifications;
	private final GroupService groupService;
	private final ClassGroupRepository groups;
	private final GroupMemberRepository members;
	private final StudentService studentService;
	private final StudentRepository students;
	private final UserRepository users;
	private final CurrentTeacher teacher;
	private final Clock clock;

	/** The latest first, with who they went to and how many read them. */
	@Transactional(readOnly = true)
	public List<AnnouncementItem> list() {
		List<Announcement> all = announcements.findByTeacherIdOrderByCreatedAtDesc(teacher.id());
		return items(all);
	}

	/** Sent at once; refused when nobody would receive it (a pupil without a login, for the pupils only). */
	@Transactional
	public AnnouncementItem create(AnnouncementRequest request) {
		Audience audience = audience(request.audience());
		boolean toGroups = request.groupIds() != null && !request.groupIds().isEmpty();
		if (toGroups == (request.studentId() != null)) {
			throw ApiException.badRequest("announcement_target_required");
		}
		List<AnnouncementTarget> chosen = new ArrayList<>();
		Set<UUID> pupilIds = new LinkedHashSet<>();
		String label;
		if (toGroups) {
			List<ClassGroup> list = new LinkedHashSet<>(request.groupIds()).stream().map(groupService::require).toList();
			for (ClassGroup group : list) {
				chosen.add(AnnouncementTarget.builder().groupId(group.getId()).label(group.getName()).position(chosen.size()).build());
				members.findById_GroupIdAndLeftAtIsNull(group.getId()).forEach(m -> pupilIds.add(m.getId().getStudentId()));
			}
			label = list.stream().map(ClassGroup::getName).collect(Collectors.joining(", "));
		} else {
			Student pupil = studentService.require(request.studentId());
			label = pupil.getUser().getFirstName() + " " + pupil.getUser().getLastName();
			chosen.add(AnnouncementTarget.builder().studentId(pupil.getId()).label(label).position(0).build());
			pupilIds.add(pupil.getId());
		}
		Announcement announcement = announcements.saveAndFlush(Announcement.builder()
				.teacherId(teacher.id())
				.title(request.title().trim())
				.body(request.body().trim())
				.audience(audience)
				.build());
		chosen.forEach(t -> t.setAnnouncementId(announcement.getId()));
		targets.saveAll(chosen);
		Instant now = clock.instant();
		User author = users.findById(teacher.id()).orElseThrow();
		int reached = notifications.announce(announcement.getId(), announcement.getTitle(), announcement.getBody(),
				author.getFirstName() + " " + author.getLastName(), label,
				pupilIds.isEmpty() ? List.of() : students.findByIdIn(pupilIds), audience.pupils(), audience.parents(), now);
		if (reached == 0) {
			throw ApiException.badRequest("announcement_nobody");
		}
		return items(List.of(announcement)).getFirst();
	}

	/** Who has not opened it yet, pupils first, to remind them in person. */
	@Transactional(readOnly = true)
	public List<UnreadPerson> unread(UUID id) {
		Announcement announcement = own(id);
		List<Notification> rows = notificationRows.findByAnnouncementIdIn(List.of(announcement.getId())).stream()
				.filter(n -> n.getReadAt() == null)
				.toList();
		Map<UUID, User> byId = users.findAllById(rows.stream().map(Notification::getUserId).toList()).stream()
				.collect(Collectors.toMap(User::getId, Function.identity()));
		return rows.stream()
				.map(n -> {
					User u = byId.get(n.getUserId());
					return new UnreadPerson(u.getFirstName(), u.getLastName(), n.getChildFirstName() != null, n.getChildFirstName());
				})
				.sorted(Comparator.comparing(UnreadPerson::parent).thenComparing(UnreadPerson::lastName, String.CASE_INSENSITIVE_ORDER))
				.toList();
	}

	/** Only while nobody has read it (business rules 10); then it stays, as sent. */
	@Transactional
	public void delete(UUID id) {
		Announcement announcement = own(id);
		boolean read = notificationRows.findByAnnouncementIdIn(List.of(id)).stream().anyMatch(n -> n.getReadAt() != null);
		if (read) {
			throw new ApiException(HttpStatus.CONFLICT, "announcement_already_read");
		}
		announcements.delete(announcement);
	}

	private Announcement own(UUID id) {
		return announcements.findByIdAndTeacherId(id, teacher.id()).orElseThrow(() -> ApiException.notFound("announcement_not_found"));
	}

	private static Audience audience(String value) {
		try {
			return Audience.valueOf(value.trim().toUpperCase(Locale.ROOT));
		} catch (IllegalArgumentException e) {
			throw ApiException.badRequest("announcement_invalid_audience");
		}
	}

	private List<AnnouncementItem> items(List<Announcement> list) {
		if (list.isEmpty()) {
			return List.of();
		}
		List<UUID> ids = list.stream().map(Announcement::getId).toList();
		Map<UUID, List<AnnouncementTarget>> byAnnouncement = targets.findByAnnouncementIdInOrderByPositionAsc(ids).stream()
				.collect(Collectors.groupingBy(AnnouncementTarget::getAnnouncementId));
		Map<UUID, List<Notification>> rows = notificationRows.findByAnnouncementIdIn(ids).stream()
				.collect(Collectors.groupingBy(Notification::getAnnouncementId));
		Set<UUID> groupIds = byAnnouncement.values().stream().flatMap(List::stream).map(AnnouncementTarget::getGroupId)
				.filter(g -> g != null).collect(Collectors.toSet());
		Map<UUID, ClassGroup> groupById = groupIds.isEmpty() ? Map.of()
				: groups.findByIdIn(groupIds).stream().collect(Collectors.toMap(ClassGroup::getId, Function.identity()));
		return list.stream()
				.map(a -> {
					List<Notification> reached = rows.getOrDefault(a.getId(), List.of());
					List<TargetItem> chosen = byAnnouncement.getOrDefault(a.getId(), List.of()).stream()
							.map(t -> new TargetItem(t.getGroupId() == null || !groupById.containsKey(t.getGroupId()) ? null
									: PlanningService.ref(groupById.get(t.getGroupId())), t.getStudentId(), t.getLabel()))
							.toList();
					return new AnnouncementItem(a.getId(), a.getTitle(), a.getBody(), a.getAudience().name(), chosen, a.getCreatedAt(),
							reached.size(), (int) reached.stream().filter(n -> n.getReadAt() != null).count());
				})
				.toList();
	}
}
