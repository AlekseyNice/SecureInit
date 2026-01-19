#!/bin/bash

#==============================================================================
# SecureInit v2.0 - Автоматизация настройки безопасности сервера
# GitHub: https://github.com/AlekseyNice/SecureInit
#==============================================================================

set -e  # Остановка при ошибке

VERSION="2.0.0"

# Цвета для вывода (для консольных сообщений)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

#==============================================================================
# Проверка прав root
#==============================================================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗]${NC} Этот скрипт должен быть запущен с правами root"
   exit 1
fi

#==============================================================================
# Определение доступного диалогового инструмента
#==============================================================================
if command -v dialog &> /dev/null; then
    DIALOG="dialog"
elif command -v whiptail &> /dev/null; then
    DIALOG="whiptail"
else
    # Установка dialog, если отсутствует
    echo -e "${BLUE}[INFO]${NC} Установка dialog для графического интерфейса..."
    apt update -qq
    apt install -y dialog > /dev/null 2>&1
    DIALOG="dialog"
fi

# Временный файл для ответов
TEMP_FILE=$(mktemp)

#==============================================================================
# Настройка "хакерского" стиля для dialog (Matrix style)
#==============================================================================
export DIALOGRC=/tmp/.dialogrc_secureinit_$
cat << 'EOF' > "$DIALOGRC"
# SecureInit - Matrix/Hacker Style Theme
# Цвета: 0=Black, 1=Red, 2=Green, 3=Yellow, 4=Blue, 5=Magenta, 6=Cyan, 7=White

use_shadow = ON
use_colors = ON

# Основной фон и текст (Зеленый на Черном - как в Matrix)
screen_color = (GREEN,BLACK,OFF)
dialog_color = (GREEN,BLACK,OFF)
title_color = (BLACK,GREEN,ON)
border_color = (GREEN,BLACK,ON)
border2_color = (GREEN,BLACK,ON)

# Кнопки
button_active_color = (BLACK,GREEN,ON)
button_inactive_color = (GREEN,BLACK,OFF)
button_key_active_color = (RED,GREEN,ON)
button_key_inactive_color = (RED,BLACK,ON)
button_label_active_color = (BLACK,GREEN,ON)
button_label_inactive_color = (GREEN,BLACK,OFF)

# Списки и меню
tag_color = (GREEN,BLACK,ON)
tag_key_color = (RED,BLACK,ON)
item_color = (GREEN,BLACK,OFF)
item_selected_color = (BLACK,GREEN,ON)
tag_selected_color = (BLACK,GREEN,ON)
menubox_color = (GREEN,BLACK,OFF)
menubox_border_color = (GREEN,BLACK,ON)
menubox_border2_color = (GREEN,BLACK,ON)

# Поля ввода
inputbox_color = (GREEN,BLACK,OFF)
inputbox_border_color = (GREEN,BLACK,ON)
inputbox_border2_color = (GREEN,BLACK,ON)

# Checklist
check_color = (GREEN,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)

# Дополнительные элементы
searchbox_color = (GREEN,BLACK,OFF)
searchbox_border_color = (GREEN,BLACK,ON)
searchbox_title_color = (BLACK,GREEN,ON)

position_indicator_color = (GREEN,BLACK,ON)

# Gauge (прогресс бар)
gauge_color = (BLACK,GREEN,ON)
EOF

trap "rm -f $TEMP_FILE $DIALOGRC" EXIT

#==============================================================================
# Функции для работы с dialog
#==============================================================================
show_msgbox() {
    $DIALOG --title "$1" --msgbox "$2" 0 0 3>&1 1>&2 2>&3
}

show_yesno() {
    $DIALOG --title "$1" --yesno "$2" 0 0 3>&1 1>&2 2>&3
    return $?
}

show_inputbox() {
    $DIALOG --title "$1" --inputbox "$2" 0 0 "$3" 3>&1 1>&2 2>&3
}

show_passwordbox() {
    $DIALOG --title "$1" --passwordbox "$2" 0 0 3>&1 1>&2 2>&3
}

show_menu() {
    local title="$1"
    local text="$2"
    shift 2
    $DIALOG --title "$title" --menu "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
}

show_checklist() {
    local title="$1"
    local text="$2"
    shift 2
    $DIALOG --title "$title" --checklist "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
}

show_gauge() {
    $DIALOG --title "$1" --gauge "$2" 0 0 "$3"
}

show_infobox() {
    $DIALOG --title "$1" --infobox "$2" 0 0
    sleep 2
}

