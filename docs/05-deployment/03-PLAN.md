# 03 · Plan

Status values: **todo**, **doing**, **done (date)**, **skipped (why)**. Update the status here and add a line to `LOG.md` whenever something moves.

## Phases

| # | Phase | Lead | Time | Done when | Status |
|---|---|---|---|---|---|
| P0 | Prepare (before buying) | Teammate | 2 to 4 days | Teammate runs the project locally; production rehearsal green on a laptop; T1 to T4 merged; CI green on `main`; privacy text sent to the teacher | todo |
| P1 | Buy | Owner | 30 min + up to a day of waiting | VPS-1 delivered (IP in the email), `.com` active | todo |
| P2 | Server access and DNS | Owner, with teammate | 30 min + up to an hour of DNS waiting | Both people enter the server with their own key; `dig +short <domain>` and `www.<domain>` give the VPS IP only | todo |
| P3 | First deploy | Owner (types), teammate (reads logs) | about 20 min | `deploy.sh` ends with "Done: https://<domain> is up." | todo |
| P4 | Verify and harden | Both | 1 to 2 hours | Smoke test passed; UptimeRobot on; OVHcloud backup seen in the panel; one backup run by hand and copied to the Mac; restore drill passed on the server before any real data (`04-RUNBOOK.md` section 7) | todo |
| P5 | Go live with the teacher | Owner | one week of watching | `06-GO_LIVE_CHECKLIST.md` all ticked; teacher account created; teacher signed in; first group and parents in | todo |
| P6 | After the test month | Owner decides | | Keep or stop (`docs/04-delivery/05-DEPLOYMENT.md`, "After the test month"); if kept: T5 (automatic deploys) after two calm manual deploys | todo |

### P0 · Prepare, in detail

1. Teammate: clone, run locally (`CLAUDE.md` "Commands"; Windows notes in `docs/04-delivery/05-DEPLOYMENT_HANDOVER.md`), tests green.
2. Teammate: production rehearsal on the laptop (`04-RUNBOOK.md`, "Rehearsal on a laptop"): HTTPS on `https://localhost`, owner account created, first-login password change, upload a file, `backup.sh`, `down` then `up`, file still there, restore the dump.
3. Teammate: pre-flight tasks T1 to T4 below, one pull request each (or one small pull request for all), the owner reviews and merges.
4. Owner: send the privacy text (`/confidentialite` in the app) to the teacher (or a lawyer) to read; ask a native Arabic speaker to read the Arabic screens.
5. Owner: decide the domain name (check it is free on ovhcloud.com).

### P2 · DNS, in detail

In the OVHcloud panel, domain › DNS zone: for `@` and `www`, keep **one A record each, pointing to the VPS IPv4**. Delete the A and AAAA lines OVHcloud adds for its parking page (an AAAA to OVH parking blocks the HTTPS certificate). Then wait until both names answer with the VPS IP:

```bash
dig +short ngclass.com
dig +short www.ngclass.com
dig +short AAAA ngclass.com
```

The first two give the VPS IP, the third gives nothing (or the VPS IPv6 if one was added on purpose). Run `deploy.sh` only then: Caddy asks for the certificate at the first start, and Let's Encrypt limits failed attempts.

## Pre-flight tasks (P0, teammate)

Each one is small. Work on a branch, open a pull request, the owner merges.

| # | Task | Why | Done when | Status |
|---|---|---|---|---|
| T1 | `infra/deploy.sh`: build the web app with `--pwa-strategy=none`, like the CI job | Both deploy paths must ship the same build; the default service worker (offline-first) can keep an old version in a browser after a deploy | `deploy.sh` and `ci.yml` use the same `flutter build web` flags | todo |
| T2 | `infra/deploy.sh`: refuse to deploy when `git status` is not clean or the branch is not `main` (an explicit `--force` flag for emergencies), and write the deployed commit to `/opt/ngclass/DEPLOYED` | The script sends the working copy, so uncommitted work would go online; the commit is needed for rollback | A dirty tree stops the script with a clear message; `cat /opt/ngclass/DEPLOYED` shows the commit and date | todo |
| T3 | `infra/deploy.sh`: when the stack already runs, run `backup.sh` on the server before `up --build` | A backup from just before each deploy makes a rollback with data possible | The deploy log shows "backup ... done" before the restart | todo |
| T4 | Off-site copy: `infra/pull-backups.sh` run on the Mac (rsync of `/var/backups/ngclass` to `~/NGClass-backups`, keeps 8 weeks), documented in the runbook. Also add `rclone` to `server-setup.sh` packages, since `backup.sh` calls it when `BACKUP_REMOTE` is set | The server and the OVHcloud account are one place; the Mac is a second one. `rclone` is not installed today, so `BACKUP_REMOTE` would fail | The script copies the latest dumps; a weekly reminder is in the owner's calendar | todo |
| T5 | (P6, only if the client keeps it) Replace the `deploy` job in `.github/workflows/ci.yml`: run on `ubuntu-latest`, deploy over SSH (key in the `production` environment's secrets, owner as required reviewer), with the server's own `infra/.env` (no secrets duplicated in GitHub). Remove the self-hosted runner. Set "Require approval for all external contributors" for fork pull request workflows (Settings › Actions › General) | No runner of ours that a fork's pull request could reach; a deploy after green tests, approved by the owner | A push to `main` waits for the owner's approval, then deploys; `DEPLOY_ENABLED` documented | todo |
| T6 | Monthly restore drill as a script, `infra/restore-drill.sh` (the throwaway-database check of `04-RUNBOOK.md` section 7), and the full drill done once in P4 | A backup is only real once restored; production data never leaves the server for a drill | The script prints the number of users and files of the latest backup and leaves nothing behind | todo |

Keep `DEPLOY_ENABLED` unset in the repository until T5 is done: the current `deploy` job targets a self-hosted runner.

## After go-live, every week (teammate, 10 minutes)

- `04-RUNBOOK.md` "Weekly check": containers healthy, disk below 70 %, last backup present, no restart loop, `apt` security updates applied, reboot if `/var/run/reboot-required` exists (in the evening, told in the channel).
- Owner: run `pull-backups.sh` (T4).
- One line in `LOG.md`.
