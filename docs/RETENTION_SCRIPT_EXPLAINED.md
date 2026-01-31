# PostgreSQL Retention Script - Line by Line Explanation

This document explains every line of `pg_retention_cleanup.sh` and provides a deep dive into the industry-standard safety guards implemented to prevent accidental data loss.

---

## 🛡️ Deep Dive: The Three Safety Shields

Retention scripts are powerful and dangerous. This script implements three layers of protection to ensure it **never** deletes something it shouldn't.

### 1. The Kill-Switch (`RETENTION_ENABLED`)

Managed by a single variable: `RETENTION_ENABLED="true"`.

- **Purpose**: A master control to stop the script instantly.
- **How it works**: If set to anything other than `true`, the script logs a message and exits immediately without checking any files.

### 2. The Preview Mode (`DRY_RUN`)

Managed by: `DRY_RUN="true"`.

- **Purpose**: Allows you to see exactly what _would_ happen without any risk.
- **How it works**: When active, the script performs all calculations and "identifies" targets, but it wraps all delete commands (`rm`, `rmdir`, etc.) in a protective check. Instead of deleting, it prints: `[DRY-RUN] Would delete: ...`.
- **Recommendation**: Always run with `DRY_RUN="true"` first when changing configuration.

### 3. The Path Shield (`realpath` Validation)

Managed by comparing `REAL_BASE` vs `REAL_ALLOWED`.

- **Purpose**: Guarantees the script only ever touches the specific intended directory.
- **How it works**:
  1. It takes the path you provided (`BASE_DIR`).
  2. It converts it to an absolute, "resolved" path using the `realpath` command (this handles symlinks, `..`, and extra slashes).
  3. It does the same for a hardcoded `ALLOWED_BASE`.
  4. If they don't match **exactly**, the script panics and exits.
- **Benefit**: Even if someone accidentally sets `BASE_DIR="/"`, the script will refuse to run because `/` does not match the allowed path.

---

## 📝 Line by Line Explanation

### 1. Script Header & Safety Mode

```bash
#!/bin/bash
set -euo pipefail
```

- `set -e`: Exit immediately if any command fails.
- `set -u`: Exit if an unset variable is used (prevents `rm -rf ${VAR}/*` where VAR is empty).
- `set -o pipefail`: Catch errors that happen inside pipes.

---

### 2. Configuration Section

```bash
ALLOWED_BASE="/home/arffy/arffy_db_bkups/odoo_18_warehouse"
BASE_DIR="${ALLOWED_BASE}"
RETENTION_UNIT="days"
RETENTION_PERIOD=10
```

- `ALLOWED_BASE`: The "Source of Truth" for where deletions are allowed.
- `RETENTION_UNIT`: Supports `days` (production) or `minutes` (testing).
- `RETENTION_PERIOD`: How many units to keep.

---

### 3. Safety Validations (Lines 31-72)

```bash
command -v realpath >/dev/null 2>&1 || { ... exit 1; }
```

- **Line 36**: Ensures the `realpath` tool exists. Safely prevents failures in minimal environments.

```bash
if [ -z "${BASE_DIR}" ]; then ... exit 1; fi
```

- **Line 42**: Emergency check to ensure the directory variable isn't empty (which could lead to deleting from `/`).

```bash
if [ "${BASE_DIR}" = "/" ] || [ "${BASE_DIR}" = "/home" ] ...
```

- **Line 48**: "Blacklist" check. Explicitly forbids running on system directories.

```bash
REAL_BASE=$(realpath "${BASE_DIR}")
REAL_ALLOWED=$(realpath "${ALLOWED_BASE}")
if [ "${REAL_BASE}" != "${REAL_ALLOWED}" ]; then ... exit 1; fi
```

- **Line 60-68**: The **Path Shield** explained above. Resolves exact paths and verifies they match the allowed target.

---

### 4. Logging & Master Toggle

```bash
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RETENTION] $1" | tee -a "${CLEANUP_LOG}"
}
```

- **Line 77**: Logs are now exclusively written to `retention_cleanup.log`. This keeps the main backup log clean.

---

### 5. Testing Logic (Minutes Mode)

```bash
if [ "${RETENTION_UNIT}" = "minutes" ]; then
    CUTOFF_EPOCH=$(date -d "${DELETE_MINUTES} minutes ago" +"%s")
```

- **Line 106**: Converts the "Cutoff Time" into a Unix Epoch (number of seconds). This is the most accurate way to compare timestamps.

