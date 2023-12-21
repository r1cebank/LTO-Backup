#!/bin/bash
source config.sh
source util.sh

trap "echo Backup aborted.; exit;" SIGINT SIGTERM

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

check_dependencies

confirm "This tool is still in development, accept risk and continue?"
rt=$?
case $rt in
    1)
        clear
        echo "Backup aborted."
        exit
    ;;
esac

enable_telegram

log "Test"

detect_tape
select_tape
select_task