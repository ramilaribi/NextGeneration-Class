# 06 · Go-live checklist

All ticked before the teacher gets her account (end of P4). Who ticks it in brackets. A "no" on a line marked **(blocker)** means no go.

## People and content
- [ ] The teacher (or a lawyer) read the privacy text (`/confidentialite`) and agreed to it **(blocker)** (owner)
- [ ] A native Arabic speaker read the Arabic screens (owner)
- [ ] The owner looked at the owner dashboard (built without a mockup) (owner)
- [ ] The teacher knows the address, how to sign in the first time and whom to call (owner)

## Code
- [ ] `main` is what runs, its commit noted in `LOG.md` (owner)
- [ ] CI green on that commit (teammate)
- [ ] T1 to T4 merged (teammate)

## Server
- [ ] Both people enter with their own key; password login off **(blocker)** (teammate)
- [ ] `sudo ufw status`: only 22, 80, 443 (teammate)
- [ ] `sudo fail2ban-client status sshd` answers (teammate)
- [ ] `timedatectl`: Africa/Tunis (teammate)
- [ ] `swapon --show`: 2 GB swap (teammate)
- [ ] `$C ps`: three parts up, api and db healthy (teammate)
- [ ] `infra/.env` mode 600, not in git, not anywhere else (teammate)

## Web
- [ ] `https://<domain>` 200, `/health` UP, `http://` and `www.` redirect **(blocker)** (teammate)
- [ ] Certificate valid (padlock), issued by Let's Encrypt (teammate)
- [ ] Smoke test of `04-RUNBOOK.md` section 4 passed, on a computer and a phone, French and Arabic **(blocker)** (owner)

## Safety net
- [ ] UptimeRobot monitor on `/health`, alerts to both emails, one test alert received (owner)
- [ ] OVHcloud automated backup visible in the panel (owner)
- [ ] Nightly backup ran at least once (backup log) (teammate)
- [ ] A copy of the backups is on the owner's Mac (owner)
- [ ] Restore drill passed (`04-RUNBOOK.md` section 7) **(blocker)** (teammate)
- [ ] Rollback steps read by both; the last good commit is in `LOG.md` (both)

## Accounts and money
- [ ] VPS renewal: monthly, the card valid (owner)
- [ ] Domain: automatic renewal on (owner)
- [ ] Owner's app password in a password manager (owner)
- [ ] Test teacher disabled (or kept for smoke tests) (owner)

Go: _____ (date) · Owner: _____ · Teammate: _____
