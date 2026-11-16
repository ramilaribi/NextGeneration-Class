# 01 · Deployment strategy

## Goal

Put NextGeneration Class online for one teacher, her pupils and their parents (up to about 100 accounts, 20 to 30 people online at once), for a **one-month test** that can become permanent without moving anything. Web only: phones use the browser (no store apps, decision of 2026-11-11).

What "good" means here, from `docs/03-conception/07-NON_FUNCTIONAL.md`: available during the school day, short maintenance at night is fine, no data lost, pupils' data protected, cheap.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Host | **OVHcloud VPS-1**: 2 vCores, 4 GB RAM, 40 GB NVMe, unlimited traffic, daily backup included | Used in Tunisia, French panel, a private person can sign up, enough for 100 users (measured: API about 370 MB, DB 45 MB, Caddy 20 MB) |
| Billing | Monthly, no commitment | One test month first |
| Data centre | France (Gravelines, Strasbourg or Roubaix) | Close to Tunisia; EU data protection |
| System | Ubuntu 24.04 LTS | Supported until 2029 |
| Domain | a `.com` at OVHcloud, DNS at OVHcloud | One account, one invoice (`.tn` is not sold there) |
| HTTPS | Let's Encrypt through Caddy, automatic renewal | Free, nothing to do |
| Environments | **Production** (the VPS) and **rehearsal** (the production stack on a laptop with `DOMAIN=localhost`). No paid staging server. | Budget; the rehearsal runs the exact production files |
| Deploy path now | `./infra/deploy.sh ubuntu@IP` from the owner's Mac | Simplest, already tested, secrets stay on the server |
| Deploy path later | GitHub Actions job on GitHub's machines that deploys **over SSH** (task T5) | Deploys after green tests without a Mac; no runner on our server |
| Not done | A self-hosted GitHub runner on the server | The repository is public: GitHub advises against self-hosted runners on public repositories (a pull request from a fork can change the workflow and run code on that machine) |
| Monitoring | UptimeRobot free, `https://<domain>/health` every 5 minutes, alerts to both people | Free; `/health` is UP only when the API and the database work |
| Cost | About $15 the first month before VAT (server + domain), then about $5.35 a month; the domain renews at about $15 to $16.50 a year | `docs/04-delivery/05-DEPLOYMENT.md` |

## Architecture in production

```
 browser (teacher, parents, pupils)
        │ HTTPS 443 (HTTP 80 redirects)
        ▼
 ┌──────────────── OVHcloud VPS-1 · Ubuntu 24.04 · /opt/ngclass ─────────────────┐
 │  firewall ufw: 22, 80, 443 only · fail2ban · automatic security updates       │
 │                                                                               │
 │  caddy (image ngclass-web = caddy:2-alpine + Flutter web build)               │
 │    /          → the web app (index.html never cached)                         │
 │    /api/*     → api:8080                                                      │
 │    /health    → api:8080/actuator/health (UptimeRobot)                        │
 │    www.       → redirect to the main address                                  │
 │        │                                                                      │
 │  api (Spring Boot, Java 21, profile prod, 1.5 GB cap) ── volume files         │
 │        │                                                                      │
 │  db (PostgreSQL 16, not reachable from the internet) ─── volume db-data       │
 │                                                                               │
 │  cron 02:00 backup.sh → /var/backups/ngclass (30 days)                        │
 └───────────────────────────────────────────────────────────────────────────────┘
        ▲ ssh (keys only)                       │ weekly copy (T4)
   owner's Mac: deploy.sh                       ▼
   teammate: checks over SSH               owner's Mac: ~/NGClass-backups
```

Files: `infra/docker-compose.prod.yml`, `infra/Caddyfile`, `backend/Dockerfile`, `app/web.Dockerfile`, `infra/server-setup.sh`, `infra/make-env.sh`, `infra/backup.sh`, `infra/deploy.sh`.

## How a version reaches production

```
branch → pull request → CI green (backend tests, flutter analyze + test, web build)
       → owner merges into main → owner on the Mac: git switch main && git pull
       → backup on the server → ./infra/deploy.sh ubuntu@IP → smoke test → LOG.md line
```

Rules:
- Deploy only `main`, clean (`git status` empty), pushed, with CI green. `deploy.sh` sends the Mac's working copy, so anything uncommitted would go online (task T2 makes the script refuse it).
- Deploy outside school hours (evenings, weekends). A deploy restarts the API: about one minute where the app answers with errors.
- Take a backup just before (task T3 makes `deploy.sh` do it).
- The first deploy creates the owner's account from the settings typed into `make-env.sh`; nothing else is seeded in production (no demo accounts, no demo data).

## Rollback

The code goes back, the data does not go back unless it must.

1. **Code only** (the new version misbehaves, no database change): on the Mac, `git switch --detach <last good commit>`, then `./infra/deploy.sh ubuntu@IP`. Note the commit of every deploy in `LOG.md` so the last good one is known.
2. **Code and database** (the new version added a Flyway migration and the old code cannot run on the new tables): restore the backup taken just before the deploy (`04-RUNBOOK.md`, "Restore"), then deploy the old commit. Anything written in between is lost, so this is the last resort.

Migrations are written to be additive (new tables and columns with defaults), so case 1 is the normal one.

## Backups: three copies, two places

| Copy | Where | When | Kept | Protects against |
|---|---|---|---|---|
| OVHcloud automated backup | OVHcloud, outside the VPS | daily | as offered by VPS-1 (check in the panel) | the whole server lost or broken |
| `backup.sh` | `/var/backups/ngclass` on the VPS | 02:00 every night + before each deploy | 30 days | a mistake in the data, a bad migration |
| Off-site copy | the owner's Mac (`~/NGClass-backups`) | weekly (task T4) | at least 8 weeks | losing the server **and** the OVHcloud account |

A backup counts only once a restore of it was tried: the restore drill (P4) restores the latest dump on the teammate's laptop.

## Security

- SSH with keys only, one key per person (never a shared private key); the teammate's key is removed when their mission ends.
- Secrets (`DB_PASSWORD`, `JWT_SECRET`, owner's first password) are generated or typed **on the server** by `make-env.sh`, stored in `/opt/ngclass/infra/.env` (mode 600), never in GitHub, chat, email or screenshots.
- Only 22, 80 and 443 open; PostgreSQL never published; containers restart by themselves; logs capped.
- The app side: production profile by default, no seeded accounts, password change forced at first login, parents accept the privacy notice before using the app, each teacher's data scoped to her (V6).

## Risks

| Risk | Likelihood | Effect | What we do |
|---|---|---|---|
| A deploy breaks the app during school hours | low | the teacher cannot work | deploy in the evening; `--wait` stops a deploy that never gets healthy; rollback |
| HTTPS certificate not issued | medium the first day | site unreachable | DNS checked before the deploy (A records only to the VPS, AAAA parking lines deleted) |
| Data deleted by mistake | low | lost work | nightly backups, restore |
| Server lost | very low | everything down | OVHcloud backup or off-site copy + `deploy.sh` on a new VPS |
| Secret leaked | low | account takeover | secrets only on the server; rotate (`05-INCIDENTS.md`) |
| Disk full | low (40 GB, logs capped, 20 MB per upload) | API errors | weekly `df -h`; backups older than 30 days deleted |
| Owner unreachable during an incident | medium | longer outage | teammate has SSH and the runbook for restart and logs; owner-only actions are listed in `02-ROLES_AND_ACCESS.md` |
| Privacy text not checked | medium | legal | go-live checklist item: the teacher (or a lawyer) reads it first |
