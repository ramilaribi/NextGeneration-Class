#!/usr/bin/env bash
# Weekly off-site copy of the server's backups to the owner's Mac (docs/05-deployment/04-RUNBOOK.md, section 7).
# On the Mac:  ./infra/pull-backups.sh ubuntu@SERVER_IP
# Copies /var/backups/ngclass to ~/NGClass-backups, then keeps 8 weeks there.
# These are children's data: keep this folder on an encrypted disk (FileVault on), never on a shared drive.
set -euo pipefail
SERVER="${1:?Usage: ./infra/pull-backups.sh ubuntu@SERVER_IP}"
KEY="${SSH_KEY:-$HOME/.ssh/ngclass_ovh}"
DEST="${BACKUP_COPY_DIR:-$HOME/NGClass-backups}"
KEEP_DAYS="${KEEP_DAYS:-56}"

command -v rsync >/dev/null || { echo "rsync is needed on this machine."; exit 1; }
mkdir -p "$DEST"
chmod 700 "$DEST"

echo "Copying the server's backups to $DEST"
rsync -az -e "ssh -i $KEY -o StrictHostKeyChecking=accept-new" "$SERVER:/var/backups/ngclass/" "$DEST/"

find "$DEST" -type f \( -name 'db_*.dump' -o -name 'files_*.tar.gz' \) -mtime +"$KEEP_DAYS" -delete

LATEST="$(ls -t "$DEST"/db_*.dump 2>/dev/null | head -1 || true)"
if [ -z "$LATEST" ]; then
	echo "No database dump found on the server. Check /var/log/ngclass-backup.log there."
	exit 1
fi
echo "Done. Newest dump: $(basename "$LATEST") ($(du -h "$LATEST" | cut -f1)). Copies kept: $(ls "$DEST"/db_*.dump | wc -l | tr -d ' ')."
