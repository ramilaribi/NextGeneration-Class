# 08 · Automatic deploys from GitHub (task T5)

Since 2026-11-17 (user decision: "always deploy new changes"), every push to `main` whose tests are green goes online by itself. Nothing runs on a machine of ours: both deploy jobs run on GitHub's own machines (`ubuntu-latest`), so a pull request from a fork never reaches the server. Pull requests are only tested, never deployed.

## What happens on a push to `main`

`.github/workflows/ci.yml`, in order:

1. **Backend (Spring Boot)** and **App (Flutter)**: the tests. The App job also builds the web app once and keeps it for the two deploy jobs.
2. **Deploy the server**: writes the deploy key for this run only, accepts only the server's pinned host key, then runs `infra/deploy.sh` as a person would (backup of the running platform, code sent, API, database and Caddy rebuilt with the server's own `infra/.env`, waits for the API to answer UP). Then checks `https://api.nextgenerationclass.online/health` from outside and removes the key.
3. **Deploy the web app**: uploads the same tested web build to the Cloudflare Worker (`infra/cloudflare`, `wrangler deploy`), then checks the site and `/health` through it. Runs after the server, never after a failed server deploy.

One deploy at a time; a newer push waits, it never cuts a deploy in the middle. A failed deploy leaves the previous version running (`deploy.sh` stops before the restart, or `docker compose --wait` fails and the API's last lines are printed in the job). Roll back by reverting the commit on `main`: the revert deploys like any change.

No application secret is in GitHub: `DB_PASSWORD`, `JWT_SECRET` and the accounts stay in `/opt/ngclass/infra/.env` on the server. The first setup of a new server stays manual (`./infra/deploy.sh ubuntu@IP` from a terminal): the pipeline refuses a server that is not set up yet.

## Settings (GitHub › Settings › Environments › `production`)

| Name | Kind | Value | Set |
|---|---|---|---|
| `DEPLOY_SSH_KEY` | secret | Private half of the pipeline's own key (ed25519, made for GitHub only, never stored anywhere else) | 2026-11-17 |
| `DEPLOY_HOST` | variable | `2.25.10.142` | 2026-11-17 |
| `DEPLOY_KNOWN_HOSTS` | variable | The server's ed25519 host key (`ssh-keyscan -t ed25519 2.25.10.142`): any other key is refused | 2026-11-17 |
| `DEPLOY_USER` | variable | `root`: this server has no `ubuntu` user, the platform was set up and is deployed as root (`ubuntu` when not set) | 2026-11-18 |
| `CLOUDFLARE_API_TOKEN` | secret | A Cloudflare API token from the template "Edit Cloudflare Workers", limited to this account | **to do (owner)** |
| `CLOUDFLARE_ACCOUNT_ID` | variable | The account id (Cloudflare dashboard, Workers & Pages, right column) | **to do (owner)** |

A job whose settings are missing is skipped: without `DEPLOY_HOST` no server deploy, without `CLOUDFLARE_ACCOUNT_ID` no web deploy.

## Still to do once

1. ~~**Server: allow the pipeline's key**~~ **done 2026-11-18**: `infra/ci-deploy-key.pub` added to `/root/.ssh/authorized_keys` (previous file kept as `authorized_keys.bak-ci`). Deploys log in as `root`, as the manual ones did. To add it again on a new server:
   ```bash
   ssh root@SERVER_IP "cat >> ~/.ssh/authorized_keys" < infra/ci-deploy-key.pub
   ```
2. **Cloudflare token** (owner): dashboard › My Profile › API Tokens › Create Token › "Edit Cloudflare Workers", limited to the account that holds `nextgenerationclass.online`, then `CLOUDFLARE_API_TOKEN` (secret) and `CLOUDFLARE_ACCOUNT_ID` (variable) in the `production` environment.
3. **Remove the old self-hosted runner** (Settings › Actions › Runners, the teammate's PC): no job uses it any more.
4. **Forks** (Settings › Actions › General): "Require approval for all external contributors", so a stranger's pull request does not even run the tests without the owner's click.
5. Optional: a required reviewer on the `production` environment makes every deploy wait for the owner's click. Not set: the decision is to deploy every change.

## Changing or revoking the key

Make a new key (`ssh-keygen -t ed25519 -N "" -f /tmp/k`), put `/tmp/k` in the `DEPLOY_SSH_KEY` secret and `/tmp/k.pub` in `infra/ci-deploy-key.pub` and the server's `/root/.ssh/authorized_keys`, delete `/tmp/k`, remove the old line from `authorized_keys`. To stop automatic deploys at once: delete the `DEPLOY_HOST` variable (or the key's line on the server).
