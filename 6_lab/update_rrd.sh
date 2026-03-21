#!/bin/bash

IFACE="$1"

if [ -z "$IFACE" ]; then
  echo "Usage: $0 <interface>" >&2
  exit 1
fi

RRD="/home/kemran/System-Programing-Apps/6_lab/eth0.rrd"

LINE=$(grep "$IFACE" /proc/net/dev | awk -F":" 'NR==1 {print $2}')

if [ -z "$LINE" ]; then
  echo "Failed to read counters for $IFACE" >&2
  exit 1
fi

INPUT=$(echo "$LINE" | awk '{print $1}')
OUTPUT=$(echo "$LINE" | awk '{print $9}')

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
  echo "Failed to read counters for $IFACE" >&2
  exit 1
fi

rrdtool update "$RRD" -t input:output N:"$INPUT":"$OUTPUT"

