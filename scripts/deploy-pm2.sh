#!/bin/bash
# ============================================================
# Deploy via PM2 — git pull + install + restart
# Usage: bash deploy-pm2.sh <app-name> [branch]
# ============================================================
APP="${1:?Usage: deploy-pm2.sh <app-name> [branch]}"
BRANCH="${2:-main}"
APP_DIR="${PM2_APP_DIR:-/home/deploy-app/apps/$APP}"

echo "🚀 Deploying $APP ($BRANCH) — $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$APP_DIR" || { echo "❌ Directory not found: $APP_DIR"; exit 1; }

echo "📥 git pull origin $BRANCH..."
git pull origin "$BRANCH" || { echo "❌ git pull failed"; exit 1; }

if [[ -f "package.json" ]]; then
    echo "📦 npm install..."
    npm install --production || { echo "❌ npm install failed"; exit 1; }
    if grep -q '"build"' package.json 2>/dev/null; then
        echo "🏗️  npm run build..."
        npm run build || { echo "❌ build failed"; exit 1; }
    fi
fi

echo "🔄 pm2 restart $APP..."
pm2 restart "$APP" || { echo "❌ pm2 restart failed"; exit 1; }

echo "💾 pm2 save..."
pm2 save

echo ""
echo "✅ Deploy complete — $APP"
pm2 show "$APP" 2>/dev/null | grep -E 'status|uptime|cpu|memory'
