# 05 · Incidents

First: say in the channel what you see and that you are looking. Then the table. `C` is the shortcut of `04-RUNBOOK.md`. Anything that loses data (restore, rollback with data) waits for the owner's yes.

## Severity

| Level | Example | Response |
|---|---|---|
| **S1** down | site unreachable, nobody can sign in, data lost | now, whoever sees it first; owner told at once |
| **S2** broken part | uploads fail, one screen errors, slow | same day, evening fix if in school hours |
| **S3** small | a wording, a layout glitch | normal pull request |

## Symptom → check → fix

| Symptom | Check | Fix |
|---|---|---|
| UptimeRobot: site down | `$C ps` | A part not `Up`: `$C up -d --wait`. Keeps stopping: `$C logs --tail 200 api`, look for the first error |
| Server does not answer at all (no SSH) | OVHcloud panel (owner): VPS state, "KVM" console | Reboot from the panel. If OVHcloud has an incident, wait (status page `status.ovhcloud.com`) |
| Browser: certificate error / "not secure" | `$C logs caddy | grep -i -E "acme|certificate|error"`; `dig +short ngclass.com` and `dig +short AAAA ngclass.com` | DNS must point only to the VPS (delete parking A/AAAA lines), then `$C restart caddy`. Too many failed attempts: Let's Encrypt waits up to an hour; do not loop restarts |
| `deploy.sh`: "The platform did not start" | the 80 lines printed; `$C logs --tail 200 api` | Flyway error: a migration failed, fix in code, never edit the database by hand; restore the pre-deploy backup if the migration half-ran. "password authentication failed": `DB_PASSWORD` was changed in `.env`, put the first one back |
| Build fails on the server (Maven or Docker) | the build output | Out of disk: `sudo docker system prune -f`. Network: run again |
| Nobody can sign in | `curl -s https://ngclass.com/health`; `$C logs --tail 100 api` | `DOWN`: database; `$C restart db`, then `api`. UP but logins refused: check the clock (`timedatectl`), recent changes to `JWT_SECRET` or `ALLOWED_ORIGINS` |
| One person cannot sign in | | Teacher: owner resets her password from the dashboard. Parent or pupil: the teacher resets it from the pupil's page |
| Slow | `sudo docker stats --no-stream`, `free -h`, `uptime` | API near 1.5 GB or swap heavy: `$C restart api` in the evening; recurring: tell the owner (bigger VPS or a memory leak to find) |
| Disk almost full | `df -h /`; `sudo du -sh /var/backups/ngclass /var/lib/docker` | `sudo docker system prune -f`; old backups (copied to the Mac first); never delete volumes |
| Uploads fail | `$C logs api | grep -i -E "multipart|size|storage"` | Over 20 MB is refused by design; disk full; volume permissions after a manual change |
| A user deleted something by mistake | when, what | Owner decides: often re-create by hand. Full restore loses everything after the backup (`04-RUNBOOK.md` section 7) |
| A new version misbehaves | what changed (LOG.md) | Rollback (`04-RUNBOOK.md` section 8) |
| Secret leaked (`.env`, a password, a private key in a chat, a commit, a screenshot) | what leaked, where | **Owner password**: change it in the app. **SSH private key**: remove its line from `authorized_keys`, make a new key. **JWT_SECRET**: new value with `openssl rand -hex 48` in `.env`, `$C up -d`. **DB_PASSWORD**: change it inside PostgreSQL first (`ALTER USER ngclass PASSWORD '...'`), then in `.env`, then `$C up -d`. In git: rewriting history is not enough on a public repository, rotate the secret. Note it in `LOG.md` without the value |
| Signs of intrusion (unknown processes, changed files, odd logins in `last`) | `sudo last -20`, `sudo fail2ban-client status sshd` | Owner: take a backup, take the site down (`$C stop caddy`), reinstall the VPS from the panel, deploy and restore (runbook section 10), new secrets |

## Telling the teacher

Short, in French (or Arabic), no technical words. S1 only, or an S2 she noticed.

- Down: « La plateforme est momentanément indisponible. Nous corrigeons, retour prévu vers HH:MM. Vos données sont en sécurité. »
- Back: « La plateforme fonctionne à nouveau. Merci de votre patience. »
- Restore with loss: say exactly what was lost (« ce qui a été saisi entre mardi 18:00 et mercredi 9:00 ») and why the choice was made.

## After an S1 or S2

Within two days, five lines in `LOG.md`: what happened, when it started and ended, the cause, what fixed it, what prevents it next time (a task in `03-PLAN.md` if code or a script must change).