#==============================================================================
# Приветствие
#==============================================================================
show_msgbox "█ SecureInit v${VERSION} █" "\
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ░█▀▀░█▀▀░█▀▀░█░█░█▀▄░█▀▀░▀█▀░█▀█░█▀▀░▀█▀░▀█▀░█░█░░    ║
║   ░▀▀█░█▀▀░█░░░█░█░█▀▄░█▀▀░░█░░█░█░█▀▀░░█░░░█░░▀▄▀░░    ║
║   ░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░▀░░░▀░░░▀░░░    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

>>> СИСТЕМА АВТОМАТИЧЕСКОЙ ЗАЩИТЫ СЕРВЕРА <<<

[!] НОВЫЕ МОДУЛИ v2.0:
 ► UFW Firewall Protection
 ► SSH Key Generation (Ed25519)
 ► Auto Security Updates
 ► Enhanced SSH Hardening
 ► Matrix-Style Interface

[!] БАЗОВЫЕ МОДУЛИ:
 • System Update & Upgrade
 • User Creation & Sudo Config
 • SSH & Fail2ban Setup

[ENTER] для инициализации защитных протоколов..."

if ! show_yesno "█ ПОДТВЕРЖДЕНИЕ █" "[?] Запустить процедуру укрепления безопасности сервера?\n\n[!] После запуска будут выполнены необнеобратимые изменения в конфигурации системы.\n\n>>> Продолжить?"; then
    clear
    echo -e "${YELLOW}[⚠]${NC} Установка отменена пользователем"
    exit 0
fi

#==============================================================================
# Сбор базовой информации
#==============================================================================

# Имя пользователя
while true; do
    USERNAME=$(show_inputbox "█ СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ █" "[>] Введите имя нового системного пользователя:\n\n[!] Этот пользователь получит полные права sudo" "")
    
    if [[ -z "$USERNAME" ]]; then
        show_msgbox "█ ОШИБКА █" "[✗] Имя пользователя не может быть пустым!\n\n[!] Требуется валидное имя пользователя для продолжения."
        continue
    fi
    
    if id "$USERNAME" &>/dev/null; then
        if show_yesno "█ ПОЛЬЗОВАТЕЛЬ ОБНАРУЖЕН █" "[!] Пользователь '$USERNAME' уже существует в системе.\n\n[?] Использовать существующего пользователя?"; then
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
AUTH_METHOD=$(show_menu "█ МЕТОД АУТЕНТИФИКАЦИИ █" "[>] Выберите метод доступа к серверу:\n\n[!] Рекомендуется использовать SSH-ключи для максимальной безопасности" \
    "1" "► Пароль (базовая защита)" \
    "2" "► SSH-ключ (рекомендовано) ★" \
    "3" "► Оба метода (гибридный режим)")

case $AUTH_METHOD in
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

