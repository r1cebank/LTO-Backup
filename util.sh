log() {
    echo "[$(date --rfc-3339=seconds)]: $*" >> $TASK_LOG
}

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
    if ! [ -x "$(command -v calc)" ]; then
        dialog --title "LTO Backup" --msgbox "calc is not installed." $HEIGHT $WIDTH
        exit 1
    fi
}

select_tape() {
    tape_section=$(dialog \
        --backtitle "LTO Backup" \
        --title "Tape Type" \
        --clear \
        --cancel-label "Exit" \
        --menu "Please select your tape type:" $HEIGHT $WIDTH 4 \
        "1" "LTO3" \
        "2" "LTO4" \
        "3" "LTO5" \
        "4" "LTO6" \
        --output-fd 1)

    case $tape_section in
        1 )
        TAPE_SIZE=$LTO3_SIZE
        $MT -f $TAPE_DEVICE stoptions scsi2logical
        ;;
        2 )
        TAPE_SIZE=$LTO4_SIZE
        $MT -f $TAPE_DEVICE stoptions scsi2logical
        ;;
        3 )
        TAPE_SIZE=$LTO5_SIZE
        ;;
        4 )
        TAPE_SIZE=$LTO6_SIZE
        ;;
        * )
        clear
        echo "Backup aborted."
        exit
        ;;
    esac
}

detect_tape() {
    if lsscsi | grep tape; then
        tape_devices=()
        i=1
        while read device; do
            tape_devices+=($i "$device")
            (( i++ ))
        done < <(ls /dev/nst* -d | grep "/dev/nst[0-9]$")
        tape_section=$(dialog \
            --backtitle "LTO Backup" \
            --title "Device Selection" \
            --clear \
            --cancel-label "Exit" \
            --menu "Please select your tape device:" $HEIGHT $WIDTH 4 \
            "${tape_devices[@]}" \
            --output-fd 1)
        TAPE_DEVICE=${tape_devices[$tape_section]}
        $MT -f $TAPE_DEVICE status
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
    log "Ejecting tape $TAPE_DEVICE"
    [ -e $MT ] && $MT -f $TAPE_DEVICE status | grep ONLINE >/dev/null
        rt=$?
    if [[ $rt -eq 0 ]]
    then
        [ -e $MT ] && rewind_tape
        [ -e $MT ] && $MT -f $TAPE_DEVICE eject
    fi
}

rewind_tape() {
    $MT -f $TAPE_DEVICE rewind
}

wait_for_tape() {
    while true
    do
        $MT -f $TAPE_DEVICE status | grep ONLINE >/dev/null
        rt=$?
        if [[ $rt -eq 0 ]]
        then
            break;
        fi
        dialog --title "LTO Backup" --msgbox "Please load tape to device and select OK." $HEIGHT $WIDTH
    done
    log "Tape loaded $TAPE_DEVICE"
}

wait_for_tape_silent() {
    log "Waiting new tape in: $TAPE_DEVICE"
    while true
    do
        $MT -f $TAPE_DEVICE status | grep ONLINE >/dev/null
        rt=$?
        if [[ $rt -eq 0 ]]
        then
            break;
        fi
        sleep 2
    done
    log "Tape loaded $TAPE_DEVICE"
}

wait_for_next_tape() {
    eject_tape
    wait_for_tape
}

wait_for_next_tape_silent() {
    eject_tape
    wait_for_tape_silent
}

enable_decryption() {
    dialog --title "Encryption" --yesno "Was data on the tape encrypted?" $HEIGHT $WIDTH
    rt=$?
    case $rt in
        0)
            ENABLE_ENCRYPTION=true
            select_encryption_key
        ;;
    esac
}

select_encryption_key() {
    ENCRYPTION_KEY=$(dialog \
        --backtitle "LTO Backup" \
        --title "Encryption Key" \
        --clear \
        --cancel-label "Exit" \
        --fselect / $HEIGHT $WIDTH \
        --output-fd 1)
    if [ -f "$ENCRYPTION_KEY" ]; then
        dialog --title "LTO Backup" --msgbox "You selected encryption key $ENCRYPTION_KEY." $HEIGHT $WIDTH
    else
        dialog --title "LTO Backup" --msgbox "Encryption key does not exist." $HEIGHT $WIDTH
        exit 1
    fi
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
        exit 1
    fi
}

select_destination() {
    RESTORE_DESTINATION=$(dialog \
        --backtitle "LTO Backup" \
        --title "Destination Selection" \
        --clear \
        --cancel-label "Exit" \
        --dselect / $HEIGHT $WIDTH \
        --output-fd 1)
    if [ -d "$RESTORE_DESTINATION" ]; then
        dialog --title "LTO Backup" --msgbox "You selected to restore to ${RESTORE_DESTINATION}." $HEIGHT $WIDTH
    else
        dialog --title "LTO Backup" --msgbox "Restore folder does not exist." $HEIGHT $WIDTH
        exit 1
    fi
}

