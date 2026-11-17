#!/usr/bin/env sh
# Nightly backup of the database and uploaded files, 30 days kept (docs/03-conception/07-NON_FUNCTIONAL.md).
# Cron on the server (server-setup.sh adds it):  0 2 * * * /opt/ngclass/infra/backup.sh >> /var/log/ngclass-backup.log 2>&1
# Restore: docs/05-deployment/04-RUNBOOK.md, section 7.
# BACKUP_REMOTE in .env sends a copy off the server (rclone).
# Each file is written as .part and renamed only when complete: a failed backup leaves no file that looks like one,
# and the log says FAILED.
set -eu
cd "$(dirname "$0")"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ngclass}"
STAMP="$(date +%Y-%m-%d_%H%M)"
DB="$BACKUP_DIR/db_$STAMP.dump"
FILES="$BACKUP_DIR/files_$STAMP.tar.gz"
# Pupils' data: readable by root only.
umask 077
mkdir -p "$BACKUP_DIR"

failed() {
	rm -f "$DB.part" "$FILES.part"
	echo "$(date) backup $STAMP FAILED: $1"
	exit 1
}

docker compose -f docker-compose.prod.yml exec -T db pg_dump -U ngclass -d ngclass --format=custom > "$DB.part" \
	|| failed "database dump (is the platform running? is infra/.env there?)"
# A custom-format dump starts with PGDMP; anything else (empty, an error text) is not a backup.
[ "$(head -c 5 "$DB.part")" = PGDMP ] || failed "database dump is empty or not a dump"
docker compose -f docker-compose.prod.yml run --rm --no-deps --user root -v "$BACKUP_DIR:/backup" --entrypoint sh api \
	-c "tar -czf /backup/files_$STAMP.tar.gz.part -C /data files" \
	|| failed "uploaded files archive"
mv "$DB.part" "$DB"
mv "$FILES.part" "$FILES"
chmod 600 "$DB" "$FILES"

find "$BACKUP_DIR" -type f -mtime +30 -delete
# Leftovers of an interrupted run, and empty files from the old script.
find "$BACKUP_DIR" -type f \( -name '*.part' -o -size 0 \) -delete

# Off-site copy (BACKUP_REMOTE in .env, for example b2:ngclass-backups): the server can be lost, the backups not.
BACKUP_REMOTE="${BACKUP_REMOTE:-$(sed -n 's/^BACKUP_REMOTE=//p' .env 2>/dev/null || true)}"
if [ -n "$BACKUP_REMOTE" ]; then
	rclone copy "$BACKUP_DIR" "$BACKUP_REMOTE" --max-age 48h --exclude '*.part' || failed "off-site copy to $BACKUP_REMOTE"
	rclone delete "$BACKUP_REMOTE" --min-age 30d
fi
echo "$(date) backup $STAMP done ($(du -h "$DB" | cut -f1) database, $(du -h "$FILES" | cut -f1) files)"
