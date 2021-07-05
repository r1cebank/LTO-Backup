## Default tape device, assuming only single SCSI tape device is attached
TAPE_DEVICE="/dev/st1"

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
TAR_ARGS="-b 1024"

## Mbuffer options
TAPE_BUFFER_SIZE="26G"

## Command location
TAR=/bin/tar
MT=/bin/mt-st
ZSTD=/usr/bin/zstd
MBUFFER=/usr/bin/mbuffer
OPENSSL=/usr/bin/openssl

## Command
COMPRESSION_CMD="zstd -3"
DECOMPRESSION_CMD="zstd -3 -d"


## Logs
FILE_LOG="files-$(date -I).log"
BACKUP_LOG="backup-$(date -I).log"
RESTORE_FILE_LOG="restore-$(date -I).log"

## Encryption
ENABLE_ENCRYPTION=false
ENCRYPTION_KEY=