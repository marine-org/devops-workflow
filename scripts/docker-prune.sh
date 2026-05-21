#!/bin/bash
# ============================================================
# Docker Prune — safe cleanup of unused Docker resources
# Schedule: weekly cronjob
# ============================================================
set -e

echo "🧹 Docker Prune — $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show before state
echo "📦 Before:"
docker system df 2>/dev/null | head -5
echo ""

# Prune stopped containers older than 24h
STOPPED=$(docker container prune -f --filter "until=24h" 2>/dev/null)
echo "🗑️  Containers: $STOPPED"

# Prune dangling images
DANGLING=$(docker image prune -f 2>/dev/null)
echo "🖼️  Images: $DANGLING"

# Prune unused volumes (careful!)
VOLUMES=$(docker volume prune -f 2>/dev/null)
echo "💾 Volumes: $VOLUMES"

# Prune build cache
BUILD=$(docker builder prune -f --filter "until=72h" 2>/dev/null)
echo "🏗️  Build cache: $BUILD"

echo ""
echo "📦 After:"
docker system df 2>/dev/null | head -5

RECLAIMED=$(docker system df 2>/dev/null | awk 'NR==2 {print $4}')
echo ""
echo "✅ Done — reclaimed: $RECLAIMED"
