#!/bin/bash
set -euo pipefail

STUDENT="$1"

# Переменные
ARCHIVE="/home/admeen/verification/${STUDENT}.tar.gz"
SCRIPT="/home/admeen/scripts/verification.sh"
REPORT_DIR="/home/admeen/verification/reports"
HISTORY_DIR="/home/admeen/verification/histories"


# Проверка существования архива
if [ ! -f "$ARCHIVE" ]; then
  echo "Ошибка: архив $ARCHIVE не найден" > run_log.txt
  exit 1
fi

# Создаём директории, если их нет
mkdir -p "$REPORT_DIR" "$HISTORY_DIR"

USER_ID=$(id -u admeen)
GROUP_ID=$(id -g admeen)
LOG_FILE="/home/admeen/scripts/run_log.txt"

# Запуск Docker и логирование
sudo -u admeen -H bash -c "
docker run --rm \
  -v \"$ARCHIVE:/work/worklab.tar.gz:ro\" \
  -v \"$SCRIPT:/work/verification.sh:ro\" \
  -v \"$REPORT_DIR:/work/reports\" \
  -v \"$HISTORY_DIR:/work/histories\" \
  ubuntu:22.04 bash -c \"
    mkdir -p /work/worklab &&
    tar -xzf /work/worklab.tar.gz -C /work/worklab &&
    cd /work/worklab &&
    cp history.txt /work/histories/'${STUDENT}.txt'
    bash /work/verification.sh &&
    echo \"======\" >> /work/reports/'${STUDENT}.txt' &&
    cat report.txt >>  /work/reports/'${STUDENT}.txt'

  \" >> \"$LOG_FILE\" 2>&1
"
