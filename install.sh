#!/bin/bash

# --- Lotus Cloud Infrastructure | Automatic Provider Deployment ---
# URL: https://github.com/alexvoste/lotuscloud
# ------------------------------------------------------------------

set -e

# Оформление
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}🪷 LOTUS CLOUD | Инициализация ноды...${NC}"

# 1. ПРОВЕРКА СЕТЕВОГО ОКРУЖЕНИЯ (Pre-flight Check)
echo -e "\n${BOLD}[1/4] Диагностика сети...${NC}"

# Получаем внешний IP
PUBLIC_IP=$(curl -s https://ifconfig.me)
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo -e "Внешний IP: ${GREEN}$PUBLIC_IP${NC}"
echo -e "Локальный IP: ${GREEN}$LOCAL_IP${NC}"

if [[ "$PUBLIC_IP" == "$LOCAL_IP" ]]; then
    echo -e "${RED}⚠️ ВНИМАНИЕ: Кажется, вы за NAT (Серый IP).${NC}"
    echo -e "Для работы ноды в Phase I необходим проброс портов на роутере."
else
    echo -e "${GREEN}✅ Обнаружен прямой доступ/Белый IP.${NC}"
fi

# 2. ПОДГОТОВКА СИСТЕМЫ
echo -e "\n${BOLD}[2/4] Проверка зависимостей...${NC}"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Проверка дистрибутива
    if [ -f /etc/arch-release ]; then
        echo "Система: Arch Linux. Обновляем репозитории..."
        sudo pacman -Syu --noconfirm docker docker-compose curl
    elif [ -f /etc/debian_version ]; then
        echo "Система: Debian/Ubuntu. Установка зависимостей..."
        sudo apt update && sudo apt install -y docker.io docker-compose curl
    fi
    
    # Автозапуск Докера
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER || true
    echo -e "${GREEN} Docker готов к работе.${NC}"
else
    echo -e "${RED} Скрипт оптимизирован под Linux (Arch/Debian).${NC}"
    exit 1
fi

# 3. РЕГИСТРАЦИЯ В СЕТИ
echo -e "\n${BOLD}[3/4] Авторизация узла...${NC}"

# Если скрипт запущен без аргументов, запрашиваем ввод
if [ -z "$1" ]; then
    echo -en "${CYAN}Введите ваш NODE_ID из @lotus_x_bot: ${NC}"
    read NODE_ID
else
    NODE_ID=$1
fi

# Генерация ключей идентификации, если их нет
if [ ! -f ~/.ssh/id_lotus ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_lotus -N "" -q
fi

# 4. РАЗВЕРТЫВАНИЕ КОНТЕЙНЕРА
echo -e "\n${BOLD}[4/4] Запуск контейнера инфраструктуры...${NC}"

mkdir -p ~/lotus-node/data
cd ~/lotus-node

cat <<EOF > docker-compose.yml
version: '3.9'
services:
  lotus-node:
    image: mzzsfy/marzban-node:latest
    container_name: lotus_node_$NODE_ID
    restart: always
    network_mode: host
    environment:
      - NODE_ID=$NODE_ID
      - XRAY_API_PORT=10001
    volumes:
      - ./data:/var/lib/marzban-node
EOF

sudo docker-compose up -d

echo -e "\n${GREEN}${BOLD} НОДА УСПЕШНО ЗАПУЩЕНА!${NC}"
echo -e "Идентификатор: ${CYAN}$NODE_ID${NC}"
echo -e "Статус можно проверить в Telegram-боте."
echo -e "--------------------------------------------------"
echo -e "Welcome to the Grid, Alex Node. Mission starts now."
