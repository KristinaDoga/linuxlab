#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

case "$SSH_ORIGINAL_COMMAND" in
    --get-lab)
        LAB_ARCHIVE="/home/admeen/worklab.zip"

        if [ ! -f "$LAB_ARCHIVE" ]; then
            echo "Ошибка: архив $LAB_ARCHIVE не найден" >&2
            exit 1
        fi

        # Отправляем архив строго в stdout без лишнего вывода
        cat "$LAB_ARCHIVE"
        exit 0
        ;;

    --send-lab*)
        # Убираем префикс --send-lab и обрезаем пробелы
        FIO="${SSH_ORIGINAL_COMMAND#--send-lab }"
        FIO="$(echo "$FIO" | xargs)"

        # Проверка на пустое значение
        if [ -z "$FIO" ]; then
            echo "Ошибка: нужно указать ФИО студента" >&2
            exit 1
        fi

        echo "Группа и ФИ студента: $FIO" >&2

        VERIFICATION_DIR="/home/admeen/verification"
        ARCHIVE="$VERIFICATION_DIR/${FIO}.tar.gz"

        # Сохраняем переданное через stdin содержимое в архив
        cat > "$ARCHIVE"

        # Запускаем проверку
        /home/admeen/scripts/run_verification.sh "$FIO"

        # === НОВАЯ ЛОГИКА ===

        EXCEEDED_FILE="$VERIFICATION_DIR/exceeded_limit.txt"
        REPORT_FILE="$VERIFICATION_DIR/reports/${FIO}.txt"

        # 1. Проверяем, есть ли ФИО в exceeded_limit.txt
        if grep -Fq -- "$FIO" "$EXCEEDED_FILE"; then
            echo "Лимит превышен"
            exit 0
        fi

        # 2. Если лимит не превышен — показываем часть отчёта после последней "======"
        if [ ! -f "$REPORT_FILE" ]; then
            echo "Ошибка: файл отчёта не найден: $REPORT_FILE" >&2
            exit 1
        fi

        # Находим номер последней строки "======"
        last_line=$(grep -n "^======" "$REPORT_FILE" | tail -n 1 | cut -d: -f1)

        if [ -z "$last_line" ]; then
            # Если разделителей нет — показать весь файл
            cat "$REPORT_FILE"
        else
            # Показать всё после последнего разделителя
            tail -n +"$((last_line + 1))" "$REPORT_FILE"
        fi
        ;;

    *)
        echo "Использование:" >&2
        echo "  --send-lab" >&2
        exit 1
        ;;
esac
