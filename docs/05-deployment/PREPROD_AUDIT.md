# Pre-production audit · 2026-11-16

Checked on `main` at `c60713c`, before going live. Goal: find bugs, regressions, and anything that turns an error into a crash, a blank page or a misleading message. Each finding says how it was verified. The fixes are tasks T7 to T13 in `03-PLAN.md`.

**Status: F1 to F7 and F9 fixed the same day on branch `preprod-cleanup` (see "After the fixes" at the end). F8 left as is (tests only).**

## Method

- Full test suites: backend `mvn test` **73 tests, 0 failures** (real PostgreSQL); app `flutter analyze` **no issues**, `flutter test` **913 passed**. No regression.
- Live probes against the dev API (`APP_ENV=dev`, local): malformed requests, wrong methods and content types, unknown ids, missing or bad tokens, oversized fields, six identical requests at once.
- Code reading: the global error handler, security config, file storage and links, authorization of the pupil and parent endpoints, upload paths, database constraints against request limits, the app's start-up, network error mapping, session restore, every Cubit's error handling, every screen's failure state.

## Findings, most important first

| # | Severity | Where | Problem | Verified | Fix (task) |
|---|---|---|---|---|---|
| F1 | **High** | `backend/.../common/GlobalExceptionHandler.java` | Four ordinary request mistakes answer **500 "Une erreur est survenue"** and write an ERROR stack trace: a missing query parameter (`GET /api/v1/sessions` without `from`), a wrong HTTP method (`DELETE /api/v1/sessions`), a wrong content type (`text/plain` body), an `Accept` the API cannot produce. On the internet, bots send these all day: the production log would fill with false errors and hide real ones. The last one also ends as a misleading **401** (Spring forwards to `/error`, which is not public). | Live: 500 on all four, 5 stack traces in the log | Handlers: 400 `missing_parameter`, 405 `method_not_allowed`, 415 `unsupported_media_type`, 406; `/error` public; logged at WARN without stack (**T7**) |
| F2 | **High** | backend, every create guarded by a unique index | A **double click** (or two tabs) sending the same create at the same moment: the service's "already exists?" check passes for both, the database refuses the second, and the user gets **500**. The data stays correct (the index protects it); only the answer is wrong. Concerns chapters, subjects, shares, quiz attempts (`unique (recipient_id, attempt_no)`: a double tap on "Commencer"), one submission per pupil. | Live: 6 identical `POST /api/v1/chapters` at once → 1 × 201, 5 × 500 (`DataIntegrityViolationException`, `chapters_title`) | Map `DataIntegrityViolationException` to **409** `conflict` ("Cette action vient d'être faite. Actualisez la page." / AR) logged at WARN (**T8**) |
| F3 | **High** | `app/lib/view/screens/parent/parent_overview_screen.dart` | The parent's home page (the one screen every parent sees) has **no error state**: when its data fails to load (no network, server down), it shows the page as if the child had no upcoming session and no attendance, with no message and no "Réessayer". Every other screen has one. | Code: the screen reads only `LoadStatus.loading`, never `failure` (the four Cubits do report failures) | Error card with retry when the planning load fails, like the other family pages (**T9**) |
| F4 | Medium | `app/lib/main.dart`, `core/network/token_store.dart` | **Blank page at start** when the browser blocks site storage (cookies and site data blocked): `main()` awaits `language.load()` before `runApp`, and `shared_preferences_web` reads `window.localStorage` without a try. `TokenStore` only catches `PlatformException`, which the web never throws, so in that browser signing in fails too. Also: no `ErrorWidget.builder` (a widget build error shows an empty grey box in release) and no `FlutterError.onError` / `PlatformDispatcher.onError`, so errors on users' devices are never seen. | Code: plugin source (no try around `localStorage`), `main.dart`, `TokenStore` | Try around the language load (device language if it fails); `TokenStore` catches any error and keeps the session in memory; a friendly `ErrorWidget`; both global handlers log (**T10**) |
| F5 | Medium | `backend/.../work/service/MyHomeworkService.java:139`, `CorrectionService.java:173` | A pupil's work or a teacher's correction uploaded with a **file name over 255 characters** gives 500: the name is stored as sent (`fileName.trim()`) in a `varchar(255)`. Documents in Contenus already cut it (`ContentService.cleanName`). | Code and migration | Use `ContentService.cleanName` in both (**T11**) |
| F6 | Low | `app/lib/core/network/api_failure.dart` | When loads run side by side (`(a, b).wait`: Ma journée, Devoirs, end of session panel) and one fails, Dart throws a `ParallelWaitError`; `ApiFailure.from` does not unwrap it, so **"no connection" becomes the generic error message**. `homework_list_cubit` unwraps it by hand; the others do not. | Code | `ApiFailure.from` unwraps `ParallelWaitError` (first error) (**T12**) |
| F7 | Low | `infra/Caddyfile` | No protection against the site being shown inside another site's frame (clickjacking) and no `Permissions-Policy`. | Code | `X-Frame-Options DENY` and `Content-Security-Policy "frame-ancestors 'none'"`; `Permissions-Policy` allowing the camera for this site only (photo scan) (**T13**) |
| F9 | Low | `backend/src/main/resources/i18n/messages.properties` | Found while fixing F1: five French messages without a value showed a doubled apostrophe to users ("Cette annonce n''existe pas.", "Quelqu''un l''a déjà lue"). Only messages with `{0}` need `''`. | Code (Spring returns a message without values as written) | Single apostrophes; a test checks every message and that FR and AR have the same keys |
| F8 | Low | backend tests | Surefire prints "going to kill self fork JVM ... 30 seconds after System.exit(0)": a non-daemon thread outlives the tests. Tests still pass; the run is 30 s longer. Not a production problem. | Test log | Optional: find the thread (thread dump at the end of a run) |

