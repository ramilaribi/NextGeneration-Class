# 07 · Front on Cloudflare, back on the server

Written 2026-11-16, when the domain **nextgenerationclass.online** was put on Cloudflare. This replaces only the web part of `01-STRATEGY.md`; the server, backups, roles and runbook stay as they are.

## What runs where

| Part | Where | Why |
|---|---|---|
| Web app (Flutter build, static files) | **Cloudflare Worker** `ngclass-web`, on `nextgenerationclass.online` and `www.` | Free, fast everywhere, a front deploy takes seconds with no downtime |
| API (Spring Boot, Java 21) + PostgreSQL 16 + uploaded files | **The VPS** (`infra/docker-compose.prod.yml`, `deploy.sh`), on `api.nextgenerationclass.online` | A Worker runs JavaScript only: no Java, no PostgreSQL, no disk. Cloudflare Containers is paid and would still need a database and file storage elsewhere (`docs/04-delivery/02-COST.md`: no paid service without the owner's written approval) |
| DNS, HTTPS for the web app | Cloudflare (free) | Certificates for the Worker's domains are automatic |
| HTTPS for the API | Caddy on the VPS (Let's Encrypt), as before | Unchanged |

```
 browser ── https://nextgenerationclass.online ──► Cloudflare Worker (infra/cloudflare)
                                                   ├─ /api/*, /health ──► https://api.nextgenerationclass.online (VPS: Caddy → api → db)
                                                   └─ everything else  ──► the Flutter build (static assets)
```

The app keeps calling its own address + `/api/v1` (`app/lib/core/config/app_config.dart`): no app change, no `API_BASE_URL`. File links are relative, so they go through the Worker too.

**Not for this project**: `npx @opennextjs/cloudflare migrate` and "Import a repository" are for Next.js projects. Workers Builds from GitHub also cannot build Flutter (no Flutter in its build image); the Worker is deployed with `wrangler` instead (later from GitHub Actions, like T5).

## Files

- `infra/cloudflare/wrangler.jsonc` · the Worker: assets from `app/build/web`, unknown paths fall back to `index.html`, only `/api/*` and `/health` run the script, `BACKEND_ORIGIN`, the two custom domains.
- `infra/cloudflare/worker.js` · forwards `/api/*` to the API and `/health` to `/actuator/health`, adds `X-Forwarded-*`, answers 502 JSON if the server cannot be reached.
- `app/web/_headers` · the same security and no-cache headers as the Caddyfile, for Cloudflare (copied into the build by `flutter build web`).
- `infra/docker-compose.prod.yml` · `ALLOWED_ORIGINS` can now be set in `infra/.env` (default: `https://${DOMAIN}`); `make-env.sh` asks for it.

## Steps

### C1 · Cloudflare (dashboard; the domain and account decisions are the owner's)
1. DNS list stays empty for `@` and `www`: the Worker deploy (C3) creates those records itself.
2. SSL/TLS › Edge Certificates: **Always Use HTTPS** on.
3. Rules › Redirect Rules › Create from template **"Redirect from WWW to root"** (301, keep the path and query). After this, `www.` sends everyone to the main address.

### C2 · The backend server (as `04-RUNBOOK.md` section 3, two answers change)
1. VPS bought (P1). In Cloudflare DNS add **one A record**: name `api`, the VPS IPv4, **Proxy status: DNS only** (grey cloud), so Caddy on the VPS can get its own Let's Encrypt certificate.
2. Wait until `nslookup api.nextgenerationclass.online` gives the VPS IP.
3. Owner runs `./infra/deploy.sh ubuntu@IP`. In `make-env.sh`:
   - Domain: `api.nextgenerationclass.online`
   - Web app address: `https://nextgenerationclass.online,https://www.nextgenerationclass.online`
   - Because a web app address is given, `make-env.sh` also writes `WWW_REDIRECT=off`: Caddy then does not ask for a `www.api.` certificate, which would fail.
4. Check: `curl -s https://api.nextgenerationclass.online/health` gives `{"status":"UP"}`.

Already deployed with another domain? On the server, add `ALLOWED_ORIGINS=https://nextgenerationclass.online,https://www.nextgenerationclass.online` to `/opt/ngclass/infra/.env` and run `$C up -d` (the API restarts, about a minute). Never touch `DB_PASSWORD`.

### C3 · The web app on the Worker (teammate's Windows PC or the owner's Mac)
Needs Flutter 3.38 and Node.js. From the project folder, on a clean `main`:
```bash
cd app && flutter build web --release --pwa-strategy=none && cd ..
cd infra/cloudflare
npx wrangler@4 login
npx wrangler@4 deploy
```
`login` opens the browser to allow wrangler on the Cloudflare account (no token pasted anywhere). `deploy` uploads the build and attaches both custom domains.

### C4 · Check
```bash
curl -sI https://nextgenerationclass.online | head -1            # 200
curl -s https://nextgenerationclass.online/health                # {"status":"UP"} through the Worker
curl -sI https://www.nextgenerationclass.online/eleves | grep -i location   # https://nextgenerationclass.online/eleves
```
Then the in-app smoke test of `04-RUNBOOK.md` section 4. UptimeRobot watches `https://nextgenerationclass.online/health` (it checks the Worker, the API and the database at once).

## Updates

- **Front only**: build, then `npx wrangler@4 deploy` from `infra/cloudflare`. No downtime. Rollback: Workers & Pages › `ngclass-web` › Deployments › an older version › Rollback.
- **API**: `./infra/deploy.sh ubuntu@IP` as before (it also rebuilds the web app inside Caddy on `api.`; harmless).
- **Both** (a change needs new API endpoints): API first, then the front.
- Line in `LOG.md` with the commit, for each.

## Limits (free plan)

100,000 Worker runs a day: only `/api/*` and `/health` count; the app's files are free and unlimited. For about 100 users this is far below the limit. Uploads up to 20 MB pass through (the Worker limit is 100 MB).
