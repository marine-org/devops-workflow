#!/bin/bash
# ============================================================
# SRE Watchdog — silent when healthy, alerts only on issues
# Runs as cronjob with no_agent=true (script-only, zero tokens)
# ============================================================
ALERTS=0
report() { echo "🔴 $*"; ALERTS=$((ALERTS + 1)); }

# ── PM2 Service Health ─────────────────────────────────────
while IFS='│' read -r id name namespace version mode pid uptime restarts status cpu mem user watching; do
    id=$(echo "$id" | xargs)
    name=$(echo "$name" | xargs)
    status=$(echo "$status" | xargs)
    restarts=$(echo "$restarts" | xargs)
    # Skip header/separator lines
    [[ "$id" =~ ^(id|├|└|$) ]] && continue
    [[ "$status" != "online" ]] && report "PM2: $name is $status"
    [[ "$restarts" != "0" && "$restarts" =~ ^[0-9]+$ && "$restarts" -gt 3 ]] && report "PM2: $name restarted $restarts times"
done < <(pm2 list 2>/dev/null | grep '│')

# ── Disk Usage ─────────────────────────────────────────────
DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
[[ "$DISK_PCT" -ge 80 ]] && report "Disk: ${DISK_PCT}% used ($(df -h / | awk 'NR==2 {print $3"/"$2}'))"
[[ "$DISK_PCT" -ge 90 ]] && report "🚨 DISK CRITICAL: ${DISK_PCT}% — immediate cleanup needed!"

# ── Memory ─────────────────────────────────────────────────
MEM_AVAIL_MB=$(free -m | awk 'NR==2 {print $7}')
[[ "$MEM_AVAIL_MB" -lt 500 ]] && report "Memory: only ${MEM_AVAIL_MB}MB available (of $(free -m | awk 'NR==2 {print $2}')MB)"
[[ "$MEM_AVAIL_MB" -lt 200 ]] && report "🚨 MEMORY CRITICAL: ${MEM_AVAIL_MB}MB — OOM risk!"

# ── Docker Containers ──────────────────────────────────────
if command -v docker &>/dev/null; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
        [[ "$status" != Up* ]] && report "Docker: $name is $status"
    done < <(docker ps -a --format '{{.Names}} {{.Status}}' 2>/dev/null | grep -v '^$')
fi

# ── Key Ports ──────────────────────────────────────────────
for port in 3000 3001 3456 5188 47778; do
    ss -tlnp 2>/dev/null | grep -q ":$port " || report "Port: $port is NOT listening"
done

# ── Load Average ───────────────────────────────────────────
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
CORES=$(nproc)
LOAD_INT=${LOAD%.*}
[[ "$LOAD_INT" -gt "$CORES" ]] && report "Load: $LOAD (cores: $CORES) — CPU saturated"

# ── Output —────────────────────────────────────────────────
if [[ "$ALERTS" -gt 0 ]]; then
    echo ""
    echo "📊 SRE Watchdog Report — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  $ALERTS alert(s) found"
    echo ""
    # Re-run PM2 list for context
    pm2 list 2>/dev/null | head -6
    echo ""
    echo "💾 Disk: $(df -h / | awk 'NR==2 {print $5 " (" $3 "/" $2 ")"}')"
    echo "🧠 Memory: $(free -h | awk 'NR==2 {print $3 "/" $2 " (avail: " $7 ")"}')"
fi
# Silent exit 0 when all good — cron deliver skips empty stdout
exit 0
