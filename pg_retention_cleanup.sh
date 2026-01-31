#!/bin/bash

set -euo pipefail

# =====================================================
# PostgreSQL Backup Retention Script (Production-Safe)
# CRITICAL: This script ONLY deletes from allowed directory
# =====================================================

# -----------------------------
# Configuration
# -----------------------------
# ALLOWED BACKUP DIRECTORY - This is the ONLY directory where deletions are permitted
ALLOWED_BASE="/home/arffy/arffy_db_bkups/odoo_18_warehouse"
BASE_DIR="${ALLOWED_BASE}"

# Retention settings
# For PRODUCTION: Use RETENTION_UNIT="days" and RETENTION_PERIOD=10
# For TESTING: Use RETENTION_UNIT="minutes" and RETENTION_PERIOD=20
RETENTION_UNIT="days"       # "days" or "minutes"
RETENTION_PERIOD=10         # Number of days/minutes to keep

# Safety Guards
RETENTION_ENABLED="true"    # Master kill-switch (true/false)
DRY_RUN="false"            # If true, identifies what to delete but makes no changes

# Logging
LOG_FILE="${BASE_DIR}/backup.log"
CLEANUP_LOG="${BASE_DIR}/retention_cleanup.log"

# -----------------------------
# SAFETY VALIDATIONS (CRITICAL - DO NOT REMOVE)
# -----------------------------

# 0. Ensure realpath command exists (cron-safe)
command -v realpath >/dev/null 2>&1 || {
  echo "[FATAL] realpath command not found. Aborting." >&2
  exit 1
}

# 1. Check if BASE_DIR is empty or unset
if [ -z "${BASE_DIR}" ]; then
  echo "[FATAL] BASE_DIR is empty. Aborting retention cleanup." >&2
  exit 1
fi

# 2. Check if BASE_DIR is root directory (CRITICAL SAFETY)
if [ "${BASE_DIR}" = "/" ] || [ "${BASE_DIR}" = "/home" ] || [ "${BASE_DIR}" = "/home/arffy" ]; then
  echo "[FATAL] BASE_DIR is a system directory: ${BASE_DIR}. This is UNSAFE. Aborting." >&2
  exit 1
fi

# 3. Check if BASE_DIR exists
if [ ! -d "${BASE_DIR}" ]; then
  echo "[FATAL] BASE_DIR does not exist: ${BASE_DIR}. Aborting." >&2
  exit 1
fi

# 4. Verify BASE_DIR matches ALLOWED_BASE (CRITICAL)
REAL_BASE=$(realpath "${BASE_DIR}")
REAL_ALLOWED=$(realpath "${ALLOWED_BASE}")

if [ "${REAL_BASE}" != "${REAL_ALLOWED}" ]; then
  echo "[FATAL] BASE_DIR does not match ALLOWED_BASE." >&2
  echo "  Expected: ${REAL_ALLOWED}" >&2
  echo "  Got:      ${REAL_BASE}" >&2
  echo "  Aborting to prevent accidental deletion." >&2
  exit 1
fi

echo "[SAFETY] All safety checks passed. Allowed directory: ${REAL_BASE}"

# -----------------------------
# Logging helper functions
# -----------------------------
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RETENTION] $1" | tee -a "${LOG_FILE}" "${CLEANUP_LOG}"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RETENTION-SUCCESS] $1" | tee -a "${LOG_FILE}" "${CLEANUP_LOG}"
}

# -----------------------------
# Calculate target date/time based on retention unit
# -----------------------------
log_info "Starting retention cleanup"
log_info "Config: Unit=${RETENTION_UNIT} | Period=${RETENTION_PERIOD} | Enabled=${RETENTION_ENABLED} | DryRun=${DRY_RUN}"

# Master Kill-switch Check
if [ "${RETENTION_ENABLED}" != "true" ]; then
    log_info "Retention cleanup is currently DISABLED via kill-switch. Exiting."
    exit 0
fi

# Unit Validation
if [ "${RETENTION_UNIT}" != "minutes" ] && [ "${RETENTION_UNIT}" != "days" ]; then
    log_info "[FATAL] Invalid RETENTION_UNIT: ${RETENTION_UNIT}. Must be 'minutes' or 'days'." >&2
    exit 1