## Checked and fine

- Tests and analyzer green; no regression from Releases 3 and 4 or the privacy work.
- Validation: request fields carry `@Size` limits matching the database columns (a 5000-character group name → 400 `validation`); phones are normalized to digits before saving.
- Bad ids, bad enums, bad dates, empty bodies, unknown routes, unknown sessions: clear 400 or 404 in the user's language.
- Authentication: no token or a forged token → 401; login lockout after repeated failures; refresh tokens in the database (so rotating `JWT_SECRET` keeps people signed in).
- Authorization: `/api/v1/admin/**` refused to everyone but the owner before any code runs; pupil and parent endpoints resolve the child through one check (`family.child`); teacher data scoped per teacher (tests).
- Files: download links are signed and expire after 30 minutes; the file type is detected from the content, not trusted from the browser; storage keys are checked against a strict pattern (no path tricks); originals are sent as downloads, not opened in the page.
- Actuator exposes `health` only (`/actuator/env` → 401). The demo data seeder runs only with the `dev` profile; production starts in `prod` by default.
- Deleting a chapter or archiving a document never breaks references (foreign keys set null or cascade; documents are archived, not deleted).
- App: every Cubit catches all errors and turns them into a message; session restore falls back to the cached user when offline and signs out only when the server refuses; the 401 refresh is queued and replayed once.
- Background jobs (homework "Manquant", quiz time-outs) log and retry on the next minute if one run fails.
- Upload limit 20 MB answered as 413 `file_too_large`; Caddy adds no lower limit.

## Order of the cleanup

T7, T8, T9 first (what users and logs would hit on day one), then T10, T11, T12, T13. Each with its tests; then `mvn test`, `flutter analyze`, `flutter test`, a production rehearsal on the laptop, and the probes above again (they should give 400, 405, 415, 406 and 409, never 500).

## After the fixes (2026-11-16, branch `preprod-cleanup`)

| # | What changed | Checked by |
|---|---|---|
| F1 | `GlobalExceptionHandler`: 400 `missing_parameter`, 405 `method_not_allowed`, 415 `unsupported_media_type`, 406 without body; `/error` public in `SecurityConfig`; messages in FR and AR | `ErrorResponsesTest.requestMistakesAreTheCallersNotServerErrors`; live probes: 400, 405, 415, 406, Arabic message, **no ERROR line** in the log |
| F2 | `DataIntegrityViolationException` → 409 `conflict` ("Cette action vient d'être faite. Actualisez la page."), one WARN line with the database's reason | `ErrorResponsesTest.theSameCreateSentSixTimesAtOnce...`; live: six identical creates → **1 × 201, 5 × 409**, one chapter in the database |
| F3 | Parent home: "Impossible de joindre le serveur" banner with "Réessayer" (key `parent-failure`) instead of an empty week | `empty_states_test.dart` "parent overview without network says so and tries again" |
| F4 | `LanguageCubit` keeps the device language when the saved one cannot be read or written; `TokenStore` falls back to memory on any storage error; release builds show `BrokenPart` ("Cette partie n'a pas pu s'afficher. Actualisez la page.") instead of a grey box; `FlutterError.onError` and `PlatformDispatcher.onError` write every error to the browser console | `test/core/blocked_storage_test.dart` (blocked storage, error widget FR and AR). Errors are only in the device's console: sending them to the server would be a later, separate feature |
| F5 | Pupil work and correction uploads keep at most 255 characters of the name (`ContentService.cleanName`) | `CorrectionTest`: a 304-character name → 200, name of 255 characters ending in `.pdf` |
| F6 | `core/async/wait_all.dart` (`waitBoth`, `waitThree`) rethrows the failing load's own error; used by Ma journée, Devoirs and the end of session panel | `test/core/wait_all_test.dart` |
| F7 | Caddy: `X-Frame-Options DENY`, `Content-Security-Policy "frame-ancestors 'none'"`, `Permissions-Policy "camera=(self), microphone=(), geolocation=()"` | `caddy validate`; headers read from a Caddy container with this Caddyfile |
| F9 | Single apostrophes | `ErrorResponsesTest.messagesWithoutValues...` |

All suites after the fixes: backend **76 tests**, 0 failures; app `flutter analyze` no issues, `flutter test` **922 passed**. The probes ran on the dev database; the one test chapter they made was deleted.
