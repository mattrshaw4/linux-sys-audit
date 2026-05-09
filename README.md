# linux-sys-audit

A four-domain Linux system health audit script built for the kind of triage you'd do at 2am when a server is misbehaving.

Covers filesystem, processes, networking, and user/permission hygiene in a single pass — reports raw system state, evaluates it against real thresholds, flags issues, and saves a timestamped log every run. Phase 3 automates it with a native systemd timer so it runs every hour without you touching it.

Built as a learning project to reinforce Linux fundamentals across all four domains a DevOps engineer interacts with daily.

---

## What It Does

### Phase 1 — Audit
Runs four domain checks and saves output to `~/audit_logs/audit_YYYY-MM-DD_HH-MM-SS.log`:

| Domain | What Gets Checked |
|--------|------------------|
| Filesystem | Disk usage by mount point, top 10 largest directories, `/var/log` breakdown |
| Processes & Services | Top CPU/memory consumers, failed systemd units |
| Networking | Listening ports, routing table, network interfaces |
| Users & Permissions | Recent login history, per-user last login, sudo privileges |

### Phase 2 — Health Checks
Evaluates output against real thresholds and flags issues:

| Check | Threshold | Flag |
|-------|-----------|------|
| Disk usage | ≥ 80% on any mount | `[CRIT]` |
| Disk usage | ≥ 60% on any mount | `[WARN]` |
| Failed systemd units | Any | `[CRIT]` |
| Exposed ports | Bound to `0.0.0.0` or `*` | `[WARN]` |
| Snap directory | ≥ 50G | `[WARN]` |

### Phase 3 — Automation
A systemd timer runs the audit automatically every hour, persistent across reboots.

---

## Real Results From My Machine

Running this script against my own Ubuntu Pro laptop caught two real issues:

**Port 3000** — Open WebUI (local Ollama front end) was bound to `0.0.0.0`, exposing it to my entire local network. Fixed by rebinding to `127.0.0.1:3000`.

**Port 80** — Apache2 was running and enabled on boot with nothing actually serving from it. Stopped and disabled.

**Snap bloat** — `/snap` was at 54G from accumulated disabled revisions across 30+ packages. Cleaned to 30G by removing old revisions.

The script caught all three. The fixes took about 10 minutes.

---

## Usage

### Run the audit manually

```bash
chmod +x sys_audit.sh
bash sys_audit.sh
```

Output goes to your terminal with color-coded section headers. A plain-text log is saved to `~/audit_logs/` automatically.

### View the latest log

```bash
cat ~/audit_logs/$(ls -t ~/audit_logs | head -1)
```

### View health checks only

```bash
grep -A 30 "HEALTH CHECKS" ~/audit_logs/$(ls -t ~/audit_logs | head -1)
```

---

## Automate With systemd (Phase 3)

Create the service file:

```bash
sudo nano /etc/systemd/system/sys-audit.service
```

```ini
[Unit]
Description=System Health Audit
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/<your-user>/sys_audit.sh
User=<your-user>

[Install]
WantedBy=multi-user.target
```

Create the timer file:

```bash
sudo nano /etc/systemd/system/sys-audit.timer
```

```ini
[Unit]
Description=Run System Health Audit every hour

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sys-audit.timer
systemctl status sys-audit.timer
```

---

## Skills Covered

- Bash scripting — functions, variables, pipelines, arithmetic, string manipulation
- Linux filesystem — `df`, `du`, mount points, superblocks, inode concepts
- Process management — `ps`, `systemctl`, systemd unit states
- Networking — `ss`, `ip route`, interface inspection, port exposure analysis
- Users & permissions — `last`, `lastlog`, sudo scope auditing
- systemd timers — `Type=oneshot`, `Persistent=true`, timer unit anatomy

---

## Author

Matt Shaw — Cloud DevOps Engineer in transition from 20+ years in food service.  
Turns out kitchens and servers fail the same way. You just use different tools to fix them.

[GitHub](https://github.com/mattrshaw4) · [Medium](https://medium.com/@matt.r.shaw4) · [Newsletter — Terraforming My Career](https://medium.com/@matt.r.shaw4)
