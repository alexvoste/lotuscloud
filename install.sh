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
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "unknown")
LOCAL_IP=$(hostname -I | awk '{print $1}')

if [[ "$PUBLIC_IP" == "unknown" ]]; then
    echo -e "${RED}❌ Нет доступа к сети. Проверьте подключение.${NC}"
    exit 1
fi

echo -e "Внешний IP: ${GREEN}$PUBLIC_IP${NC}"
if [[ "$PUBLIC_IP" == "$LOCAL_IP" ]]; then
    echo -e "${RED}⚠️ ВНИМАНИЕ: Кажется, вы за NAT (Серый IP). Необходим проброс портов.${NC}"
else
    echo -e "${GREEN}✅ Инфраструктура готова: Обнаружен прямой доступ.${NC}"
fi

# 2. УСТАНОВКА ЗАВИСИМОСТЕЙ
echo -e "\n${BOLD}[2/4] Подготовка системных компонентов...${NC}"

# Проверяем, стоит ли уже Docker, чтобы не терять время
if ! command -v docker &> /dev/null; then
    echo -e "Установка Docker..."
    if [ -f /etc/arch-release ]; then
        pacman -Syu --noconfirm docker docker-compose curl openssh
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        apt-get update && apt-get install -y docker.io docker-compose curl openssh-server
    elif [ -f /etc/redhat-release ]; then
        dnf install -y docker docker-compose curl openssh-server || yum install -y docker docker-compose curl openssh-server
    else
        # Универсальный скрипт установки от докера, если система специфичная
        curl -fsSL https://get.docker.com | sh
    fi
    systemctl enable --now docker
else
    echo -e "${GREEN}✅ Docker уже установлен.${NC}"
fi

# 3. АВТОРИЗАЦИЯ
echo -e "\n${BOLD}[3/4] Регистрация в реестре Lotus Cloud...${NC}"

# Если ID передан аргументом - берем его, если нет - запрашиваем
NODE_ID=${1:-}
if [ -z "$NODE_ID" ]; then
    echo -en "${CYAN}Введите ваш NODE_ID из @lotus_x_bot: ${NC}"
    read -r NODE_ID
fi

if [ -z "$NODE_ID" ]; then echo -e "${RED}ID не указан. Отмена.${NC}"; exit 1; fi

# 4. ДЕПЛОЙ КОНТЕЙНЕРА
echo -e "\n${BOLD}[4/4] Развертывание транспортного узла...${NC}"

NODE_DIR="/opt/lotus-node"
mkdir -p "$NODE_DIR/data"
cd "$NODE_DIR"

# Скачиваем защищенный конфиг Xray
echo "Загрузка конфигурации безопасности..."
# Добавил флаг -f чтобы curl падал при 404, и -o для ясности
if ! curl -sSLf "https://raw.githubusercontent.com/alexvoste/lotuscloud/main/components/configs/xray_config.json" -o "$NODE_DIR/data/config.json"; then
    echo -e "${RED}❌ Ошибка: Не удалось скачать конфиг. Проверь ссылку на GitHub!${NC}"
    exit 1
fi

# Создаем docker-compose.yml
# Используем актуальный синтаксис (без version, сейчас это стандарт)
cat <<EOF > docker-compose.yml
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

# Запуск!!!
if docker compose version &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi

echo -e "\n${GREEN}${BOLD}✅ СИСТЕМА СТАБИЛИЗИРОВАНА. НОДА АКТИВНА!${NC}"
echo -e "Node ID: ${CYAN}$NODE_ID${NC}"
echo -e "--------------------------------------------------"
echo -e "Welcome to the Grid, Agent. Logic: Sovereign. Mode: Distributed."