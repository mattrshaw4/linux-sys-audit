#!/usr/bin/env bash

# =============================================================================
# sys_audit.sh — System Health Audit Script
# Author: Matt Shaw | github.com/mattrshaw4
# Description: Triages the local machine the way you'd interrogate a sick EC2
#              instance at 2am. Covers filesystem, processes, networking, and
#              user/permission hygiene in one pass.
# Usage: bash sys_audit.sh
# =============================================================================

#--- Configuration -------------------------------------------------
LOG_DIR="$HOME/audit_logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/audit_$TIMESTAMP.log"

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helper Functions --------------------------------------------------------
print_header() {
    local title="$1"
    local line="============================================================"
    echo -e "\n${CYAN}${BOLD}${line}${RESET}"
    echo -e "${CYAN}${BOLD}  $title${RESET}"
    echo -e "${CYAN}${BOLD}${line}${RESET}"

    echo -e "\n${line}" >> "$LOG_FILE"
    echo "  $title" >> "$LOG_FILE"
    echo -e "${line}" >> "$LOG_FILE"
}

log() {
    echo -e "$@" | tee -a "$LOG_FILE"
}

# --- Domain 1: Filesystem ----------------------------------------------------
check_filesystem() {
    print_header "DOMAIN 1: FILESYSTEM"

    log "\n${BOLD}Disk usage by mount point:${RESET}"
    df -hT | tee -a "$LOG_FILE"

    log "\n${BOLD}Top 10 largest directories under /:${RESET}"
    du -sh /* 2>/dev/null | sort -rh | head -10 | tee -a "$LOG_FILE"

    log "\n${BOLD}/var/log size breakdown:${RESET}"
    du -sh /var/log/* 2>/dev/null | sort -rh | head -10 | tee -a "$LOG_FILE"
}

# --- Domain 2: Processes & Services ------------------------------------------
check_processes() {
    print_header "DOMAIN 2: PROCESSES & SERVICES"

    log "\n${BOLD}Top 10 processes by CPU:${RESET}"
    ps aux --sort=-%cpu | head -11 | tee -a "$LOG_FILE"

    log "\n${BOLD}Top 10 processes by memory:${RESET}"
    ps aux --sort=-%mem | head -11 | tee -a "$LOG_FILE"

    log "\n${BOLD}Failed systemd units:${RESET}"
    systemctl list-units --state=failed | tee -a "$LOG_FILE"
}

# --- Domain 3: Networking ----------------------------------------------------
check_networking() {
    print_header "DOMAIN 3: NETWORKING"

    log "\n${BOLD}Listening ports:${RESET}"
    ss -tuln | tee -a "$LOG_FILE"

    log "\n${BOLD}Routing table:${RESET}"
    ip route show | tee -a "$LOG_FILE"

    log "\n${BOLD}Network interfaces:${RESET}"
    ip addr show | tee -a "$LOG_FILE"
}

# --- Health Checks -----------------------------------------------------------
run_health_checks() {
    print_header "HEALTH CHECKS"
log "\n${BOLD}Checking disk usage thresholds:${RESET}"
    df -h --output=target,pcent | tail -n +2 | while read -r mount usage; do
        pct="${usage%%%}"
        if [ "$pct" -ge 80 ]; then
            log "${RED}[CRIT] $mount is at ${usage} — above 80% threshold${RESET}"
        elif [ "$pct" -ge 60 ]; then
            log "${YELLOW}[WARN] $mount is at ${usage} — watch this${RESET}"
        else
            log "${GREEN}[OK]   $mount is at ${usage}${RESET}"
        fi
    done
log "\n${BOLD}Checking for failed systemd units:${RESET}"
    failed=$(systemctl list-units --state=failed --no-legend | wc -l)
    if [ "$failed" -gt 0 ]; then
        log "${RED}[CRIT] $failed failed systemd unit(s) detected${RESET}"
        systemctl list-units --state=failed --no-legend | tee -a "$LOG_FILE"
    else
        log "${GREEN}[OK]   No failed systemd units${RESET}"
    fi
log "\n${BOLD}Checking for exposed ports:${RESET}"
    exposed=$(ss -tuln | grep LISTEN | awk '{print $5}' | grep -E '^0\.0\.0\.0:|^\*:' | grep -v '^127\.')
    if [ -n "$exposed" ]; then
        log "${YELLOW}[WARN] The following ports are exposed on all interfaces:${RESET}"
        echo "$exposed" | tee -a "$LOG_FILE"
    else
        log "${GREEN}[OK]   No unexpected ports exposed on all interfaces${RESET}"
    fi
log "\n${BOLD}Checking snap directory size:${RESET}"
    snap_size=$(du -sh /snap 2>/dev/null | cut -f1)
    snap_gb=$(du -sb /snap 2>/dev/null | cut -f1)
    snap_threshold=$((50 * 1024 * 1024 * 1024))
    if [ "$snap_gb" -ge "$snap_threshold" ]; then
        log "${YELLOW}[WARN] /snap is using ${snap_size} — consider pruning old snap revisions${RESET}"
    else
        log "${GREEN}[OK]   /snap is using ${snap_size}${RESET}"
    fi
}

# --- Domain 4: Users & Permissions -------------------------------------------
check_users() {
    print_header "DOMAIN 4: USERS & PERMISSIONS"

    log "\n${BOLD}Recent login history:${RESET}"
    last -n 15 | tee -a "$LOG_FILE"

    log "\n${BOLD}Last login per user:${RESET}"
    lastlog | tee -a "$LOG_FILE"

    log "\n${BOLD}Sudo privileges for current user:${RESET}"
    sudo -l 2>&1 | tee -a "$LOG_FILE"
}

# --- Main --------------------------------------------------------------------
main() {
    mkdir -p "$LOG_DIR"

    echo -e "${GREEN}${BOLD}"
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │         SYS AUDIT — STARTING            │"
    echo "  │  $(date)  │"
    echo "  └─────────────────────────────────────────┘"
    echo -e "${RESET}"

    echo "SYS AUDIT REPORT — $TIMESTAMP" >> "$LOG_FILE"
    echo "Host: $(hostname)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"

    check_filesystem
    check_processes
    check_networking
    check_users
    run_health_checks

    echo -e "\n${GREEN}${BOLD}Audit complete. Log saved to: ${LOG_FILE}${RESET}\n"
}

main
