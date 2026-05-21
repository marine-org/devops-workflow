#!/bin/bash
# ============================================================
# Log Rotation — rotate app logs, clean journald, manage PM2 logs
# Usage: bash log-rotation.sh [--dry-run]
# ============================================================
set -e

DRY_RUN=false
MAX_LOG_SIZE="${MAX_LOG_SIZE:-100M}"
LOG_RETENTION="${LOG_RETENTION:-14}"     # days
JOURNALD_MAX="${JOURNALD_MAX:-500M}"     # max journald disk usage
PM2_LOG_RETENTION="${PM2_LOG_RETENTION:-7}"  # days

for arg in "$@"; do
    case $arg in --dry-run) DRY_RUN=true ;; esac
done

echo "🔄 Log Rotation — $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ "$DRY_RUN" == true ]] && echo "⚠️  DRY RUN — no files will be modified"
echo ""

# ── PM2 Logs ───────────────────────────────────────────────
if command -v pm2 &>/dev/null; then
    echo "📋 PM2 logs (>${PM2_LOG_RETENTION}d)..."
    PM2_LOG_DIR="${HOME}/.pm2/logs"
    if [[ -d "$PM2_LOG_DIR" ]]; then
        BEFORE=$(du -sh "$PM2_LOG_DIR" 2>/dev/null | cut -f1)
        if $DRY_RUN; then
            COUNT=$(find "$PM2_LOG_DIR" -name "*.log" -mtime "+${PM2_LOG_RETENTION}" | wc -l)
            echo "   Would delete $COUNT files (${BEFORE} total)"
        else
            find "$PM2_LOG_DIR" -name "*.log" -mtime "+${PM2_LOG_RETENTION}" -delete 2>/dev/null || true
            # Flush current logs (pm2 keeps writing to same file descriptors)
            pm2 flush 2>/dev/null || true
            AFTER=$(du -sh "$PM2_LOG_DIR" 2>/dev/null | cut -f1)
            echo "   ${BEFORE} → ${AFTER}"
        fi
    fi
fi

# ── App Logs (common locations) ────────────────────────────
echo "📁 App logs..."
LOG_DIRS=(
    "/var/log/nginx"
    "/var/log/app"
    "${HOME}/apps/*/logs"
    "/tmp/app-logs"
)

for dir_pattern in "${LOG_DIRS[@]}"; do
    for dir in $dir_pattern; do
        [[ ! -d "$dir" ]] && continue
        BEFORE=$(du -sh "$dir" 2>/dev/null | cut -f1)

        if $DRY_RUN; then
            COUNT=$(find "$dir" -name "*.log" -mtime "+${LOG_RETENTION}" 2>/dev/null | wc -l)
            [[ "$COUNT" -gt 0 ]] && echo "   $dir: would delete $COUNT files (${BEFORE})"
        else
            find "$dir" -name "*.log" -mtime "+${LOG_RETENTION}" -delete 2>/dev/null || true
            # Truncate large logs (keep last 10K lines)
            for log in "$dir"/*.log; do
                [[ -f "$log" ]] || continue
                SIZE=$(stat -c%s "$log" 2>/dev/null || echo 0)
                if [[ "$SIZE" -gt 104857600 ]]; then  # >100MB
                    tail -10000 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
                    echo "   ✂️  Truncated $(basename "$log"): $(numfmt --to=iec $SIZE) → $(du -h "$log" | cut -f1)"
                fi
            done
            AFTER=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "   $dir: ${BEFORE} → ${AFTER}"
        fi
    done
done

# ── journald ───────────────────────────────────────────────
if command -v journalctl &>/dev/null && [[ $EUID -eq 0 || -n "$SUDO_USER" ]]; then
    echo "📰 journald (max ${JOURNALD_MAX})..."
    BEFORE=$(journalctl --disk-usage 2>/dev/null | cut -d' ' -f7-)
    if $DRY_RUN; then
        echo "   Would set SystemMaxUse=${JOURNALD_MAX}, vacuum retention=${LOG_RETENTION}d"
    else
        journalctl --vacuum-time="${LOG_RETENTION}days" 2>/dev/null || true
        # Set max disk usage in config
        if ! grep -q "SystemMaxUse=" /etc/systemd/journald.conf 2>/dev/null; then
            echo "SystemMaxUse=${JOURNALD_MAX}" | sudo tee -a /etc/systemd/journald.conf >/dev/null 2>&1 || true
        fi
        AFTER=$(journalctl --disk-usage 2>/dev/null | cut -d' ' -f7-)
        echo "   ${BEFORE} → ${AFTER}"
    fi
else
    echo "📰 journald: skipped (no root access)"
fi

# ── Docker logs ────────────────────────────────────────────
if command -v docker &>/dev/null; then
    echo "🐳 Docker logs..."
    if $DRY_RUN; then
        echo "   Would run: docker system prune -f --filter 'until=${LOG_RETENTION}d'"
    else
        # Clean exited containers (which hold onto logs)
        docker container prune -f --filter "until=${LOG_RETENTION}h" 2>/dev/null || true
        echo "   Pruned containers older than ${LOG_RETENTION}h"
    fi
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "📊 Disk after rotation:"
df -h / /var 2>/dev/null | grep -v '^tmpfs'

echo ""
if $DRY_RUN; then
    echo "⚠️  DRY RUN complete — run without --dry-run to apply"
else
    echo "✅ Log rotation complete"
fi
