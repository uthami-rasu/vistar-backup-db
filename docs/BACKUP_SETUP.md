# PostgreSQL Backup Setup Guide

## 📋 Prerequisites

- PostgreSQL installed
- Database name: `govt`
- User: `postgres`

---

## 🛠️ Setup Steps

### Step 1: Set Permissions

#### A. Set `.pgpass` file permissions (Required)

```bash
chmod 600 /home/arffy/cproj/vistar/.pgpass
```

**Why:** PostgreSQL requires strict permissions for password files.

#### B. Make backup scripts executable

```bash
chmod +x /home/arffy/cproj/vistar/pg_hourly_backup.sh
chmod +x /home/arffy/cproj/vistar/pg_retention_cleanup.sh
```

#### C. Set backup directory permissions

```bash
chmod 755 /home/arffy/cproj/vistar/odoo_prod_warehouse
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
  /home/arffy/cproj/vistar/odoo_prod_warehouse/JAN-31-2026/VISTAR-11-00-AM.backup
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
  /home/arffy/cproj/vistar/odoo_prod_warehouse/JAN-31-2026/VISTAR-11-00-AM.backup
```

---

## 📊 Monitoring

### View backup logs:

```bash
tail -f /home/arffy/cproj/vistar/odoo_prod_warehouse/backup.log
```

### Check backup files:

```bash
ls -lh /home/arffy/cproj/vistar/odoo_prod_warehouse/2026-01-31/
```

### Count total backups:

```bash
find /home/arffy/cproj/vistar/odoo_prod_warehouse -name "*.backup" | wc -l
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

The retention script includes advanced safety protections to prevent accidental data loss.

### 1. Master Kill-Switch (`RETENTION_ENABLED`)

Located at the top of `pg_retention_cleanup.sh`:

- `true` (default): Retention is active.
- `false`: Script will exit without doing anything.

### 2. Dry-Run Mode (`DRY_RUN`)

Use this to test your retention settings safely:

1. Edit `pg_retention_cleanup.sh` and set `DRY_RUN="true"`.
2. Run the script: `./pg_retention_cleanup.sh`.
3. Check the logs (`retention_cleanup.log`). It will show "[DRY-RUN] Would delete: ..." but **no files will be removed**.
4. Once you are happy with the results, set `DRY_RUN="false"` for live operation.

### 3. Safety Validations

The script automatically verifies:

- `BASE_DIR` matches the explicit `ALLOWED_BASE` path.
- `BASE_DIR` is not a system directory (like `/` or `/home`).
- `RETENTION_UNIT` is valid (`days` or `minutes`).

---

## 📁 File Structure

```
vistar/
├── pg_hourly_backup.sh          # Hourly backup script
├── pg_retention_cleanup.sh      # Daily cleanup script
├── .pgpass                      # PostgreSQL password (600)
└── odoo_prod_warehouse/         # Backup storage (755)
    ├── backup.log
    ├── backup_errors.log
    ├── retention_cleanup.log
    └── 2026-01-31/
        ├── VISTAR-2026-01-31_01-00-00.backup
        ├── VISTAR-2026-01-31_02-00-00.backup
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
