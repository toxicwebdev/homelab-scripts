#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE

# App Default Values
APP="Alpine-Docker"
var_tags="docker;alpine"
var_cpu="1"
var_ram="1024"
var_disk="2"
var_os="alpine"
var_version="3.20"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  if ! apk -e info newt >/dev/null 2>&1; then
    apk add -q newt
  fi
  while true; do
    CHOICE=$(
      whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "ПОДДЕРЖКА" --menu "Выберите опцию" 11 58 1 \
        "1" "Проверить наличие обновлений для Docker" 3>&2 2>&1 1>&3
    )
    exit_status=$?
    if [ $exit_status == 1 ]; then
      clear
      exit-script
    fi
    header_info
    case $CHOICE in
    1)
      apk update && apk upgrade
      exit
      ;;
    esac
  done
}

start
build_container
description

msg_ok "Установка успешно завершена!\n"
