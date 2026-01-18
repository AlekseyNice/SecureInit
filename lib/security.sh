#!/bin/bash

#==============================================================================
# SecureInit v2.0 - Автоматизация настройки безопасности сервера
# GitHub: https://github.com/AlekseyNice/SecureInit
#==============================================================================

set -e  # Остановка при ошибке

VERSION="2.0.0"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

#==============================================================================
# Функции вывода
#==============================================================================
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "\n${CYAN}▶${NC} ${MAGENTA}$1${NC}"
}

#==============================================================================
# Проверка прав root
#==============================================================================
if [[ $EUID -ne 0 ]]; then
   print_error "Этот скрипт должен быть запущен с правами root"
   exit 1
fi

#==============================================================================
# Приветствие
#==============================================================================
clear
print_header "SecureInit v${VERSION}"

echo -e "${CYAN}Автоматическая настройка безопасности Linux-сервера${NC}"
echo ""
echo -e "${BLUE}Новые возможности v2.0:${NC}"
echo -e "  ${GREEN}✓${NC} Настройка UFW Firewall"
echo -e "  ${GREEN}✓${NC} Генерация и установка SSH-ключей"
echo -e "  ${GREEN}✓${NC} Автоматическое закрытие опасных портов"
echo -e "  ${GREEN}✓${NC} Автоматические обновления безопасности"
echo -e "  ${GREEN}✓${NC} Усиленная защита SSH"
echo ""
echo -e "${BLUE}Базовые функции:${NC}"
echo "  • Обновление системы"
echo "  • Создание пользователя с sudo-правами"
echo "  • Настройка SSH и Fail2ban"
echo ""

read -p "Продолжить? (y/n): " -n 1 -r </dev/tty
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Установка отменена"
    exit 0
fi

#==============================================================================
# Сбор базовой информации
#==============================================================================
print_header "БАЗОВЫЕ ПАРАМЕТРЫ"

# Имя пользователя
while true; do
    read -p "Введите имя нового пользователя: " USERNAME </dev/tty
    if [[ -z "$USERNAME" ]]; then
        print_error "Имя пользователя не может быть пустым"
        continue
    fi
    if id "$USERNAME" &>/dev/null; then
        print_warning "Пользователь $USERNAME уже существует"
        read -p "Использовать существующего пользователя? (y/n): " -n 1 -r </dev/tty
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USER_EXISTS=true
            break
        fi
    else
        USER_EXISTS=false
        break
    fi
done

#==============================================================================
# Выбор метода аутентификации
#==============================================================================
print_header "МЕТОД АУТЕНТИФИКАЦИИ SSH"

echo "Выберите метод аутентификации:"
echo "  1) Пароль (менее безопасно)"
echo "  2) SSH-ключ (рекомендуется)"
echo "  3) Оба метода"
echo ""

while true; do
    read -p "Ваш выбор [1-3]: " AUTH_METHOD </dev/tty
    case $AUTH_METHOD in
        1)
            USE_PASSWORD=true
            USE_SSH_KEY=false
            DISABLE_PASSWORD_AUTH=false
            break
            ;;
        2)
            USE_PASSWORD=false
            USE_SSH_KEY=true
            DISABLE_PASSWORD_AUTH=true
            break
            ;;
        3)
            USE_PASSWORD=true
            USE_SSH_KEY=true
            DISABLE_PASSWORD_AUTH=false
            break
            ;;
        *)
            print_error "Неверный выбор. Введите 1, 2 или 3"
            ;;
    esac
done

