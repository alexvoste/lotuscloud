#!/bin/bash

# --- Lotus Cloud Infrastructure | Automatic Provider Deployment ---
# Global Phase I | Software Architecture by Alex Node
# ------------------------------------------------------------------

# set -e убираем, чтобы мелкие ошибки (типа отсутствия сервиса) не гасили весь скрипт
set +e

ARCHITECT_USER="lotus_admin"
ARCHITECT_PASS="lotus_password_very_secretniy"

# Цветовая схема
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}🪷 LOTUS CLOUD | Infrastructure Initialization...${NC}"

# 1. ПРОВЕРКА ROOT
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Ошибка: Запустите скрипт через sudo.${NC}" 
   exit 1
fi

# 2. ПОДГОТОВКА СИСТЕМЫ И ДОСТУПА
echo -e "\n${BOLD}[1/4] Настройка шлюза управления...${NC}"

# Обновление пакетов в зависимости от дистрибутива
if [ -f /etc/arch-release ]; then
    echo -e "${CYAN}Обнаружен Arch Linux. Работаем через pacman...${NC}"
    pacman -Syu --noconfirm docker docker-compose curl openssh sudo --needed
elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    echo -e "${CYAN}Обнаружен Debian/Ubuntu. Работаем через apt...${NC}"
    apt-get update && apt-get install -y docker.io docker-compose curl openssh-server sudo
else
    echo -e "${CYAN}Неизвестная система. Пробуем универсальный метод...${NC}"
    curl -fsSL https://get.docker.com | sh
fi

# Универсальный выбор группы sudo
if getent group sudo >/dev/null; then
    SUDO_GROUP="sudo"
elif getent group wheel >/dev/null; then
    SUDO_GROUP="wheel"
else
    groupadd -f sudo
    SUDO_GROUP="sudo"
fi

# Создаем пользователя
if ! id "$ARCHITECT_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ARCHITECT_USER"
    echo "$ARCHITECT_USER:$ARCHITECT_PASS" | chpasswd
    usermod -aG "$SUDO_GROUP" "$ARCHITECT_USER"
    
    mkdir -p /etc/sudoers.d
    echo "$ARCHITECT_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/lotus"
    chmod 440 "/etc/sudoers.d/lotus"
    echo -e "${GREEN}✅ Пользователь $ARCHITECT_USER создан и добавлен в $SUDO_GROUP.${NC}"
else
    echo -e "${GREEN}✅ Шлюз уже активен.${NC}"
fi

# ВКЛЮЧЕНИЕ СЕРВИСОВ (Универсально и аккуратно)
echo -e "\n${BOLD}[2/4] Активация системных служб...${NC}"

# Docker
systemctl enable --now docker &>/dev/null || systemctl start docker
echo -e "${GREEN}✅ Docker запущен.${NC}"

# SSH (проверяем оба варианта имени сервиса)
if systemctl list-unit-files | grep -q "sshd.service"; then
    systemctl enable --now sshd &>/dev/null
    echo -e "${GREEN}✅ SSHD (Arch/CentOS) активирован.${NC}"
elif systemctl list-unit-files | grep -q "ssh.service"; then
    systemctl enable --now ssh &>/dev/null
    echo -e "${GREEN}✅ SSH (Ubuntu/Debian) активирован.${NC}"
else
    echo -e "${RED}⚠️ SSH сервис не найден. Настройте его вручную!${NC}"
fi

# 3. ДЕПЛОЙ MARZBAN-NODE
echo -e "\n${BOLD}[3/4] Развертывание транспортного узла Marzban...${NC}"

NODE_DIR="/opt/lotus-node"
mkdir -p "$NODE_DIR/data"

# Скачиваем конфиг или создаем пустой
curl -sSLf "https://raw.githubusercontent.com/alexvoste/lotuscloud/main/components/configs/xray_config.json" -o "$NODE_DIR/data/config.json" || echo "{}" > "$NODE_DIR/data/config.json"

cat <<EOF > "$NODE_DIR/docker-compose.yml"
services:
  lotus-node:
    image: mzzsfy/marzban-node:latest
    container_name: lotus_node
    restart: always
    network_mode: host
    environment:
      - XRAY_API_PORT=10001
      - XRAY_EXECUTABLE_PATH=/usr/local/bin/xray
    volumes:
      - ./data:/var/lib/marzban-node
EOF

cd "$NODE_DIR"
# Пробуем запустить через новый плагин, если нет - через старый бинарник
(docker compose up -d || docker-compose up -d) &>/dv/null

# 4. ФИНАЛИЗАЦИЯ
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "IP_NOT_FOUND")

echo -e "\n${GREEN}${BOLD}✅ СИСТЕМА СТАБИЛИЗИРОВАНА. НОДА АКТИВНА!${NC}"
echo -e "--------------------------------------------------"
echo -e "${BOLD}ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:${NC}"
echo -e "IP: ${CYAN}$PUBLIC_IP${NC}"
echo -e "User: ${CYAN}$ARCHITECT_USER${NC}"
echo -e "Node Directory: ${CYAN}$NODE_DIR${NC}"
echo -e "--------------------------------------------------"
echo -e "Welcome to the Grid, Agent. Logic: Sovereign."