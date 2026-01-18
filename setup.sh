#!/bin/bash

#==============================================================================
# Скрипт автоматической настройки безопасности сервера
# Использование: curl -sSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/setup.sh | bash
#==============================================================================

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# Функции вывода
#==============================================================================
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}\n"
}

#==============================================================================
# Проверка прав root
#==============================================================================
if [[ $EUID -ne 0 ]]; then
   print_error "Этот скрипт должен быть запущен с правами root"
   exit 1
fi

#==============================================================================
# Приветствие и сбор данных
#==============================================================================
clear
print_header "АВТОМАТИЧЕСКАЯ НАСТРОЙКА БЕЗОПАСНОСТИ СЕРВЕРА"

echo -e "${BLUE}Этот скрипт выполнит следующие действия:${NC}"
echo "  • Обновление системы"
echo "  • Установка необходимых пакетов (sudo, fail2ban, mc)"
echo "  • Создание нового пользователя с sudo-правами"
echo "  • Настройка SSH (отключение входа под root)"
echo "  • Настройка fail2ban для защиты от брутфорса"
echo ""

read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Установка отменена"
    exit 0
fi

#==============================================================================
# Сбор информации от пользователя
#==============================================================================
print_header "ВВОД ПАРАМЕТРОВ НАСТРОЙКИ"

# Имя пользователя
while true; do
    read -p "Введите имя нового пользователя: " USERNAME
    if [[ -z "$USERNAME" ]]; then
        print_error "Имя пользователя не может быть пустым"
        continue
    fi
    if id "$USERNAME" &>/dev/null; then
        print_warning "Пользователь $USERNAME уже существует"
        read -p "Использовать существующего пользователя? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USER_EXISTS=true
            break
        fi
    else
        USER_EXISTS=false
        break
    fi
done

