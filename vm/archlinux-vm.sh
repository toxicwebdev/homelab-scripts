#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/LICENSE

source /dev/stdin <<<$(curl -fsSL https://raw.githubusercontent.com/toxicwebdev/homelab-scripts/main/misc/api.func)

function header_info {
  clear
  cat <<"EOF"
    ___              __       __    _                     _    ____  ___
   /   |  __________/ /_     / /   (_)___  __  ___  __   | |  / /  |/  /
  / /| | / ___/ ___/ __ \   / /   / / __ \/ / / / |/_/   | | / / /|_/ /
 / ___ |/ /  / /__/ / / /  / /___/ / / / / /_/ />  <     | |/ / /  / /
/_/  |_/_/   \___/_/ /_/  /_____/_/_/ /_/\__,_/_/|_|     |___/_/  /_/

EOF
}
header_info
echo -e "\n Загрузка..."
#API VARIABLES
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="arch-linux-vm"
var_os="arch-linux"
var_version=" "
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")

CL=$(echo "\033[m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
OS="${TAB}🖥️${TAB}${CL}"
CONTAINERTYPE="${TAB}📦${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
GATEWAY="${TAB}🌐${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"
MACADDRESS="${TAB}🔗${TAB}${CL}"
VLANTAG="${TAB}🏷️${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"

THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  post_update_to_api "failed" "${commad}"
  local error_message="${RD}[ОШИБКА]${CL} в строке ${RD}$line_number${CL}: код завершился ${RD}$exit_code${CL}: при выполнении команды ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status "$VMID" &>/dev/null; then
    qm stop "$VMID" &>/dev/null
    qm destroy "$VMID" &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf "$TEMP_DIR"
}

TEMP_DIR=$(mktemp -d)
pushd "$TEMP_DIR" >/dev/null
if whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "Arch Linux VM" --yesno "Это создаст новую виртуальную машину Arch Linux. Продолжить?" 10 58; then
  :
else
  header_info && echo -e "${CROSS}${RD}Пользователь вышел из скрипта${CL}\n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne "${TAB}${YW}${HOLD}${msg}${HOLD}"
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR}${CM}${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR}${CROSS}${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Пожалуйста, запустите этот скрипт от имени root."
    echo -e "\nВыход..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8\.[1-3](\.[0-9]+)*"; then
    msg_error "${CROSS}${RD}Эта версия Proxmox Virtual Environment не поддерживается"
    echo -e "Требуется версия Proxmox Virtual Environment 8.1 или более поздняя."
    echo -e "Выход..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${INFO}${YWB}Этот скрипт не будет работать с PiMox! \n"
    echo -e "\n ${YWB}Посетите https://github.com/asylumexp/Proxmox для поддержки ARM64. \n"
    echo -e "Выход..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --defaultno --title "SSH DETECTED" --yesno "Предлагается использовать проксимный терминал вместо SSH, так как SSH может создавать проблемы при сборе переменных. Хотите продолжить использование SSH?" 10 62; then
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
  echo -e "\n${CROSS}${RD}Пользователь вышел из скрипта${CL}\n"
  exit
}

function default_settings() {
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_SIZE="4G"
  DISK_CACHE=""
  HN="arch-linux"
  CPU_TYPE=""
  CORE_COUNT="1"
  RAM_SIZE="1024"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  METHOD="default"
  echo -e "${CONTAINERID}${BOLD}${DGN}ID виртуальной машины: ${BGN}${VMID}${CL}"
  echo -e "${CONTAINERTYPE}${BOLD}${DGN}Тип машины: ${BGN}i440fx${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Размер диска: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Кэш диска: ${BGN}None${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${OS}${BOLD}${DGN}Модель CPU: ${BGN}KVM64${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}Количество ядер CPU: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}Размер RAM: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Мост: ${BGN}${BRG}${CL}"
  echo -e "${MACADDRESS}${BOLD}${DGN}MAC-адрес: ${BGN}${MAC}${CL}"
  echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}По умолчанию${CL}"
  echo -e "${DEFAULT}${BOLD}${DGN}Размер MTU интерфейса: ${BGN}По умолчанию${CL}"
  echo -e "${GATEWAY}${BOLD}${DGN}Запуск ВМ при завершении: ${BGN}да${CL}"
  echo -e "${CREATING}${BOLD}${DGN}Создание Arch Linux VM с использованием вышеуказанных стандартных настроек${CL}"
}

