# Production log

One line per action on production or on the plan: date, who, what, commit (for deploys), result. **Never a secret, never a pupil's name.** Newest at the bottom.

| Date | Who | What | Commit | Result |
|---|---|---|---|---|
| 2026-11-12 | owner + agent | Host chosen: OVHcloud VPS-1 monthly, `.com` at OVHcloud. Production stack rehearsed on the Mac (`DOMAIN=localhost`): HTTPS, owner account, upload, backup, restore | | ok |
| 2026-11-16 | owner + agent | Deployment plan written (`docs/05-deployment/`), playbook PDF for owner and teammate. Nothing bought yet | 4446b59 (main) | plan ready, P0 next |
| 2026-11-16 | owner + agent | Pre-production audit (`PREPROD_AUDIT.md`): tests green (backend 73, app 913), 8 findings, cleanup tasks T7 to T13 added to the plan. Audit probes ran on the dev database only (one test chapter created and deleted) | c60713c (main) | 3 high, 2 medium, 3 low |
| 2026-11-16 | owner + agent | Audit cleanup T7 to T13 (and F9, doubled apostrophes) on branch `preprod-cleanup`: backend 76 and app 922 tests green, probes give 400/405/415/406/409 and no ERROR line | preprod-cleanup | done, waiting for merge |
