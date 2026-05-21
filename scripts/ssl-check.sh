#!/bin/bash
# ============================================================
# SSL Certificate Expiry Check
# Usage: bash ssl-check.sh [domains_file]
# ============================================================
WARN_DAYS=30
ALERTS=0

# Default domains
DOMAINS=(
    "ipptt.com:443"
    "marine-org.github.io:443"
)

# Load from file if provided
if [[ -n "$1" && -f "$1" ]]; then
    mapfile -t DOMAINS < "$1"
fi

for entry in "${DOMAINS[@]}"; do
    [[ -z "$entry" || "$entry" =~ ^# ]] && continue
    domain="${entry%:*}"
    port="${entry##*:}"
    
    expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:$port" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [[ -z "$expiry" ]]; then
        echo "🔴 $domain — SSL check failed (connection error?)"
        ALERTS=$((ALERTS + 1))
        continue
    fi
    
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [[ "$days_left" -lt "$WARN_DAYS" ]]; then
        echo "🔴 $domain — SSL expires in $days_left days ($expiry)"
        ALERTS=$((ALERTS + 1))
    fi
done

if [[ "$ALERTS" -gt 0 ]]; then
    echo ""
    echo "🔐 SSL Certificate Check — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "⚠️  $ALERTS certificate(s) expiring soon"
fi
exit 0
