-- Release 4: announcements (spec 08, mockups screens/r4/Annonces*.png, approved 2026-11-13). A one-way message
-- from the teacher to groups or one pupil, read by the pupils, their parents, or both. Each person gets one
-- notification row (the bell, the parents' tab, the home page for 7 days); its read_at is what "9 / 14 lus" counts.
create table announcements (
	id uuid primary key default gen_random_uuid(),
	teacher_id uuid not null references users (id),
	title varchar(120) not null,
	body varchar(2000) not null,
	audience varchar(8) not null check (audience in ('PUPILS', 'PARENTS', 'BOTH')),
	created_at timestamptz not null default now()
);
create index announcements_teacher on announcements (teacher_id, created_at desc);

-- What the teacher chose: groups, or one pupil. Kept with the names of the day, as notifications do.
create table announcement_targets (
	id uuid primary key default gen_random_uuid(),
	announcement_id uuid not null references announcements (id) on delete cascade,
	group_id uuid references class_groups (id) on delete set null,
	student_id uuid references students (id) on delete set null,
	label varchar(160) not null,
	position integer not null
);
create index announcement_targets_announcement on announcement_targets (announcement_id);

alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
	check (type in ('SESSION_CANCELLED', 'SESSION_MOVED', 'SESSION_RESTORED', 'HOMEWORK_ASSIGNED', 'HOMEWORK_CORRECTED',
		'EVALUATION_GRADED', 'WORK_SUBMITTED', 'DEADLINE_PASSED', 'ANNOUNCEMENT'));
alter table notifications add column announcement_id uuid references announcements (id) on delete cascade;
-- The announcement's text, kept on the row like every notification keeps what it says.
alter table notifications add column body varchar(2000);
-- Who wrote it, as signed then ("Ines Haddad").
alter table notifications add column author varchar(160);
create index notifications_announcement on notifications (announcement_id) where announcement_id is not null;
