# PostgreSQL Backup Setup Guide

## 📋 Prerequisites

- PostgreSQL installed
- Database name: `govt`
- User: `postgres`

---

## 🛠️ Setup Steps

### Step 2: Configure System (CRITICAL)

Configure all database and retention settings in `backup.config`. You do **NOT** need to edit the `.sh` scripts.

```bash
cd /home/arffy/cproj/vistar
nano backup.config
```

#### Key Variables in `backup.config`:

| Variable           | Description                 | Example                 |
| :----------------- | :-------------------------- | :---------------------- |
| `PROJECT_PREFIX`   | Filename prefix for backups | `"VISTAR"`              |
| `PG_DB`            | Database name to backup     | `"govt"`                |
| `BASE_DIR`         | Where to store backups      | `"/home/arffy/backups"` |
| `RETENTION_PERIOD` | How many units to keep      | `5`                     |
| `RETENTION_UNIT`   | Unit for retention          | `"days"` or `"minutes"` |

---

### Step 3: Set Permissions

#### A. Set `.pgpass` and `backup.config` permissions

```bash
chmod 600 /home/arffy/cproj/vistar/.pgpass
chmod 600 /home/arffy/cproj/vistar/backup.config # Contains DB info
```

#### B. Make backup scripts executable

```bash
chmod +x /home/arffy/cproj/vistar/pg_hourly_backup.sh
chmod +x /home/arffy/cproj/vistar/pg_retention_cleanup.sh
```

#### C. Set backup directory permissions

The `BASE_DIR` defined in `backup.config` must be owned by your user.

```bash
# Example for /home/arffy/arffy_db_bkups
sudo mkdir -p /home/arffy/arffy_db_bkups/odoo_18_warehouse
sudo chown -R arffy:arffy /home/arffy/arffy_db_bkups
```

---

### Step 2: Test Backup Script

Run manually to verify it works:

```bash
cd /home/arffy/cproj/vistar
./pg_hourly_backup.sh
```

**Expected output:**

```
[2026-01-31 11:34:00] [INFO] Starting backup for database: govt
[2026-01-31 11:34:15] [SUCCESS] Backup completed successfully | Size: 83M
```

---

### Step 3: Setup Cron Jobs

#### Edit crontab

```bash
crontab -e
```

#### Add these two lines

```bash
# Backup every 5 minutes
*/5 * * * * /home/arffy/cproj/vistar/pg_hourly_backup.sh

# Retention cleanup - runs every 20 minutes
*/20 * * * * /home/arffy/cproj/vistar/pg_retention_cleanup.sh
```

#### Verify cron jobs

```bash
crontab -l
```

> [!IMPORTANT]
> If you were already using an older version of these scripts, ensure your crontab points to the scripts in `/home/arffy/cproj/vistar/`.

---

## 🔄 How to Restore

### Restore from backup:

```bash
pg_restore \
  --host=localhost \
  --port=5432 \
  --username=postgres \
  --dbname=govt \
  --clean \
  --if-exists \
  /home/arffy/arffy_db_bkups/odoo_18_warehouse/2026-01-31/VISTAR-2026-01-31_11-00-00.backup
```

### Restore to different database:

```bash
pg_restore \
  --host=localhost \
  --port=5432 \
  --username=postgres \
  --dbname=govt_local \
  --clean \
  --if-exists \
  /home/arffy/arffy_db_bkups/odoo_18_warehouse/2026-01-31/VISTAR-2026-01-31_11-00-00.backup
```

---

## 📊 Monitoring

### View logs:

- **Backup logs**: `tail -f /home/arffy/arffy_db_bkups/odoo_18_warehouse/backup.log`
- **Retention cleanup logs**: `tail -f /home/arffy/arffy_db_bkups/odoo_18_warehouse/retention_cleanup.log`
- **Error logs**: `tail -f /home/arffy/arffy_db_bkups/odoo_18_warehouse/backup_errors.log`

### Check backup files:

```bash
ls -lh /home/arffy/arffy_db_bkups/odoo_18_warehouse/2026-01-31/
```

### Count total backups:

```bash
find /home/arffy/arffy_db_bkups/odoo_18_warehouse -name "*.backup" | wc -l
```

---

## ✅ Quick Checklist

- [ ] `.pgpass` permissions set to `600`
- [ ] Backup scripts executable (`chmod +x`)
- [ ] Test backup script manually
- [ ] Cron jobs added
- [ ] Verify backups are being created hourly

---

## 📚 Related Documentation

- [`BACKUP_SCRIPT_EXPLAINED.md`](file:///home/arffy/cproj/vistar/docs/BACKUP_SCRIPT_EXPLAINED.md) - Line-by-line guide for the **Backup** script.
- [`RETENTION_SCRIPT_EXPLAINED.md`](file:///home/arffy/cproj/vistar/docs/RETENTION_SCRIPT_EXPLAINED.md) - Line-by-line guide for the **Retention** script.

---

---

## 🛡️ Safety & Dry-Run Mode

The retention script includes advanced safety protections. All controls are now in `backup.config`.

### 1. Master Kill-Switch (`RETENTION_ENABLED`)

- `true` (default): Retention is active.
- `false`: Script will exit without doing anything.

### 2. Dry-Run Mode (`DRY_RUN`)

1. Edit `backup.config` and set `DRY_RUN="true"`.
2. Run the cleanup script: `./pg_retention_cleanup.sh`.
3. Check the logs. It will show "[DRY-RUN] Would delete: ..." but **no files will be removed**.
4. Set `DRY_RUN="false"` for live operation.

### 3. Safety Validations

The script automatically verifies:

- `BASE_DIR` matches the `ALLOWED_BASE` path in `backup.config`.
- `BASE_DIR` is not a system directory.

---

## 📁 File Structure

```
vistar/
├── backup.config                # NEW: Central configuration
├── pg_hourly_backup.sh          # Hourly backup script
├── pg_retention_cleanup.sh      # Daily cleanup script
├── .pgpass                      # PostgreSQL password (600)
└── /path/to/backups/            # Defined in BASE_DIR
    ├── backup.log
    ├── backup_errors.log
    ├── retention_cleanup.log
    └── 2026-01-31/
        ├── VISTAR-2026-01-31_01-00-00.backup
        └── ...
```

---

## 🆘 Troubleshooting

### Backup not running?

```bash
# Check cron service
sudo systemctl status cron

# Check script permissions
ls -la pg_hourly_backup.sh
```

### Password errors?

```bash
# Verify .pgpass permissions
ls -la .pgpass
# Should be: -rw------- (600)
```

### Manual test restore?

```bash
# Test on different database first
createdb -U postgres govt_test
pg_restore --dbname=govt_test /path/to/backup.backup
```
