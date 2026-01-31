# PostgreSQL Backup Script - Line by Line Explanation

This document explains every line of `pg_hourly_backup.sh` and why each part is necessary.

---

## Script Header

```bash
#!/bin/bash
```

**Why:** Tells the system to use Bash shell to execute this script. Required for all shell scripts.

---

## PostgreSQL Configuration

```bash
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="postgres"
PG_DB="govt"
```

**Why:**

- `PG_HOST`: Database server location (localhost = same machine)
- `PG_PORT`: Default PostgreSQL port
- `PG_USER`: Database user with backup privileges
- `PG_DB`: Target database to backup

**Why centralize:** Easy to change if database details change. One place to update.

---

## Backup Directory Configuration

```bash
BASE_DIR="/home/arffy/cproj/vistar/odoo_prod_warehouse"
```

**Why:** Root directory where all backups are stored. Keeps backups organized in one location.

---

## Date & Time Formatting

```bash
DATE_DIR=$(date +"%Y-%m-%d")                    # 2026-01-31
TIME_STAMP=$(date +"%Y-%m-%d_%H-%M-%S")          # 2026-01-31_16-07-11
```

**Why DATE_DIR:**

- Groups backups by day (ISO format: `2026-01-31`)
- Standard format makes it easier to sort folders by name
- Format: Year-Month-Day

**Why TIME_STAMP:**

- Identifies exact backup day and time
- Full timestamp format for absolute sorting
- Format: `2026-01-31_15-30-00` (YYYY-MM-DD_HH-MM-SS)

**Why this matters:**

- 24 backups per day = 24 restore points per day
- Easy to find "I need yesterday at 3 PM"

---

## File Paths

```bash
BACKUP_DIR="${BASE_DIR}/${DATE_DIR}"
TMP_FILE="${BACKUP_DIR}/.VISTAR-${TIME_STAMP}.tmp"
FINAL_FILE="${BACKUP_DIR}/VISTAR-${TIME_STAMP}.backup"
```

**Why BACKUP_DIR:**

- Combines base path + date folder
- Example: `/odoo_prod_warehouse/2026-01-31/`

**Why TMP_FILE:**

- Hidden file (starts with `.`)
- Used during backup creation
- Prevents incomplete backups from being visible

**Why FINAL_FILE:**

- Final backup name: `VISTAR-2026-01-31_13-45-00.backup`
- Only appears when backup is complete

**Why this pattern (tmp → final):**

- **Atomic operation**: Backup is either complete or doesn't exist
- Prevents corruption if script crashes mid-backup
- This is a **production-grade practice**

---

## Logging Setup

```bash
LOG_FILE="${BASE_DIR}/backup.log"
ERROR_LOG="${BASE_DIR}/backup_errors.log"
```

**Why separate logs:**

- `backup.log`: All operations (success + info)
- `backup_errors.log`: Only errors (easy to monitor)

**Why this matters:**

- Quick troubleshooting: Check error log first
- Cron-safe: Outputs are logged, not lost
- Audit trail: Know when backups ran

---

## Password File Setup

```bash
export PGPASSFILE="/home/arffy/cproj/vistar/.pgpass"
```

**Why:**

- PostgreSQL reads password from `.pgpass` file
- **No password in script** = more secure
- Required for automation (cron jobs)

**Format of `.pgpass`:**

```
localhost:5432:govt:postgres:your_password
```

**Security:**

- Must have `600` permissions (owner read/write only)
- Never commit to git

---

## Logging Helper Functions

```bash
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "${LOG_FILE}"
}
```

**Why:**

- Timestamp every log entry
- Format: `[2026-01-31 11:34:00] [INFO] message`
- `tee -a`: Shows on screen AND appends to file

```bash
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${LOG_FILE}" "${ERROR_LOG}"
}
```

**Why:**

- Errors go to BOTH logs
- Easy to spot critical issues

```bash
log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "${LOG_FILE}"
}
```

**Why:**

- Clear success confirmation
- Helps verify cron jobs are working

---

## Create Backup Directory

```bash
mkdir -p "${BACKUP_DIR}"
```

**Why:**

- `-p`: Creates parent directories if needed
- Example: Creates `JAN-31-2026/` folder automatically
- Won't error if folder already exists

---

## Pre-Backup Logging

```bash
log_info "Starting backup for database: ${PG_DB}"
log_info "Backup destination: ${FINAL_FILE}"
```

**Why:**

- Creates audit trail
- Debugging: See what was attempted
- Helps correlate with PostgreSQL logs

---

## The Actual Backup Command

```bash
pg_dump \
  --host="${PG_HOST}" \
  --port="${PG_PORT}" \
  --username="${PG_USER}" \
  --format=custom \
  --file="${TMP_FILE}" \
  --no-owner \
  --no-acl \
  "${PG_DB}" 2>> "${ERROR_LOG}"
```

**Line by line:**

### `pg_dump`

The PostgreSQL backup utility.

### `--host="${PG_HOST}"`

Connect to database server (localhost).

### `--port="${PG_PORT}"`

Use port 5432 (PostgreSQL default).

### `--username="${PG_USER}"`

