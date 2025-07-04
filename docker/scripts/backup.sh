#!/bin/sh
# ClarityXDR Database Backup Script

set -e

# Configuration
BACKUP_DIR="/backups"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-clarityxdr}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/clarityxdr_backup_${TIMESTAMP}.sql.gz"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Starting backup of database: ${DB_NAME}"

# Perform backup
pg_dump \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --verbose \
    --no-owner \
    --no-privileges \
    --format=plain \
    --encoding=UTF8 | gzip > "${BACKUP_FILE}"

# Check if backup was successful
if [ -f "${BACKUP_FILE}" ]; then
    SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "[$(date)] Backup completed successfully: ${BACKUP_FILE} (${SIZE})"
    
    # Create a latest symlink
    ln -sf "$(basename ${BACKUP_FILE})" "${BACKUP_DIR}/latest.sql.gz"
    
    # Remove old backups
    echo "[$(date)] Cleaning up old backups (older than ${RETENTION_DAYS} days)"
    find "${BACKUP_DIR}" -name "clarityxdr_backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete
    
    # List remaining backups
    echo "[$(date)] Current backups:"
    ls -lh "${BACKUP_DIR}"/clarityxdr_backup_*.sql.gz 2>/dev/null || echo "No backups found"
else
    echo "[$(date)] ERROR: Backup failed!"
    exit 1
fi

echo "[$(date)] Backup process completed"