fi

if [ "${RETENTION_UNIT}" = "minutes" ]; then
    # For testing: Delete backups older than X minutes
    DELETE_MINUTES=$((RETENTION_PERIOD + 1))
    CUTOFF_TIME=$(date -d "${DELETE_MINUTES} minutes ago" +"%Y-%m-%d %H:%M:%S")
    CUTOFF_EPOCH=$(date -d "${DELETE_MINUTES} minutes ago" +"%s")
    
    log_info "Testing mode: Identifying backups older than ${DELETE_MINUTES} minutes"
    log_info "Cutoff time: ${CUTOFF_TIME}"
    
    # Find and delete old backup files by timestamp
    DELETED_COUNT=0
    while read -r backup_file; do
        FILE_EPOCH=$(stat -c %Y "$backup_file")
        if [ ${FILE_EPOCH} -lt ${CUTOFF_EPOCH} ]; then
            FILE_TIME=$(date -d "@${FILE_EPOCH}" +"%Y-%m-%d %H:%M:%S")
            FILE_SIZE=$(du -h "$backup_file" | cut -f1)
            
            if [ "${DRY_RUN}" = "true" ]; then
                log_info "[DRY-RUN] Would delete: $(basename "$backup_file") | Created: ${FILE_TIME} | Size: ${FILE_SIZE}"
            else
                rm -f "$backup_file"
                log_info "Deleted: $(basename "$backup_file") | Created: ${FILE_TIME} | Size: ${FILE_SIZE}"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            fi
        fi
    done < <(find "${BASE_DIR}" -type f -name "*.backup")
    
    if [ "${DRY_RUN}" = "true" ]; then
        log_success "[DRY-RUN] Completed. Would have deleted ${DELETED_COUNT} backup file(s)."
    else
        log_success "Testing mode cleanup: Deleted ${DELETED_COUNT} backup file(s)"
    fi
    
    # Clean up empty directories
    if [ "${DRY_RUN}" = "true" ]; then
        log_info "[DRY-RUN] Would cleanup empty directories."
    else
        find "${BASE_DIR}" -type d -empty -delete 2>/dev/null
    fi
    
else
    # For production: Delete backups by day folders
    DELETE_DAYS=$((RETENTION_PERIOD + 1))
    TARGET_DATE=$(date -d "${DELETE_DAYS} days ago" +"%Y-%m-%d")
    TARGET_DIR="${BASE_DIR}/${TARGET_DATE}"
    
    log_info "Production mode: Keep ${RETENTION_PERIOD} days, target folder: ${TARGET_DATE} (${DELETE_DAYS} days old)"
    
    if [ -d "${TARGET_DIR}" ]; then
        FILE_COUNT=$(find "${TARGET_DIR}" -type f -name "*.backup" | wc -l)
        TOTAL_SIZE=$(du -sh "${TARGET_DIR}" 2>/dev/null | cut -f1)
        
        if [ "${DRY_RUN}" = "true" ]; then
            log_info "[DRY-RUN] Would delete folder: ${TARGET_DIR} | Files: ${FILE_COUNT} | Size: ${TOTAL_SIZE}"
        else
            log_info "Found folder: ${TARGET_DIR} | Files: ${FILE_COUNT} | Size: ${TOTAL_SIZE}"
            # Delete all backup files in that day's folder
            find "${TARGET_DIR}" -type f -name "*.backup" -delete
            # Remove the empty directory
            rmdir "${TARGET_DIR}" 2>/dev/null
            log_success "Deleted ${FILE_COUNT} backup files from ${TARGET_DATE} | Freed: ${TOTAL_SIZE}"
        fi
    else
        log_info "No folder found for ${TARGET_DATE} - nothing to delete"
    fi
    
    # Cleanup empty directories (safety)
    if [ "${DRY_RUN}" = "true" ]; then
        log_info "[DRY-RUN] Would cleanup empty directories."
    else
        find "${BASE_DIR}" -type d -empty -delete 2>/dev/null
    fi
fi



log_info "Retention cleanup completed"
log_info "=========================================="