Login as `postgres` user.

### `--format=custom`

**CRITICAL CHOICE:**

- Custom binary format (compressed)
- Fast backup and restore
- Smaller files (~83MB vs ~150MB for SQL)
- Requires `pg_restore` to restore

**Alternatives:**

- `--format=plain`: SQL text file (DBeaver-friendly, but larger)
- `--format=directory`: Multiple files (parallel restore)

### `--file="${TMP_FILE}"`

Write to temporary file first.

### `--no-owner`

**Why:** Don't dump ownership info. Prevents restore failures when:

- Restoring to different server
- Original database owner doesn't exist
- Different PostgreSQL versions

### `--no-acl`

**Why:** Don't dump permissions. Same reason as `--no-owner`.

**Together:** Makes backups portable across environments.

### `"${PG_DB}"`

Target database name (`govt`).

### `2>> "${ERROR_LOG}"`

Redirect errors to error log file.

---

## Capture Exit Code

```bash
DUMP_EXIT_CODE=$?
```

**Why:**

- `$?` contains exit code of last command
- `0` = success
- Non-zero = failure
- Must capture immediately (overwritten by next command)

---

## Validation & Finalization

```bash
if [ ${DUMP_EXIT_CODE} -eq 0 ] && [ -s "${TMP_FILE}" ]; then
```

**Two checks:**

### `[ ${DUMP_EXIT_CODE} -eq 0 ]`

Did `pg_dump` succeed?

### `[ -s "${TMP_FILE}" ]`

Is temp file non-empty? (size > 0)

**Why both:**

- `pg_dump` might exit 0 but create empty file
- Catches silent failures
- Double validation = safer backups

---

## Success Path

```bash
mv "${TMP_FILE}" "${FINAL_FILE}"
FILE_SIZE=$(du -h "${FINAL_FILE}" | cut -f1)
log_success "Backup completed successfully | Size: ${FILE_SIZE} | File: ${FINAL_FILE}"
```

**Why rename (mv):**

- Atomic operation: File appears only when complete
- Hidden `.tmp` becomes visible `.backup`

**Why log file size:**

- Verify backup is complete (~83MB expected)
- Spot anomalies (tiny file = problem)
- Track growth over time

---

## Failure Path

```bash
else
    rm -f "${TMP_FILE}"
    log_error "Backup FAILED | Exit code: ${DUMP_EXIT_CODE} | Check ${ERROR_LOG} for details"
    exit 1
fi
```

**Why delete temp file:**

- Cleans up failed attempt
- Prevents confusion (partial backup)

**Why `exit 1`:**

- Non-zero exit = cron knows it failed
- Can trigger monitoring alerts
- Stops execution (don't proceed on failure)

---

## Final Separator

```bash
log_info "=========================================="
```

**Why:**

- Visual separator in log file
- Easy to see where one backup ends

---

## Key Design Decisions

### ✅ Atomic Writes (tmp → final)

**Problem solved:** No corrupted/incomplete backups visible to users.

### ✅ Custom Format

**Problem solved:** Fast, small, efficient backups for production.

### ✅ Double Validation (exit code + size)

**Problem solved:** Catches silent failures.

### ✅ Separate Error Logs

**Problem solved:** Quick troubleshooting, monitoring-friendly.

### ✅ No Passwords in Script

**Problem solved:** Security, git-safe.

### ✅ Date-Based Folders

**Problem solved:** Natural retention, human-readable organization.

---

## Production-Grade Patterns Used

| Pattern                | Why It Matters           |
| ---------------------- | ------------------------ |
| Atomic file operations | No partial backups       |
| Exit code checking     | Proper error handling    |
| Size validation        | Catch silent failures    |
| Structured logging     | Debuggable, auditable    |
| Environment variables  | Configuration separation |
| `.pgpass` usage        | Secure automation        |

---

## Common Questions

### Q: Why not use `.sql` format?

**A:** Custom format is:

- Smaller (compressed)
- Faster to create and restore
- More efficient for production hourly backups

### Q: Why hourly backups?

**A:** Maximum 1 hour data loss in disaster scenarios.

### Q: Why 10-day retention?

**A:** Balance between:

- Disk space usage
- Recovery window
- Common compliance requirements

### Q: Can I restore to a different database?

**A:** Yes! Change `--dbname` in `pg_restore`:

```bash
pg_restore --dbname=govt_test backup.backup
```

---

## Related Files

- [`pg_hourly_backup.sh`](file:///home/arffy/cproj/vistar/pg_hourly_backup.sh) - The backup script
- [`pg_retention_cleanup.sh`](file:///home/arffy/cproj/vistar/pg_retention_cleanup.sh) - Cleans old backups
- [`RETENTION_SCRIPT_EXPLAINED.md`](file:///home/arffy/cproj/vistar/docs/RETENTION_SCRIPT_EXPLAINED.md) - How the retention script works
- [`.pgpass`](file:///home/arffy/cproj/vistar/.pgpass) - PostgreSQL password file
- [`BACKUP_SETUP.md`](file:///home/arffy/cproj/vistar/docs/BACKUP_SETUP.md) - Setup guide
