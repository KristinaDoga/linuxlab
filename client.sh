#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

PRIVATE_KEY_FILE="lab_checker"
PRIVATE_KEY_CONTENT='''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
AAAECTsGxJj0prFqUh/SdIUTR1aP/SAjk/WIzaLIFM1X8rj4/sNLM3NgPq6M/XrF2HKoAw
Cwxemwn29nBC9lj3zkhAAAAAEWFkbWVlbkBxbHNqcXVyenN1AQIDBA==
-----END OPENSSH PRIVATE KEY-----
'''




# ======================================
# 1. Тут после запуска server.sh будут PRIVATE_KEY_FILE 
# и PRIVATE_KEY_CONTENT с реальным именем и ключом
# ======================================
USERNAME="linuxoid"
HOME="/home/linuxoid"
LAB_DIR="$HOME"
SERVER="admeen@45.144.179.139"
PRIVATE_KEY_PATH="$HOME/.ssh/$PRIVATE_KEY_FILE"

# ======================================
# 2. Проверка установки SSH
# ======================================
if ! command -v ssh >/dev/null 2>&1; then
    echo "SSH не найден, устанавливаем..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y openssh-client
        echo "SSH установлен"
    else
        echo "Пакетный менеджер не поддерживается, установите SSH вручную"
        exit 1
    fi
else
    echo "SSH уже установлен"
fi

# ======================================
# 3. Создание локального пользователя Linuxoid
# ======================================


if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "Создаём пользователя $USERNAME..."
    sudo adduser --gecos "" "$USERNAME"
    sudo usermod -aG sudo "$USERNAME"
    # Скрыть пользователя из дисплейного менеджера
    sudo mkdir -p /var/lib/AccountsService/users
    echo -e "[User]\nSystemAccount=true" | sudo tee /var/lib/AccountsService/users/linuxoid
    echo "Пользователь $USERNAME создан и добавлен в sudo"
else
    echo "Пользователь $USERNAME уже существует"
fi

# ======================================
# 4. Пробное соединение по ключу с сервером
# ======================================

# ======= подготовка ключа =======
sudo -u "$USERNAME" bash <<EOF
set -e
cd "$HOME"
mkdir -p .ssh
chmod 700 .ssh
cd .ssh

if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    cat > "$PRIVATE_KEY_FILE" <<KEYEOF$PRIVATE_KEY_CONTENT
KEYEOF
    chmod 600 "$PRIVATE_KEY_FILE"
    echo "Приватный ключ создан."
else
    echo "Приватный ключ уже существует."
fi
EOF

mkdir -p "$LAB_DIR"

ssh -i "$HOME/.ssh/$PRIVATE_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "$SERVER" -- --get-lab > "$LAB_DIR/worklab.zip"


# ======= распаковка на клиенте =======
unzip -o "$LAB_DIR/worklab.zip" -d "$LAB_DIR"
chown -R linuxoid:linuxoid "$LAB_DIR"
echo "Лабораторная распакована в $LAB_DIR"
rm -f "$LAB_DIR/worklab.zip"

# ======================================
# 4. Данные студента
# ======================================
DATA_FILE="$HOME/.studentData"

# Ввод данных
while true; do
    read -p "Фамилия и имя студента (кириллицей): " FIO
    if [[ -n "$FIO" ]]; then
        break
    else
        echo "Поле ФИО не может быть пустым. Попробуйте снова."
    fi
done

# Ввод группы с проверкой на пустое значение
while true; do
    read -p "Группа студента: " GROUP
    if [[ -n "$GROUP" ]]; then
        break
    else
        echo "Поле группа не может быть пустым. Попробуйте снова."
    fi
done
# Запись в файл (перезапишет, если файл уже есть)
echo "$FIO" > "$DATA_FILE"
echo "$GROUP" >> "$DATA_FILE"

# ======================================
# 5. Функция для подключения к серверу с аргументами
# ======================================

LABSERVER_FUNC=$(cat <<EOF
labserver() {

    if [ -z "$SERVER" ] || [ -z "$PRIVATE_KEY_PATH" ]; then
        echo "Ошибка: переменные SERVER и PRIVATE_KEY_PATH должны быть заданы"
        return 1
    fi

    if [ \$# -eq 0 ]; then
        echo "Ошибка: необходимо указать команду для сервера:"
        echo "  --send-lab"
        return 1
    fi

    if [ "\$1" = "--send-lab" ]; then
        # Проверяем наличие .studentData
        if [ ! -f /home/linuxoid/.studentData ]; then
            echo "Ошибка: нет файла /home/linuxoid/.studentData"
            return 1
        fi

        # Читаем ФИО и группу студента
        FIO=\$(head -n 1 /home/linuxoid/.studentData)
        GROUP=$(head -n 2 /home/linuxoid/.studentData | tail -n 1)

        # Сохраняем историю в файл с ФИО
        cat ~/.bash_history > "/home/linuxoid/history.txt"

        # Путь к архиву
        ARCHIVE="/home/linuxoid/\${FIO}.tar.gz"

        # Создаём архив всей папки /home/linuxoid
        tar -czf "\$ARCHIVE" -C /home/linuxoid .

        # Отправляем архив на сервер
        ssh -i "$PRIVATE_KEY_PATH" -o StrictHostKeyChecking=no "$SERVER" -- --send-lab "\$GROUP" "\$FIO" < "\$ARCHIVE"

        # Удаляем временный архив
        rm -f "\$ARCHIVE"
        rm -f "/home/linuxoid/history.txt"
    else
        echo "Укажите верный аргумент"
    fi
}
EOF
)

# Добавляем функцию в ~/.bashrc, если её там ещё нет
if ! grep -q "labserver()" "$HOME/.bashrc"; then
    echo "$LABSERVER_FUNC" >> "$HOME/.bashrc"
    echo "Функция labserver добавлена в ~/.bashrc"
    echo "Чтобы применить изменения: source ~/.bashrc"
else
    echo "Функция labserver уже существует"
fi