#!/bin/bash
# ============================================================
# HTTP Health Check — poll endpoints, report non-200 responses
# Usage: bash health-check.sh [endpoints_file]
# ============================================================
TIMEOUT=10
ALERTS=0

# Default endpoints — override via file or env var
ENDPOINTS=(
    "http://localhost:3000/health"
    "http://localhost:3001/health"
)

# Load from file if provided
if [[ -n "$1" && -f "$1" ]]; then
    mapfile -t ENDPOINTS < "$1"
fi

# Or from env var (comma-separated)
if [[ -n "$HEALTH_CHECK_URLS" ]]; then
    IFS=',' read -ra ENDPOINTS <<< "$HEALTH_CHECK_URLS"
fi

for url in "${ENDPOINTS[@]}"; do
    [[ -z "$url" || "$url" =~ ^# ]] && continue
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null)
    if [[ "$code" != "200" ]]; then
        echo "🔴 $url → HTTP $code"
        ALERTS=$((ALERTS + 1))
    fi
done

if [[ "$ALERTS" -gt 0 ]]; then
    echo ""
    echo "🏥 Health Check — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "⚠️  $ALERTS endpoint(s) unhealthy"
fi
exit 0
