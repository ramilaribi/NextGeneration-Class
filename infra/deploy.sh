#!/usr/bin/env bash
# Puts the platform on the server, the first time and for every update (docs/04-delivery/05-DEPLOYMENT.md).
# From the project folder on the Mac:  ./infra/deploy.sh ubuntu@SERVER_IP
# Builds the web app here, sends the code, prepares the server once, then rebuilds and restarts it.
set -euo pipefail
SERVER="${1:?Usage: ./infra/deploy.sh ubuntu@SERVER_IP}"
KEY="${SSH_KEY:-$HOME/.ssh/ngclass_ovh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE=/opt/ngclass
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new)
COMPOSE="cd $REMOTE/infra && sudo docker compose -f docker-compose.prod.yml"

remote() { ssh "${SSH_OPTS[@]}" "$SERVER" "$@"; }
remote_tty() { ssh -t "${SSH_OPTS[@]}" "$SERVER" "$@"; }
send() { rsync -az --delete -e "ssh ${SSH_OPTS[*]}" "$@"; }

echo "1/5 Building the web app"
(cd "$ROOT/app" && flutter build web --release)

echo "2/5 Preparing the server folder"
remote_tty "sudo mkdir -p $REMOTE && sudo chown \$(id -un) $REMOTE"

echo "3/5 Sending the project"
send --exclude target --exclude data --exclude .env "$ROOT/backend/" "$SERVER:$REMOTE/backend/"
send --exclude .env --exclude dev-tools "$ROOT/infra/" "$SERVER:$REMOTE/infra/"
remote "mkdir -p $REMOTE/app/build"
send "$ROOT/app/build/web/" "$SERVER:$REMOTE/app/build/web/"
# The web server's image is Caddy with the web build inside (app/web.Dockerfile), as in the GitHub pipeline.
rsync -az -e "ssh ${SSH_OPTS[*]}" "$ROOT/app/web.Dockerfile" "$ROOT/app/.dockerignore" "$SERVER:$REMOTE/app/"

echo "4/5 First time only: server setup and settings"
if ! remote "command -v docker >/dev/null && test -f /etc/cron.d/ngclass-backup"; then
	remote_tty "sudo bash $REMOTE/infra/server-setup.sh"
fi
if ! remote "test -f $REMOTE/infra/.env"; then
	remote_tty "bash $REMOTE/infra/make-env.sh"
fi

echo "5/5 Starting the platform (the first build takes about 5 minutes)"
# --wait: done only once the API answers UP and the web server is running (health checks in the compose file).
if remote_tty "$COMPOSE up -d --build --wait --wait-timeout 300 --remove-orphans && sudo docker image prune -f >/dev/null"; then
	DOMAIN="$(remote "sed -n 's/^DOMAIN=//p' $REMOTE/infra/.env")"
	echo "Done: https://$DOMAIN is up."
else
	echo "The platform did not start. The API's last lines:"
	remote "$COMPOSE logs --tail 80 api"
	exit 1
fi
