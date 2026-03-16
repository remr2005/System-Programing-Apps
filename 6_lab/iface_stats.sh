#!/bin/bash
# iface_stats.sh IFACE
# Скрипт выводит количество полученных и отправленных байт для заданного интерфейса.
# Используется mrtg как внешний источник данных (Target[...] в mrtg.cfg).

IFACE="$1"

if [ -z "$IFACE" ]; then
  echo "Usage: $0 <interface>" >&2
  exit 1
fi

# Формат /proc/net/dev:
#   Inter-|   Receive                                                |  Transmit
#            bytes    packets errs drop fifo frame compressed multicast ... bytes ...
# Нас интересуют 1-е (RX bytes) и 9-е (TX bytes) поля после двоеточия.
LINE=$(grep "$IFACE" /proc/net/dev | awk -F":" 'NR==1 {print $2}')

if [ -z "$LINE" ]; then
  echo "Interface $IFACE not found in /proc/net/dev" >&2
  # mrtg ожидает два числа, но при ошибке лучше вернуть нули
  echo "0"
  echo "0"
  exit 1
fi

RX_TX=$(echo "$LINE" | awk '{print $1 "\n" $9;}')

# MRTG для внешней программы ожидает 4 строки:
# 1) входящий счётчик, 2) исходящий счётчик, 3) uptime (сек), 4) имя/описание
echo "$RX_TX"
cut -d' ' -f1 /proc/uptime
hostname

