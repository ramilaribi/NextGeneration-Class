-- Release 3, step 1: pages written in the app, like in Word (user decision 2026-10-09, design
-- r3/EditeurDocument.png). A page is a library item without a file: its text is the editor's document
-- (a Quill Delta, JSON), and its Corrigé a second one that only the teacher reads. Images inside a page
-- are the teacher's file_assets, named in the Delta by their id.
alter table content_items drop constraint content_items_type_check;
alter table content_items add constraint content_items_type_check check (type in ('DOCUMENT', 'PAGE'));
alter table content_items alter column file_id drop not null;
alter table content_items add column body jsonb;
alter table content_items add column answer_body jsonb;
alter table content_items add constraint content_items_file_or_body check (
	(type = 'DOCUMENT' and file_id is not null) or (type = 'PAGE' and file_id is null and body is not null));
