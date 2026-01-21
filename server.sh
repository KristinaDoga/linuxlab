#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kristina Doga

set -euo pipefail
IFS=$'\n\t'

SSHD_CFG="/etc/ssh/ssh_config"
USER="admeen"
SSH_FILE_NAME="lab_checker"
KEY_FILE="/home/$USER/.ssh/$SSH_FILE_NAME"
AUTH_KEYS="/home/$USER/.ssh/authorized_keys"
CMD_RESTRICT='command="/home/admeen/scripts/on_connect_ssh.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding'
KEY_FILE="/home/$USER/.ssh/$SSH_FILE_NAME"
CLIENT_FILE="./client.sh"

# 1. Заходим под пользователем admeen
echo "[1] Проверка пользователя $USER..."

if ! id "$USER" >/dev/null 2>&1; then
    echo "Пользователь $USER не найден! Создаём..."
    sudo adduser --gecos "" "$USER"
    sudo usermod -aG sudo "$USER"
    sudo usermod -aG docker "$USER"
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
    if id -nG "$USER" | grep -qw "docker"; then
        echo "Пользователь $USER уже в группе docker."
    else
        echo "Добавляем $USER в группу docker..."
        sudo usermod -aG docker "$USER"
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
PUB_KEY=$(sudo cat ${KEY_FILE}.pub)
echo "[3] Настройка authorized_keys..."
echo "${CMD_RESTRICT} ${PUB_KEY}" | sudo tee "$AUTH_KEYS" >/dev/null
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

while IFS= read -r line; do
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
cp run_log.txt /home/admeen/
cp worklab.zip /home/admeen/
mkdir -p /home/admeen/verification/histories
mkdir -p /home/admeen/verification/reports
touch /home/admeen/verification/all_students.json
touch /home/admeen/verification/exceeded_limit.txt
cp -r scripts /home/admeen
chmod +x /home/admeen/scripts/on_connect_ssh.sh
chmod +x /home/admeen/scripts/run_verification.sh
chmod +x /home/admeen/scripts/verification.sh
chown -R admeen:admeen /home/admeen
sudo usermod -aG admeen root
echo "=== Готово! ==="
