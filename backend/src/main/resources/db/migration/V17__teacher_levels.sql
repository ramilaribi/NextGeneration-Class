-- A teacher adds her own levels (user request 2026-11-18): Préparatoire, 7ème année... The six years of
-- the primary school stay shared (teacher_id null); a teacher's own level is seen only in her space.
-- No foreign key on purpose: accounts are never deleted (an owner closes them), and a key to users would
-- let a "truncate users cascade" empty the shared levels too.
alter table levels add column teacher_id uuid;
alter table levels drop constraint levels_name_fr_key;
create unique index levels_shared_name on levels (lower(name_fr)) where teacher_id is null;
create unique index levels_teacher_name on levels (teacher_id, lower(name_fr)) where teacher_id is not null;
create index levels_teacher on levels (teacher_id);
