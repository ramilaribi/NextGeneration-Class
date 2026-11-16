#!/usr/bin/env bash
# Monthly restore drill, on the server (docs/05-deployment/04-RUNBOOK.md, section 7).
#   sudo /opt/ngclass/infra/restore-drill.sh
# Restores the newest dump into a throwaway PostgreSQL container, counts users, lists the newest files archive,
# then removes the container. Production is not touched and no data leaves the server.
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ngclass}"
NAME=ngclass-restore-drill

DUMP="$(ls -t "$BACKUP_DIR"/db_*.dump 2>/dev/null | head -1 || true)"
FILES="$(ls -t "$BACKUP_DIR"/files_*.tar.gz 2>/dev/null | head -1 || true)"
[ -n "$DUMP" ] || { echo "No db_*.dump in $BACKUP_DIR: run backup.sh first."; exit 1; }

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "Dump: $(basename "$DUMP")"
docker run -d --name "$NAME" --network none -e POSTGRES_PASSWORD=drill postgres:16-alpine >/dev/null
for _ in $(seq 1 30); do
	docker exec "$NAME" pg_isready -U postgres -q 2>/dev/null && break
	sleep 1
done
docker exec -i "$NAME" pg_restore --no-owner --no-acl --exit-on-error -U postgres -d postgres < "$DUMP"
USERS="$(docker exec "$NAME" psql -U postgres -tAc 'select count(*) from users')"
MIGRATION="$(docker exec "$NAME" psql -U postgres -tAc 'select max(version::int) from flyway_schema_history where success')"
echo "Database: restored, $USERS users, schema at migration V$MIGRATION."

if [ -n "$FILES" ]; then
	COUNT="$(tar -tzf "$FILES" | grep -vc '/$' || true)"
	echo "Files: $(basename "$FILES"), $COUNT files, archive readable."
else
	echo "Files: no files_*.tar.gz found."
	exit 1
fi
echo "Restore drill passed. The throwaway database is removed. Add a line to docs/05-deployment/LOG.md."
