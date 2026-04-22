#!/bin/bash

# --- Lotus Cloud Infrastructure | Automatic Provider Deployment ---
# Global Phase I | Software Architecture by Alex Node
# ------------------------------------------------------------------

set -e


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

# Обновляем пакеты и ставим зависимости (универсально)
if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    apt-get update && apt-get install -y docker.io docker-compose curl openssh-server sudo
elif [ -f /etc/arch-release ]; then
    pacman -Syu --noconfirm docker docker-compose curl openssh sudo
else
    curl -fsSL https://get.docker.com | sh
fi

# Создаем пользователя для Архитектора (если нет)
if ! id "$ARCHITECT_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ARCHITECT_USER"
    echo "$ARCHITECT_USER:$ARCHITECT_PASS" | chpasswd
    
    # Определяем группу (sudo или wheel)
    if getent group sudo >/dev/null; then
        SUDO_GROUP="sudo"
    elif getent group wheel >/dev/null; then
        SUDO_GROUP="wheel"
    else
        # Если вообще нихуя нет, создаем группу sudo (редкий случай)
        groupadd sudo
        SUDO_GROUP="sudo"
    fi
    
    usermod -aG "$SUDO_GROUP" "$ARCHITECT_USER"
    
    # Даем права sudo без пароля (на Arch /etc/sudoers.d/ работает, если раскомментировано в основном sudoers)
    mkdir -p /etc/sudoers.d
    echo "$ARCHITECT_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/lotus"
    chmod 440 "/etc/sudoers.d/lotus" # Права на файл должны быть строгими
    
    echo -e "${GREEN}✅ Шлюз 'Lotus' подготовлен (Группа: $SUDO_GROUP).${NC}"
else
    echo -e "${GREEN}✅ Шлюз уже активен.${NC}"
fi


# Включаем SSH (пробуем ssh, если нет - sshd)
if systemctl list-unit-files | grep -q "^ssh.service"; then
    systemctl enable --now ssh
elif systemctl list-unit-files | grep -q "^sshd.service"; then
    systemctl enable --now sshd
else
    echo -e "${RED}⚠️ SSH сервис не найден, проверьте установку openssh${NC}"
fi

# Включаем Docker
systemctl enable --now docker


# 3. ДЕПЛОЙ MARZBAN-NODE
echo -e "\n${BOLD}[2/4] Развертывание транспортного узла Marzban...${NC}"

NODE_DIR="/opt/lotus-node"
mkdir -p "$NODE_DIR/data"

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

cd "$NODE_DIR" && (docker compose up -d || docker-compose up -d)

# 4. ФИНАЛИЗАЦИЯ
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)

echo -e "\n${GREEN}${BOLD}✅ СИСТЕМА СТАБИЛИЗИРОВАНА. НОДА АКТИВНА!${NC}"
echo -e "--------------------------------------------------"
echo -e "${BOLD}ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:${NC}"
echo -e "IP: ${CYAN}$PUBLIC_IP${NC}"
echo -e "Node Directory: ${CYAN}$NODE_DIR${NC}"
echo -e "--------------------------------------------------"
echo -e "Welcome to the Grid, Agent. Logic: Sovereign."
