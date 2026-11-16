-- Before going live: the privacy notice and the parents' agreement (loi organique n° 2004-63). A parent accepts the
-- current version of the notice once (users.privacy_version); each child then shows who agreed and how.
alter table users add column privacy_version integer;
alter table users add column privacy_accepted_at timestamptz;

create table student_consents (
	student_id uuid primary key references students (id) on delete cascade,
	version integer not null,
	method varchar(10) not null check (method in ('APP', 'PAPER')),
	given_by varchar(160),
	given_at timestamptz not null,
	recorded_by uuid references users (id) on delete set null
);
