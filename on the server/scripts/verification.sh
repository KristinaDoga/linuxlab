#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kristina Doga
set -euo pipefail

# Файл отчёта
REPORT="report.txt"
> "$REPORT"  # очистить старый отчёт

BASE="worklab/mathTeacher"

# ================= ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =================

append_error() {
    echo "$1" >> "$REPORT"
}

compare_file_content() {
    local file_path="$1"
    local expected="$2"

    if [ ! -e "$file_path" ]; then
        append_error "Файл $file_path отсутствует"
        return
    fi

    actual="$(cat -- "$file_path")"

    if [ "$actual" != "$expected" ]; then
        actual_esc="$(printf '%s' "$actual" | sed -e ':a;N;$!ba;s/\n/\\n/g')"
        expected_esc="$(printf '%s' "$expected" | sed -e ':a;N;$!ba;s/\n/\\n/g')"
        append_error "В файле $file_path получено $actual_esc ожидалось $expected_esc"
    fi
}

check_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        append_error "Каталог $dir отсутствует"
    fi
}

check_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        append_error "Файл $file отсутствует"
    fi
}

check_dir_absent() {
    local dir="$1"
    if [ -e "$dir" ]; then
        append_error "Каталог $dir присутствует, но должен отсутствовать"
    fi
}

check_file_absent() {
    local file="$1"
    if [ -e "$file" ]; then
        append_error "Файл $file присутствует, но должен отсутствовать"
    fi
}

# Проверка прав доступа (цифровая форма)
check_permissions() {
    local path="$1"
    local expected="$2"
    local actual
    actual=$(stat -c "%a" "$path" 2>/dev/null || echo "none")

    if [ "$actual" != "$expected" ]; then
        append_error "Для $path права $actual, ожидались $expected"
    fi
}

# Проверка наличия флага выполнения (x)
check_executable() {
    local path="$1"
    if [ ! -x "$path" ]; then
        append_error "Для $path отсутствует право на выполнение"
    fi
}

# Проверка владельца и группы
check_owner_group() {
    local path="$1"
    local expected_owner="$2"
    local expected_group="$3"
    local actual_owner actual_group
    actual_owner=$(stat -c "%U" "$path" 2>/dev/null || echo "none")
    actual_group=$(stat -c "%G" "$path" 2>/dev/null || echo "none")

    if [ "$actual_owner" != "$expected_owner" ] || [ "$actual_group" != "$expected_group" ]; then
        append_error "Для $path владелец $actual_owner:$actual_group, ожидалось $expected_owner:$expected_group"
    fi
}

# Проверка, содержит ли файл строку с подстрокой
check_file_contains() {
    local file="$1"
    local substring="$2"
    if [ ! -f "$file" ]; then
        append_error "Файл $file отсутствует"
        return
    fi
    if ! grep -q "$substring" "$file"; then
        append_error "В файле $file нет строки, содержащей '$substring'"
    fi
}

# ================== ПРОВЕРКИ ОСНОВНОЙ ЛАБОРАТОРНОЙ ==================

check_dir_absent "$BASE/class_7A_2011"
check_file_absent "$BASE/5a.jpg"
check_file_absent "$BASE/'1 сентября.png'"

check_dir_exists "$BASE/class_5A"
check_file_exists "$BASE/class_5A/5a.jpg"
check_dir_exists "$BASE/class_5A/lessons"
check_dir_exists "$BASE/class_5A/homework"

compare_file_content "$BASE/class_5A/lessons/lesson_addition.txt" "2 + 3 = 5"
compare_file_content "$BASE/class_5A/lessons/lesson_subtraction.txt" "5 - 2 = 3"
compare_file_content "$BASE/class_5A/lessons/lesson_multiplication.txt" "3 * 4 = 12"

compare_file_content "$BASE/class_5A/homework/hw_addition.txt" "1+1, 4+5"
compare_file_content "$BASE/class_5A/homework/hw_subtraction.txt" "10-3, 7-2"
compare_file_content "$BASE/class_5A/homework/hw_multiplication.txt" "2*2, 5*3"

check_dir_exists "$BASE/class_5B"
check_dir_exists "$BASE/class_5B/lessons"
check_dir_exists "$BASE/class_5B/homework"

compare_file_content "$BASE/class_5B/lessons/lesson_addition.txt" "2 + 3 = 5"
compare_file_content "$BASE/class_5B/lessons/lesson_subtraction.txt" "5 - 2 = 3"
compare_file_content "$BASE/class_5B/lessons/lesson_multiplication.txt" "3 * 4 = 12"

expected_all_homework="1+1, 4+5
10-3, 7-2
2*2, 5*3
for 5B from 5A"
compare_file_content "$BASE/class_5B/homework/all_homework.txt" "$expected_all_homework"

expected_found_files="class_5A/homework/hw_addition.txt
class_5A/homework/hw_subtraction.txt
class_5A/homework/hw_multiplication.txt
class_5B/homework/all_homework.txt"
compare_file_content "$BASE/found_files.txt" "$expected_found_files"

# ================== ПРОВЕРКИ ANSWERS ==================

