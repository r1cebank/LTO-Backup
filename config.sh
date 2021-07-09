## Default tape device, assuming only single SCSI tape device is attached
TAPE_DEVICE="/dev/st0"

LTO3_SIZE="400*1000*1000*1000"
LTO4_SIZE="800*1000*1000*1000"
LTO5_SIZE="1500*1000*1000*1000"
LTO6_SIZE="2500*1000*1000*1000"

## Default selectin will be LTO6, but can be configured
TAPE_SIZE=$LTO6_SIZE

TAPE_SPEED="160*1000*1000"
BLOCK_SIZE="512K"

## Backup source and restore destination
BACKUP_SOURCE=
RESTORE_DESTINATION=

## Dialog config
HEIGHT=20
WIDTH=80

## Tar options
TAR_ARGS="-b 4096"

## Mbuffer options
TAPE_BUFFER_SIZE="4G"

## Command location
TAR=/bin/tar
MT=/bin/mt-st
ZSTD=/usr/bin/zstd
MBUFFER=/usr/bin/mbuffer
OPENSSL=/usr/bin/openssl

## Compression
ENABLE_COMPRESSION=false

## Logs
BACKUP_FILE_LOG="backup-files-$(date "+%Y-%m-%d_%N").log"
TASK_LOG="task-log-$(date "+%Y-%m-%d_%N").log"
RESTORE_FILE_LOG="restore-files-$(date "+%Y-%m-%d_%N").log"

## Encryption
ENABLE_ENCRYPTION=false
ENCRYPTION_KEY=
ENCRYPT_CMD="-aes-256-cbc"
DECRYPT_CMD="-d -aes-256-cbc"