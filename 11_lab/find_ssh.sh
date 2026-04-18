#!/bin/bash

if [ -z "$1" ]; then
    echo "Использование: $0 /путь/к/директории"
    exit 1
fi

SEARCH_DIR=$1

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Ошибка: Директория $SEARCH_DIR не найдена."
    exit 1
fi

echo "--- Поиск ошибок SSH в директории: $SEARCH_DIR ---"

ERR_PATTERNS="Failed password|invalid user|Connection closed|Authentication failure"

find "$SEARCH_DIR" -type f -name "*.log" | while read -r log_file; do
    results=$(grep -iE "sshd.*($ERR_PATTERNS)" "$log_file" 2>/dev/null)
    
    if [ -n "$results" ]; then
        echo -e "\n[ФАЙЛ]: $log_file"
        echo "--------------------------------------"
        echo "$results"
    fi
done

echo -e "\n--- Поиск завершен ---"