# Пароль (если выбран)
if [[ "$USE_PASSWORD" == true ]] && [[ "$USER_EXISTS" == false ]]; then
    echo ""
    while true; do
        read -s -p "Введите пароль для пользователя $USERNAME: " PASSWORD </dev/tty
        echo ""
        if [[ ${#PASSWORD} -lt 8 ]]; then
            print_error "Пароль должен содержать минимум 8 символов"
            continue
        fi
        read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM </dev/tty
        echo ""
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            print_error "Пароли не совпадают"
            continue
        fi
        break
    done
fi

# SSH-ключ (если выбран)
if [[ "$USE_SSH_KEY" == true ]]; then
    echo ""
    print_info "SSH-ключи будут сгенерированы автоматически"
    SSH_KEY_PATH="/root/.ssh/${USERNAME}_key"
fi

#==============================================================================
# SSH порт
#==============================================================================
print_header "НАСТРОЙКА SSH"

echo "Выберите SSH порт:"
echo "  1) Оставить стандартный порт 22"
echo "  2) Изменить на другой порт (повышенная безопасность)"
echo ""

while true; do
    read -p "Ваш выбор [1-2]: " SSH_CHOICE </dev/tty
    case $SSH_CHOICE in
        1)
            SSH_PORT=22
            print_info "Используется стандартный порт 22"
            break
            ;;
        2)
            while true; do
                read -p "Введите новый SSH порт (1024-65535, или 0 для отмены): " SSH_PORT </dev/tty
                if [[ "$SSH_PORT" == "0" ]]; then
                    SSH_PORT=22
                    print_info "Отменено. Используется порт 22"
                    break
                fi
                if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1024 ] && [ "$SSH_PORT" -le 65535 ]; then
                    print_success "Будет использован порт $SSH_PORT"
                    break
                else
                    print_error "Неверный порт. Введите число от 1024 до 65535 (или 0 для отмены)"
                fi
            done
            break
            ;;
        *)
            print_error "Неверный выбор. Введите 1 или 2"
            ;;
    esac
done

#==============================================================================
# Настройка Firewall (UFW)
#==============================================================================
print_header "НАСТРОЙКА FIREWALL (UFW)"

echo "Firewall будет настроен с базовыми правилами:"
echo "  • SSH (порт $SSH_PORT) - РАЗРЕШЕН"
echo "  • Все остальные входящие - ЗАПРЕЩЕНЫ"
echo ""
echo "Дополнительные порты (необязательно):"
echo ""

read -p "Открыть порт 80 (HTTP)? [y/n]: " -n 1 -r </dev/tty
echo ""
[[ $REPLY =~ ^[Yy]$ ]] && OPEN_HTTP=true || OPEN_HTTP=false

read -p "Открыть порт 443 (HTTPS)? [y/n]: " -n 1 -r </dev/tty
echo ""
[[ $REPLY =~ ^[Yy]$ ]] && OPEN_HTTPS=true || OPEN_HTTPS=false

echo ""
echo "Если нужно открыть другие порты (например для Docker, баз данных),"
echo "введите их через пробел или нажмите Enter для пропуска"
read -p "Дополнительные порты: " CUSTOM_PORTS </dev/tty

#==============================================================================
# Параметры Fail2ban
#==============================================================================
print_header "НАСТРОЙКА FAIL2BAN"

echo "Fail2ban защищает от брутфорс-атак, блокируя IP после неудачных попыток входа."
echo ""
echo "Если у вас есть статический IP адрес, можете добавить его в белый список,"
echo "чтобы случайно не заблокировать себя. Введите IP или нажмите Enter для пропуска."
echo ""

read -p "Ваш IP адрес (или пропустить): " USER_IP </dev/tty
if [[ -z "$USER_IP" ]]; then
    IGNORE_IPS="127.0.0.1/8"
else
    IGNORE_IPS="127.0.0.1/8 $USER_IP"
    print_success "IP $USER_IP добавлен в белый список"
fi

echo ""
read -p "Максимальное количество попыток входа [по умолчанию 3]: " MAXRETRY </dev/tty
MAXRETRY=${MAXRETRY:-3}

read -p "Время бана в часах [по умолчанию 24]: " BANTIME_HOURS </dev/tty
BANTIME_HOURS=${BANTIME_HOURS:-24}

