#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE
# Source: https://casaos.io/

# App Default Values
APP="CasaOS"
var_tags="cloud"
var_cpu="2"
var_ram="2048"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
   header_info
   check_container_storage
   check_container_resources
   if [[ ! -d /var ]]; then
      msg_error "Отсутствует установленная версия ${APP}"
      exit
   fi
   msg_info "Обновляю ${APP} LXC"
   apt-get update &>/dev/null
   apt-get -y upgrade &>/dev/null
   msg_ok "Updated ${APP} LXC"
   exit
}

start
build_container
description

msg_ok "Установка успешно завершена!\n"
echo -e "${CREATING}${GN}${APP} Установка успешно завершена!${CL}"
echo -e "${INFO}${YW} Сервис доступен по ссылке:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
