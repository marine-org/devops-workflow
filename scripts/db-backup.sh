#!/bin/bash
# ============================================================
# Database Backup — dump + compress + upload to S3/rclone
# Usage: bash db-backup.sh <db-type> <db-name> [--s3|--local]
#
# Supports: mysql, postgres, mongodb
# ============================================================
set -e

DB_TYPE="${1:?Usage: db-backup.sh <mysql|postgres|mongo> <db-name> [--s3|--local] [--retention=days]}"
DB_NAME="${2:?Database name required}"
DEST="local"
RETENTION="${BACKUP_RETENTION:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/tmp/db-backups}"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}"

# Parse flags
shift 2
for arg in "$@"; do
    case $arg in
        --s3)        DEST="s3" ;;
        --local)     DEST="local" ;;
        --retention=*) RETENTION="${arg#*=}" ;;
    esac
done

mkdir -p "$BACKUP_DIR"

echo "💾 DB Backup — $DB_TYPE:$DB_NAME → $DEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Dump ───────────────────────────────────────────────────
case "$DB_TYPE" in
    mysql|mariadb)
        BACKUP_FILE="${BACKUP_FILE}.sql.gz"
        echo "🐬 mysqldump $DB_NAME..."
        mysqldump \
            ${MYSQL_HOST:+--host=$MYSQL_HOST} \
            ${MYSQL_PORT:+--port=$MYSQL_PORT} \
            ${MYSQL_USER:+--user=$MYSQL_USER} \
            ${MYSQL_PASSWORD:+--password=$MYSQL_PASSWORD} \
            --single-transaction \
            --routines \
            --triggers \
            --events \
            "$DB_NAME" | gzip > "$BACKUP_FILE"
        ;;

    postgres|postgresql|pg)
        BACKUP_FILE="${BACKUP_FILE}.sql.gz"
        echo "🐘 pg_dump $DB_NAME..."
        PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}" pg_dump \
            ${PGHOST:+--host=$PGHOST} \
            ${PGPORT:+--port=$PGPORT} \
            ${PGUSER:+--username=$PGUSER} \
            --no-owner \
            --no-acl \
            "$DB_NAME" | gzip > "$BACKUP_FILE"
        ;;

    mongo|mongodb)
        BACKUP_FILE="${BACKUP_FILE}.archive.gz"
        echo "🍃 mongodump $DB_NAME..."
        mongodump \
            ${MONGO_URI:+--uri=$MONGO_URI} \
            ${MONGO_HOST:+--host=$MONGO_HOST} \
            --db="$DB_NAME" \
            --archive --gzip > "$BACKUP_FILE"
        ;;

    *)
        echo "❌ Unknown DB type: $DB_TYPE (use: mysql, postgres, mongo)"
        exit 1
        ;;
esac

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "📦 Backup created: $BACKUP_FILE ($SIZE)"

# ── Upload ─────────────────────────────────────────────────
if [[ "$DEST" == "s3" ]]; then
    S3_PATH="${S3_BACKUP_PATH:-s3://my-backups/databases}/${DB_NAME}/"
    echo "☁️  Uploading to $S3_PATH..."

    if command -v aws &>/dev/null; then
        aws s3 cp "$BACKUP_FILE" "${S3_PATH}$(basename "$BACKUP_FILE")"
    elif command -v rclone &>/dev/null; then
        rclone copy "$BACKUP_FILE" "${RCLONE_REMOTE:-s3:}/${DB_NAME}/"
    else
        echo "⚠️  Neither aws CLI nor rclone found — skipping upload"
        echo "   Install: pip install awscli  or  curl https://rclone.org/install.sh | bash"
    fi
fi

# ── Retention cleanup ──────────────────────────────────────
echo "🧹 Cleaning backups older than $RETENTION days..."
find "$BACKUP_DIR" -name "${DB_NAME}_*" -mtime "+$RETENTION" -delete 2>/dev/null || true

# Also clean S3 if configured
if [[ "$DEST" == "s3" ]] && command -v aws &>/dev/null; then
    S3_PATH="${S3_BACKUP_PATH:-s3://my-backups/databases}/${DB_NAME}/"
    aws s3 ls "$S3_PATH" 2>/dev/null | while read -r _ _ date_str _ key; do
        file_age_days=$(( ($(date +%s) - $(date -d "$date_str" +%s)) / 86400 ))
        if [[ "$file_age_days" -gt "$RETENTION" ]]; then
            aws s3 rm "${S3_PATH}${key}" 2>/dev/null
            echo "   🗑️  Deleted S3: $key (${file_age_days}d old)"
        fi
    done
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "✅ Backup complete — $DB_NAME ($SIZE)"
echo "📁 Local: $BACKUP_DIR ($(du -sh "$BACKUP_DIR" | cut -f1) total)"
echo "⏳ Retention: $RETENTION days"
