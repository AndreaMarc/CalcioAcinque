#!/usr/bin/env bash
# Prova di ripristino: carica l'ultimo backup in un database temporaneo, conta le
# tabelle e le righe principali, poi lo elimina. Un backup mai ripristinato non e'
# un backup. Da lanciare a mano ogni tanto (o dopo una migration importante):
#
#   /opt/apps/calcioacinque/ops/restore-test.sh [file.sql.gz]
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"
CONTAINER="infra-mysql-1"
TMP_DB="incampo_restore_test"
FILE="${1:-$(ls -t /opt/backups/db/incampo-*.sql.gz | head -1)}"

DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')"
[ -n "$DB_PASSWORD" ] || { echo "DB_PASSWORD mancante in $ENV_FILE" >&2; exit 1; }
[ -f "$FILE" ] || { echo "backup non trovato: $FILE" >&2; exit 1; }

mysql() { docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "$CONTAINER" mysql -uroot "$@"; }

echo "ripristino di $FILE in $TMP_DB ..."
mysql -e "DROP DATABASE IF EXISTS \`$TMP_DB\`; CREATE DATABASE \`$TMP_DB\` CHARACTER SET utf8mb4;"
gzip -dc "$FILE" | mysql "$TMP_DB"

mysql -N "$TMP_DB" <<'SQL'
SELECT CONCAT('tabelle: ', COUNT(*)) FROM information_schema.tables WHERE table_schema = DATABASE();
SELECT CONCAT('teams: ', COUNT(*)) FROM teams;
SELECT CONCAT('players: ', COUNT(*)) FROM players;
SELECT CONCAT('matches: ', COUNT(*)) FROM matches;
SELECT CONCAT('player_payments: ', COUNT(*)) FROM player_payments;
SQL

mysql -e "DROP DATABASE \`$TMP_DB\`;"
echo "ripristino ok, database temporaneo eliminato"
