#!/bin/bash
source config.sh
source util.sh

trap "echo Backup aborted.; exit;" SIGINT SIGTERM

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

check_dependencies

dialog --title "Confirmation" --yesno "This tool is still in development, accept risk and continue?" $HEIGHT $WIDTH

rt=$?
case $rt in
    1)
        clear
        echo "Backup aborted."
        exit
    ;;
esac

detect_tape
select_tape
select_task