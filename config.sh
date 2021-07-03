## Default tape device, assuming only single SCSI tape device is attached
TAPE_DEVICE="/dev/st0"

LTO3_SIZE="400*1000*1000*1000"
LTO4_SIZE="800*1000*1000*1000"
LTO5_SIZE="1500*1000*1000*1000"
LTO6_SIZE="2500*1000*1000*1000"

## Default selectin will be LTO6, but can be configured
TAPE_SIZE=$LTO6_SIZE

TAPE_SPEED="70*1000*1000"
BLOCK_SIZE="512K"

## Dialog config
HEIGHT=20
WIDTH=80