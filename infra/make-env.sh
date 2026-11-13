#!/usr/bin/env bash
# Writes infra/.env on the server, the first time only (deploy.sh runs it).
# The secrets are made here and never leave the server; the owner's password is typed here, never in a chat.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then
	echo ".env already exists: nothing changed."
	exit 0
fi

echo "Production settings (stored in /opt/ngclass/infra/.env on this server only)."
read -rp "Domain, without https:// (example: ngclass.com): " DOMAIN
read -rp "Owner username for the admin dashboard (example: rami): " ADMIN_USERNAME
read -rp "Owner first name (example: Rami): " ADMIN_FIRST_NAME
read -rp "Owner last name (example: Laribi): " ADMIN_LAST_NAME
while true; do
	read -rsp "Owner first password, at least 8 characters (changed at first login): " ADMIN_PASSWORD
	echo
	read -rsp "Same password again: " CONFIRM
	echo
	if [ "${#ADMIN_PASSWORD}" -ge 8 ] && [ "$ADMIN_PASSWORD" = "$CONFIRM" ]; then
		break
	fi
	echo "The two passwords differ or are shorter than 8 characters. Try again."
done

umask 077
cat > .env <<EOF
DOMAIN=${DOMAIN}
DB_PASSWORD=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 48)
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_FIRST_NAME=${ADMIN_FIRST_NAME}
ADMIN_LAST_NAME=${ADMIN_LAST_NAME}
TEACHER_USERNAME=
TEACHER_PASSWORD=
TEACHER_FIRST_NAME=
TEACHER_LAST_NAME=
BACKUP_REMOTE=
EOF
echo "Saved. Keep the owner password somewhere safe (a password manager)."
