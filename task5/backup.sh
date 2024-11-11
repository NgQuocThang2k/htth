#!/bin/bash

source /home/thang/task5/var.txt

mkdir -p "$BACKUP_DIR/mysql"
echo "Starting Backup Database";
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys)"`
for db in $databases; do
    $MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD $db | gzip > "$BACKUP_DIR/mysql/$db.gz"
done
echo "Finished";
echo '';

echo "Starting Backup Website";
for D in /var/www/*; do
    if [ -d "${D}" ]; then
        domain=${D##*/}
        echo "- "$domain;
        zip -r $BACKUP_DIR/$domain.zip /var/www/$domain/ -q -x /var/www/$domain/wp-content/cache/**\*
    fi
done
echo "Finished";
echo '';

echo "Starting Backup nginx Configuration";
cp -r /etc/nginx/sites-enabled/ $BACKUP_DIR/nginx/
echo "Finished";
echo '';

echo "Starting Compress Files";
zip -r /var/backup/$SERVER_NAME-$TIMESTAMP.zip $BACKUP_DIR -q
BACKUP_FILE="/var/backup/$SERVER_NAME-$TIMESTAMP.zip"
rm -rf $BACKUP_DIR
size=$(ls -lah /var/backup/$SERVER_NAME-$TIMESTAMP.zip | awk '{ print $5}')
echo "Finished";
echo '';

# Upload to AWS S3, FTP server using rclone
  for remote in  ${REMOTE[@]}; do
echo "Starting upload to $remote"
rclone copy "$BACKUP_FILE" "$remote":"$Rcl_PATH/"
if [ $? -eq 0 ]; then
    echo "$remote upload completed successfully"
    # Clean up old backups in S3
    echo "Cleaning up old backups in $remote..."
    # List and delete files older than retention period
    rclone delete --min-age 5d "$remote":"$Rcl_PATH/"
    if [ $? -eq 0 ]; then
        echo "Old backups cleanup completed successfully"
    else
        echo "Failed to clean up old backups"
    fi
else
    echo "Upload failed with error code $?"
fi
done
#Remove older local backups (5 days)
find /var/backup/ -mindepth 1 -mtime +5 -delete

duration=$SECONDS
echo "Total $size, $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
