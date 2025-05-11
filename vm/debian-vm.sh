#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    ____       __    _                ______
   / __ \___  / /_  (_)___ _____     <  /__ \
  / / / / _ \/ __ \/ / __ `/ __ \    / /__/ /
 / /_/ /  __/ /_/ / / /_/ / / / /   / // __/
/_____/\___/_.___/_/\__,_/_/ /_/   /_//____/

EOF
}
header_info
echo -e "\n Загрузка..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ОШИБКА]${CL} в строке ${RD}$line_number${CL}: код завершился ${RD}$exit_code${CL}: при выполнении команды ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "Debian 12 VM" --yesno "Это создаст новую виртуальную машину Debian 12. Продолжить?" 10 58; then
  :
else
  header_info && echo -e "⚠ Пользователь вышел из скрипта \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Пожалуйста запустите данный скрипт под пользователем root."
    echo -e "\nВыхожу..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
    msg_error "Эта версия Proxmox Virtual Environment не поддерживается"
    echo -e "Требуется Proxmox Virtual Environment версии 8.1 и выше."
    echo -e "Выход..."
    sleep 2
    exit
fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "Этот скрипт не будет работать с PiMox! \n"
    echo -e "Выход..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --defaultno --title "Обнаружено подключение по SSH" --yesno "Рекомендуется использовать проксимный терминал вместо SSH, так как SSH может создавать проблемы при сборе переменных. Хотите продолжить использование SSH?" 10 62; then
        echo "Вы были предупреждены"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  Пользователь вышел из скрипта \n"
  exit
}

function default_settings() {
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE=""
  HN="debian"
  CPU_TYPE=""
  CORE_COUNT="2"
  RAM_SIZE="2048"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  echo -e "${DGN}Используемый ID виртуальной машины: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Используемый тип машины: ${BGN}i440fx${CL}"
  echo -e "${DGN}Используемый кэш диска: ${BGN}None${CL}"
  echo -e "${DGN}Используемый Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}Используемая модель CPU: ${BGN}KVM64${CL}"
  echo -e "${DGN}Количество ядер CPU: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Размер RAM: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}Используемый Мост: ${BGN}${BRG}${CL}"
  echo -e "${DGN}Используемый MAC-адрес: ${BGN}${MAC}${CL}"
  echo -e "${DGN}Используемый VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}Используемый размер MTU интерфейса: ${BGN}Default${CL}"
  echo -e "${DGN}Запуск ВМ при завершении: ${BGN}yes${CL}"
  echo -e "${BL}Создание Debian 12 VM с использованием вышеуказанных стандартных настроек${CL}"
}

function advanced_settings() {
  while true; do
    if VMID=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите ID виртуальной машины" 8 58 $NEXTID --title "ID ВИРТУАЛЬНОЙ МАШИНЫ" --cancel-button Выход 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID уже используется${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}ID виртуальной машины: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if MACH=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "ТИП МАШИНЫ" --radiolist --cancel-button Exit-Script "Выберите тип" 10 58 2 \
    "i440fx" "Машина i440fx" ON \
    "q35" "Машина q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${DGN}Используемый тип машины: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${DGN}Используемый тип машины: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_CACHE=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "КЭШ ДИСКА" --radiolist "Выберите" --cancel-button Exit-Script 10 58 2 \
    "0" "Нет (По умолчанию)" ON \
    "1" "Write Through" OFF \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE = "1" ]; then
      echo -e "${DGN}Используемый кэш диска: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${DGN}Используемый кэш диска: ${BGN}None${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите имя хоста(hostname)" 8 58 debian --title "ИМЯ ХОСТА(HOSTNAME)" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="debian"
      echo -e "${DGN}Используемый Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Используемый Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "ТИП ПРОЦЕССОРА" --radiolist "Выберите" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64 (По умолчанию)" ON \
    "1" "Host" OFF \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${DGN}Используемая модель CPU: ${BGN}Host${CL}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${DGN}Используемая модель CPU: ${BGN}KVM64${CL}"
      CPU_TYPE=""
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите кол-во процессорных ядер(CPU count)" 8 58 2 --title "КОЛИЧЕСТВО ПРОЦЕССОРНЫХ ЯДЕР(CPU COUNT)" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
      echo -e "${DGN}Количество ядер CPU: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Количество ядер CPU: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите ОЗУ в MiB" 8 58 2048 --title "ОЗУ" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="2048"
      echo -e "${DGN}Размер RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Размер RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите сетевой мост(bridge)" 8 58 vmbr0 --title "СЕТЕВОЙ МОСТ(BRIDGE)" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}Используемый Мост: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Используемый Мост: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Настройка MAC адресса" 8 58 $GEN_MAC --title "MAC АДРЕС" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}Используемый MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}Используемый MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Укажите Vlan(оставьте пустым для использования параметров по умолчанию)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}Используемый Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Используемый Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --inputbox "Set Interface MTU Size (оставьте пустым для использования параметров по умолчанию)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}Используемый размер MTU интерфейса: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Используемый размер MTU интерфейса: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "START VIRTUAL MACHINE" --yesno "Запуск ВМ при завершении?" 10 58); then
    echo -e "${DGN}Запуск ВМ при завершении: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Запуск ВМ при завершении: ${BGN}no${CL}"
    START_VM="no"
  fi

  if (whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "РАСШИРЕННЫЕ НАСТРОЙКИ ЗАВЕРШЕНЫ" --yesno " Готовы к созданию Debian 12 VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Создание Debian 12 VM с использованием вышеуказанных расширенных настроек${CL}"
  else
    header_info
    echo -e "${RD}Используются расширенные настройки${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "НАСТРОЙКИ" --yesno "Использовать стандартные настройки?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Используются стандартные настройки${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Используются расширенные настройки${CL}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script

msg_info "Проверяю Хранилище"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Не удается обнаружить действительное место хранения."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0 --title "ХРАНИЛИЩЕ ДЛЯ ДАННЫХ" --radiolist \
      "Какой пул хранения вы хотели бы использовать ${HN}?\nЧтобы сделать выбор, используйте пробел.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Используется ${CL}${BL}$STORAGE${CL} ${GN}для места хранения."
msg_ok "Virtual Machine ID ${CL}${BL}$VMID${CL}."
msg_info "Запрос на получение URL для образа диска Qcow2 Debian 12"
URL=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Загрузка ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  THIN=""
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  FORMAT=",efitype=4m"
  THIN=""
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

msg_info "Создание Debian 12 VM"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -tags proxmox-helper-scripts -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=2G \
  -boot order=scsi0 \
  -serial0 socket \
  -description "<div align='center'><a href='https://github.com/toxicwebdev'><img src='https://github.com/toxicwebdev/toxicblue/blob/main/assets/toxic.png'/></a>

  # Debian VM
  </div>" >/dev/null
qm resize $VMID scsi0 4G >/dev/null

msg_ok "Создание Debian 12 VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Запускаю Debian 12 VM"
  qm start $VMID
  msg_ok "Запустил Debian 12 VM"
fi
msg_ok "Установка успешно завершена!\n"
echo "More Info at https://github.com/community-scripts/ProxmoxVE/discussions/836"