function advanced_settings() {
  METHOD="advanced"
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите ID виртуальной машины" 8 58 "$NEXTID" --title "ID ВИРТУАЛЬНОЙ МАШИНЫ" --cancel-button Выход 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID уже используется${CL}"
        sleep 2
        continue
      fi
      echo -e "${CONTAINERID}${BOLD}${DGN}ID виртуальной машины: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if MACH=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "MACHINE TYPE" --radiolist --cancel-button Выход "Выберите тип" 10 58 2 \
    "i440fx" "Машина i440fx" ON \
    "q35" "Машина q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ "$MACH" = q35 ]; then
      echo -e "${CONTAINERTYPE}${BOLD}${DGN}Тип машины: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${CONTAINERTYPE}${BOLD}${DGN}Тип машины: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите размер диска в GiB (например, 10, 20)" 8 58 "$DISK_SIZE" --title "РАЗМЕР ДИСКА" --cancel-button Выход 3>&1 1>&2 2>&3); then
    DISK_SIZE=$(echo "$DISK_SIZE" | tr -d ' ')
    if [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then
      DISK_SIZE="${DISK_SIZE}G"
      echo -e "${DISKSIZE}${BOLD}${DGN}Размер диска: ${BGN}$DISK_SIZE${CL}"
    elif [[ "$DISK_SIZE" =~ ^[0-9]+G$ ]]; then
      echo -e "${DISKSIZE}${BOLD}${DGN}Размер диска: ${BGN}$DISK_SIZE${CL}"
    else
      echo -e "${DISKSIZE}${BOLD}${RD}Недопустимый размер диска. Пожалуйста, используйте число (например, 10 или 10G).${CL}"
      exit-script
    fi
  else
    exit-script
  fi

  if DISK_CACHE=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "DISK CACHE" --radiolist "Выберите" --cancel-button Выход 10 58 2 \
    "0" "None (По умолчанию)" ON \
    "1" "Write Through" OFF \
    3>&1 1>&2 2>&3); then
    if [ "$DISK_CACHE" = "1" ]; then
      echo -e "${DISKSIZE}${BOLD}${DGN}Кэш диска: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${DISKSIZE}${BOLD}${DGN}Кэш диска: ${BGN}None${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите имя хоста" 8 58 arch-linux --title "ИМЯ ХОСТА" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$VM_NAME" ]; then
      HN="arch-linux"
      echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo "${VM_NAME,,}" | tr -d ' ')
      echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "CPU MODEL" --radiolist "Выберите" --cancel-button Выход 10 58 2 \
    "0" "KVM64 (По умолчанию)" ON \
    "1" "Host" OFF \
    3>&1 1>&2 2>&3); then
    if [ "$CPU_TYPE1" = "1" ]; then
      echo -e "${OS}${BOLD}${DGN}Модель CPU: ${BGN}Host${CL}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${OS}${BOLD}${DGN}Модель CPU: ${BGN}KVM64${CL}"
      CPU_TYPE=""
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Allocate CPU Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z "$CORE_COUNT" ]; then
      CORE_COUNT="2"
      echo -e "${CPUCORE}${BOLD}${DGN}Количество ядер CPU: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${CPUCORE}${BOLD}${DGN}Количество ядер CPU: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Выделить RAM в MiB" 8 58 2048 --title "RAM" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$RAM_SIZE" ]; then
      RAM_SIZE="2048"
      echo -e "${RAMSIZE}${BOLD}${DGN}Размер RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${RAMSIZE}${BOLD}${DGN}Размер RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите мост" 8 58 vmbr0 --title "МОСТ" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$BRG" ]; then
      BRG="vmbr0"
      echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите MAC-адрес" 8 58 "$GEN_MAC" --title "MAC-АДРЕС" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$MAC1" ]; then
      MAC="$GEN_MAC"
      echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите VLAN (оставьте пустым для значения по умолчанию)" 8 58 --title "VLAN" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$VLAN1" ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --inputbox "Установите размер MTU интерфейса (оставьте пустым для значения по умолчанию)" 8 58 --title "РАЗМЕР MTU" --cancel-button Выход 3>&1 1>&2 2>&3); then
    if [ -z "$MTU1" ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DEFAULT}${BOLD}${DGN}Размер MTU интерфейса: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DEFAULT}${BOLD}${DGN}Размер MTU интерфейса: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "ЗАПУСК ВИРТУАЛЬНОЙ МАШИНЫ" --yesno "Запустить ВМ при завершении?" 10 58); then
    echo -e "${GATEWAY}${BOLD}${DGN}Запуск ВМ при завершении: ${BGN}да${CL}"
    START_VM="yes"
  else
    echo -e "${GATEWAY}${BOLD}${DGN}Запуск ВМ при завершении: ${BGN}нет${CL}"
    START_VM="no"
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "РАСШИРЕННЫЕ НАСТРОЙКИ ЗАВЕРШЕНЫ" --yesno "Готовы создать Arch Linux VM?" --no-button Do-Over 10 58); then
    echo -e "${CREATING}${BOLD}${DGN}Создание Arch Linux VM с использованием вышеуказанных расширенных настроек${CL}"
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Использование расширенных настроек${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "НАСТРОЙКИ" --yesno "Использовать стандартные настройки?" --no-button Расширенные 10 58); then
    header_info
    echo -e "${DEFAULT}${BOLD}${BL}Использование стандартных настроек${CL}"
    default_settings
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Использование расширенных настроек${CL}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script
post_to_api_vm

