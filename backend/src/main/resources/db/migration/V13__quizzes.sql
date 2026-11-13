-- Release 3, steps 2 and 3: quizzes and QCM (spec 05, designs r3/QuizEditeur.png, QuizSaisieRapide.png,
-- SeriesQuizPhone.png). A quiz is a library item without a file; its settings and questions sit in its own row.
-- The questions are one JSON list, saved whole by the editor like a page; the server reads and grades them.
alter table content_items drop constraint content_items_type_check;
alter table content_items add constraint content_items_type_check check (type in ('DOCUMENT', 'PAGE', 'QUIZ'));
alter table content_items drop constraint content_items_file_or_body;
alter table content_items add constraint content_items_file_or_body check (
	(type = 'DOCUMENT' and file_id is not null)
	or (type = 'PAGE' and file_id is null and body is not null)
	or (type = 'QUIZ' and file_id is null));

create table quizzes (
	content_item_id uuid primary key references content_items (id) on delete cascade,
	-- Minutes; null: no timer.
	time_limit_min integer check (time_limit_min is null or time_limit_min between 1 and 300),
	attempts_allowed integer not null default 1 check (attempts_allowed between 1 and 10),
	score_policy varchar(8) not null default 'BEST' check (score_policy in ('BEST', 'LAST')),
	answers_shown varchar(16) not null default 'AFTER_DEADLINE' check (answers_shown in ('AFTER_DEADLINE', 'AFTER_SUBMIT', 'NEVER')),
	shuffle boolean not null default false,
	-- Made from "Créer > QCM": the builder offers multiple choice first, nothing else changes.
	mcq_only boolean not null default false,
	questions jsonb not null default '[]'::jsonb,
	-- Set when a pupil first starts it: its questions can no longer change ("Dupliquer" for a new version).
	locked_at timestamptz
);

-- A quiz given as homework is taken online.
alter table assignments drop constraint assignments_submission_mode_check;
alter table assignments add constraint assignments_submission_mode_check check (submission_mode in ('FILE', 'NONE', 'QUIZ'));

-- One pupil's attempt. [answers] by question id; [question_order] the order this pupil sees; [scores] the
-- points of each question (null for an open question not corrected yet). [score] once every question has
-- points. The recipient row keeps the grade that counts (best or last attempt, as the quiz says).
create table quiz_attempts (
	id uuid primary key default gen_random_uuid(),
	recipient_id uuid not null references assignment_recipients (id) on delete cascade,
	attempt_no integer not null,
	started_at timestamptz not null,
	submitted_at timestamptz,
	is_late boolean not null default false,
	question_order jsonb not null,
	answers jsonb not null default '{}'::jsonb,
	scores jsonb,
	auto_score numeric(6, 2),
	score numeric(6, 2),
	needs_manual boolean not null default false,
	started_by uuid not null references users (id),
	unique (recipient_id, attempt_no)
);
create index quiz_attempts_open on quiz_attempts (submitted_at) where submitted_at is null;
