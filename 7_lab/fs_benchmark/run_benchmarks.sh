#!/usr/bin/env bash
# Бенчмарки для п.15–20 (лабораторная). Результаты — в CSV (удобно для графиков, п.21).
# Запуск: ./run_benchmarks.sh
# Свои точки монтирования: FS_MOUNTS="/mnt/a /mnt/b" ./run_benchmarks.sh

set -euo pipefail

OUT_DIR="${OUT_DIR:-./bench_results}"
CSV_ALL="${CSV_ALL:-$OUT_DIR/all_tests.csv}"
CSV_BY_TEST="${CSV_BY_TEST:-$OUT_DIR}"

# Разделы по умолчанию — под твою схему; переопредели через env.
FS_MOUNTS="${FS_MOUNTS:-/mnt/ext2 /mnt/ext3 /mnt/ext4 /mnt/xfs /mnt/btrfs /mnt/zfs /mnt/reiser /mnt/fat32 /mnt/ntfs}"

SMALL_KB="${SMALL_KB:-16}"
READ_CYCLES="${READ_CYCLES:-100}"
LARGE_MB="${LARGE_MB:-500}"
SMALL_WRITE_COUNT="${SMALL_WRITE_COUNT:-500}"
TREE_DIRS="${TREE_DIRS:-1000}"

now_sec() { date +%s.%N; }

elapsed() {
  awk -v s="$1" -v e="$2" 'BEGIN { printf "%.6f", e - s }'
}

require_writable() {
  local m="$1"
  [[ -d "$m" ]] || { echo "SKIP (нет каталога): $m" >&2; return 1; }
  [[ -w "$m" ]] || { echo "SKIP (нет записи): $m" >&2; return 1; }
  return 0
}

fs_label() {
  basename "$1"
}

run_for_mounts() {
  local fn="$1"
  shift
  for m in $FS_MOUNTS; do
    require_writable "$m" || continue
    "$fn" "$m" || true
  done
}

append_csv() {
  local fs="$1" test_id="$2" test_name="$3" seconds="$4"
  mkdir -p "$OUT_DIR"
  echo "${fs},${test_id},${test_name},${seconds}" >> "$CSV_ALL"
  echo "${fs},${test_id},${test_name},${seconds}" >> "${CSV_BY_TEST}/test_${test_id}.csv"
}

# --- 15: чтение маленьких файлов 16 KiB, цикл >= 100 раз ---
bench_15_read_small() {
  local m="$1"
  local w
  w=$(mktemp -d "$m/bench15_XXXXXX")
  local f="$w/f16k.bin"
  dd if=/dev/zero of="$f" bs="${SMALL_KB}K" count=1 status=none conv=fsync 2>/dev/null || dd if=/dev/zero of="$f" bs="${SMALL_KB}K" count=1 status=none

  local t0 t1 i
  t0=$(now_sec)
  for ((i = 0; i < READ_CYCLES; i++)); do
    dd if="$f" of=/dev/null bs="${SMALL_KB}K" count=1 status=none iflag=fullblock 2>/dev/null \
      || cat "$f" >/dev/null
  done
  t1=$(now_sec)

  rm -rf "$w"
  append_csv "$(fs_label "$m")" "15" "read_small_${SMALL_KB}K_x${READ_CYCLES}" "$(elapsed "$t0" "$t1")"
}

# --- 16: запись большого файла 500 MiB ---
bench_16_write_large() {
  local m="$1"
  local w
  w=$(mktemp -d "$m/bench16_XXXXXX")
  local out="$w/large_${LARGE_MB}M.bin"
  local t0 t1
  t0=$(now_sec)
  dd if=/dev/zero of="$out" bs=1M count="$LARGE_MB" status=none conv=fsync 2>/dev/null \
    || dd if=/dev/zero of="$out" bs=1M count="$LARGE_MB" status=none
  t1=$(now_sec)
  rm -rf "$w"
  append_csv "$(fs_label "$m")" "16" "write_single_${LARGE_MB}MiB" "$(elapsed "$t0" "$t1")"
}

