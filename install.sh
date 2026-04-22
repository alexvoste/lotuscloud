#!/bin/bash

# --- Lotus Cloud Infrastructure | Automatic Provider Deployment ---
# Global Phase I | Software Architecture by Alex Node
# ------------------------------------------------------------------

set -e

# Цветовая схема
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Проверка на права root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Ошибка: Запустите скрипт через sudo.${NC}" 
   exit 1
fi

echo -e "${CYAN}${BOLD}🪷 LOTUS CLOUD | Infrastructure Initialization...${NC}"

# 1. ПРОВЕРКА СЕТИ
echo -e "\n${BOLD}[1/4] Диагностика сетевого окружения...${NC}"
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)
LOCAL_IP=$(hostname -I | awk '{print $1}')

if [ -z "$PUBLIC_IP" ]; then
    echo -e "${RED}❌ Нет доступа к сети. Проверьте подключение.${NC}"
    exit 1
fi

echo -e "Внешний IP: ${GREEN}$PUBLIC_IP${NC}"
if [[ "$PUBLIC_IP" == "$LOCAL_IP" ]]; then
    echo -e "${RED}⚠️ ВНИМАНИЕ: Кажется, вы за NAT (Серый IP). Необходим проброс портов.${NC}"
else
    echo -e "${GREEN}✅ Инфраструктура готова: Обнаружен прямой доступ.${NC}"
fi

# 2. УСТАНОВКА ЗАВИСИМОСТЕЙ (Универсальная)
echo -e "\n${BOLD}[2/4] Подготовка системных компонентов...${NC}"

if [ -f /etc/arch-release ]; then
    pacman -Syu --noconfirm docker docker-compose curl openssh
elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    apt-get update && apt-get install -y docker.io docker-compose curl openssh-server
elif [ -f /etc/redhat-release ]; then
    dnf install -y docker docker-compose curl openssh-server || yum install -y docker docker-compose curl openssh-server
else
    echo -e "${RED}Неизвестная система. Попробуйте установить Docker вручную.${NC}"
fi

# Запуск Docker
systemctl enable --now docker

# 3. АВТОРИЗАЦИЯ И КЛЮЧИ
echo -e "\n${BOLD}[3/4] Регистрация в реестре Lotus Cloud...${NC}"

if [ -z "$1" ]; then
    echo -en "${CYAN}Введите ваш NODE_ID из @lotus_x_bot: ${NC}"
    read NODE_ID
else
    NODE_ID=$1
fi

if [ -z "$NODE_ID" ]; then echo -e "${RED}ID не указан. Отмена.${NC}"; exit 1; fi

# Генерация ключа идентификации
if [ ! -f ~/.ssh/id_lotus ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_lotus -N "" -q
fi

# 4. ДЕПЛОЙ КОНТЕЙНЕРА
echo -e "\n${BOLD}[4/4] Развертывание транспортного узла...${NC}"

NODE_DIR="/opt/lotus-node"
mkdir -p "$NODE_DIR/data"
cd "$NODE_DIR"

# Скачиваем защищенный конфиг Xray из репозитория
echo "Загрузка конфигурации безопасности..."
curl -sSL https://raw.githubusercontent.com/alexvoste/lotuscloud/main/components/configs/xray_config.json > "$NODE_DIR/data/config.json"

# Создаем docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.9'
services:
  lotus-node:
    image: mzzsfy/marzban-node:latest
    container_name: lotus_node
    restart: always
    network_mode: host
    environment:
      - NODE_ID=$NODE_ID
      - XRAY_API_PORT=10001
      - XRAY_EXECUTABLE_PATH=/usr/local/bin/xray
    volumes:
      - ./data:/var/lib/marzban-node
EOF

# Запуск
docker-compose up -d

echo -e "\n${GREEN}${BOLD}✅ СИСТЕМА СТАБИЛИЗИРОВАНА. НОДА АКТИВНА!${NC}"
echo -e "Node ID: ${CYAN}$NODE_ID${NC}"
echo -e "--------------------------------------------------"
echo -e "Welcome to the Grid, Agent. Logic: Sovereign. Mode: Distributed."
