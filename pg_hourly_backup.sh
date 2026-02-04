#!/bin/bash

# =====================================================
# PostgreSQL Hourly Backup Script (Production-Safe)
# Database: govt | Format: Custom | Lightweight
# =====================================================


# -----------------------------
# Load Configuration
# -----------------------------
CONFIG_FILE="$(dirname "$0")/backup.config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Configuration file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# -----------------------------
# Validate Essential Config
# -----------------------------
: "${PROJECT_PREFIX:?PROJECT_PREFIX must be set in config}"
: "${BASE_DIR:?BASE_DIR must be set in config}"
: "${PG_DB:?PG_DB must be set in config}"
: "${PG_USER:?PG_USER must be set in config}"

# -----------------------------
# Derived Paths & Timestamps
# -----------------------------
# Date & Time formatting
DATE_DIR=$(date +"%Y-%m-%d")                    # 2026-01-31
TIME_STAMP=$(date +"%Y-%m-%d_%H-%M-%S")          # 2026-01-31_16-07-11

BACKUP_DIR="${BASE_DIR}/${DATE_DIR}"
TMP_FILE="${BACKUP_DIR}/.${PROJECT_PREFIX}-${TIME_STAMP}.tmp"
FINAL_FILE="${BACKUP_DIR}/${PROJECT_PREFIX}-${TIME_STAMP}.backup"

# Logging
LOG_FILE="${BASE_DIR}/backup.log"
ERROR_LOG="${BASE_DIR}/backup_errors.log"

# Export PGPASSFILE so pg_dump can find it
export PGPASSFILE="${PGPASS_FILE}"

# -----------------------------
# Logging helper functions
# -----------------------------
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${LOG_FILE}" "${ERROR_LOG}"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "${LOG_FILE}"
}

# -----------------------------
# Ensure directory exists
# -----------------------------
mkdir -p "${BACKUP_DIR}"

log_info "Starting backup for database: ${PG_DB}"
log_info "Backup destination: ${FINAL_FILE}"

# -----------------------------
# Run backup (atomic)
# -----------------------------
pg_dump \
  --host="${PG_HOST}" \
  --port="${PG_PORT}" \
  --username="${PG_USER}" \
  --format=custom \
  --file="${TMP_FILE}" \
  --no-owner \
  --no-acl \
  "${PG_DB}" 2>> "${ERROR_LOG}"

DUMP_EXIT_CODE=$?

# -----------------------------
# Validate & finalize
# -----------------------------
if [ ${DUMP_EXIT_CODE} -eq 0 ] && [ -s "${TMP_FILE}" ]; then
    mv "${TMP_FILE}" "${FINAL_FILE}"
    FILE_SIZE=$(du -h "${FINAL_FILE}" | cut -f1)
    log_success "Backup completed successfully | Size: ${FILE_SIZE} | File: ${FINAL_FILE}"
else
    rm -f "${TMP_FILE}"
    log_error "Backup FAILED | Exit code: ${DUMP_EXIT_CODE} | Check ${ERROR_LOG} for details"
    exit 1
fi


log_info "=========================================="
