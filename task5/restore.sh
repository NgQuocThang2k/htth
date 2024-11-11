#!/bin/bash

RESTORE_DIR=/tmp/restore
DB_USER=thang
DB_PASS=password
mkdir -p ${RESTORE_DIR}

latest_backup=$(rclone lsf ftp:/backup-nhom1 | grep '^Nhom1-' | tail -n 1)
rclone copyto ftp:/backup-nhom1/${latest_backup} ${RESTORE_DIR}
echo 'finished'
# Unzip the backup file
unzip -e ${RESTORE_DIR}/Nhom1-*.zip -d ${RESTORE_DIR}
# Untar all MySQL databases
for file in ${RESTORE_DIR}/var/backup/*/mysql/*.gz; do
    gunzip $file
    mysql -u "${DB_USER}" -p"${DB_PASS}" < "$sql_file"
done
echo 'finished'
# Restore MySQL databases
for sql_file in ${RESTORE_DIR}/var/backup/*/mysql/*.sql; do
    mysql -u ${DB_USER} -p${DB_PASS} < $sql_file
done
echo 'finished'
# Move nginx configuration to /etc/nginx/sites-available/ then link to /etc/nginx/sites-enabled/
for conf_file in ${RESTORE_DIR}/var/backup/*/nginx/*.conf; do
    mv $conf_file /etc/nginx/sites-available/
    ln -s "/etc/nginx/sites-available/$(basename "$conf_file")" /etc/nginx/sites-enabled/
done
echo 'finished'
# Unzip website to nginx root directory and cut all empty file dir then move to /var/www/
ROOT_DIR=$(find ${RESTORE_DIR}/var/backup/*/ -type f | grep 'nhom1')
for file in ${ROOT_DIR}/*.zip do;
   unzip -q $file -d /tmp/tmp/
done 
mv /tmp/tmp/var/www/* /var/www/
rm /tmp/tmp/*
echo 'finished'
nginx -t
chown -R www-data:www-data /var/www/
systemctl restart nginx
systemctl restart mariadb