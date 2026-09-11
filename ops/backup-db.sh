#!/usr/bin/env bash
# Backup giornaliero del database InCampo (MySQL nel container infra-mysql-1).
#
#   /opt/apps/calcioacinque/ops/backup-db.sh
#
# Legge la password dal .env dell'app (DB_PASSWORD), scrive un dump gzippato in
# /opt/backups/db/ e tiene gli ultimi 14 giorni. Installato in crontab da
# ops/install-cron.sh. Log in /var/log/incampo-backup.log.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"
DEST_DIR="/opt/backups/db"
KEEP_DAYS=14
CONTAINER="infra-mysql-1"
DB_NAME="${DB_NAME:-calcioacinque}"

[ -f "$ENV_FILE" ] || { echo "manca $ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')"
[ -n "$DB_PASSWORD" ] || { echo "DB_PASSWORD mancante in $ENV_FILE" >&2; exit 1; }

mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$DEST_DIR/incampo-$STAMP.sql.gz"

# --single-transaction: dump coerente senza bloccare le tabelle InnoDB.
# La password passa via variabile d'ambiente al client, non sulla riga di comando.
docker exec -e MYSQL_PWD="$DB_PASSWORD" "$CONTAINER" \
  mysqldump -uroot --single-transaction --quick --routines --triggers "$DB_NAME" \
  | gzip -9 > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
chmod 600 "$OUT"

# Un dump vuoto o troncato e' peggio di nessun dump: controlla che finisca bene.
if ! gzip -dc "$OUT" | tail -c 400 | grep -q "Dump completed"; then
  echo "$(date -Is) ERRORE: dump incompleto $OUT" >&2
  exit 2
fi

find "$DEST_DIR" -name 'incampo-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "$(date -Is) ok $OUT ($(du -h "$OUT" | cut -f1)), conservati: $(ls "$DEST_DIR" | wc -l)"
