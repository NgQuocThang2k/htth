#!/bin/bash
source /home/thang/task7/var.txt
# Verify required variables are set
required_vars=(
    "DB_HOST"
    "DB_USER"
    "DB_PASS"
    "NFS_HOST"
    "NFS_SOURCE_DIR"
    "WEB_HOST"
    "WEB_SOURCE_DIR"
    "RCLONE_PATH"
)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required variable $var is not set in config file"
        exit 1
    fi
done

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/thang/backup/$DATE"
SERVER_NAME=$(hostname)
REMOTE=( "aws" "ftp" )
mkdir -p "${BACKUP_DIR}/database"
mkdir -p "${BACKUP_DIR}/nfs"
mkdir -p "${BACKUP_DIR}/web"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/backup.log"
}
# Backup Database
log_message "Starting database backup..."
ssh "${DB_HOST}" "mysqldump -u"$DB_USER" --password="$DB_PASS" --single-transaction --all-databases > backup.sql"
scp "${DB_HOST}:/home/${DB_USER}/backup.sql" "${BACKUP_DIR}/database/"
ssh "${DB_HOST}" "rm /home/${DB_USER}/backup.sql"
# Backup NFS
log_message "Starting NFS backup..."
scp -r -q "${NFS_HOST}:${NFS_SOURCE_DIR}" "${BACKUP_DIR}/nfs/"
# Backup Web Server
log_message "Starting web server backup..."
ssh "${WEB_HOST}" "tar czf /tmp/lsws_backup.tar.gz /usr/local/lsws/conf /usr/local/lsws/admin/conf"
scp -q "${WEB_HOST}":/tmp/lsws_backup.tar.gz "${BACKUP_DIR}/web"
# Compress backup directory
log_message "Compressing backup directory..."
zip -r "${BACKUP_DIR}.zip" "${BACKUP_DIR}"
# Remove old backups
log_message "Cleaning up old backups..."
find /home/thang/backup/ -type f -mtime +7 -exec rm {} \;
# Set backup file path
BACKUP_FILE="/home/thang/backup/$SERVER_NAME-$DATE.zip"
mv "${BACKUP_DIR}.zip" "$BACKUP_FILE"
size=$(ls -lah "$BACKUP_FILE" | awk '{ print $5}')
# Remove the uncompressed backup directory
rm -rf "$BACKUP_DIR"

for remote in ${REMOTE[@]}; do
    log_message "Starting upload to $remote"
    rclone copy "$BACKUP_FILE" "$remote:$RCLONE_PATH/"
    if [ $? -eq 0 ]; then
        log_message "$remote upload completed successfully"
        log_message "Cleaning up old backups in $remote..."
        rclone delete --min-age 5d "$remote:$RCLONE_PATH/"
        if [ $? -eq 0 ]; then
            log_message "Old backups cleanup in $remote completed successfully"
        else
            log_message "Failed to clean up old backups in $remote"
        fi
    else
        log_message "Upload to $remote failed"
    fi
done

log_message "Cleaning up old local backups..."
find /var/backup/ -mindepth 1 -mtime +5 -delete
check_status "Local backup cleanup"

duration=$SECONDS
log_message "Backup completed successfully!"
log_message "Total backup size: $size"
log_message "Time elapsed: $(($duration / 60)) minutes and $(($duration % 60)) seconds"
