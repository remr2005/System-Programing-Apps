# Графики по CSV (п.21).
# Запуск из каталога 7_lab/fs_benchmark:
#   gnuplot plot_results.gnuplot
#
# Нужен gnuplot: sudo apt install gnuplot-nox

if (!exists("bench_dir")) bench_dir = "bench_results"

set terminal pngcairo size 960, 540 enhanced font "Arial,10"
set datafile separator comma
set grid ytics
set ylabel "Время, с"
set format y "%.3f"
set xlabel "Точка монтирования (имя каталога)"
set xtics rotate by -35 scale 0

do for [tid in "15 16 17 18 19 20"] {
  outfile = bench_dir . "/plot_test_" . tid . ".png"
  set output outfile
  set title "Тест " . tid
  plot bench_dir . "/test_" . tid . ".csv" every ::1 using 4:xtic(1) with boxes lc rgb "#5b8ff9" notitle
}

unset output