#==============================================================================
# Дополнительные опции безопасности
#==============================================================================
print_header "ДОПОЛНИТЕЛЬНЫЕ ОПЦИИ"

read -p "Включить автоматические обновления безопасности? [y/n]: " -n 1 -r </dev/tty
echo ""
[[ $REPLY =~ ^[Yy]$ ]] && AUTO_UPDATES=true || AUTO_UPDATES=false

#==============================================================================
# Подтверждение параметров
#==============================================================================
print_header "ПОДТВЕРЖДЕНИЕ ПАРАМЕТРОВ"

echo -e "${CYAN}Пользователь:${NC}"
echo "  • Имя: $USERNAME"
if [[ "$USE_PASSWORD" == true ]]; then
    echo "  • Пароль: установлен"
fi
if [[ "$USE_SSH_KEY" == true ]]; then
    echo "  • SSH-ключ: будет сгенерирован"
fi

echo ""
echo -e "${CYAN}SSH:${NC}"
echo "  • Порт: $SSH_PORT"
if [[ "$DISABLE_PASSWORD_AUTH" == true ]]; then
    echo "  • Парольная аутентификация: ОТКЛЮЧЕНА (только ключи)"
else
    echo "  • Парольная аутентификация: включена"
fi

echo ""
echo -e "${CYAN}Firewall (UFW):${NC}"
echo "  • SSH порт $SSH_PORT: ОТКРЫТ"
[[ "$OPEN_HTTP" == true ]] && echo "  • HTTP (80): ОТКРЫТ" || echo "  • HTTP (80): закрыт"
[[ "$OPEN_HTTPS" == true ]] && echo "  • HTTPS (443): ОТКРЫТ" || echo "  • HTTPS (443): закрыт"
if [[ -n "$CUSTOM_PORTS" ]]; then
    echo "  • Дополнительные порты: $CUSTOM_PORTS"
fi

echo ""
echo -e "${CYAN}Fail2ban:${NC}"
echo "  • Игнорируемые IP: $IGNORE_IPS"
echo "  • Макс. попыток: $MAXRETRY"
echo "  • Время бана: ${BANTIME_HOURS}ч"

echo ""
echo -e "${CYAN}Дополнительно:${NC}"
[[ "$AUTO_UPDATES" == true ]] && echo "  • Автообновления: включены" || echo "  • Автообновления: отключены"

echo ""
read -p "Начать установку с этими параметрами? (y/n): " -n 1 -r </dev/tty
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Установка отменена"
    exit 0
fi

#==============================================================================
# УСТАНОВКА И НАСТРОЙКА
#==============================================================================

# 1. Обновление системы
print_header "ШАГ 1/8: ОБНОВЛЕНИЕ СИСТЕМЫ"
print_step "Обновление списка пакетов..."
apt update -qq
print_success "Система обновлена"

# 2. Установка пакетов
print_header "ШАГ 2/8: УСТАНОВКА ПАКЕТОВ"
print_step "Установка необходимых пакетов..."
DEBIAN_FRONTEND=noninteractive apt install -y sudo fail2ban mc openssh-server ufw unattended-upgrades > /dev/null 2>&1
print_success "Пакеты установлены"

# 3. Создание/настройка пользователя
print_header "ШАГ 3/8: НАСТРОЙКА ПОЛЬЗОВАТЕЛЯ"
if [[ "$USER_EXISTS" == false ]]; then
    print_step "Создание пользователя $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    if [[ "$USE_PASSWORD" == true ]]; then
        echo "$USERNAME:$PASSWORD" | chpasswd
    fi
    print_success "Пользователь создан"
else
    print_info "Использование существующего пользователя $USERNAME"
fi

print_step "Добавление в группу sudo..."
usermod -aG sudo "$USERNAME"

print_step "Настройка sudo..."
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME
print_success "Пользователь настроен"

