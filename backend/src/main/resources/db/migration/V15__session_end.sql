-- Release 4: the end of a session (spec 03, "End of session"). What was covered: a chapter of the group's
-- subject and level, the documents used, and a short line; families see it in Cours, the next session shows it.
alter table sessions add column covered_chapter_id uuid references chapters (id) on delete set null;
alter table sessions add column covered_details varchar(300);

create table session_contents (
	session_id uuid not null references sessions (id) on delete cascade,
	content_id uuid not null references content_items (id) on delete cascade,
	primary key (session_id, content_id)
);

create index idx_session_contents_content on session_contents (content_id);
create index idx_sessions_covered_chapter on sessions (covered_chapter_id) where covered_chapter_id is not null;
