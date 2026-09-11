#!/usr/bin/env bash
# Pianifica il backup giornaliero alle 03:30 (idempotente).
#   /opt/apps/calcioacinque/ops/install-cron.sh
# Usa un timer systemd: sul server non c'e' cron. Se c'e' crontab, usa quello.
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$APP_DIR"/ops/*.sh
LOG=/var/log/incampo-backup.log

if command -v systemctl >/dev/null 2>&1; then
  cat > /etc/systemd/system/incampo-backup.service <<EOF
[Unit]
Description=Backup giornaliero del database InCampo

[Service]
Type=oneshot
ExecStart=$APP_DIR/ops/backup-db.sh
StandardOutput=append:$LOG
StandardError=append:$LOG
EOF
  cat > /etc/systemd/system/incampo-backup.timer <<EOF
[Unit]
Description=Backup giornaliero del database InCampo (03:30)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now incampo-backup.timer
  echo "timer installato:"; systemctl list-timers incampo-backup.timer --no-pager | head -3
elif command -v crontab >/dev/null 2>&1; then
  LINE="30 3 * * * $APP_DIR/ops/backup-db.sh >> $LOG 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'ops/backup-db.sh' ; echo "$LINE" ) | crontab -
  echo "cron installato:"; crontab -l | grep backup-db
else
  echo "ne' systemd ne' cron: pianificare a mano ops/backup-db.sh" >&2
  exit 1
fi
