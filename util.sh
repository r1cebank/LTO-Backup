check_dependencies() {
    if ! [ -x "$(command -v dialog)" ]; then
        echo "Please install dialog"
        exit 1
    fi
    if ! [ -x "$(command -v lsscsi)" ]; then
        dialog --title "LTO Backup" --msgbox "lsscsi is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v mbuffer)" ]; then
        dialog --title "LTO Backup" --msgbox "mbuffer is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v pv)" ]; then
        dialog --title "LTO Backup" --msgbox "pv is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v mtx)" ]; then
        dialog --title "LTO Backup" --msgbox "mtx is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v mt-st)" ]; then
        dialog --title "LTO Backup" --msgbox "mt-st is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v pipemeter)" ]; then
        dialog --title "LTO Backup" --msgbox "pipemeter is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v zstd)" ]; then
        dialog --title "LTO Backup" --msgbox "zstd is not installed." $HEIGHT $WIDTH
        exit 1
    fi
    if ! [ -x "$(command -v calc)" ]; then
        dialog --title "LTO Backup" --msgbox "calc is not installed." $HEIGHT $WIDTH
        exit 1
    fi
}

detect_tape() {
    if lsscsi | grep tape; then
        tape_devices=()
        i=1
        while read device; do
            tape_devices+=($i "$device")
            (( i++ ))
        done < <(lsscsi | grep -Eio "/dev/st[0-9]")
        tape_section=$(dialog \
            --backtitle "LTO Backup" \
            --title "Device Selection" \
            --clear \
            --cancel-label "Exit" \
            --menu "Please select your tape device:" $HEIGHT $WIDTH 4 \
            "${tape_devices[@]}" \
            --output-fd 1)
        TAPE_DEVICE=${tape_devices[$tape_section]}
        mt -f $TAPE_DEVICE status
        rt=$?
        if [ $rt -eq 0 ]; then
            dialog --title "LTO Backup" --msgbox "Tape drive connected successfully" $HEIGHT $WIDTH
        else
            dialog --title "LTO Backup" --msgbox "Failed to connect to tape drive" $HEIGHT $WIDTH
            exit 1
        fi
    else
        dialog --title "LTO Backup" --msgbox "No SCSI tape device is found." $HEIGHT $WIDTH
    fi
}

eject_tape() {
    [ -e $MT ] && mt -f $TAPE_DEVICE status | grep ONLINE >/dev/null
        rt=$?
    if [[ $rt -eq 0 ]]
    then
        [ -e $MT ] && $MT -f $TAPE_DEVICE rewind
        [ -e $MT ] && $MT -f $TAPE_DEVICE eject
    fi
}

wait_for_tape() {
    while true
    do
        mt -f $TAPE_DEVICE status | grep ONLINE >/dev/null
            rt=$?
            if [[ $rt -eq 0 ]]
            then
            break;
        fi
        dialog --title "LTO Backup" --msgbox "Please load tape to device and select OK." $HEIGHT $WIDTH
    done
}

wait_for_next_tape() {
    eject_tape
    wait_for_tape
}

select_source() {
    BACKUP_SOURCE=$(dialog \
        --backtitle "LTO Backup" \
        --title "Source Selection" \
        --clear \
        --cancel-label "Exit" \
        --dselect / $HEIGHT $WIDTH \
        --output-fd 1)
    if [ -d "$BACKUP_SOURCE" ]; then
        dialog --title "LTO Backup" --msgbox "You selected to backup ${BACKUP_SOURCE}." $HEIGHT $WIDTH
    else
        dialog --title "LTO Backup" --msgbox "Backup folder does not exist." $HEIGHT $WIDTH
    fi
}

estimate_size() {
    du -sh $BACKUP_SOURCE | cut -f1
}

estimate_raw_size() {
    du -sbc $BACKUP_SOURCE | cut -f1 | tail -n1
}

confirm() {
    dialog --title "Confirmation" --yesno "$1" $HEIGHT $WIDTH
    rt=$?
    case $rt in
        1)
            clear
            echo "Backup aborted."
            exit
        ;;
    esac
}

backup() {
    # wait_for_tape
    size=$( estimate_size )
    raw_size=$( estimate_raw_size )
    tape_required=$(numfmt --to iec --format "%1.0f" $( calc "$raw_size/($TAPE_SIZE)" ))
    dialog --title "LTO Backup" --msgbox "Estimated backup size: ${size}." $HEIGHT $WIDTH
    dialog --title "LTO Backup" --msgbox "Estimated tape(s) required: ${tape_required}." $HEIGHT $WIDTH
    confirm "Run backup task?"
    $TAR $TAR_ARGS -cvf - $BACKUP_SOURCE  2> $FILE_LOG | \
        pipemeter -s $size -a -b $BLOCK_SIZE -l | \
        $COMPRESSION_CMD | \
        # $OPENSSL enc -aes-256-cbc -pass file:$KEYFILE | \
        $MBUFFER \
            -A "bash -c \"TAPE_DEVICE=$TAPE_DEVICE; MT=$MT; source util.sh; wait_for_next_tape\"" \
            -P 95 \
            -m $TAPE_BUFFER_SIZE \
            -f \
            -o $TAPE_SIZE \
            -L \
            -s$BLOCK_SIZE
    rt=$?
    if [ ! $rt -eq 0 ]
    then
        error "tar command failed with $rt"
    else
        sendmail_event FULLEND
    fi
}