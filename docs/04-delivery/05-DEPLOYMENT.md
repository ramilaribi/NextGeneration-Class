# Delivery 05. Deployment strategy

Decided with the user on 2026-11-12. The step-by-step guide for buying and setting up is `05-DEPLOYMENT_GUIDE.pdf` (same folder). Mohamed's deployment track (CI/CD with GitHub Actions, his rehearsals) is in `05-DEPLOYMENT_HANDOVER.md`; both use the same production files (combined on 2026-11-13, see "Two ways to deploy").

## Decision

| Item | Choice | Why |
|---|---|---|
| Product | **Web platform only** (no Play Store, no App Store) | Phones use the web version in the browser |
| Host | **OVHcloud VPS-1** (2 vCores, 4 GB RAM, 40 GB NVMe, daily backup included, unlimited traffic) | Widely used in Tunisia, French panel and support, data centres in France, a private person can sign up (no company needed) |
| Billing | **Monthly, no commitment** | A one-month test for the client first, then keep or stop |
| Location | France (Gravelines, Strasbourg or Roubaix) | Close to Tunisia |
| System | Ubuntu 24.04 | Long-term support until 2029 |
| Domain | a `.com` bought at OVHcloud | One account and one invoice. `.tn` is not sold by OVHcloud. |
| Load | up to 100 users (about 20 to 30 online at once) | 4 GB is enough. Measured locally: API about 370 MB, database about 45 MB, Caddy about 20 MB at rest. |

## Cost (before VAT, check the cart on the day)

