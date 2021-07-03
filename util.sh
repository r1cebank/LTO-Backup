detect_tape() {
    if lsscsi | grep tape; then
        tape_devices=$(lsscsi | grep -Eio "/dev/st[0-9]")
        echo $tape_devices
    else
        dialog --title "LTO Backup" --msgbox "No SCSI tape device is found." $HEIGHT $WIDTH
    fi
}

eject_tape() {
    [ -e $MT ] && mt -f /dev/st0 status | grep ONLINE >/dev/null
        rt=$?
    if [[ $rt -eq 0 ]]
    then
        [ -e $MT ] && $MT -f $TAPE rewind
        [ -e $MT ] && $MT -f $TAPE eject
    fi
}
