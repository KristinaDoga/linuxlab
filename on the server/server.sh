#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kristina Doga

set -euo pipefail
IFS=$'\n\t'

USER="admeen"
SSH_FILE_NAME="lab_checker"
KEY_FILE="/home/$USER/.ssh/$SSH_FILE_NAME"
AUTH_KEYS="/home/$USER/.ssh/authorized_keys"
CMD_RESTRICT="command=\"/home/$USER/scripts/on_connect_ssh.sh\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CLIENT_FILE="$SCRIPT_DIR/client.sh"



# 1. Заходим под пользователем admeen
echo "[1] Проверка пользователя $USER..."

if ! id "$USER" >/dev/null 2>&1; then
    echo "Пользователь $USER не найден! Создаём..."
    sudo adduser --gecos "" "$USER"
    sudo usermod -aG sudo "$USER"
    if getent group docker >/dev/null 2>&1; then
        echo "Добавляем $USER в группу docker..."
        sudo usermod -aG docker "$USER"
    else
    echo "Группа docker не существует — пропускаем добавление пользователя."
fi
    echo "Пользователь $USER создан и добавлен в группы: sudo, docker."
else
    echo "Пользователь $USER существует. Проверяем группы..."
    # проверяем sudo
    if id -nG "$USER" | grep -qw "sudo"; then
        echo "Пользователь $USER уже в группе sudo."
    else
        echo "Добавляем $USER в группу sudo..."
        sudo usermod -aG sudo "$USER"
    fi

# проверяем docker
if getent group docker >/dev/null 2>&1; then
    if id -nG "$USER" | grep -qw "docker"; then
        echo "Пользователь $USER уже в группе docker."
    else
        echo "Добавляем $USER в группу docker..."
        sudo usermod -aG docker "$USER"
    fi
else
    echo "Группа docker не существует — пропускаем добавление пользователя."
fi

fi


# 2. Генерация ключей в ~/.ssh
echo "[2] Генерация SSH-ключа..."
sudo -u "$USER" mkdir -p /home/$USER/.ssh
sudo -u "$USER" chmod 700 /home/$USER/.ssh

if [ ! -f "$KEY_FILE" ]; then
    sudo -u "$USER" ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
else
    echo "Ключ уже существует, пропускаем генерацию."
fi


# 3. Запись публичного ключа в authorized_keys с ограничением

sudo mkdir -p "$(dirname "$AUTH_KEYS")" 
sudo touch "$AUTH_KEYS" 
sudo chown "$USER:$USER" "$AUTH_KEYS" 
sudo chmod 600 "$AUTH_KEYS"

PUB_KEY=$(sudo cat "${KEY_FILE}.pub")
echo "[3] Настройка authorized_keys..."
LINE="${CMD_RESTRICT} ${PUB_KEY}"

if ! sudo grep -Fqx "$LINE" "$AUTH_KEYS" 2>/dev/null; then
    echo "$LINE" | sudo tee -a "$AUTH_KEYS" >/dev/null
fi

sudo chown $USER:$USER "$AUTH_KEYS"
sudo chmod 600 "$AUTH_KEYS"

echo "[3] authorized_keys обновлён."

# 4. Внедрение приватного ключа в client.sh
echo "[4] Внедрение приватного ключа в client.sh..."

if [ ! -f "$CLIENT_FILE" ]; then
    echo "Ошибка: файл $CLIENT_FILE не найден!"
    exit 1
fi

# Читаем приватный ключ
PRIV_KEY=$(sudo cat "$KEY_FILE")

# Временный файл
TMP_CLIENT=$(mktemp)

# Флаг, чтобы знать, что вставили блок
INSERTED=0
# Флаг пропуска старого блока
SKIP_BLOCK=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Если это начало старого блока, пропускаем
    if [[ $line =~ ^PRIVATE_KEY_FILE= ]]; then
        SKIP_BLOCK=1
        continue
    fi
    if [[ $line =~ ^PRIVATE_KEY_CONTENT= ]] && [[ $SKIP_BLOCK -eq 1 ]]; then
        SKIP_BLOCK=2
        continue
    fi
    if [[ $SKIP_BLOCK -eq 2 ]]; then
        # ищем конец блока: тройные апострофы '''
        if [[ $line =~ ^\'\'\'$ ]]; then
            SKIP_BLOCK=0
        fi
        continue
    fi

    echo "$line" >> "$TMP_CLIENT"

    # Вставляем новый блок после IFS=, если ещё не вставили
    if [[ $INSERTED -eq 0 && $line =~ ^IFS= ]]; then
        echo "" >> "$TMP_CLIENT"
        echo "PRIVATE_KEY_FILE=\"$SSH_FILE_NAME\"" >> "$TMP_CLIENT"
        echo "PRIVATE_KEY_CONTENT='''" >> "$TMP_CLIENT"
        echo "$PRIV_KEY" >> "$TMP_CLIENT"
        echo "'''" >> "$TMP_CLIENT"
        INSERTED=1
    fi
done < "$CLIENT_FILE"

mv "$TMP_CLIENT" "$CLIENT_FILE"

echo "[4] client.sh обновлён."



# Создаем структуру для корректной работы скриптов
cp "$SCRIPT_DIR/worklab.zip" /home/$USER/
touch /home/$USER/run_log.txt
mkdir -p /home/$USER/verification/histories
mkdir -p /home/$USER/verification/reports
touch /home/$USER/verification/all_students.json
touch /home/$USER/verification/exceeded_limit.txt
mkdir -p /home/$USER/scripts
cp -r "$SCRIPT_DIR/scripts/"* /home/$USER/scripts/
chmod +x /home/$USER/scripts/on_connect_ssh.sh
chmod +x /home/$USER/scripts/run_verification.sh
chmod +x /home/$USER/scripts/verification.sh
chown -R "$USER:$USER" "/home/$USER"
chmod 770 /home/admeen/verification

echo "=== Готово! ==="


