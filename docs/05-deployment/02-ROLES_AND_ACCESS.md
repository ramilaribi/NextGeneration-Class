# 02 · Roles and access

## Who does what

R = does it · A = decides and approves · C = consulted · I = told after

| Activity | Owner | Teammate |
|---|---|---|
| Buy the VPS and the domain, pay every month | R, A | I |
| Pre-flight fixes T1 to T13 (branches and pull requests) | A (reviews, merges) | R |
| Rehearse the production stack on a laptop | C | R |
| SSH keys: make one's own key | R | R |
| Add the teammate's public key to the server | R | C (sends the **public** key) |
| DNS records | R | C (checks with `dig`) |
| First deploy (`deploy.sh`, types the owner account in `make-env.sh`) | R, A | C (watches, reads the logs) |
| Smoke test in the app (owner dashboard, a teacher, a parent) | R | C |
| Server checks (containers, logs, disk, backups) | I | R |
| UptimeRobot monitor | R (account), A | I (receives the alerts) |
| Weekly backup copy to the Mac | R | C (reminds, checks the log) |
| Restore drill (on the server, `04-RUNBOOK.md` section 7) | A | R |
| Later deploys | R | C, or R once T5 exists and the owner agrees |
| Incident first response (restart, logs) | R | R |
| Incident decisions (restore, rollback, tell the teacher) | A | C |
| Add teachers to the platform (owner dashboard) | R | none |
| Keep `LOG.md` and `03-PLAN.md` current | R | R |

## Access matrix

| Access | Owner | Teammate | Notes |
|---|---|---|---|
| OVHcloud account (billing, VPS panel, reinstall, DNS zone, backups) | yes, only | no | The teammate asks the owner for anything in the panel. Do not share the OVHcloud password. |
| Domain registration | yes | no | Renewal reminder in the owner's calendar |
| Server SSH as `ubuntu` (sudo) | own key `~/.ssh/ngclass_ovh` | own key, added by the owner | One key per person; the teammate's line is removed from `~/.ssh/authorized_keys` when the mission ends. The GitHub pipeline has its own key (`infra/ci-deploy-key.pub`, `08-CI_DEPLOY.md`) |
| Server secrets (`/opt/ngclass/infra/.env`) | yes | technically yes (sudo) | Read only when needed; never copied off the server, never shown in a screen share |
| GitHub repository | admin | collaborator (write) or fork + pull request | Only the owner merges into `main` |
| GitHub secrets and variables | yes | no | Environment `production`: the pipeline's deploy key, the server's address and host key, the Cloudflare token (`08-CI_DEPLOY.md`). No application secret |
| The platform's owner account (admin dashboard) | yes | no | The teammate never needs it; smoke tests that need it are done by the owner |
| UptimeRobot | account owner | alert contact | Both emails in the alert |
| Off-site backups (the Mac) | yes | no | Children's data: they stay on the owner's machine |

## Rules on secrets and personal data

1. A secret is typed by a person into a terminal, never pasted into a chat (human or AI), an email, an issue, a commit or a screenshot.
2. Production secrets are made on the server (`make-env.sh` uses `openssl rand`). The rehearsal on a laptop uses throwaway values.
3. Private SSH keys never leave the machine that made them. Only `.pub` files are sent.
4. Production data (pupils' names, grades, photos of work) never leaves the server except as an encrypted-at-rest backup on the owner's Mac (FileVault on). It is never used for tests on a laptop: restore drills run on the server, in a throwaway database removed right after.
5. If a secret might have leaked: tell the owner at once and follow "Secret leaked" in `05-INCIDENTS.md`.

## Working together

- **One channel** for production (a WhatsApp or Signal group of the two): say before acting on the server ("I restart the API"), and after ("done, healthy").
- **One writer at a time on the server.** Only one person runs `deploy.sh` or a `docker compose` command that changes something, at a time.
- **Pairing for the first deploy**: a call with screen share, the owner types, the teammate reads the logs (and looks away while the owner types passwords).
- **Written trace**: every production action goes in `LOG.md` (date, who, what, commit), the plan status in `03-PLAN.md`.
- **Using an AI agent**: start it with `AGENT_PROMPT.md`. The agent explains each command; the person runs it.
