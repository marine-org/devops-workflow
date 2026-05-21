# Webhook Templates for Hermes Agent

These are prompt templates for `hermes webhook` subscriptions.
Substitute `<placeholders>` and run via Hermes CLI.

---

## 🚀 Deploy on Push

Triggers deployment when code is pushed to a specific branch.

```yaml
webhook: deploy-on-push
trigger: GitHub push event
filter:
  repo: marine-org/<repo-name>
  branch: main

prompt: |
  Deploy <project-name> to production.

  1. cd ~/apps/<project-name>
  2. git pull origin main
  3. Run install: <install-command>
  4. Run build if needed: <build-command>
  5. Restart service: pm2 restart <app-name>
  6. Verify: curl -s http://localhost:<port>/health

  Report results in Thai. On failure, escalate immediately.
```

**Usage:**
```bash
hermes webhook create \
  --name "Deploy <project>" \
  --source github \
  --repo marine-org/<repo> \
  --events push \
  --prompt-file webhooks/deploy.yml
```

---

## 🔔 Incident Response (AlertManager / Grafana)

Receives alerts and auto-creates GitHub issues with diagnostic context.

```yaml
webhook: incident-response
trigger: AlertManager webhook

prompt: |
  An incident alert was received. Triage immediately.

  Alert payload is in context. Do the following:

  1. **Parse severity**: critical (>5 services down) vs warning
  2. **Run diagnostics**:
     - pm2 list (check services)
     - df -h / && free -h (system health)
     - docker ps -a (container status)
     - tail -100 /var/log/nginx/error.log (recent errors)
  3. **Create GitHub issue** on marine-org/<repo>:
     - Title: "[INC] <alert name> — <timestamp>"
     - Labels: incident, <severity>
     - Body: alert details + diagnostic output
  4. **Notify**: summarize in Thai, include issue link

  For critical alerts: also run `pm2 resurrect` as first aid.
```

**Usage:**
```bash
hermes webhook create \
  --name "Incident Response" \
  --source alertmanager \
  --prompt-file webhooks/incident.yml
```

---

## 📊 Grafana Dashboard Snapshot (weekly)

```yaml
webhook: weekly-metrics
trigger: cron (Monday 9am)

prompt: |
  Generate weekly infrastructure summary.

  1. Check all PM2 services: pm2 list
  2. Check system: df -h / && free -h && uptime
  3. Check Docker: docker ps -a && docker system df
  4. Summarize trends vs last week (check session history)
  5. Flag any resources trending toward thresholds

  Output as concise briefing in Thai. Include recommendations.
```

---

## 🔌 Webhook Setup Reference

| Source | Hermes Command |
|--------|---------------|
| GitHub | `hermes webhook create --source github --repo <org/repo> --events push` |
| AlertManager | `hermes webhook create --source alertmanager` |
| Grafana | Point Grafana alert channel to Hermes webhook URL |
| Generic HTTP | `hermes webhook create --source http` |
