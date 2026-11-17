# 04 · Runbook

Every command, with where it runs. Replace `IP` with the VPS address and `ngclass.com` with the real domain. On the server, this shortcut is used everywhere:

```bash
C="sudo docker compose -f /opt/ngclass/infra/docker-compose.prod.yml"
```

(Compose reads `/opt/ngclass/infra/.env` by itself, from wherever the command runs.)

## 1. SSH keys (P1, P2)

Each person makes their own key, once.

Owner, on the Mac (Terminal):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ngclass_ovh -C "owner-ngclass"
cat ~/.ssh/ngclass_ovh.pub
```
The `.pub` line is pasted in the OVHcloud order (or added after delivery). `deploy.sh` uses `~/.ssh/ngclass_ovh` by default.

Teammate, on Windows (PowerShell; OpenSSH is built into Windows 10 and 11):
```powershell
ssh-keygen -t ed25519 -f $HOME\.ssh\ngclass_ovh -C "teammate-ngclass"
Get-Content $HOME\.ssh\ngclass_ovh.pub
```
Send the `.pub` line to the owner (it is public, it can go in a message).

Owner adds it on the server:
```bash
ssh -i ~/.ssh/ngclass_ovh ubuntu@IP
echo 'ssh-ed25519 AAAA...the teammate line... teammate-ngclass' >> ~/.ssh/authorized_keys
```

Teammate checks (PowerShell):
```powershell
ssh -i $HOME\.ssh\ngclass_ovh ubuntu@IP
```

Removing the teammate later: delete their line in `~/.ssh/authorized_keys` on the server.

### Password login off (P4)

Once both keys work, keep one SSH session open and in a second one:
```bash
sudo sshd -T | grep -i '^passwordauthentication'
```
If it says `yes`:
```bash
echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/99-ngclass.conf
sudo systemctl reload ssh
```
Then open a **new** session with the key to be sure it still works before closing the old one.

## 2. Rehearsal on a laptop (P0)

The production files on a laptop, `DOMAIN=localhost` (Caddy then makes its own local certificate; the browser warns, accept it). Docker Desktop must run. Ports 80 and 443 must be free.

1. From `app/`: `flutter build web --release --pwa-strategy=none`
2. Write `infra/.env` (git-ignored) with **throwaway** values: `DOMAIN=localhost`, a random `DB_PASSWORD` and `JWT_SECRET`, an `ADMIN_USERNAME`, `ADMIN_PASSWORD` (8+ characters), `ADMIN_FIRST_NAME`, `ADMIN_LAST_NAME`. `infra/.env.example` lists every name.
3. From `infra/`: `docker compose -f docker-compose.prod.yml up -d --build --wait`
4. Open `https://localhost`, sign in as the owner, change the password, add a teacher, sign in as her in a private window, upload a file.
5. From `infra/`: `BACKUP_DIR=./rehearsal-backups sh backup.sh` (Git Bash or Mac terminal), then the restore of section 7 on the laptop (no `sudo`, `./rehearsal-backups` instead of `/var/backups/ngclass`).
6. Clean up (laptop only): `docker compose -f docker-compose.prod.yml down -v`, delete `infra/.env` and the rehearsal backups.

## 3. First deploy (P3)

On the Mac, from the project folder, on a clean, pulled `main`:
```bash
git switch main && git pull && git status
./infra/deploy.sh ubuntu@IP
```
What happens: web build on the Mac → code sent to `/opt/ngclass` → first time only, `server-setup.sh` (time zone, updates, Docker, firewall, fail2ban, swap, automatic security updates, nightly backup) → first time only, `make-env.sh` asks the domain and the owner's account (the owner types the password; the teammate looks away) → images built, stack started, waits until healthy (the first build takes about 5 minutes). Ends with `Done: https://ngclass.com is up.`

If it ends with "The platform did not start", read the 80 lines it prints and go to `05-INCIDENTS.md`.

## 4. Smoke test (P4, after every deploy in short)

From any terminal:
```bash
curl -sI https://ngclass.com | head -1          # HTTP/2 200
curl -s https://ngclass.com/health              # {"status":"UP"}
curl -sI http://ngclass.com | head -3           # a redirect to https
curl -sI https://www.ngclass.com | head -3      # a redirect to https://ngclass.com
```

In the app (first deploy, full; later deploys, steps 1 and 2 only):
1. Owner signs in → asked for a new password → the owner dashboard.
2. Owner adds a test teacher → in a private window she signs in, changes the password, creates a subject and a group, uploads a PDF, plans a session.
3. She adds a pupil with a parent → the parent signs in, changes the password, sees the privacy notice, accepts, sees the child.
4. On a phone: the site opens, Arabic switch works, right to left.
5. `./infra/deploy.sh ubuntu@IP` again (same commit): everything above is still there.
6. Owner disables the test teacher from the dashboard (or keeps it for later smoke tests).

## 5. Updates (every later deploy)

1. Changes merged into `main` through a pull request, CI green.
2. Evening or weekend; say it in the channel.
3. On the Mac:
   ```bash
   git switch main && git pull && git status
   ./infra/deploy.sh ubuntu@IP
   ```
   `deploy.sh` refuses a branch other than `main` or uncommitted files, takes a backup on the server before the restart, and writes the deployed commit to `/opt/ngclass/DEPLOYED` (`ssh -i ~/.ssh/ngclass_ovh ubuntu@IP cat /opt/ngclass/DEPLOYED`).