```bash
while read -r backup_file; do
    FILE_EPOCH=$(stat -c %Y "$backup_file")
    if [ ${FILE_EPOCH} -lt ${CUTOFF_EPOCH} ]; then
```

- **Line 113-115**: Iterates through every `.backup` file and compares its last modification time (`stat -c %Y`) against our cutoff time.

---

### 6. The Deletion Guard (Inside Loop)

```bash
if [ "${DRY_RUN}" = "true" ]; then
    log_info "[DRY-RUN] Would delete: ..."
else
    rm -f "$backup_file"
fi
```

- **Line 119**: The **Dry-Run Guard**. This is exactly where the decision to delete (or just log) happens for every single file.

---

### 7. Production Logic (Days Mode)

```bash
else
    TARGET_DATE=$(date -d "${DELETE_DAYS} days ago" +"%b-%d-%Y" | tr 'a-z' 'A-Z')
    TARGET_DIR="${BASE_DIR}/${TARGET_DATE}"
```

- **Line 144-146**: Calculates the specific date folder to delete (e.g., `JAN-20-2026`).

```bash
if [ -d "${TARGET_DIR}" ]; then
    if [ "${DRY_RUN}" = "true" ]; then
        log_info "[DRY-RUN] Would delete folder: ..."
    else
        find "${TARGET_DIR}" -type f -name "*.backup" -delete
        rmdir "${TARGET_DIR}" 2>/dev/null
    fi
```

- **Line 150-163**: Checks if the folder exists. If `DRY_RUN` is off, it clears all `.backup` files inside and then removes the directory.

---

### 8. Cleanup Factory

```bash
find "${BASE_DIR}" -type d -empty -delete 2>/dev/null
```

- **Line 139 & 172**: Sweeps the directory for any empty folders left behind and removes them. Safe because it only touches **empty** directories.

---

## 📈 Summary of Protections

| Feature             | Protection Level | Benefit                                              |
| ------------------- | ---------------- | ---------------------------------------------------- |
| `set -euo pipefail` | Script-wide      | Prevents execution on errors or unset variables      |
| `ALLOWED_BASE`      | Path-wide        | Hard-locks the script to one specific folder         |
| `realpath`          | Path-wide        | Prevents "Symlink Attacks" or relative path mistakes |
| `DRY_RUN`           | Action-wide      | Allows safe testing before live execution            |
| `RETENTION_ENABLED` | Global           | Emergency kill-switch to stop all deletions          |

---

## 📁 Related Files

