# PostgreSQL Backup System

A robust, production-grade PostgreSQL backup and retention system with automation via cron.

## 🚀 Features

- **Hourly Backups**: Automated backups using PostgreSQL's custom binary format (compressed and fast).
- **Atomic Operations**: Uses a `tmp` to `final` file rotation to ensure no partial or corrupted backups.
- **Secure Credentials**: Uses `.pgpass` for database authentication (no passwords in scripts).
- **Safe Retention**: Automatic cleanup of old backups with multiple safety guards (kill-switch, dry-run, path validation).
- **Comprehensive Logging**: Detailed success and error logs for auditability.
- **Standard Formatting**: Uses ISO `YYYY-MM-DD` folder names and full `YYYY-MM-DD_HH-MM-SS` file timestamps for perfect sorting.

## 📁 Repository Structure

- `pg_hourly_backup.sh`: The core backup script.
- `pg_retention_cleanup.sh`: The retention and cleanup script.
- `docs/`: Detailed documentation and setup guides.
  - [BACKUP_SETUP.md](file:///home/arffy/cproj/vistar/docs/BACKUP_SETUP.md): Quick-start and cron setup.
  - [BACKUP_SCRIPT_EXPLAINED.md](file:///home/arffy/cproj/vistar/docs/BACKUP_SCRIPT_EXPLAINED.md): Deep dive into backup logic.
  - [RETENTION_SCRIPT_EXPLAINED.md](file:///home/arffy/cproj/vistar/docs/RETENTION_SCRIPT_EXPLAINED.md): Deep dive into safety and deletion logic.
- `restore.txt`: Quick reference for restore commands.

## 🛠️ Quick Start

1.  **Configure**: Update the database and path details in the script headers.
2.  **Permissions**: Run `chmod +x *.sh`.
3.  **Authentication**: Setup your `.pgpass` file with `600` permissions.
4.  **Cron**: Add the scripts to your crontab using the examples in `docs/BACKUP_SETUP.md`.

---

_Maintained by Antigravity for Vistar._
