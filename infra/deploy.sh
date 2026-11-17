#!/usr/bin/env bash
# Puts the platform on the server, the first time and for every update (docs/05-deployment/04-RUNBOOK.md).
# From the project folder on the Mac:  ./infra/deploy.sh ubuntu@SERVER_IP
# Emergencies only (a commit off main, or uncommitted work):  ./infra/deploy.sh ubuntu@SERVER_IP --force
# Checks the working copy, builds the web app here, sends the code, prepares the server once,
# backs up the running platform, then rebuilds and restarts it.
# The GitHub pipeline runs it too (.github/workflows/ci.yml, job "Deploy the server"), with:
#   SSH_KEY        the deploy key written from the repository secret
#   SSH_STRICT=yes only the server key pinned in DEPLOY_KNOWN_HOSTS is accepted
#   DEPLOY_BRANCH  the branch GitHub checked out (its checkout has no branch name)
#   SKIP_WEB_BUILD=1 the web build tested by the "App" job is already in app/build/web
set -euo pipefail
SERVER="${1:?Usage: ./infra/deploy.sh ubuntu@SERVER_IP [--force]}"
FORCE="${2:-}"
KEY="${SSH_KEY:-$HOME/.ssh/ngclass_ovh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE=/opt/ngclass
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking="${SSH_STRICT:-accept-new}")
# Without a terminal (the pipeline), ssh must fail at once instead of waiting for a password.
[ -t 0 ] || SSH_OPTS+=(-o BatchMode=yes)
COMPOSE="cd $REMOTE/infra && sudo docker compose -f docker-compose.prod.yml"

remote() { ssh "${SSH_OPTS[@]}" "$SERVER" "$@"; }
# A terminal on the server only when there is one here (the pipeline has none; its steps never ask anything).
remote_tty() { if [ -t 0 ]; then ssh -t "${SSH_OPTS[@]}" "$SERVER" "$@"; else ssh "${SSH_OPTS[@]}" "$SERVER" "$@"; fi; }
send() { rsync -az --delete -e "ssh ${SSH_OPTS[*]}" "$@"; }

command -v rsync >/dev/null || { echo "rsync is needed on this machine (Mac: built in; Windows: use WSL)."; exit 1; }

echo "1/6 Checking the working copy"
# The script sends this folder as it is, so only a clean main (what CI tested) goes online.
BRANCH="${DEPLOY_BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)}"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
DIRTY="$(git -C "$ROOT" status --porcelain)"
if [ "$BRANCH" != main ] || [ -n "$DIRTY" ]; then
	if [ "$FORCE" != --force ]; then
		echo "Refused: deploy a clean, pushed main (branch: $BRANCH, uncommitted files: $([ -n "$DIRTY" ] && echo yes || echo no))."
		echo "  git switch main && git pull && git status"
		echo "Emergency or rollback to an older commit: add --force as the second argument."
		exit 1
	fi
	echo "  --force: deploying $BRANCH at $COMMIT$([ -n "$DIRTY" ] && echo ' with uncommitted changes')"
fi
[ -n "$DIRTY" ] && COMMIT="$COMMIT-dirty"

echo "2/6 Building the web app (same flags as the CI job)"
if [ "${SKIP_WEB_BUILD:-}" = 1 ] && [ -f "$ROOT/app/build/web/index.html" ]; then
	echo "  Using the web build of the pipeline's App job."
else
	(cd "$ROOT/app" && flutter build web --release --pwa-strategy=none)
fi

echo "3/6 Preparing the server folder"
remote_tty "sudo mkdir -p $REMOTE && sudo chown \$(id -un) $REMOTE"

echo "4/6 Sending the project"
send --exclude target --exclude data --exclude .env "$ROOT/backend/" "$SERVER:$REMOTE/backend/"
send --exclude .env --exclude dev-tools --exclude 'rehearsal-backups' "$ROOT/infra/" "$SERVER:$REMOTE/infra/"
remote "mkdir -p $REMOTE/app/build"
send "$ROOT/app/build/web/" "$SERVER:$REMOTE/app/build/web/"
# The web server's image is Caddy with the web build inside (app/web.Dockerfile), as in the GitHub pipeline.
rsync -az -e "ssh ${SSH_OPTS[*]}" "$ROOT/app/web.Dockerfile" "$ROOT/app/.dockerignore" "$SERVER:$REMOTE/app/"

echo "5/6 First time only: server setup and settings. Otherwise: a backup of the running platform"
if ! remote "command -v docker >/dev/null && test -f /etc/cron.d/ngclass-backup && test -f $REMOTE/infra/.env"; then
	# Both ask questions: the first time is always done by hand, from a terminal.
	[ -t 0 ] || { echo "Refused: the server is not set up yet. Run ./infra/deploy.sh once by hand first."; exit 1; }
fi
if ! remote "command -v docker >/dev/null && test -f /etc/cron.d/ngclass-backup"; then
	remote_tty "sudo bash $REMOTE/infra/server-setup.sh"
fi
if ! remote "test -f $REMOTE/infra/.env"; then
	remote_tty "bash $REMOTE/infra/make-env.sh"
fi
# A dump from just before the restart, so a rollback with data is possible (docs/05-deployment/01-STRATEGY.md).
if remote "$COMPOSE ps --status running --services 2>/dev/null | grep -qx db"; then
	remote "sudo sh $REMOTE/infra/backup.sh"
else
	echo "  The platform is not running yet: no backup needed."
fi

echo "6/6 Starting the platform (the first build takes about 5 minutes)"
# --wait: done only once the API answers UP and the web server is running (health checks in the compose file).
if remote_tty "$COMPOSE up -d --build --wait --wait-timeout 300 --remove-orphans && sudo docker image prune -f >/dev/null"; then
	remote "echo '$COMMIT $(date -u +%Y-%m-%dT%H:%MZ) $BRANCH' > $REMOTE/DEPLOYED"
	DOMAIN="$(remote "sed -n 's/^DOMAIN=//p' $REMOTE/infra/.env")"
	echo "Done: https://$DOMAIN is up (commit $COMMIT, written to $REMOTE/DEPLOYED). Add it to docs/05-deployment/LOG.md."
else
	echo "The platform did not start. The API's last lines:"
	remote "$COMPOSE logs --tail 80 api"
	exit 1
fi
