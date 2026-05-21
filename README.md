# 🛠️ DevOps Workflow Templates

Production-ready DevOps/SRE workflow templates for [Hermes Agent](https://github.com/nousresearch/hermes-agent). Scripts, cronjobs, webhooks, and Docker configs — copy, customize, deploy.

```
📁 devops-workflow/
├── scripts/          ← Bash/Python automation scripts
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
**File:** `cronjobs/ssl-check.md`  
Checks SSL cert expiry for configured domains, alerts when < 30 days remaining.

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
