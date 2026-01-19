#!/bin/bash

#==============================================================================
# SecureInit v2.0 - Matrix Style (Pure Bash TUI)
# GitHub: https://github.com/AlekseyNice/SecureInit
#==============================================================================

set -e
VERSION="2.0.0"

#==============================================================================
# Matrix Style Colors
#==============================================================================
MATRIX_GREEN='\033[1;32m'
MATRIX_DIM='\033[0;32m'
BLACK_BG='\033[40m'
GREEN_BG='\033[42m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Специальные символы
CHECK="✓"
CROSS="✗"
ARROW="►"
PROMPT=">"
ALERT="!"
QUESTION="?"

#==============================================================================
# Проверка root
#==============================================================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[${CROSS}]${RESET} Требуются права root"
   exit 1
fi

#==============================================================================
# Функции отрисовки
#==============================================================================
clear_screen() {
    clear
    echo -e "${BLACK_BG}${MATRIX_GREEN}"
}

print_banner() {
    clear_screen
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗██╗███╗   ║
    ║   ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝██║████╗  ║
    ║   ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗  ██║██╔██╗ ║
    ║   ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝  ██║██║╚██╗║
    ║   ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗██║██║ ╚████
    ║   ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═══║
    ║                                                               ║
    ║              СИСТЕМА АВТОМАТИЧЕСКОЙ ЗАЩИТЫ v2.0              ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

print_box() {
    local title="$1"
    local width=65
    
    echo -e "${MATRIX_GREEN}╔$(printf '═%.0s' $(seq 1 $width))╗${RESET}"
    echo -e "${MATRIX_GREEN}║${MATRIX_DIM} ${title}$(printf ' %.0s' $(seq 1 $((width - ${#title} - 1))))${MATRIX_GREEN}║${RESET}"
    echo -e "${MATRIX_GREEN}╚$(printf '═%.0s' $(seq 1 $width))╝${RESET}"
}

print_section() {
    echo ""
    echo -e "${MATRIX_GREEN}┌─────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${MATRIX_GREEN}│${GREEN_BG}${BLACK_BG} $1 ${RESET}${MATRIX_GREEN}$(printf ' %.0s' $(seq 1 $((63 - ${#1}))))│${RESET}"
    echo -e "${MATRIX_GREEN}└─────────────────────────────────────────────────────────────────┘${RESET}"
}

print_line() {
    echo -e "${MATRIX_DIM}  $1${RESET}"
}

print_option() {
    echo -e "${MATRIX_GREEN}  [$2]${RESET} ${MATRIX_DIM}${ARROW} $1${RESET}"
}

print_info() {
    echo -e "${CYAN}  [${PROMPT}]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}  [${ALERT}]${RESET} $1"
}

print_error() {
    echo -e "${RED}  [${CROSS}]${RESET} $1"
}

print_success() {
    echo -e "${MATRIX_GREEN}  [${CHECK}]${RESET} $1"
}

type_text() {
    local text="$1"
    local delay="${2:-0.02}"
    
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

matrix_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    echo -ne "${MATRIX_GREEN}  [${PROMPT}]${RESET} ${prompt}: ${MATRIX_DIM}"
    read input </dev/tty
    echo -e "${RESET}"
    
    if [[ -z "$input" && -n "$default" ]]; then
        echo "$default"
    else
        echo "$input"
    fi
}

matrix_password() {
    local prompt="$1"
    local password
    
    echo -ne "${MATRIX_GREEN}  [${PROMPT}]${RESET} ${prompt}: ${MATRIX_DIM}"
    read -s password </dev/tty
    echo -e "${RESET}"
    echo "$password"
}

matrix_confirm() {
    local prompt="$1"
    local answer
    
    echo -ne "${YELLOW}  [${QUESTION}]${RESET} ${prompt} ${MATRIX_DIM}[y/n]:${RESET} "
    read -n 1 answer </dev/tty
    echo -e "${RESET}"
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

matrix_menu() {
    local title="$1"
    shift
    local options=("$@")
    local choice
    
    print_section "$title"
    echo ""
    
    for i in "${!options[@]}"; do
        local num=$((i + 1))
        print_option "${options[$i]}" "$num"
    done
    
    echo ""
    while true; do
        choice=$(matrix_input "Выберите опцию [1-${#options[@]}]" "")
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "$choice"
            return 0
        else
            print_error "Неверный выбор. Введите число от 1 до ${#options[@]}"
        fi
    done
}

show_progress() {
    local current=$1
    local total=$2
    local text="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    
    echo -ne "${MATRIX_GREEN}  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((50 - filled))s" | tr ' ' '░'
    echo -ne "]${RESET} ${percent}% - ${MATRIX_DIM}${text}${RESET}\r"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

#==============================================================================
# Приветствие
#==============================================================================
print_banner

echo ""
print_info "Система автоматической защиты Linux-серверов"
echo ""
sleep 0.5

print_section "НОВЫЕ ВОЗМОЖНОСТИ v2.0"
echo ""
print_success "UFW Firewall Protection"
print_success "SSH Key Generation (Ed25519)"
print_success "Auto Security Updates"
print_success "Enhanced SSH Hardening"
print_success "Matrix-Style Interface"
echo ""
sleep 0.5

print_section "БАЗОВЫЕ МОДУЛИ"
echo ""
print_line "• Обновление системы"
print_line "• Создание пользователя с sudo"
print_line "• Настройка SSH и Fail2ban"
echo ""

if ! matrix_confirm "Запустить процедуру укрепления безопасности?"; then
    echo ""
    print_warning "Установка отменена пользователем"
    exit 0
fi

#==============================================================================
# Сбор данных
#==============================================================================

# Имя пользователя
while true; do
    print_section "СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ"
    echo ""
    print_info "Этот пользователь получит полные права sudo"
    echo ""
    
    USERNAME=$(matrix_input "Введите имя пользователя" "")
    
    if [[ -z "$USERNAME" ]]; then
        print_error "Имя не может быть пустым!"
        sleep 2
        clear_screen
        print_banner
        continue
    fi
    
    if id "$USERNAME" &>/dev/null; then
        echo ""
        if matrix_confirm "Пользователь '$USERNAME' существует. Использовать?"; then
            USER_EXISTS=true
            break
        fi
    else
        USER_EXISTS=false
        break
    fi
done

# Метод аутентификации
clear_screen
print_banner

AUTH_CHOICE=$(matrix_menu "МЕТОД АУТЕНТИФИКАЦИИ SSH" \
    "Пароль (базовая защита)" \
    "SSH-ключ (рекомендовано) ${CHECK}" \
    "Оба метода (гибридный режим)")

case $AUTH_CHOICE in
    1)
        USE_PASSWORD=true
        USE_SSH_KEY=false
        DISABLE_PASSWORD_AUTH=false
        ;;
    2)
        USE_PASSWORD=false
        USE_SSH_KEY=true
        DISABLE_PASSWORD_AUTH=true
        ;;
    3)
        USE_PASSWORD=true
        USE_SSH_KEY=true
        DISABLE_PASSWORD_AUTH=false
        ;;