estimate_size() {
    du -sh "$BACKUP_SOURCE" | cut -f1
}

estimate_time() {
    estimated_seconds=$(calc "$1//($TAPE_SPEED)")
    echo $((estimated_seconds/86400))" days "$(date -d "1970-01-01 + $estimated_seconds seconds" "+%H hours %M minutes %S seconds")
}

estimate_raw_size() {
    du -sbc "$BACKUP_SOURCE" | cut -f1 | tail -n1
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

enable_encryption() {
    dialog --title "Encryption" --yesno "Enable encryption?" $HEIGHT $WIDTH
    rt=$?
    case $rt in
        0)
            ENABLE_ENCRYPTION=true
            dialog --title "Encryption" --yesno "Use existing encryption key?" $HEIGHT $WIDTH
            rt=$?
            case $rt in
                0)
                    select_encryption_key
                ;;
                1)
                    ENCRYPTION_KEY="$(date +%m%d%Y_%H%M%S)-$1.key"
                    $OPENSSL rand 512 > $ENCRYPTION_KEY
                    dialog --title "LTO Backup" --msgbox "Encryption key generated in ${ENCRYPTION_KEY}." $HEIGHT $WIDTH
                ;;
            esac
        ;;
    esac
}

enable_compression() {
    dialog --title "Compression" --yesno "Enable compression?" $HEIGHT $WIDTH
    rt=$?
    case $rt in
        0)
            ENABLE_COMPRESSION=true
        ;;
    esac
}

enable_decompression() {
    dialog --title "Compression" --yesno "Was compression enabled during backup?" $HEIGHT $WIDTH
    rt=$?
    case $rt in
        0)
            ENABLE_COMPRESSION=true
        ;;
    esac
}

text_prompt() {
    input_text=$(dialog --title "$1" --backtitle "LTO Backup" --inputbox "$2"  $HEIGHT $WIDTH --output-fd 1)
    echo $input_text
}

select_task() {
    task_section=$(dialog \
        --backtitle "LTO Backup" \
        --title "Select Task" \
        --clear \
        --cancel-label "Exit" \
        --menu "Please select the task you want to perform:" $HEIGHT $WIDTH 4 \
        "1" "Backup" \
        "2" "Restore" \
        "3" "List Backup" \
        --output-fd 1)

    case $task_section in
        1 )
            select_source
            confirm "Confirm backup $BACKUP_SOURCE to $TAPE_DEVICE?"
            backup
        ;;
        2 )
            select_destination
            confirm "Confirm restore $TAPE_DEVICE to $RESTORE_DESTINATION?"
            restore
        ;;
        3 )
            list_backups
        ;;
        * )
            clear
            echo "Backup aborted."
            exit
        ;;
    esac
}

prepare_backup() {
    # disable drive compression since we use zstd
    $MT -f $TAPE_DEVICE compression 0
    wait_for_tape
    rewind_tape
    backup_script

    # Clear the log files
    > $TASK_LOG
    > $BACKUP_FILE_LOG
    clear
}

prepare_restore() {
    wait_for_tape
    rewind_tape
    skip_to_data
    # Clear the log files
    > $TASK_LOG
    > $RESTORE_FILE_LOG
    clear
}

backup_script() {
    # Backup current script and config, allow restore with only tape
    echo "ENABLE_COMPRESSION=$ENABLE_COMPRESSION" >> custom.sh
    echo "ENABLE_ENCRYPTION=$ENABLE_ENCRYPTION" >> custom.sh
    echo "BACKUP_SOURCE=$BACKUP_SOURCE" >> custom.sh
    echo "TAPE_DEVICE=$TAPE_DEVICE" >> custom.sh
    echo "ENCRYPTION_KEY=$ENCRYPTION_KEY" >> custom.sh
    echo "TAPE_SIZE=$TAPE_SIZE" >> custom.sh
    $TAR -cvf $TAPE_DEVICE *.sh > /dev/null 2>&1
    rm custom.sh
}

skip_to_data() {
    # Skip the script portion and jump to file 2
    $MT -f $TAPE_DEVICE asf 1
}

