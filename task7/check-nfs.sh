#!/bin/bash

source /home/thang/task7/var.txt


send_telegram_message() {
    local message=$1
    curl -s -X POST https://api.telegram.org/bot"$bot_token"/sendMessage -d chat_id="$chat_id" -d text="$message"
}

if ! ssh lomp "mountpoint -q '${NFS_SOURCE_DIR}'"; then
    send_telegram_message "NFS share $NFS_SOURCE_DIR is not mounted on web server "
fi

