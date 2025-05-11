#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Устанавливаю зависимости(необходимое ПО).."
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Зависимости(необходимое ПО) установлены."

msg_info "Устанавливаю AdGuard Home"
$STD tar zxvf <(curl -fsSL https://static.adtidy.org/adguardhome/release/AdGuardHome_linux_amd64.tar.gz) -C /opt
msg_ok "AdGuard Home установлен"

msg_info "Создаю сервис"
cat <<EOF >/etc/systemd/system/AdGuardHome.service
[Unit]
Description=AdGuard Home: Блокировка на уровне сети
ConditionFileIsExecutable=/opt/AdGuardHome/AdGuardHome
After=syslog.target network-online.target

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHome/AdGuardHome "-s" "run"
WorkingDirectory=/opt/AdGuardHome
StandardOutput=file:/var/log/AdGuardHome.out
StandardError=file:/var/log/AdGuardHome.err
Restart=always
RestartSec=10
EnvironmentFile=-/etc/sysconfig/AdGuardHome

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now AdGuardHome.service
msg_ok "Создан сервис"

motd_ssh
customize

msg_info "Очистка"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Временные файлы установки - удалены!"
