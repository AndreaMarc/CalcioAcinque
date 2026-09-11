#!/usr/bin/env bash
# Installa (idempotente) il backup giornaliero alle 03:30 nella crontab di root.
#   /opt/apps/calcioacinque/ops/install-cron.sh
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$APP_DIR"/ops/*.sh
LINE="30 3 * * * $APP_DIR/ops/backup-db.sh >> /var/log/incampo-backup.log 2>&1"
( crontab -l 2>/dev/null | grep -v 'ops/backup-db.sh' ; echo "$LINE" ) | crontab -
echo "cron installato:"; crontab -l | grep backup-db