# --- 17: запись многих маленьких файлов ---
bench_17_write_small_many() {
  local m="$1"
  local w
  w=$(mktemp -d "$m/bench17_XXXXXX")
  local t0 t1 i
  t0=$(now_sec)
  for ((i = 0; i < SMALL_WRITE_COUNT; i++)); do
    dd if=/dev/zero of="$w/small_$(printf '%05d' "$i").bin" bs="${SMALL_KB}K" count=1 status=none 2>/dev/null \
      || dd if=/dev/zero of="$w/small_$(printf '%05d' "$i").bin" bs="${SMALL_KB}K" count=1 status=none
  done
  sync
  t1=$(now_sec)
  rm -rf "$w"
  append_csv "$(fs_label "$m")" "17" "write_many_${SMALL_WRITE_COUNT}x${SMALL_KB}K_sync" "$(elapsed "$t0" "$t1")"
}

# --- 18: запись большого файла + sync (отдельный замер «тяжёлой» записи) ---
bench_18_write_large_sync() {
  local m="$1"
  local w
  w=$(mktemp -d "$m/bench18_XXXXXX")
  local out="$w/large_sync_${LARGE_MB}M.bin"
  local t0 t1
  t0=$(now_sec)
  dd if=/dev/zero of="$out" bs=1M count="$LARGE_MB" status=none 2>/dev/null \
    || dd if=/dev/zero of="$out" bs=1M count="$LARGE_MB" status=none
  sync
  t1=$(now_sec)
  rm -rf "$w"
  append_csv "$(fs_label "$m")" "18" "write_single_${LARGE_MB}MiB_plus_sync" "$(elapsed "$t0" "$t1")"
}

bench_19_mkdir_tree() {
  local m="$1"
  local root="$m/bench_tree_$$"
  local t0 t1 a b c

  mkdir -p "$root"
  t0=$(now_sec)
  for a in $(seq -w 0 9); do
    mkdir -p "$root/L1_$a"
    for b in $(seq -w 0 9); do
      mkdir -p "$root/L1_$a/L2_$b"
      for c in $(seq -w 0 9); do
        mkdir -p "$root/L1_$a/L2_$b/L3_$c"
      done
    done
  done
  t1=$(now_sec)

  echo "needle" > "$root/L1_04/L2_02/L3_07/needle.txt"
  append_csv "$(fs_label "$m")" "19" "mkdir_tree_3levels_1110dirs" "$(elapsed "$t0" "$t1")"
}

bench_20_search() {
  local m="$1"
  local root="$m/bench_tree_$$"
  local t0 t1

  [[ -d "$root" ]] || { echo "SKIP (нет дерева для поиска): $root" >&2; return 1; }

  t0=$(now_sec)
  find "$root" -name 'needle.txt' -print >/dev/null
  t1=$(now_sec)

  append_csv "$(fs_label "$m")" "20" "find_in_existing_tree" "$(elapsed "$t0" "$t1")"
  rm -rf "$root"
}

main() {
  mkdir -p "$OUT_DIR" "$CSV_BY_TEST"
  echo "filesystem,test_id,test_name,seconds" >"$CSV_ALL"
  local tid
  for tid in 15 16 17 18 19 20; do
    echo "filesystem,test_id,test_name,seconds" >"${CSV_BY_TEST}/test_${tid}.csv"
  done

  echo "Результаты: $CSV_ALL" >&2
  echo "Точки: $FS_MOUNTS" >&2

  run_for_mounts bench_15_read_small
  run_for_mounts bench_16_write_large
  run_for_mounts bench_17_write_small_many
  run_for_mounts bench_18_write_large_sync
  run_for_mounts bench_19_mkdir_tree
  run_for_mounts bench_20_search

  echo "Готово. Для графиков: см. plot_results.gnuplot или импорт CSV в LibreOffice Calc." >&2
}

main "$@"