# 4. Настройка SSH-ключей
if [[ "$USE_SSH_KEY" == true ]]; then
    print_header "ШАГ 4/8: НАСТРОЙКА SSH-КЛЮЧЕЙ"
    
    print_step "Генерация SSH-ключей..."
    mkdir -p /root/.ssh
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "${USERNAME}@$(hostname)" > /dev/null 2>&1
    
    print_step "Установка публичного ключа для $USERNAME..."
    USER_HOME=$(eval echo ~$USERNAME)
    mkdir -p "$USER_HOME/.ssh"
    cat "${SSH_KEY_PATH}.pub" > "$USER_HOME/.ssh/authorized_keys"
    chown -R $USERNAME:$USERNAME "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    
    print_success "SSH-ключи настроены"
    print_warning "ВАЖНО! Приватный ключ сохранен в: ${SSH_KEY_PATH}"
    print_warning "Скопируйте его на локальную машину ПЕРЕД закрытием сессии!"
    echo ""
    echo -e "${YELLOW}Команда для копирования ключа:${NC}"
    echo -e "${CYAN}cat ${SSH_KEY_PATH}${NC}"
    echo ""
else
    print_header "ШАГ 4/8: НАСТРОЙКА SSH-КЛЮЧЕЙ"
    print_info "Пропущено (выбрана парольная аутентификация)"
fi

# 5. Настройка SSH
print_header "ШАГ 5/8: НАСТРОЙКА SSH"
print_step "Создание резервной копии..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

print_step "Настройка параметров безопасности SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

if [[ "$DISABLE_PASSWORD_AUTH" == true ]]; then
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    print_info "Парольная аутентификация ОТКЛЮЧЕНА"
else
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

if [[ "$SSH_PORT" != "22" ]]; then
    print_step "Изменение SSH порта на $SSH_PORT..."
    sed -i "s/^#*Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
fi

print_step "Перезапуск SSH..."
systemctl restart ssh || systemctl restart sshd
print_success "SSH настроен"

# 6. Настройка UFW Firewall
print_header "ШАГ 6/8: НАСТРОЙКА FIREWALL (UFW)"

print_step "Сброс правил UFW..."
ufw --force reset > /dev/null 2>&1

print_step "Настройка базовых правил..."
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

print_step "Открытие SSH порта $SSH_PORT..."
ufw allow $SSH_PORT/tcp comment 'SSH' > /dev/null 2>&1

if [[ "$OPEN_HTTP" == true ]]; then
    print_step "Открытие HTTP порта 80..."
    ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
fi

if [[ "$OPEN_HTTPS" == true ]]; then
    print_step "Открытие HTTPS порта 443..."
    ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1
fi

if [[ -n "$CUSTOM_PORTS" ]]; then
    for port in $CUSTOM_PORTS; do
        print_step "Открытие порта $port..."
        ufw allow $port/tcp comment 'Custom' > /dev/null 2>&1
    done
fi

print_step "Активация UFW..."
ufw --force enable > /dev/null 2>&1

print_success "Firewall настроен и активирован"

# 7. Настройка Fail2ban
print_header "ШАГ 7/8: НАСТРОЙКА FAIL2BAN"
print_step "Создание конфигурации fail2ban..."

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

print_step "Запуск fail2ban..."
systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban
print_success "Fail2ban настроен и запущен"

# 8. Автоматические обновления
if [[ "$AUTO_UPDATES" == true ]]; then
    print_header "ШАГ 8/8: АВТОМАТИЧЕСКИЕ ОБНОВЛЕНИЯ"
    print_step "Настройка unattended-upgrades..."
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    print_success "Автоматические обновления настроены"
else
    print_header "ШАГ 8/8: АВТОМАТИЧЕСКИЕ ОБНОВЛЕНИЯ"
    print_info "Пропущено (не выбрано)"
fi

#==============================================================================
# Финальная информация
#==============================================================================
print_header "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"