4. Smoke test, steps 1 and 2.
5. `LOG.md`: date, who, the commit, result.

Browsers get the new version on the next visit (Caddy sends the version files with `no-cache`).

## 6. Looking at the server

```bash
ssh -i ~/.ssh/ngclass_ovh ubuntu@IP
C="sudo docker compose -f /opt/ngclass/infra/docker-compose.prod.yml"
$C ps                                  # the three parts and their health
$C logs --tail 100 api                 # the API's last lines
$C logs --tail 50 caddy                # HTTPS and requests
$C logs -f api                         # follow live (Ctrl+C to stop)
sudo docker stats --no-stream          # memory and CPU per part
df -h /                                # disk
free -h                                # memory and swap
uptime                                 # load
tail -5 /var/log/ngclass-backup.log    # last nightly backups: "done (size)" each night; "FAILED: reason" means no backup that night
ls -lh /var/backups/ngclass | tail -6  # the newest backup files
cat /var/run/reboot-required 2>/dev/null   # a reboot is waiting for a system update
```

Restart one part (about a minute for the API):
```bash
$C restart api
```
Start everything again after a stop:
```bash
$C up -d --wait
```

### Weekly check (teammate, 10 minutes)

- `$C ps`: three parts `Up`, `api` and `db` `(healthy)`.
- `df -h /` below 70 %. `free -h`: swap used stays small.
- Backup log: one line per night, last night present.
- `$C logs --since 168h api | grep -c ERROR` (look at them if the number jumps).
- Reboot waiting? Do it in the evening, after telling the channel: `sudo reboot`, then `$C ps` a minute later.
- One line in `LOG.md`.

## 7. Backups and restore

Backup now:
```bash
sudo /opt/ngclass/infra/backup.sh
```

Copy to the owner's Mac (weekly, from the project folder; copies into `~/NGClass-backups`, keeps 8 weeks):
```bash
./infra/pull-backups.sh ubuntu@IP
```

**Restore** (on the server, replace `DATE` by the backup's date and time, for example `2026-11-20_0200`). Everything written after that backup is lost: the owner decides.
```bash
cd /opt/ngclass/infra
sudo docker compose -f docker-compose.prod.yml stop api
sudo docker compose -f docker-compose.prod.yml exec -T db pg_restore --clean --if-exists -U ngclass -d ngclass < /var/backups/ngclass/db_DATE.dump
sudo docker compose -f docker-compose.prod.yml run --rm --no-deps --user root -v /var/backups/ngclass:/backup --entrypoint sh api -c "rm -rf /data/files/* && tar -xzf /backup/files_DATE.tar.gz -C /data"
sudo docker compose -f docker-compose.prod.yml start api
```

### Restore drill

- **P4, on production itself, before the teacher's data exists**: with only the test accounts in, run a backup, change something visible (rename the test group, upload one more file), restore that backup, check the change is gone and the files open. This proves the whole procedure at no risk.
- **Every month after go-live, without touching production**: check the latest dump restores into a throwaway database on the server, then remove it. `infra/restore-drill.sh` does all of it (no network for the throwaway container, removed even on failure):
  ```bash
  sudo /opt/ngclass/infra/restore-drill.sh
  ```
  The same by hand:
  ```bash
  F=$(ls -t /var/backups/ngclass/db_*.dump | head -1)
  sudo docker run -d --name restore-test -e POSTGRES_PASSWORD=drill postgres:16-alpine
  sleep 10
  sudo docker exec -i restore-test pg_restore --no-owner -U postgres -d postgres < "$F"
  sudo docker exec restore-test psql -U postgres -c "select count(*) from users;"
  sudo docker rm -f restore-test
  tar -tzf $(ls -t /var/backups/ngclass/files_*.tar.gz | head -1) | wc -l
  ```
  A count of users and a number of files mean the backup is good. Production data never leaves the server for a drill.

## 8. Rollback

Code only:
```bash
git switch --detach <last good commit from LOG.md>
./infra/deploy.sh ubuntu@IP --force
git switch main
```
(`--force` because the script otherwise refuses anything but a clean `main`.) Code and data: restore the backup taken before the bad deploy (section 7), then deploy the old commit. See `01-STRATEGY.md`, "Rollback".

## 9. Server care

- Security updates install by themselves (unattended-upgrades). Full update, monthly, in the evening: `sudo apt update && sudo apt upgrade -y`, then reboot if asked.
- Docker images: `deploy.sh` removes unused ones after each deploy. If the disk fills: `sudo docker system prune -f` (never with `--volumes`).
- The HTTPS certificate renews by itself (Caddy). Never delete the `caddy-data` volume.
- Domain: renews yearly in the OVHcloud account (automatic renewal on, card valid). VPS: monthly.
- Never change `DB_PASSWORD` in `infra/.env`. `JWT_SECRET` can be changed (users stay signed in: their refresh tokens are in the database), then `$C up -d`.

## 10. A new server (lost server, or a move)

1. New VPS with Ubuntu 24.04 and the owner's key.
2. DNS A records to the new IP (section P2 of `03-PLAN.md`), wait.
3. `./infra/deploy.sh ubuntu@NEWIP`; in `make-env.sh` give the same domain and owner account (the database is replaced next anyway).
4. Copy the latest backup from the Mac to `/var/backups/ngclass/` on the new server (`rsync` the other way), restore (section 7).
5. Smoke test, UptimeRobot still green, `LOG.md`.