- [`pg_retention_cleanup.sh`](file:///home/arffy/cproj/vistar/pg_retention_cleanup.sh) - The script itself
- [`BACKUP_SETUP.md`](file:///home/arffy/cproj/vistar/docs/BACKUP_SETUP.md) - How to setup the system
- [`BACKUP_SCRIPT_EXPLAINED.md`](file:///home/arffy/cproj/vistar/docs/BACKUP_SCRIPT_EXPLAINED.md) - How the backup script works

Perfect — this is exactly the **right time** to ask this 👍
I’ll explain this **line by line**, **what it does**, **why it exists**, and **the logic behind it**, in simple but precise terms.

I’ll split it into **two flows**:

1. **Minutes mode (testing / local)**
2. **Days mode (production)**

---

# 🔁 Overall decision logic

```bash
if [ "${RETENTION_UNIT}" = "minutes" ]; then
```

👉 Checks **which retention strategy to use**

- `"minutes"` → fine-grained testing
- `"days"` → production cleanup

Only **one branch runs**.

---

# 🟦 MINUTES MODE (Testing / Local)

---

### 1️⃣ Calculate delete threshold

```bash
DELETE_MINUTES=$((RETENTION_PERIOD + 1))
```

- If `RETENTION_PERIOD=20`
- Delete anything **older than 21 minutes**

🧠 The `+1` avoids edge cases where a file is exactly 20 minutes old.

---

```bash
CUTOFF_TIME=$(date -d "${DELETE_MINUTES} minutes ago" +"%Y-%m-%d %H:%M:%S")
```

- Human-readable cutoff time
- Used **only for logs**

Example:

```
2026-01-31 12:19:01
```

---

```bash
CUTOFF_EPOCH=$(date -d "${DELETE_MINUTES} minutes ago" +"%s")
```

- Converts cutoff time to **epoch seconds**
- Used for **numeric comparison**

🧠 Computers compare numbers faster and safer than strings.

---

### 2️⃣ Log what the script is about to do

```bash
log_info "Testing mode: Identifying backups older than ${DELETE_MINUTES} minutes"
log_info "Cutoff time: ${CUTOFF_TIME}"
```

✔ Transparency
✔ Auditability

---

### 3️⃣ Scan backup files (SAFE loop)

```bash
DELETED_COUNT=0
```

- Counter to track how many files are affected

---

```bash
while read -r backup_file; do
```

- Reads **one backup file path at a time**
- `-r` prevents backslash escape bugs

---

```bash
done < <(find "${BASE_DIR}" -type f -name "*.backup")
```

- Finds **only `.backup` files**
- Feeds them into the loop **without a subshell**

🧠 This is important so `DELETED_COUNT` actually updates.

---

### 4️⃣ Decide whether each file is old enough

```bash
FILE_EPOCH=$(stat -c %Y "$backup_file")
```

- Gets **file creation / modification time**
- Returned as epoch seconds

---

```bash
if [ ${FILE_EPOCH} -lt ${CUTOFF_EPOCH} ]; then
```

- If file is **older than cutoff**
- Only then deletion logic runs

✔ New backups are untouched
✔ No guessing by filename

---

### 5️⃣ Gather metadata for logging

```bash
FILE_TIME=$(date -d "@${FILE_EPOCH}" +"%Y-%m-%d %H:%M:%S")
FILE_SIZE=$(du -h "$backup_file" | cut -f1)
```

Used **only for logs**, not logic.

---

### 6️⃣ DRY RUN vs REAL DELETE

```bash
if [ "${DRY_RUN}" = "true" ]; then
```

#### DRY RUN (`true`)

```bash
log_info "[DRY-RUN] Would delete: ..."
```

✔ Shows intent
✔ Deletes nothing

---

#### REAL RUN (`false`)

```bash
rm -f "$backup_file"
log_info "Deleted: ..."
```

⚠️ Actual deletion happens here.

---

```bash
((DELETED_COUNT++))
```

- Increments deleted-file counter
- Works correctly because no subshell

---

### 7️⃣ Summary log

```bash
if [ "${DRY_RUN}" = "true" ]; then
```

- Logs **what would have happened**
- Or **what actually happened**

---

### 8️⃣ Cleanup empty directories

```bash
find "${BASE_DIR}" -type d -empty -delete
```

- Removes empty date folders
- Runs **only if not DRY RUN**

✔ No leftover junk
✔ Safe (empty only)

---

# 🟧 DAYS MODE (Production)

---

### 1️⃣ Calculate target day

```bash
DELETE_DAYS=$((RETENTION_PERIOD + 1))
```

- Keep last `RETENTION_PERIOD` days
- Delete **next older day**

---

```bash
TARGET_DATE=$(date -d "${DELETE_DAYS} days ago" +"%Y-%m-%d")
```

Example:

```
2026-01-20
```

Matches your backup folder naming exactly.

---

```bash
TARGET_DIR="${BASE_DIR}/${TARGET_DATE}"
```

Points to **one specific day folder**.

---

### 2️⃣ Log intent

```bash
log_info "Production mode: Keep ${RETENTION_PERIOD} days..."
```

---

### 3️⃣ If folder exists → act

```bash
if [ -d "${TARGET_DIR}" ]; then
```

✔ Avoids errors
✔ No deletion if folder missing

---

```bash
FILE_COUNT=$(find ... | wc -l)
TOTAL_SIZE=$(du -sh ...)
```

Used only for **logging & auditing**.

---

### 4️⃣ DRY RUN vs REAL DELETE

#### DRY RUN

```bash
log_info "[DRY-RUN] Would delete folder: ..."
```

No deletion.

---

#### REAL RUN

```bash
find "${TARGET_DIR}" -type f -name "*.backup" -delete
rmdir "${TARGET_DIR}"
```

✔ Deletes only `.backup` files
✔ Removes directory only if empty

---

### 5️⃣ Final cleanup

Same empty-directory cleanup logic as minutes mode.

---

# ✅ Why this logic is PROFESSIONAL

✔ Deletes **only what qualifies**
✔ Two independent strategies (minutes vs days)
✔ No filename assumptions
✔ No wildcard deletes
✔ DRY RUN protection
✔ Full audit logs

---

# 🏁 Final takeaway

This block is:

> A **controlled decision engine** that chooses _what to delete_, _when to delete_, and _how safely to delete_, based on time.