backup() {
    size=$( estimate_size )
    raw_size=$( estimate_raw_size )
    tape_required=$(numfmt --to iec --format "%1.0f" $( calc "$raw_size/($TAPE_SIZE)" ))
    estimated_time=$( estimate_time $raw_size )
    dialog --title "LTO Backup" --msgbox "Estimated backup size: ${size}.\nEstimated tape(s) required: ${tape_required}.\n\nEstimated time to completion: ${estimated_time}." $HEIGHT $WIDTH
    label=$( text_prompt "Backup Name" "Enter the name for this backup task" )

    if [ -z "$label" ]
    then
        clear
        echo "Backup aborted."
        exit
    fi

    enable_compression
    enable_encryption $label
    confirm "Run backup task?"

    prepare_backup

    log "Backup task: $label"
    log "Backup started for $BACKUP_SOURCE to $TAPE_DEVICE"
    log "Encryption: $ENABLE_ENCRYPTION"
    log "Compression: $ENABLE_COMPRESSION"

    ## Start the backup task
    $TAR $TAR_ARGS --label="$label $(date -I)" -cvf - "$BACKUP_SOURCE"  2> $BACKUP_FILE_LOG | \
    ( [ -z "$ENABLE_COMPRESSION" ] && cat || $COMPRESSION_CMD ) | \
    ( [ -z "$ENABLE_ENCRYPTION" ] && cat || $OPENSSL enc $ENCRYPT_CMD -pass file:$ENCRYPTION_KEY ) | \
    $MBUFFER \
        -A "bash -c \"TASK_LOG=$TASK_LOG TAPE_DEVICE=$TAPE_DEVICE; MT=$MT; source util.sh; wait_for_next_tape_silent\"" \
        -P 95 \
        -m $TAPE_BUFFER_SIZE \
        -f \
        -o $TAPE_DEVICE \
        -L \
        -s $BLOCK_SIZE

    rt=$?
    if [ ! $rt -eq 0 ]
    then
        log  "Backup failed $rt"
        dialog --title "LTO Backup" --msgbox "Backup failed tar $rt." $HEIGHT $WIDTH
    else
        log  "Backup finished"
        eject_tape
        dialog --title "LTO Backup" --msgbox "Backup finished successfully." $HEIGHT $WIDTH
    fi
}

restore() {
    tapes_count=$( text_prompt "Tape Count" "Enter the number of tapes used for restore" )

    if [ -z "$tapes_count" ]
    then
        clear
        echo "Restore aborted."
        exit
    fi

    enable_decompression
    enable_decryption
    
    confirm "Run restore task?"

    prepare_restore

    log "Restore started for $TAPE_DEVICE to $RESTORE_DESTINATION with $tapes_count tapes"

    $MBUFFER -n $tapes_count -i $TAPE_DEVICE \
        -A "bash -c \"TASK_LOG=$TASK_LOG TAPE_DEVICE=$TAPE_DEVICE; MT=$MT; source util.sh; wait_for_next_tape_silent\"" \
        -P 100 \
        -m $TAPE_BUFFER_SIZE \
        -f \
        -L \
        -q \
        -s $BLOCK_SIZE |
        ( [ -z "$ENABLE_ENCRYPTION" ] && cat || $OPENSSL enc $DECRYPT_CMD -pass file:$ENCRYPTION_KEY ) | \
        ( [ -z "$ENABLE_COMPRESSION" ] && cat || $DECOMPRESSION_CMD ) | \
        $TAR $TAR_ARGS -xvf - -C "$RESTORE_DESTINATION" | tee $RESTORE_FILE_LOG


    rt=$?
    if [ ! $rt -eq 0 ]
    then
        dialog --title "LTO Backup" --msgbox "Restore failed $rt." $HEIGHT $WIDTH
    else
        eject_tape
        dialog --title "LTO Backup" --msgbox "Restore finished successfully." $HEIGHT $WIDTH
    fi
}

list_backups() {
    tapes_count=$( text_prompt "Tape Count" "Enter the number of tapes used for restore" )

    if [ -z "$tapes_count" ]
    then
        clear
        echo "Restore aborted."
        exit
    fi

    enable_decompression
    enable_decryption

    wait_for_tape
    rewind_tape
    skip_to_data

    $MBUFFER -n $tapes_count -i $TAPE_DEVICE \
        -A "bash -c \"TASK_LOG=$TASK_LOG TAPE_DEVICE=$TAPE_DEVICE; MT=$MT; source util.sh; wait_for_next_tape_silent\"" \
        -P 100 \
        -m $TAPE_BUFFER_SIZE \
        -f \
        -L \
        -q \
        -s $BLOCK_SIZE |
        ( [ -z "$ENABLE_ENCRYPTION" ] && cat || $OPENSSL enc $DECRYPT_CMD -pass file:$ENCRYPTION_KEY ) | \
        ( [ -z "$ENABLE_COMPRESSION" ] && cat || $DECOMPRESSION_CMD ) | \
        $TAR $TAR_ARGS -tvf - -C $(mktemp -d) | awk '{print $NF}' | dialog --programbox "File List" $HEIGHT $WIDTH

    eject_tape
}
