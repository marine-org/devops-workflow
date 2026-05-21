# Cronjob Templates for Hermes Agent

Copy these snippets and run with `hermes cron create ...`.
Replace placeholders (`<...>`) with your values.

---

## SRE Watchdog (bash-only, zero tokens)

```bash
hermes cron create \
  --name "SRE Watchdog" \
  --script sre-watchdog.sh \
  --schedule "every 30m" \
  --no-agent \
  --deliver origin
```

**What it does:** Checks PM2, disk, memory, Docker, ports every 30 min.
Silent when healthy. Alerts only when something is wrong.
Zero LLM tokens — pure bash.

---

## HTTP Health Check

```bash
hermes cron create \
  --name "HTTP Health Check" \
  --script health-check.sh \
  --schedule "every 5m" \
  --no-agent \
  --deliver origin
```

Customize endpoints by editing `scripts/health-check.sh` or setting `HEALTH_CHECK_URLS` env var.

---

## Docker Weekly Prune

```bash
hermes cron create \
  --name "Docker Weekly Prune" \
  --script docker-prune.sh \
  --schedule "0 3 * * 0" \
  --no-agent \
  --deliver origin
```

Runs Sundays at 3am. Cleans stopped containers >24h, dangling images, unused volumes, build cache.

---

## Daily Status Report (LLM-powered)

```bash
hermes cron create \
  --name "Daily Status Report" \
  --schedule "30 8 * * *" \
  --deliver origin \
  --prompt "Generate a daily DevOps status report:
1. Check PM2 services: run 'pm2 list'
2. Check system health: run 'df -h / && free -h'
3. Check GitHub: list open PRs and recent issues for marine-org
4. Format as a clean morning briefing in Thai language
Keep it concise — one message."
```

Runs weekdays at 8:30am. Uses LLM to summarize everything into a human-readable briefing.

---

## SSL Certificate Monitor

```bash
hermes cron create \
  --name "SSL Certificate Monitor" \
  --script ssl-check.sh \
  --schedule "0 9 * * *" \
  --no-agent \
  --deliver origin
```

Checks SSL cert expiry daily at 9am. Alerts when < 30 days remain.

---

## Database Backup (daily)

```bash
hermes cron create \
  --name "DB Backup — MySQL" \
  --script db-backup.sh \
  --schedule "0 2 * * *" \
  --no-agent \
  --deliver origin
```

**Env vars to set on the machine:**
```bash
export MYSQL_HOST=localhost
export MYSQL_USER=backup
export MYSQL_PASSWORD=...
export S3_BACKUP_PATH=s3://my-bucket/backups
```

Then run with: `--s3` flag added to the script. Supports MySQL, PostgreSQL, MongoDB.
Daily at 2am with 7-day retention by default.

---

## Log Rotation (weekly)

```bash
hermes cron create \
  --name "Log Rotation" \
  --script log-rotation.sh \
  --schedule "0 4 * * 0" \
  --no-agent \
  --deliver origin
```

Runs Sundays at 4am. Cleans PM2 logs, app logs, journald, Docker container logs.
Customize with env vars: `MAX_LOG_SIZE`, `LOG_RETENTION`, `JOURNALD_MAX`, `PM2_LOG_RETENTION`.

**Test first:**
```bash
bash scripts/log-rotation.sh --dry-run
```

---

## K8s Deploy (webhook-triggered)

Not a cronjob — use as webhook action:

```bash
# Webhook prompt:
Deploy <app> to K8s namespace <namespace>:
bash scripts/deploy-k8s.sh <namespace> <app> --helm --tag=v1.2.3
```

Or schedule canary deployments:
```bash
hermes cron create \
  --name "K8s Canary Deploy" \
  --schedule "0 10 * * 1-5" \
  --deliver origin \
  --prompt "Run deploy-k8s.sh for staging namespace with latest tag. Report results."
```

---

## Custom: Any bash script

```bash
# 1. Write your script to ~/.hermes/scripts/my-check.sh
# 2. Schedule it:
hermes cron create \
  --name "Custom Check" \
  --script my-check.sh \
  --schedule "<cron expression>" \
  --no-agent \
  --deliver origin
```

**Rule:** Script outputs → delivered to user. Empty stdout → silent.
Non-zero exit → error alert delivered.
