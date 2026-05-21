.PHONY: install test deploy clean

# ── Install scripts to Hermes ──────────────────────────────
HERMES_SCRIPTS := $(HOME)/.hermes/scripts

install:
	@echo "📋 Installing scripts to $(HERMES_SCRIPTS)..."
	@mkdir -p $(HERMES_SCRIPTS)
	cp scripts/*.sh $(HERMES_SCRIPTS)/
	chmod +x $(HERMES_SCRIPTS)/*.sh
	@echo "✅ Done — scripts installed (8):"
	@ls -1 $(HERMES_SCRIPTS)/*.sh

# ── Test all scripts ───────────────────────────────────────
test:
	@echo "🧪 Testing scripts..."
	@for script in scripts/*.sh; do \
		echo "━━━ $$script ━━━"; \
		bash "$$script" 2>&1 | head -20; \
		echo ""; \
	done
	@echo "✅ All scripts executed"

# ── Set up all cronjobs ────────────────────────────────────
cron-setup:
	@echo "⏰ Setting up cronjobs..."
	hermes cron create --name "SRE Watchdog" --script sre-watchdog.sh --schedule "every 30m" --no-agent --deliver origin
	hermes cron create --name "HTTP Health Check" --script health-check.sh --schedule "every 5m" --no-agent --deliver origin
	hermes cron create --name "Docker Weekly Prune" --script docker-prune.sh --schedule "0 3 * * 0" --no-agent --deliver origin
	hermes cron create --name "SSL Check" --script ssl-check.sh --schedule "0 9 * * *" --no-agent --deliver origin
	hermes cron create --name "DB Backup" --script db-backup.sh --schedule "0 2 * * *" --no-agent --deliver origin
	hermes cron create --name "Log Rotation" --script log-rotation.sh --schedule "0 4 * * 0" --no-agent --deliver origin
	@echo "✅ All 6 cronjobs created"

# ── Show cronjob status ────────────────────────────────────
cron-list:
	hermes cron list

# ── Deploy monitoring stack ────────────────────────────────
monitor-up:
	docker compose -f docker/docker-compose.monitor.yml up -d

monitor-down:
	docker compose -f docker/docker-compose.monitor.yml down

# ── Run watchdog once ──────────────────────────────────────
watch:
	bash scripts/sre-watchdog.sh

# ── Clean up ───────────────────────────────────────────────
clean:
	@echo "🧹 Cleaning..."
	rm -f $(HERMES_SCRIPTS)/sre-watchdog.sh
	rm -f $(HERMES_SCRIPTS)/health-check.sh
	rm -f $(HERMES_SCRIPTS)/docker-prune.sh
	rm -f $(HERMES_SCRIPTS)/ssl-check.sh
	rm -f $(HERMES_SCRIPTS)/deploy-pm2.sh
	rm -f $(HERMES_SCRIPTS)/deploy-k8s.sh
	rm -f $(HERMES_SCRIPTS)/db-backup.sh
	rm -f $(HERMES_SCRIPTS)/log-rotation.sh
	@echo "✅ Cleaned"