ANS="$BASE/answers"

check_dir_exists "$ANS"
check_file_exists "$ANS/.exam.txt"
check_file_exists "$ANS/vpr.txt"
check_file_exists "$ANS/greeting.sh"
check_dir_exists "$ANS/grades"
check_file_exists "$ANS/grades/ivanov.txt"

check_permissions "$ANS/.exam.txt" "444"
check_permissions "$ANS/vpr.txt" "660"
check_executable "$ANS/greeting.sh"
check_permissions "$ANS/grades" "755"
check_permissions "$ANS/grades/ivanov.txt" "777"

compare_file_content "$ANS/grades/ivanov.txt" "алгебра: 5
геометрия: 4"
compare_file_content "$ANS/vpr.txt" "1: треугольник"

# ================== НОВЫЕ ПРОВЕРКИ: EXAM-RESULTS ==================

EXAM="worklab/exam-results"

check_dir_exists "$EXAM"
check_permissions "$EXAM" "770"

# Проверки файлов и их содержимого
compare_file_content "$EXAM/Dmitrienko.txt" "56/100"
check_permissions "$EXAM/Dmitrienko.txt" "770"

compare_file_content "$EXAM/Sidorova.txt" "95/100"
check_permissions "$EXAM/Sidorova.txt" "764"

compare_file_content "$EXAM/Petrov.txt" "72/100"
check_permissions "$EXAM/Petrov.txt" "746"

compare_file_content "$EXAM/Averina.txt" "100/100"
check_permissions "$EXAM/Averina.txt" "707"

check_file_exists "$EXAM/right.txt"

# ================== ПРОВЕРКА USERINFO ==================

UI="worklab/userInfo"
check_file_exists "$UI/passwd.txt"
check_file_contains "$UI/passwd.txt" "labus"

check_file_exists "$UI/group.txt"
check_file_contains "$UI/group.txt" "teachers"

# ================== ПРОВЕРКА ФАЙЛА right.txt (владельцы/группы) ==================

if [ -f "$EXAM/right.txt" ]; then
    # Проверяем по содержимому файла right.txt
    while read -r line; do
        case "$line" in
            *Averina.txt*)
                [[ "$line" == *"linuxoid linuxoid"* ]] || append_error "Неверный владелец/группа для Averina.txt"
                ;;
            *Dmitrienko.txt*)
                [[ "$line" == *"linuxoid linuxoid"* ]] || append_error "Неверный владелец/группа для Dmitrienko.txt"
                ;;
            *Petrov.txt*)
                [[ "$line" == *"linuxoid teachers"* ]] || append_error "Неверный владелец/группа для Petrov.txt"
                ;;
            *Sidorova.txt*)
                [[ "$line" == *"linuxoid teachers"* ]] || append_error "Неверный владелец/группа для Sidorova.txt"
                ;;
        esac
    done < "$EXAM/right.txt"
fi

# ================== ПРОВЕРКА PACKAGEINFO ==================

PKG="worklab/packageInfo/packages.txt"
check_file_exists "$PKG"

if [ -f "$PKG" ]; then
    # Считываем файл построчно, убираем лишние пробелы
    mapfile -t pkglines < <(sed 's/[[:space:]]*$//' "$PKG")

    # Проверяем наличие нужных путей (в любом порядке)
    required_paths=(
        "/usr/bin/tree"
        "/usr/bin/screenfetch"
        "/usr/bin/cpufetch"
    )

    for req in "${required_paths[@]}"; do
        found=false
        for line in "${pkglines[@]}"; do
            if [[ "$line" == "$req" ]]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            append_error "Путь к исполняемому файлу ${req##*/} не прописан в packages.txt"
        fi
    done
fi

# ================== ПРОВЕРКА LINKINFO ==================

LINKS="worklab/linksInfo"
ARCHIVE="$LINKS/archive"

# Проверяем наличие каталога linksInfo
check_dir_exists "$LINKS"

# Проверяем отсутствие файла message.txt
check_file_absent "$LINKS/message.txt"

# Проверяем наличие подкаталога archive
check_dir_exists "$ARCHIVE"

# Проверяем файлы с экзаменом
check_file_exists "$ARCHIVE/exam-date.txt"
compare_file_content "$ARCHIVE/exam-date.txt" "Экзамен будет 22.07.2020"

# Проверяем "битую" символическую ссылку
SYM_FILE="$ARCHIVE/message-sym.txt"
if [ -L "$SYM_FILE" ]; then
    target=$(readlink "$SYM_FILE" 2>/dev/null || echo "")
    if [ -n "$target" ] && [ ! -e "$LINKS/$(basename "$target")" ]; then
        # целевой файл отсутствует — это ожидаемо
        :
    else
        append_error "Символьная ссылка $SYM_FILE должна вести на отсутствующий файл message.txt"
    fi
else
    append_error "$SYM_FILE не является символьной ссылкой"
fi


# ================== ФИНАЛИЗАЦИЯ ==================

if [ ! -s "$REPORT" ]; then
    echo "Лабораторная сдана без ошибок" > "$REPORT"
fi