msg_info "Проверка хранилища"
while read -r line; do
  TAG=$(echo "$line" | awk '{print $1}')
  TYPE=$(echo "$line" | awk '{printf "%-10s", $2}')
  FREE=$(echo "$line" | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Не удалось обнаружить допустимое местоположение хранилища."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts: ToxicWeb Edition v0.1.0" --title "Storage Pools" --radiolist \
      "Какое хранилище вы хотите использовать для ${HN}?\nЧтобы сделать выбор, используйте пробел.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Использование ${CL}${BL}$STORAGE${CL} ${GN}для местоположения хранилища."
msg_ok "ID виртуальной машины ${CL}${BL}$VMID${CL}."
msg_info "Получение URL для архива Arch Linux .iso"
URL=https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
curl -f#SL -o "$(basename "$URL")" "$URL"
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Загрузка ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage "$STORAGE" | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir | cifs)
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
  eval DISK"${i}"=vm-"${VMID}"-disk-"${i}""${DISK_EXT:-}"
  eval DISK"${i}"_REF="${STORAGE}":"${DISK_REF:-}""${!disk}"
done

msg_info "Создание Arch Linux VM"
qm create "$VMID" -agent 1"${MACHINE}" -tablet 0 -localtime 1 -bios ovmf"${CPU_TYPE}" -cores "$CORE_COUNT" -memory "$RAM_SIZE" \
  -name "$HN" -tags community-script -net0 virtio,bridge="$BRG",macaddr="$MAC""$VLAN""$MTU" -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc "$STORAGE" "$VMID" "$DISK0" 4M 1>&/dev/null
qm importdisk "$VMID" "${FILE}" "$STORAGE" "${DISK_IMPORT:-}" 1>&/dev/null
qm set "$VMID" \
  -efidisk0 "${DISK0_REF}"${FORMAT} \
  -scsi0 "${DISK1_REF}",${DISK_CACHE}${THIN}size="${DISK_SIZE}" \
  -ide2 "${STORAGE}":cloudinit \
  -boot order=scsi0 \
  -serial0 socket \
  -description "<div align='center'><a href='https://github.com/toxicwebdev'><img src='https://github.com/toxicwebdev/toxicblue/blob/main/assets/toxic.png'/></a>

  # ArchLinux VM
  </div>" >/dev/null

if [ -n "$DISK_SIZE" ]; then
  msg_info "Изменение размера диска до $DISK_SIZE GB"
  qm resize "$VMID" scsi0 "${DISK_SIZE}" >/dev/null
else
  msg_info "Использование размера диска по умолчанию $DEFAULT_DISK_SIZE GB"
  qm resize "$VMID" scsi0 "${DEFAULT_DISK_SIZE}" >/dev/null
fi

msg_ok "Создан Arch Linux VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Запуск Arch Linux VM"
  qm start "$VMID"
  msg_ok "Запущен Arch Linux VM"
fi
post_update_to_api "done" "none"

msg_ok "Успешно завершено!\n"
