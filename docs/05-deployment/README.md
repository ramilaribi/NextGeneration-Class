# Deployment · start here

Written 2026-11-16, when the product was finished (Releases 1 to 4, privacy notice) and a teammate joined to put it online with the owner. This folder is the **single plan for going live and running production**. Agents read the Markdown files; the two people read `DEPLOYMENT_PLAYBOOK.pdf` (same content, laid out for people).

## Who is who

| | Who | Machine | Does |
|---|---|---|---|
| **Owner** | Rami (`ramilaribi`), the user of these sessions | Mac | Pays, owns every account, holds the secrets, decides, merges into `main`, runs the deploy |
| **Teammate** | joins for the deployment (Mohamed Salah Jalel built the CI/CD in October; if someone else joins, same role) | Windows 11 (PowerShell, Git Bash) or any | Prepares and checks: pre-flight fixes, rehearsals, server checks over SSH, monitoring, restore drill, the runbook |
| **Teacher** | the client | phone, computer | Uses the platform; checks the privacy text |

## Read in this order

1. `01-STRATEGY.md` · what we deploy, where, how, and why (decisions, architecture, the two deploy paths, backups, risks).
2. `02-ROLES_AND_ACCESS.md` · who does what, who holds which access, the rules on secrets.
3. `03-PLAN.md` · the phases P0 to P6 and the pre-flight and cleanup tasks T1 to T13, each with an owner and "done when". **The status column is the live status.**
4. `04-RUNBOOK.md` · every command: first deploy, updates, checks, logs, backups, restore, rollback, server care.
5. `05-INCIDENTS.md` · symptom → check → fix, and how to tell the teacher.
   `07-CLOUDFLARE.md` · **since 2026-11-16**: the web app on a Cloudflare Worker (`nextgenerationclass.online`), the API and database stay on the server (`api.`).
   `08-CI_DEPLOY.md` · **since 2026-11-17**: every green push to `main` deploys itself from GitHub (server over SSH, then the web app on Cloudflare); the settings and the two steps left.
6. `06-GO_LIVE_CHECKLIST.md` · the go / no-go list before the teacher gets her account.
7. `LOG.md` · what was done on production, dated (no secrets).
   `PREPROD_AUDIT.md` · the audit of 2026-11-16: bugs and crash risks found before going live, with evidence (fixes are T7 to T13).
8. `AGENT_PROMPT.md` · the prompt to start a new deployment session.

Older documents, still true and referenced from here: `docs/04-delivery/05-DEPLOYMENT.md` (the decision of 2026-11-12), `05-DEPLOYMENT_GUIDE.pdf` (the owner's click-by-click guide to buy and set up, with the OVHcloud screens), `05-DEPLOYMENT_HANDOVER.md` (the teammate's October track: Windows setup, CI). The scripts are in `infra/`.

## The strategy in one paragraph

One OVHcloud VPS-1 in France (monthly, no commitment, about $6.50 a month with VAT) and a `.com` at OVHcloud run the whole platform in three Docker containers (Caddy for HTTPS and the web app, the Spring Boot API, PostgreSQL 16). The owner deploys from the Mac with one command (`./infra/deploy.sh ubuntu@IP`), always from a clean, pushed, green `main`, after a backup. Backups exist three times: OVHcloud's daily snapshot, our nightly dump on the server (30 days), and a weekly copy on the owner's Mac. UptimeRobot (free) emails both people when the site is down. Automatic deploys from GitHub come later, and only through SSH from GitHub's own machines, never through a runner installed on the server while the repository is public.

## Rules for agents (on top of `CLAUDE.md`)

- Never print, paste, commit or copy off the server: `infra/.env`, `backend/.env`, passwords, the JWT secret, private SSH keys. Ask a person to type a secret into the terminal, never into the chat.
- Never run anything on the production server without the person in the session asking for it, and say before each command what it changes. Read-only checks (`ps`, `logs`, `df`, `curl`) are fine once asked to look.
- Never change `DB_PASSWORD` in the server's `infra/.env` after the first start: PostgreSQL keeps the first one, and the API would stop connecting.
- Never delete the Docker volumes (`down -v`, `volume rm`): `db-data` and `files` are the teacher's data, `caddy-data` holds the HTTPS certificate.
- Never buy or enable a paid option (`docs/04-delivery/02-COST.md`). Never enter payment details.
- Commit and push only when asked, on a branch, through a pull request the owner merges.
- After any production action, add a dated line to `LOG.md` and update the status in `03-PLAN.md`.