| | Price |
|---|---|
| VPS-1, monthly | about $5.35 a month |
| `.com` domain | about $9.20 the first year, then about $15 to $16.50 a year |
| HTTPS (Let's Encrypt), uptime alert (UptimeRobot), backups | free |
| **First month** (server + domain) | **about $15** |
| First year | about $73 |

## How it runs

One server, three Docker containers (`infra/docker-compose.prod.yml`):

- **Caddy**: HTTPS certificate (automatic and renewed), serves the Flutter web build (baked into its image by `app/web.Dockerfile`, so a deploy ships the app in one piece), forwards `/api/*` to the API, `/health` for the uptime alert, `www.` sends visitors to the main address. Starts only once the API is healthy.
- **API**: Spring Boot, profile `prod`, uploaded files in the `files` volume (`STORAGE_DIR=/data/files`).
- **PostgreSQL 16**: data in the `db-data` volume, never exposed to the internet.

## What keeps it stable

| Risk | Protection |
|---|---|
| A container crashes | `restart: unless-stopped` |
| A deploy that does not start | health checks (PostgreSQL ready, the API answers UP); `up --wait` stops the deploy with an error instead of leaving a half-started site |
| The server reboots | Docker starts with the system and the containers come back |
| Java takes all the memory | API capped at 1.5 GB (heap 75 % of it) |
| Memory peak | 2 GB swap file, `vm.swappiness=10` |
| Logs fill the disk | container logs capped at 5 × 10 MB each |
| Attacks on SSH | firewall (only 22, 80, 443 open), fail2ban, SSH key login |
| Security holes in the system | Ubuntu security updates installed automatically |
| Data lost | OVHcloud daily backup + our nightly backup (`infra/backup.sh`, 02:00, database dump + files archive, 30 days kept). Optional off-site copy with rclone (`BACKUP_REMOTE`). |
| Site down and nobody knows | UptimeRobot checks `https://<domain>/health` every 5 minutes and emails the owner |
| Old app version stuck in browsers | `index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json` and `manifest.json` are never cached |

A single server is up about 99.9 % of the time (rare short outages, usually OVHcloud maintenance at night). This matches `docs/03-conception/07-NON_FUNCTIONAL.md` ("available during the school day; short maintenance at night").

## The scripts (`infra/`)

| Script | Where it runs | What it does |
|---|---|---|
| `deploy.sh ubuntu@IP` | the Mac, from the project folder | Builds the web app, sends `backend/`, `infra/` and `app/build/web/` to `/opt/ngclass` with rsync, prepares the server the first time, asks the settings the first time, rebuilds and restarts, waits until the API is healthy. **Same command for every update.** |
| `server-setup.sh` | the server, once (deploy.sh runs it) | Time zone Africa/Tunis, updates, Docker, firewall, fail2ban, swap, automatic security updates, nightly backup cron |
| `make-env.sh` | the server, once (deploy.sh runs it) | Writes `infra/.env`: asks the domain and the owner's account, generates the database password and the JWT secret. Secrets never leave the server. |
| `backup.sh` | the server, every night (cron) | Database dump + files archive in `/var/backups/ngclass`, 30 days kept, optional off-site copy |

The SSH key for the server is `~/.ssh/ngclass_ovh` on the Mac (`SSH_KEY` overrides it).

## Two ways to deploy

Both start the same stack with the same command (`docker compose -f docker-compose.prod.yml up -d --build --wait`), so the site is the same either way. Use one per server.

| | `./infra/deploy.sh ubuntu@IP` (this guide) | The GitHub pipeline (Mohamed, `.github/workflows/ci.yml`) |
|---|---|---|
| Started by | you, from the Mac | a push to `main`, once the tests are green |
| Tests first | run them on the Mac before | always: backend and app jobs on GitHub's machines |
| Settings | `infra/.env` on the server, written by `make-env.sh` | the repository's variables (`DEPLOY_DOMAIN`, usernames) and secrets (passwords, `JWT_SECRET`) |
| Where it runs | over SSH on the server | a "self-hosted runner" labelled `ngclass-deploy`: Mohamed's PC for the rehearsal, the server later |
| Switched on | always | only when the repository variable `DEPLOY_ENABLED` is `true` |

**Today**: the OVHcloud server is set up with `deploy.sh` (simplest to start). To let GitHub deploy it later: install the runner on the server, copy the values of the server's `infra/.env` into the repository's variables and secrets (the same `DB_PASSWORD` and `JWT_SECRET`, or the database and sessions break), then set `DEPLOY_ENABLED=true`. Every push to `main` then deploys, after the tests.

CI runs on every push and pull request (all branches): the backend tests on a real PostgreSQL, `flutter analyze`, `flutter test`, a release web build.

## Restore a backup

On the server, from `/opt/ngclass/infra` (replace the dates by the backup to restore):

```bash
sudo docker compose -f docker-compose.prod.yml stop api
sudo docker compose -f docker-compose.prod.yml exec -T db pg_restore --clean --if-exists -U ngclass -d ngclass < /var/backups/ngclass/db_DATE.dump
sudo docker compose -f docker-compose.prod.yml run --rm --no-deps --user root -v /var/backups/ngclass:/backup --entrypoint sh api -c "rm -rf /data/files/* && tar -xzf /backup/files_DATE.tar.gz -C /data"
sudo docker compose -f docker-compose.prod.yml start api
```

## Tested before buying (2026-11-12, on the Mac)

The production stack (`docker-compose.prod.yml`, release web build, `DOMAIN=localhost`) was started and checked:

- HTTPS, `/health` answers UP, the home page and a deep link (`/teacher/home`) answer 200, `www.` redirects, the no-cache headers are sent.
- The owner account is created from the settings, and the server refuses everything until the first password change.
- The owner creates a teacher, the teacher signs in, creates a subject, uploads a file; the file is in the `files` volume.
- `backup.sh` writes the database dump and the files archive.
- After `down` and `up --build`, the document and its file are still there and download through HTTPS.
- `pg_restore` of the dump works.

Fixed on the way: uploads were written inside the container instead of the volume (lost on rebuild, and not writable by the app user); the owner account was not passed to the API; the files backup could not write as the app user; no memory cap; no log cap.

## After the test month

- **The client continues:** keep the same server and domain. Nothing to change.
- **The client stops:** in the OVHcloud panel, cancel the VPS renewal (and the domain renewal if not needed). Download a last backup first.
- **Move later to a cheaper host:** copy the latest backup, run `deploy.sh` on the new server, restore, point the domain to the new IP.