echo -e "${GREEN}Выполнено:${NC}"
echo -e "  ${GREEN}✓${NC} Система обновлена"
echo -e "  ${GREEN}✓${NC} Пользователь $USERNAME создан и настроен"
echo -e "  ${GREEN}✓${NC} SSH настроен (порт: $SSH_PORT)"
if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "  ${GREEN}✓${NC} SSH-ключи сгенерированы"
fi
echo -e "  ${GREEN}✓${NC} UFW Firewall настроен и активен"
echo -e "  ${GREEN}✓${NC} Fail2ban защищает от брутфорса"
if [[ "$AUTO_UPDATES" == true ]]; then
    echo -e "  ${GREEN}✓${NC} Автоматические обновления включены"
fi

echo ""
print_header "⚠️  КРИТИЧЕСКИ ВАЖНАЯ ИНФОРМАЦИЯ"

if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "${RED}1. СОХРАНИТЕ ПРИВАТНЫЙ SSH-КЛЮЧ!${NC}"
    echo -e "   Расположение: ${CYAN}${SSH_KEY_PATH}${NC}"
    echo ""
    echo -e "   ${YELLOW}На вашей локальной машине выполните:${NC}"
    echo -e "   ${CYAN}scp -P $SSH_PORT root@ВАШ_IP:${SSH_KEY_PATH} ~/.ssh/${USERNAME}_key${NC}"
    echo -e "   ${CYAN}chmod 600 ~/.ssh/${USERNAME}_key${NC}"
    echo ""
fi

echo -e "${RED}2. ПРОВЕРЬТЕ ПОДКЛЮЧЕНИЕ В НОВОЙ СЕССИИ!${NC}"
echo -e "   ${YELLOW}Команда для подключения:${NC}"
if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "   ${CYAN}ssh -i ~/.ssh/${USERNAME}_key -p $SSH_PORT $USERNAME@ВАШ_IP${NC}"
else
    echo -e "   ${CYAN}ssh -p $SSH_PORT $USERNAME@ВАШ_IP${NC}"
fi

echo ""
echo -e "${RED}3. НЕ ЗАКРЫВАЙТЕ ТЕКУЩУЮ СЕССИЮ${NC}"
echo -e "   пока не проверите вход в новой сессии!"

echo ""
print_header "📊 ПОЛЕЗНЫЕ КОМАНДЫ"

echo -e "${CYAN}Firewall (UFW):${NC}"
echo "  • Статус UFW:             sudo ufw status verbose"
echo "  • Список правил:          sudo ufw status numbered"
echo "  • Открыть порт:           sudo ufw allow ПОРТ/tcp"
echo "  • Закрыть порт:           sudo ufw delete НОМЕР_ПРАВИЛА"
echo ""

echo -e "${CYAN}Fail2ban:${NC}"
echo "  • Статус:                 sudo fail2ban-client status"
echo "  • Заблокированные IP:     sudo fail2ban-client status sshd"
echo "  • Разблокировать IP:      sudo fail2ban-client unban IP_АДРЕС"
echo ""

echo -e "${CYAN}SSH:${NC}"
echo "  • Проверить SSH порт:     sudo netstat -tlnp | grep ssh"
echo "  • Просмотр логов SSH:     sudo tail -f /var/log/auth.log"
echo ""

if [[ "$AUTO_UPDATES" == true ]]; then
    echo -e "${CYAN}Автообновления:${NC}"
    echo "  • Проверить статус:       sudo systemctl status unattended-upgrades"
    echo "  • Логи обновлений:        sudo cat /var/log/unattended-upgrades/unattended-upgrades.log"
    echo ""
fi

print_success "🎉 SecureInit v${VERSION} - Настройка завершена!"
echo ""
echo -e "${CYAN}Поддержите проект: ${NC}https://github.com/AlekseyNice/SecureInit ⭐"
echo ""