# Пароль (только для нового пользователя)
if [[ "$USER_EXISTS" == false ]]; then
    while true; do
        read -s -p "Введите пароль для пользователя $USERNAME: " PASSWORD
        echo
        if [[ ${#PASSWORD} -lt 8 ]]; then
            print_error "Пароль должен содержать минимум 8 символов"
            continue
        fi
        read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM
        echo
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            print_error "Пароли не совпадают"
            continue
        fi
        break
    done
fi

# SSH порт
read -p "Изменить SSH порт? (по умолчанию 22) [y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    while true; do
        read -p "Введите новый SSH порт (1024-65535): " SSH_PORT
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1024 ] && [ "$SSH_PORT" -le 65535 ]; then
            break
        else
            print_error "Неверный порт. Введите число от 1024 до 65535"
        fi
    done
else
    SSH_PORT=22
fi

# IP адреса для игнорирования в fail2ban
read -p "Введите IP адреса для игнорирования в fail2ban (через пробел, Enter для пропуска): " IGNORE_IPS
if [[ -z "$IGNORE_IPS" ]]; then
    IGNORE_IPS="127.0.0.1/8"
else
    IGNORE_IPS="127.0.0.1/8 $IGNORE_IPS"
fi

# Параметры fail2ban
read -p "Максимальное количество попыток входа (по умолчанию 3): " MAXRETRY
MAXRETRY=${MAXRETRY:-3}

read -p "Время бана в часах (по умолчанию 24): " BANTIME_HOURS
BANTIME_HOURS=${BANTIME_HOURS:-24}

#==============================================================================
# Подтверждение параметров
#==============================================================================
print_header "ПОДТВЕРЖДЕНИЕ ПАРАМЕТРОВ"
echo "Имя пользователя: $USERNAME"
echo "SSH порт: $SSH_PORT"
echo "Fail2ban - игнорируемые IP: $IGNORE_IPS"
echo "Fail2ban - макс. попыток: $MAXRETRY"
echo "Fail2ban - время бана: ${BANTIME_HOURS}ч"
echo ""

read -p "Начать установку с этими параметрами? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Установка отменена"
    exit 0
fi

#==============================================================================
# Установка и настройка
#==============================================================================

# 1. Обновление системы
print_header "ШАГ 1: ОБНОВЛЕНИЕ СИСТЕМЫ"
print_info "Обновление списка пакетов..."
apt update -qq
print_success "Система обновлена"

# 2. Установка пакетов
print_header "ШАГ 2: УСТАНОВКА ПАКЕТОВ"
print_info "Установка sudo, fail2ban, mc, openssh-server..."
apt install -y sudo fail2ban mc openssh-server > /dev/null 2>&1
print_success "Пакеты установлены"

# 3. Создание/настройка пользователя
print_header "ШАГ 3: НАСТРОЙКА ПОЛЬЗОВАТЕЛЯ"
if [[ "$USER_EXISTS" == false ]]; then
    print_info "Создание пользователя $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    print_success "Пользователь создан"
else
    print_info "Использование существующего пользователя $USERNAME"
fi

print_info "Добавление в группу sudo..."
usermod -aG sudo "$USERNAME"

print_info "Настройка sudo без пароля..."
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME
print_success "Пользователь настроен"

# 4. Настройка SSH
print_header "ШАГ 4: НАСТРОЙКА SSH"
print_info "Создание резервной копии конфигурации SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

print_info "Настройка параметров безопасности SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

if [[ "$SSH_PORT" != "22" ]]; then
    print_info "Изменение SSH порта на $SSH_PORT..."
    sed -i "s/^#*Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
fi

print_info "Перезапуск SSH..."
systemctl restart ssh || systemctl restart sshd
print_success "SSH настроен"

if [[ "$SSH_PORT" != "22" ]]; then
    print_warning "SSH порт изменен на $SSH_PORT. Не забудьте использовать: ssh -p $SSH_PORT $USERNAME@server_ip"
fi

# 5. Настройка fail2ban
print_header "ШАГ 5: НАСТРОЙКА FAIL2BAN"
print_info "Создание конфигурации fail2ban..."

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime  = ${BANTIME_HOURS}h
findtime  = 1h
maxretry = ${MAXRETRY}
ignoreip = ${IGNORE_IPS}

[sshd]
enabled   = true
port      = ${SSH_PORT}
logpath   = %(sshd_log)s
backend   = %(sshd_backend)s
EOF

print_info "Запуск fail2ban..."
systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban
print_success "Fail2ban настроен и запущен"

#==============================================================================
# Финальная информация
#==============================================================================
print_header "УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"

echo -e "${GREEN}✓${NC} Система обновлена"
echo -e "${GREEN}✓${NC} Пользователь $USERNAME создан и настроен"
echo -e "${GREEN}✓${NC} SSH настроен (порт: $SSH_PORT, вход под root запрещен)"
echo -e "${GREEN}✓${NC} Fail2ban активирован и защищает систему"

echo ""
print_header "ВАЖНАЯ ИНФОРМАЦИЯ"
echo -e "${YELLOW}⚠${NC}  Для подключения к серверу используйте:"
echo -e "   ${BLUE}ssh -p $SSH_PORT $USERNAME@your_server_ip${NC}"
echo ""
echo -e "${YELLOW}⚠${NC}  Перед завершением текущей сессии:"
echo -e "   1. Откройте новое SSH соединение и проверьте вход"
echo -e "   2. Убедитесь, что можете использовать sudo"
echo -e "   3. Только после этого закрывайте текущую сессию"
echo ""

print_info "Полезные команды для проверки:"
echo "  • Статус fail2ban:        sudo fail2ban-client status"
echo "  • Список заблокированных: sudo fail2ban-client status sshd"
echo "  • Разблокировать IP:      sudo fail2ban-client unban <IP>"
echo "  • Проверить SSH порт:     sudo netstat -tlnp | grep ssh"
echo ""

print_success "Настройка безопасности сервера завершена!"
