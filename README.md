# 🛠️ DevOps Workflow Templates

Production-ready DevOps/SRE workflow templates for [Hermes Agent](https://github.com/nousresearch/hermes-agent). Scripts, cronjobs, webhooks, and Docker configs — copy, customize, deploy.

```
📁 devops-workflow/
├── scripts/          ← Bash automation scripts (8 scripts)
├── cronjobs/         ← Hermes cronjob config templates
├── webhooks/         ← Webhook handler templates (incident, deploy)
├── docker/           ← Docker Compose + Dockerfiles
└── .github/          ← CI/CD workflows
```

---

## ⚡ Quickstart

### 1. Clone this repo onto your server
```bash
git clone https://github.com/marine-org/devops-workflow.git
cp devops-workflow/scripts/* ~/.hermes/scripts/
```

### 2. Set up SRE Watchdog (30s)
```bash
# Customize thresholds for your machine
vim ~/.hermes/scripts/sre-watchdog.sh

# Create the cronjob (silent when healthy, alerts on issues)
hermes cron create \
  --name "SRE Watchdog" \
  --script sre-watchdog.sh \
  --schedule "every 30m" \
  --no-agent \
  --deliver origin
```

### 3. Monitor — it just works
- ✅ All green → silent, no noise
- 🔴 Issue detected → alert delivered to your chat

---

## 📦 Workflow Catalog

| Workflow | Type | Use Case |
|----------|------|----------|
| [SRE Watchdog](#sre-watchdog) | `cron + bash` | PM2, disk, memory, Docker, ports health check |
| [HTTP Health Check](#http-health-check) | `script` | Poll endpoints, alert on non-200 |
| [Docker Prune](#docker-prune) | `script` | Clean up unused images/volumes on schedule |
| [Deploy Pipeline](#deploy-pipeline) | `webhook` | Git push → auto deploy Vercel / PM2 |
| [Incident Response](#incident-response) | `webhook` | AlertManager/Grafana → auto-triage + GitHub issue |
| [Daily Status Report](#daily-status-report) | `cron + LLM` | Morning summary of PRs, issues, service status |
| [SSL Certificate Monitor](#ssl-certificate-monitor) | `cron + bash` | Check cert expiry, alert < 30 days |
| [K8s Deploy](#k8s-deploy) | `script` | kubectl apply / Helm upgrade + rollout watch |
| [Database Backup](#database-backup) | `cron + bash` | MySQL/PostgreSQL/Mongo dump + S3 upload |
| [Log Rotation](#log-rotation) | `cron + bash` | PM2, app logs, journald, Docker log cleanup |

---

## 🔧 Workflows In Detail

### SRE Watchdog
**File:** `scripts/sre-watchdog.sh`  
**Schedule:** every 30m (adjustable)  
**Mode:** `no_agent=true` (bash-only, zero LLM tokens)

Monitors:
- PM2 service status & restart count
- Disk usage (≥80% warn, ≥90% critical)
- Memory available (<500MB warn, <200MB critical)
- Docker container status
- Key port availability
- CPU load average

```bash
# Add custom port checks — edit the for loop
for port in 3000 3001 8080 9090; do
    ss -tlnp | grep -q ":$port " || report "Port: $port down"
done
```

### HTTP Health Check
**File:** `scripts/health-check.sh`  
Polls a list of endpoints and reports any non-200 responses.

```bash
# Customize endpoints
ENDPOINTS=(
    "https://api.example.com/health"
    "https://app.example.com/ping"
)
```

### Docker Prune
**File:** `scripts/docker-prune.sh`  
Weekly cleanup of dangling images, stopped containers, unused volumes. Safe — only removes unused resources.

### Deploy Pipeline
**File:** `webhooks/deploy.yml`  
Triggers on Git push webhook → runs deploy script for the matching project.

### Incident Response
**File:** `webhooks/incident.yml`  
Receives AlertManager/Grafana webhook → creates GitHub issue with diagnostic context → alerts on Telegram.

### Daily Status Report
**File:** `cronjobs/daily-report.md`  
LLM-powered morning briefing: pulls open PRs, recent issues, PM2 status, and system health into a single digest.

### SSL Certificate Monitor
**File:** `scripts/ssl-check.sh`  
Checks SSL cert expiry for configured domains, alerts when < 30 days remaining.

### K8s Deploy
**File:** `scripts/deploy-k8s.sh`  
kubectl apply or Helm upgrade with rollout status watching. Supports `--dry-run`, `--tag`, and `--timeout`.

```bash
# kubectl mode
bash scripts/deploy-k8s.sh production my-app

# Helm mode with version tag
bash scripts/deploy-k8s.sh staging my-app --helm --tag=v1.2.3

# Dry run (verify before deploying)
bash scripts/deploy-k8s.sh production my-app --helm --dry-run
```

### Database Backup
**File:** `scripts/db-backup.sh`  
Dump + compress + upload to S3. Supports MySQL, PostgreSQL, MongoDB. Auto-retention cleanup.

```bash
# Local backup (default)
bash scripts/db-backup.sh mysql mydb

# With S3 upload
bash scripts/db-backup.sh postgres mydb --s3

# Custom retention (30 days)
bash scripts/db-backup.sh mongo mydb --s3 --retention=30
```

**Env vars:** `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, `POSTGRES_PASSWORD`, `MONGO_URI`, `S3_BACKUP_PATH`, `BACKUP_RETENTION`

### Log Rotation
**File:** `scripts/log-rotation.sh`  
Rotates PM2 logs, app logs, journald, and Docker container logs. Safe defaults — test with `--dry-run` first.

```bash
# Dry run (see what would be deleted)
bash scripts/log-rotation.sh --dry-run

# Execute rotation
bash scripts/log-rotation.sh
```

**Env vars:** `MAX_LOG_SIZE` (default 100M), `LOG_RETENTION` (default 14d), `JOURNALD_MAX` (default 500M), `PM2_LOG_RETENTION` (default 7d)

---

## 🔩 Customization

Every script uses environment variables or inline config blocks for thresholds. No hardcoded values you can't change:

```bash
# sre-watchdog.sh custom thresholds
DISK_WARN=80      # percentage
DISK_CRIT=90
MEM_WARN=500      # MB
MEM_CRIT=200
```

---

## 📋 Requirements

- **Hermes Agent** — for cronjob scheduling and delivery
- **PM2** — optional, for service monitoring
- **Docker** — optional, for container monitoring
- **kubectl / Helm** — optional, for K8s deployments
- **mysqldump / pg_dump / mongodump** — optional, for DB backups
- **AWS CLI or rclone** — optional, for S3 backup uploads
- **GitHub CLI (`gh`)** — optional, for incident auto-issue creation

---

## 🤝 Contributing

Add your own workflow templates! PRs welcome for:
- New monitoring scripts
- Platform-specific deploy scripts (K8s, AWS, GCP)
- Incident runbooks
- Dashboard/config templates

---

## 📄 License

MIT — use freely, modify, share.
