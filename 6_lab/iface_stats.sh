#!/bin/bash


IFACE="$1"

if [ -z "$IFACE" ]; then
  echo "Usage: $0 <interface>" >&2
  exit 1
fi


LINE=$(grep "$IFACE" /proc/net/dev | awk -F":" 'NR==1 {print $2}')

if [ -z "$LINE" ]; then
  echo "Interface $IFACE not found in /proc/net/dev" >&2
  echo "0"
  echo "0"
  exit 1
fi

RX_TX=$(echo "$LINE" | awk '{print $1 "\n" $9;}')


echo "$RX_TX"
cut -d' ' -f1 /proc/uptime
hostname

