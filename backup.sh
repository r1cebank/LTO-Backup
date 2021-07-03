#!/bin/bash
source config.sh
source util.sh

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


dialog --title "LTO Backup" --msgbox "Thank you for using LTO-Backup." $HEIGHT $WIDTH

dialog --title "Confirmation" --yesno "This tool is still in development, accept risk and continue?" $HEIGHT $WIDTH

case $? in
    1)
        clear
        echo "Backup aborted."
        exit
    ;;
esac

tape_section=$(dialog \
    --backtitle "LTO Tape Type" \
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
      ;;
    2 )
      TAPE_SIZE=$LTO4_SIZE
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

detect_tape