# Установка пароля (если выбран)
if [[ "$USE_PASSWORD" == true ]] && [[ "$USER_EXISTS" == false ]]; then
    while true; do
        PASSWORD=$(show_passwordbox "█ УСТАНОВКА ПАРОЛЯ █" "[>] Введите пароль для пользователя '$USERNAME':\n\n[!] Минимум 8 символов\n[!] Используйте сложные комбинации")
        
        if [[ ${#PASSWORD} -lt 8 ]]; then
            show_msgbox "█ ОШИБКА █" "[✗] Пароль слишком короткий!\n\n[!] Требуется минимум 8 символов для базовой защиты."
            continue
        fi
        
        PASSWORD_CONFIRM=$(show_passwordbox "█ ПОДТВЕРЖДЕНИЕ █" "[>] Подтвердите введенный пароль:")
        
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            show_msgbox "█ ОШИБКА █" "[✗] Пароли не совпадают!\n\n[!] Повторите ввод пароля."
            continue
        fi
        
        break
    done
fi

# Информация об SSH-ключах
if [[ "$USE_SSH_KEY" == true ]]; then
    show_msgbox "█ SSH КРИПТОГРАФИЯ █" "[+] SSH-ключи будут автоматически сгенерированы\n\n[>] Тип шифрования: Ed25519 (256-bit)\n[>] Уровень защиты: Военный стандарт\n\n[!] После установки получите инструкции по экспорту приватного ключа."
    SSH_KEY_PATH="/root/.ssh/${USERNAME}_key"
fi

#==============================================================================
# SSH порт
#==============================================================================
SSH_PORT_CHOICE=$(show_menu "█ КОНФИГУРАЦИЯ SSH █" "[>] Выберите порт для SSH-сервера:\n\n[!] Изменение стандартного порта усложнит автоматизированные атаки" \
    "1" "► Порт 22 (стандартный)" \
    "2" "► Пользовательский порт (↑ безопасность)")

if [[ "$SSH_PORT_CHOICE" == "2" ]]; then
    while true; do
        SSH_PORT=$(show_inputbox "█ CUSTOM SSH PORT █" "[>] Введите номер порта (диапазон: 1024-65535):\n\n[!] Рекомендуемые порты: 2222, 2200, 49152-65535" "2222")
        
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1024 ] && [ "$SSH_PORT" -le 65535 ]; then
            break
        elif [[ "$SSH_PORT" == "22" ]]; then
            break
        else
            show_msgbox "█ ОШИБКА █" "[✗] Неверный номер порта!\n\n[!] Допустимый диапазон: 1024-65535\n[!] Либо используйте порт 22 (стандартный)"
        fi
    done
else
    SSH_PORT=22
fi

#==============================================================================
# Настройка Firewall (UFW)
#==============================================================================
show_msgbox "UFW Firewall" "Сейчас будет настроен файрвол UFW.\n\nБазовые правила:\n• SSH (порт $SSH_PORT) - РАЗРЕШЕН\n• Все остальные входящие - ЗАПРЕЩЕНЫ\n\nДалее вы сможете выбрать дополнительные порты для открытия."

# Выбор портов через checklist
SELECTED_PORTS=$(show_checklist "Дополнительные порты" "Выберите порты для открытия (пробел - выбрать):" \
    "80" "HTTP (веб-сервер)" off \
    "443" "HTTPS (защищенный веб-сервер)" off \
    "3000" "Node.js / React (разработка)" off \
    "5432" "PostgreSQL (база данных)" off \
    "3306" "MySQL (база данных)" off \
    "6379" "Redis (кеш)" off \
    "8080" "Альтернативный HTTP" off)

# Убираем кавычки из результата
SELECTED_PORTS=$(echo $SELECTED_PORTS | tr -d '"')

# Дополнительные порты
CUSTOM_PORTS=$(show_inputbox "Дополнительные порты" "Введите другие порты через пробел (или оставьте пустым):\n\nНапример: 9000 27017" "")

# Объединяем порты
ALL_PORTS="$SELECTED_PORTS $CUSTOM_PORTS"

#==============================================================================
# Параметры Fail2ban
#==============================================================================
show_msgbox "Fail2ban" "Fail2ban защищает от брутфорс-атак.\n\nПосле нескольких неудачных попыток входа IP-адрес атакующего будет заблокирован.\n\nСейчас вы сможете настроить параметры защиты."

# Белый список IP
USER_IP=$(show_inputbox "Белый список IP" "Введите ваш IP для добавления в белый список\n(чтобы не заблокировать себя):\n\nОставьте пустым, если не знаете или не нужно." "")

if [[ -z "$USER_IP" ]]; then
    IGNORE_IPS="127.0.0.1/8"
else
    IGNORE_IPS="127.0.0.1/8 $USER_IP"
fi

# Максимальное количество попыток
MAXRETRY=$(show_inputbox "Fail2ban - попытки входа" "Максимальное количество неудачных попыток входа:" "3")
MAXRETRY=${MAXRETRY:-3}

# Время бана
BANTIME_HOURS=$(show_inputbox "Fail2ban - время бана" "Время блокировки IP в часах:" "24")
BANTIME_HOURS=${BANTIME_HOURS:-24}

#==============================================================================
# Дополнительные опции
#==============================================================================
if show_yesno "Автоматические обновления" "Включить автоматическую установку обновлений безопасности?\n\nРекомендуется для автоматического получения критических патчей."; then
    AUTO_UPDATES=true
else
    AUTO_UPDATES=false
fi

#==============================================================================
# Подтверждение параметров
#==============================================================================
SUMMARY="ПОЛЬЗОВАТЕЛЬ:
• Имя: $USERNAME
"

if [[ "$USE_PASSWORD" == true ]]; then
    SUMMARY+="• Пароль: установлен
"
fi

if [[ "$USE_SSH_KEY" == true ]]; then
    SUMMARY+="• SSH-ключ: будет сгенерирован
"
fi

SUMMARY+="
SSH:
• Порт: $SSH_PORT
"

if [[ "$DISABLE_PASSWORD_AUTH" == true ]]; then
    SUMMARY+="• Парольная аутентификация: ОТКЛЮЧЕНА
"
else
    SUMMARY+="• Парольная аутентификация: включена
"
fi

SUMMARY+="
FIREWALL (UFW):
• SSH порт $SSH_PORT: открыт
"

if [[ -n "$ALL_PORTS" ]]; then
    SUMMARY+="• Дополнительные порты: $ALL_PORTS
"
fi

SUMMARY+="
FAIL2BAN:
• Игнорируемые IP: $IGNORE_IPS
• Макс. попыток: $MAXRETRY
• Время бана: ${BANTIME_HOURS}ч

ДОПОЛНИТЕЛЬНО:
"

if [[ "$AUTO_UPDATES" == true ]]; then
    SUMMARY+="• Автообновления: включены"
else
    SUMMARY+="• Автообновления: отключены"
fi

if ! show_yesno "Подтверждение настроек" "$SUMMARY\n\nНачать установку с этими параметрами?"; then
    clear
    echo -e "${YELLOW}[⚠]${NC} Установка отменена пользователем"
    exit 0
fi

#==============================================================================
# УСТАНОВКА И НАСТРОЙКА
#==============================================================================

# Закрываем dialog и переходим к консольному выводу
clear

echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         SecureInit v${VERSION} - Установка          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Обновление системы
echo -e "${BLUE}[1/8]${NC} Обновление системы..."
apt update -qq
apt upgrade -y -qq > /dev/null 2>&1
echo -e "${GREEN}  ✓${NC} Система обновлена"

# 2. Установка пакетов
echo -e "${BLUE}[2/8]${NC} Установка пакетов..."
DEBIAN_FRONTEND=noninteractive apt install -y sudo fail2ban mc openssh-server ufw unattended-upgrades apt-listchanges > /dev/null 2>&1
echo -e "${GREEN}  ✓${NC} Пакеты установлены: sudo, fail2ban, mc, openssh, ufw"

# 3. Создание пользователя
echo -e "${BLUE}[3/8]${NC} Настройка пользователя..."
if [[ "$USER_EXISTS" == false ]]; then
    useradd -m -s /bin/bash "$USERNAME"
    if [[ "$USE_PASSWORD" == true ]]; then
        echo "$USERNAME:$PASSWORD" | chpasswd
    fi
    echo -e "${GREEN}  ✓${NC} Пользователь $USERNAME создан"
else
    echo -e "${GREEN}  ✓${NC} Используется существующий пользователь $USERNAME"
fi

usermod -aG sudo "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME
echo -e "${GREEN}  ✓${NC} Права sudo настроены"

# 4. SSH-ключи
if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "${BLUE}[4/8]${NC} Генерация SSH-ключей..."
    mkdir -p /root/.ssh
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "${USERNAME}@$(hostname)" > /dev/null 2>&1
    
    USER_HOME=$(eval echo ~$USERNAME)
    mkdir -p "$USER_HOME/.ssh"
    cat "${SSH_KEY_PATH}.pub" > "$USER_HOME/.ssh/authorized_keys"
    chown -R $USERNAME:$USERNAME "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    
    echo -e "${GREEN}  ✓${NC} SSH-ключи сгенерированы (Ed25519)"
    echo -e "${YELLOW}  ⚠${NC} Приватный ключ: ${SSH_KEY_PATH}"
else
    echo -e "${BLUE}[4/8]${NC} Настройка SSH-ключей..."
    echo -e "${CYAN}  →${NC} Пропущено (выбрана парольная аутентификация)"
fi

# 5. Настройка SSH
echo -e "${BLUE}[5/8]${NC} Настройка SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

if [[ "$DISABLE_PASSWORD_AUTH" == true ]]; then
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo -e "${GREEN}  ✓${NC} Парольная аутентификация ОТКЛЮЧЕНА"
else
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

if [[ "$SSH_PORT" != "22" ]]; then
    sed -i "s/^#*Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    echo -e "${GREEN}  ✓${NC} SSH порт изменен на $SSH_PORT"
fi

systemctl restart ssh || systemctl restart sshd
echo -e "${GREEN}  ✓${NC} SSH настроен и перезапущен"

# 6. UFW Firewall
echo -e "${BLUE}[6/8]${NC} Настройка UFW Firewall..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

ufw allow $SSH_PORT/tcp comment 'SSH' > /dev/null 2>&1
echo -e "${GREEN}  ✓${NC} SSH порт $SSH_PORT открыт"

if [[ -n "$ALL_PORTS" ]]; then
    for port in $ALL_PORTS; do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            ufw allow $port/tcp comment 'Custom' > /dev/null 2>&1
            echo -e "${GREEN}  ✓${NC} Порт $port открыт"
        fi
    done
fi

ufw --force enable > /dev/null 2>&1
echo -e "${GREEN}  ✓${NC} Firewall активирован"

# 7. Fail2ban
echo -e "${BLUE}[7/8]${NC} Настройка Fail2ban..."

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
echo -e "${GREEN}  ✓${NC} Fail2ban настроен и запущен"

# 8. Автообновления
if [[ "$AUTO_UPDATES" == true ]]; then
    echo -e "${BLUE}[8/8]${NC} Настройка автообновлений..."
    
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

    echo -e "${GREEN}  ✓${NC} Автообновления настроены"
else
    echo -e "${BLUE}[8/8]${NC} Автообновления..."
    echo -e "${CYAN}  →${NC} Пропущено"
fi

#==============================================================================
# Финальная информация
#==============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✓ УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Показываем финальную информацию через dialog
FINAL_MESSAGE="УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!

Выполнено:
✓ Система обновлена
✓ Пользователь $USERNAME создан
✓ SSH настроен (порт $SSH_PORT)
"

if [[ "$USE_SSH_KEY" == true ]]; then
    FINAL_MESSAGE+="✓ SSH-ключи сгенерированы
"
fi

FINAL_MESSAGE+="✓ UFW Firewall активирован
✓ Fail2ban защищает систему
"

if [[ "$AUTO_UPDATES" == true ]]; then
    FINAL_MESSAGE+="✓ Автообновления включены
"
fi

FINAL_MESSAGE+="
"

if [[ "$USE_SSH_KEY" == true ]]; then
    FINAL_MESSAGE+="⚠ ВАЖНО! СОХРАНИТЕ ПРИВАТНЫЙ КЛЮЧ!

Расположение ключа:
${SSH_KEY_PATH}

На вашей локальной машине выполните:
scp -P $SSH_PORT root@IP_СЕРВЕРА:${SSH_KEY_PATH} ~/.ssh/
chmod 600 ~/.ssh/$(basename $SSH_KEY_PATH)

"
fi

FINAL_MESSAGE+="⚠ ПРОВЕРЬТЕ ПОДКЛЮЧЕНИЕ В НОВОЙ СЕССИИ!

Команда для подключения:
"

if [[ "$USE_SSH_KEY" == true ]]; then
    FINAL_MESSAGE+="ssh -i ~/.ssh/$(basename $SSH_KEY_PATH) -p $SSH_PORT $USERNAME@IP_СЕРВЕРА
"
else
    FINAL_MESSAGE+="ssh -p $SSH_PORT $USERNAME@IP_СЕРВЕРА
"
fi

FINAL_MESSAGE+="
⚠ НЕ ЗАКРЫВАЙТЕ ТЕКУЩУЮ СЕССИЮ
пока не проверите вход в новой сессии!
"

show_msgbox "SecureInit - Готово!" "$FINAL_MESSAGE"

# Консольный вывод финальной информации
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✓ SecureInit v${VERSION} - Готово!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "${RED}ВАЖНО! СОХРАНИТЕ ПРИВАТНЫЙ SSH-КЛЮЧ:${NC}"
    echo -e "${CYAN}${SSH_KEY_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}Команда для копирования на локальную машину:${NC}"
    echo -e "${CYAN}scp -P $SSH_PORT root@ВАШ_IP:${SSH_KEY_PATH} ~/.ssh/${NC}"
    echo ""
fi

echo -e "${YELLOW}Команда для подключения:${NC}"
if [[ "$USE_SSH_KEY" == true ]]; then
    echo -e "${CYAN}ssh -i ~/.ssh/$(basename $SSH_KEY_PATH) -p $SSH_PORT $USERNAME@ВАШ_IP${NC}"
else
    echo -e "${CYAN}ssh -p $SSH_PORT $USERNAME@ВАШ_IP${NC}"
fi

echo ""
echo -e "${RED}⚠ НЕ ЗАКРЫВАЙТЕ эту сессию до проверки входа!${NC}"
echo ""
echo -e "${BLUE}Полезные команды:${NC}"
echo -e "  ${CYAN}sudo ufw status${NC}              - статус firewall"
echo -e "  ${CYAN}sudo fail2ban-client status${NC}  - статус fail2ban"
echo ""
echo -e "${GREEN}Поддержите проект: ${NC}${CYAN}https://github.com/AlekseyNice/SecureInit${NC} ⭐"
echo ""