esac

# Установка пароля
if [[ "$USE_PASSWORD" == true ]] && [[ "$USER_EXISTS" == false ]]; then
    clear_screen
    print_banner
    print_section "УСТАНОВКА ПАРОЛЯ"
    echo ""
    print_warning "Минимум 8 символов"
    echo ""
    
    while true; do
        PASSWORD=$(matrix_password "Введите пароль для '$USERNAME'")
        
        if [[ ${#PASSWORD} -lt 8 ]]; then
            echo ""
            print_error "Пароль слишком короткий! Минимум 8 символов."
            sleep 2
            continue
        fi
        
        echo ""
        PASSWORD_CONFIRM=$(matrix_password "Подтвердите пароль")
        
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            echo ""
            print_error "Пароли не совпадают!"
            sleep 2
            continue
        fi
        
        break
    done
fi

# SSH ключи
if [[ "$USE_SSH_KEY" == true ]]; then
    clear_screen
    print_banner
    print_section "SSH КРИПТОГРАФИЯ"
    echo ""
    print_info "Тип шифрования: Ed25519 (256-bit)"
    print_info "Уровень защиты: Военный стандарт"
    echo ""
    print_warning "После установки сохраните приватный ключ!"
    echo ""
    SSH_KEY_PATH="/root/.ssh/${USERNAME}_key"
    sleep 2
fi

# SSH порт
clear_screen
print_banner

SSH_PORT_CHOICE=$(matrix_menu "КОНФИГУРАЦИЯ SSH ПОРТА" \
    "Порт 22 (стандартный)" \
    "Пользовательский порт (↑ безопасность)")

if [[ "$SSH_PORT_CHOICE" == "2" ]]; then
    echo ""
    print_info "Рекомендуемые порты: 2222, 2200, 49152-65535"
    echo ""
    
    while true; do
        SSH_PORT=$(matrix_input "Введите номер порта [1024-65535]" "2222")
        
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1024 ] && [ "$SSH_PORT" -le 65535 ]; then
            break
        else
            print_error "Неверный порт! Диапазон: 1024-65535"
        fi
    done
else
    SSH_PORT=22
fi

# UFW Firewall
clear_screen
print_banner
print_section "КОНФИГУРАЦИЯ UFW FIREWALL"
echo ""
print_info "SSH (порт $SSH_PORT) будет автоматически открыт"
echo ""

OPEN_HTTP=false
OPEN_HTTPS=false

if matrix_confirm "Открыть порт 80 (HTTP)?"; then
    OPEN_HTTP=true
fi

echo ""
if matrix_confirm "Открыть порт 443 (HTTPS)?"; then
    OPEN_HTTPS=true
fi

echo ""
print_info "Дополнительные порты можно указать через пробел"
CUSTOM_PORTS=$(matrix_input "Доп. порты (или Enter)" "")

# Fail2ban
clear_screen
print_banner
print_section "НАСТРОЙКА FAIL2BAN"
echo ""
print_info "Защита от брутфорс-атак"
echo ""

USER_IP=$(matrix_input "Ваш IP для белого списка (или Enter)" "")
if [[ -z "$USER_IP" ]]; then
    IGNORE_IPS="127.0.0.1/8"
else
    IGNORE_IPS="127.0.0.1/8 $USER_IP"
fi

echo ""
MAXRETRY=$(matrix_input "Макс. попыток входа" "3")
MAXRETRY=${MAXRETRY:-3}

BANTIME_HOURS=$(matrix_input "Время бана (часы)" "24")
BANTIME_HOURS=${BANTIME_HOURS:-24}

# Автообновления
echo ""
if matrix_confirm "Включить автоматические обновления безопасности?"; then
    AUTO_UPDATES=true
else
    AUTO_UPDATES=false
fi

#==============================================================================
# Подтверждение
#==============================================================================
clear_screen
print_banner
print_section "ПОДТВЕРЖДЕНИЕ НАСТРОЕК"
echo ""

echo -e "${MATRIX_GREEN}ПОЛЬЗОВАТЕЛЬ:${RESET}"
print_line "  • Имя: $USERNAME"
[[ "$USE_PASSWORD" == true ]] && print_line "  • Пароль: установлен"
[[ "$USE_SSH_KEY" == true ]] && print_line "  • SSH-ключ: будет сгенерирован"

echo ""
echo -e "${MATRIX_GREEN}SSH:${RESET}"
print_line "  • Порт: $SSH_PORT"
[[ "$DISABLE_PASSWORD_AUTH" == true ]] && print_line "  • Парольная auth: ОТКЛЮЧЕНА" || print_line "  • Парольная auth: включена"

echo ""
echo -e "${MATRIX_GREEN}FIREWALL:${RESET}"
print_line "  • SSH ($SSH_PORT): открыт"
[[ "$OPEN_HTTP" == true ]] && print_line "  • HTTP (80): открыт"
[[ "$OPEN_HTTPS" == true ]] && print_line "  • HTTPS (443): открыт"
[[ -n "$CUSTOM_PORTS" ]] && print_line "  • Доп. порты: $CUSTOM_PORTS"

echo ""
echo -e "${MATRIX_GREEN}FAIL2BAN:${RESET}"
print_line "  • Белый список: $IGNORE_IPS"
print_line "  • Макс. попыток: $MAXRETRY"
print_line "  • Время бана: ${BANTIME_HOURS}ч"

echo ""
[[ "$AUTO_UPDATES" == true ]] && print_success "Автообновления: включены" || print_line "Автообновления: отключены"

echo ""
if ! matrix_confirm "Начать установку с этими параметрами?"; then
    echo ""
    print_warning "Установка отменена"
    exit 0
fi

#==============================================================================
# УСТАНОВКА
#==============================================================================
clear_screen
print_banner

echo ""
print_section "ИНИЦИАЛИЗАЦИЯ ЗАЩИТНЫХ ПРОТОКОЛОВ"
echo ""
sleep 1

# 1. Обновление
show_progress 1 8 "Обновление системы..."
apt update -qq 2>&1 | grep -v "^#" || true
apt upgrade -y -qq > /dev/null 2>&1
show_progress 1 8 "Обновление системы... ГОТОВО"
echo ""

# 2. Установка пакетов
show_progress 2 8 "Установка пакетов..."
DEBIAN_FRONTEND=noninteractive apt install -y sudo fail2ban mc openssh-server ufw unattended-upgrades > /dev/null 2>&1
show_progress 2 8 "Установка пакетов... ГОТОВО"
echo ""

# 3. Пользователь
show_progress 3 8 "Настройка пользователя..."
if [[ "$USER_EXISTS" == false ]]; then
    useradd -m -s /bin/bash "$USERNAME"
    [[ "$USE_PASSWORD" == true ]] && echo "$USERNAME:$PASSWORD" | chpasswd
fi
usermod -aG sudo "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME
show_progress 3 8 "Настройка пользователя... ГОТОВО"
echo ""

# 4. SSH ключи
if [[ "$USE_SSH_KEY" == true ]]; then
    show_progress 4 8 "Генерация SSH-ключей (Ed25519)..."
    mkdir -p /root/.ssh
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "${USERNAME}@$(hostname)" > /dev/null 2>&1
    
    USER_HOME=$(eval echo ~$USERNAME)
    mkdir -p "$USER_HOME/.ssh"
    cat "${SSH_KEY_PATH}.pub" > "$USER_HOME/.ssh/authorized_keys"
    chown -R $USERNAME:$USERNAME "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    show_progress 4 8 "Генерация SSH-ключей... ГОТОВО"
    echo ""
else
    show_progress 4 8 "SSH-ключи пропущены"
    echo ""
fi

# 5. SSH
show_progress 5 8 "Конфигурация SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

[[ "$DISABLE_PASSWORD_AUTH" == true ]] && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

[[ "$SSH_PORT" != "22" ]] && sed -i "s/^#*Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config

systemctl restart ssh || systemctl restart sshd
show_progress 5 8 "Конфигурация SSH... ГОТОВО"
echo ""

# 6. UFW
show_progress 6 8 "Активация UFW Firewall..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow $SSH_PORT/tcp comment 'SSH' > /dev/null 2>&1

[[ "$OPEN_HTTP" == true ]] && ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
[[ "$OPEN_HTTPS" == true ]] && ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1

if [[ -n "$CUSTOM_PORTS" ]]; then
    for port in $CUSTOM_PORTS; do
        [[ "$port" =~ ^[0-9]+$ ]] && ufw allow $port/tcp comment 'Custom' > /dev/null 2>&1
    done
fi

ufw --force enable > /dev/null 2>&1
show_progress 6 8 "Активация UFW Firewall... ГОТОВО"
echo ""

# 7. Fail2ban
show_progress 7 8 "Конфигурация Fail2ban..."
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

systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban
show_progress 7 8 "Конфигурация Fail2ban... ГОТОВО"
echo ""

# 8. Автообновления
if [[ "$AUTO_UPDATES" == true ]]; then
    show_progress 8 8 "Настройка автообновлений..."
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
    show_progress 8 8 "Настройка автообновлений... ГОТОВО"
else
    show_progress 8 8 "Автообновления пропущены"
fi

echo ""
echo ""

#==============================================================================
# Финал
#==============================================================================
print_section "УСТАНОВКА ЗАВЕРШЕНА"
echo ""

print_success "Система защищена и готова к работе"
echo ""

if [[ "$USE_SSH_KEY" == true ]]; then
    print_warning "КРИТИЧЕСКИ ВАЖНО!"
    echo ""
    print_info "Сохраните приватный SSH-ключ:"
    echo -e "  ${CYAN}${SSH_KEY_PATH}${RESET}"
    echo ""
    print_info "Команда для копирования на локальную машину:"
    echo -e "  ${MATRIX_DIM}scp -P $SSH_PORT root@ВАШ_IP:${SSH_KEY_PATH} ~/.ssh/${RESET}"
    echo ""
fi

print_info "Команда для подключения к серверу:"
if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "  ${MATRIX_DIM}ssh -i ~/.ssh/$(basename $SSH_KEY_PATH) -p $SSH_PORT $USERNAME@ВАШ_IP${RESET}"
else
    echo -e "  ${MATRIX_DIM}ssh -p $SSH_PORT $USERNAME@ВАШ_IP${RESET}"
fi

echo ""
print_warning "НЕ ЗАКРЫВАЙТЕ эту сессию до проверки входа!"
echo ""

echo -e "${MATRIX_GREEN}┌─────────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${MATRIX_GREEN}│ ${MATRIX_DIM}Полезные команды:${RESET}${MATRIX_GREEN}                                              │${RESET}"
echo -e "${MATRIX_GREEN}│ ${MATRIX_DIM}• sudo ufw status              - статус firewall${RESET}${MATRIX_GREEN}              │${RESET}"
echo -e "${MATRIX_GREEN}│ ${MATRIX_DIM}• sudo fail2ban-client status  - статус fail2ban${RESET}${MATRIX_GREEN}             │${RESET}"
echo -e "${MATRIX_GREEN}└─────────────────────────────────────────────────────────────────┘${RESET}"
echo ""

echo -e "${MATRIX_DIM}SecureInit v${VERSION} | github.com/AlekseyNice/SecureInit${RESET}"
echo ""
