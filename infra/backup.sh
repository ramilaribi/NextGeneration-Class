#!/usr/bin/env sh
# Nightly backup of the database and uploaded files, 30 days kept (docs/03-conception/07-NON_FUNCTIONAL.md).
# Cron on the server (server-setup.sh adds it):  0 2 * * * /opt/ngclass/infra/backup.sh >> /var/log/ngclass-backup.log 2>&1
# Restore: docs/04-delivery/05-DEPLOYMENT.md, section "Restore a backup".
# BACKUP_REMOTE in .env sends a copy off the server (rclone).
set -eu
cd "$(dirname "$0")"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ngclass}"
STAMP="$(date +%Y-%m-%d_%H%M)"
mkdir -p "$BACKUP_DIR"

docker compose -f docker-compose.prod.yml exec -T db pg_dump -U ngclass -d ngclass --format=custom \
	> "$BACKUP_DIR/db_$STAMP.dump"
docker compose -f docker-compose.prod.yml run --rm --no-deps --user root -v "$BACKUP_DIR:/backup" --entrypoint sh api \
	-c "tar -czf /backup/files_$STAMP.tar.gz -C /data files"

find "$BACKUP_DIR" -type f -mtime +30 -delete

# Off-site copy (BACKUP_REMOTE in .env, for example b2:ngclass-backups): the server can be lost, the backups not.
BACKUP_REMOTE="${BACKUP_REMOTE:-$(sed -n 's/^BACKUP_REMOTE=//p' .env 2>/dev/null || true)}"
if [ -n "$BACKUP_REMOTE" ]; then
	rclone copy "$BACKUP_DIR" "$BACKUP_REMOTE" --max-age 48h
	rclone delete "$BACKUP_REMOTE" --min-age 30d
fi
echo "$(date) backup $STAMP done"
