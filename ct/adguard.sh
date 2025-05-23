#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE
# Source: https://adguard.com/

# App Default Values
APP="Adguard"
var_tags="adblock"
var_cpu="1"
var_ram="512"
var_disk="2"
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
    if [[ ! -d /opt/AdGuardHome ]]; then
        msg_error "Отсутствует установленная версия ${APP}"
        exit
    fi
    msg_error "Adguard Home должен быть обновлен через пользовательский интерфейс."
    exit
}

start
build_container
description

msg_ok "Установка успешно завершена!\n"
echo -e "${CREATING}${GN}${APP} Установка успешно завершена!${CL}"
echo -e "${INFO}${YW} Сервис доступен по ссылке:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
