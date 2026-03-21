### Лабораторная №6 — мониторинг сетевой активности (гайд)

Интерфейс: **`wlp2s0`**  
Каталог работы: **`/home/kemran/System-Programing-Apps/6_lab`**

---

## 1. Скрипт для сбора статистики с интерфейса

Файл: `iface_stats.sh`

```bash
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
```

**Как работает:**

- Берёт имя интерфейса из аргумента (`wlp2s0`).
- Читает строку интерфейса из `/proc/net/dev`, извлекает:
  - 1‑е поле – RX bytes (входящие байты),
  - 9‑е поле – TX bytes (исходящие байты).
- Дополнительно выводит:
  - uptime в секундах из `/proc/uptime`,
  - имя хоста (`hostname`).
- В итоге печатает 4 строки в формате, который ожидает MRTG.

---

## 2. Конфигурация MRTG (`mrtg.cfg`)

Файл: `mrtg.cfg`

```cfg
WithPeak[^]: wym
Suppress[^]: y

# Внешний скрипт: iface_stats.sh wlp2s0
Target[wlp2s0]: `/home/kemran/System-Programing-Apps/6_lab/iface_stats.sh wlp2s0`
WorkDir: /home/kemran/System-Programing-Apps/6_lab/html/mrtg
Options[wlp2s0]: growright
Title[wlp2s0]: wlp2s0 Traffic
PageTop[wlp2s0]: wlp2s0 Traffic
MaxBytes[wlp2s0]: 99999999
kilo[wlp2s0]: 1024
YLegend[wlp2s0]: bytes per Second
ShortLegend[wlp2s0]: bytes/s
LegendO[wlp2s0]: wlp2s0 In Traffic :
LegendI[wlp2s0]: wlp2s0 Out Traffic :
WriteExpires: Yes
Refresh: 300
```

**Смысл основных директив:**

- **`Target[wlp2s0]`** – MRTG при запуске выполняет:

  ```bash
  /home/kemran/System-Programing-Apps/6_lab/iface_stats.sh wlp2s0
  ```

  Читает 4 строки (RX, TX, uptime, hostname) и по разнице RX/TX между запусками считает среднюю скорость входящего/исходящего трафика.

- **`WorkDir`** – каталог, куда MRTG пишет:
  - HTML‑страницы (`wlp2s0.html`),
  - PNG‑графики (`wlp2s0-day.png`, `wlp2s0-week.png`),
  - свои служебные файлы.

- **`Options[wlp2s0]: growright`** – ось времени идёт слева направо.
- **`MaxBytes`, `kilo`, `YLegend`, `ShortLegend`, `LegendO`, `LegendI`** – масштаб и подписи (bytes/s, In/Out).
- **`WriteExpires`, `Refresh: 300`** – HTML обновляется каждые 300 секунд (5 минут).

**Запуск MRTG:**

```bash
mkdir -p /home/kemran/System-Programing-Apps/6_lab/html/mrtg

env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg
env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg
env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg

xdg-open /home/kemran/System-Programing-Apps/6_lab/html/mrtg/wlp2s0.html
```

Для автоматического сбора:

```bash
crontab -e

0-59/5 * * * * env LANG=C /usr/bin/mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg
```

---

## 3. Кольцевая БД RRD (`eth0.rrd`)

Создание:

```bash
cd /home/kemran/System-Programing-Apps/6_lab

rrdtool create eth0.rrd --step 300 \
 DS:input:COUNTER:600:U:U \
 DS:output:COUNTER:600:U:U \
 RRA:AVERAGE:0.5:1:576 \
 RRA:MAX:0.5:1:576 \
 RRA:AVERAGE:0.5:6:672 \
 RRA:MAX:0.5:6:672 \
 RRA:AVERAGE:0.5:24:732 \
 RRA:MAX:0.5:24:732 \
 RRA:AVERAGE:0.5:144:1460 \
 RRA:MAX:0.5:144:1460
```

**Параметры:**

- `--step 300` – базовый шаг 300 секунд (5 минут).

**DS (источники данных):**

- `DS:input:COUNTER:600:U:U`
- `DS:output:COUNTER:600:U:U`

Задают два счётчика:

- `input` / `output` – имена источников (вход/выход),
- `COUNTER` – тип «накапливающийся счётчик» (RRD сам считает скорость),
- `600` – максимум 600 секунд без обновления, иначе UNKNOWN,
- `U:U` – нет границ по минимуму/максимуму.

**RRA (архивы):**

Каждый `RRA` задаёт, как хранить историю:

- `RRA:AVERAGE:0.5:1:576` – среднее за каждый шаг (5 минут), 576 точек ≈ 2 суток.
- `RRA:AVERAGE:0.5:6:672` – 6×5 минут = 30 минут за точку, 672 точки ≈ 2 недели.
- `RRA:AVERAGE:0.5:24:732` – 2 часа за точку, ≈ несколько месяцев.
- `RRA:AVERAGE:0.5:144:1460` – 12 часов за точку, ≈ несколько лет.

Таким образом, `eth0.rrd` – это «кольцевая» база, где:

- хранятся два счётчика (вход/выход),
- старая история постепенно затирается новой,
- есть разные уровни детализации по времени.

---

## 4. Обновление RRD (`update_rrd.sh`)

Файл: `update_rrd.sh`

```bash
#!/bin/bash
# update_rrd.sh IFACE
# Обновляет кольцевую БД /home/kemran/System-Programing-Apps/6_lab/eth0.rrd
# текущими счётчиками байт на интерфейсе.

IFACE="$1"

if [ -z "$IFACE" ]; then
  echo "Usage: $0 <interface>" >&2
  exit 1
fi

RRD="/home/kemran/System-Programing-Apps/6_lab/eth0.rrd"

# Читаем счётчики напрямую из /proc/net/dev, как в iface_stats.sh
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
```

**Как использовать:**

```bash
cd /home/kemran/System-Programing-Apps/6_lab
chmod +x update_rrd.sh
./update_rrd.sh wlp2s0
```

Для автоматического обновления (user crontab):

```bash
crontab -e

*/5 * * * * /home/kemran/System-Programing-Apps/6_lab/update_rrd.sh wlp2s0
```

---

## 5. Построение графиков из RRD

### Полный график (`net.png`)

```bash
cd /home/kemran/System-Programing-Apps/6_lab

rrdtool graph net.png -v "bytes/sec" --slope-mode --imgformat PNG \
 DEF:input=eth0.rrd:input:AVERAGE \
 DEF:output=eth0.rrd:output:AVERAGE \
 "CDEF:output_neg=output,-1,*" \
 AREA:input#32CD32:"In " \
 GPRINT:input:MAX:"Max\: %6.1lf %S" \
 GPRINT:input:AVERAGE:"Average\: %6.1lf %S" \
 GPRINT:input:LAST:"Current\: %6.1lf %S\n" \
 HRULE:0#000000 \
 AREA:output_neg#0033CC:"Out" \
 GPRINT:output:MAX:"Max\: %6.1lf %S" \
 GPRINT:output:AVERAGE:"Average\: %6.1lf %S" \
 GPRINT:output:LAST:"Current\: %6.1lf %S\n"
```

**Разбор:**

- `DEF:input/output` – подтягивают данные из `eth0.rrd`.
- `CDEF:output_neg=output,-1,*` – инвертирует исходящий трафик (рисуем его вниз).
- `AREA:input#32CD32:"In "` – зелёная заливка входящего трафика.
- `AREA:output_neg#0033CC:"Out"` – синяя заливка исходящего.
- `GPRINT` – печатает Max/Average/Current под графиком.
- `HRULE:0` – горизонтальная ось 0, разделяющая In/Out.

### График за последние ~30 минут (`net-30min.png`)

```bash
rrdtool graph net-30min.png -v "bytes/sec" --slope-mode --imgformat PNG \
 --start -2000 --end now \
 DEF:input=eth0.rrd:input:AVERAGE \
 DEF:output=eth0.rrd:output:AVERAGE \
 "CDEF:output_neg=output,-1,*" \
 AREA:input#32CD32:"In " \
 GPRINT:input:MAX:"Max\: %6.1lf %S" \
 GPRINT:input:AVERAGE:"Average\: %6.1lf %S" \
 GPRINT:input:LAST:"Current\: %6.1lf %S\n" \
 HRULE:0#000000 \
 AREA:output_neg#0033CC:"Out" \
 GPRINT:output:MAX:"Max\: %6.1lf %S" \
 GPRINT:output:AVERAGE:"Average\: %6.1lf %S" \
 GPRINT:output:LAST:"Current\: %6.1lf %S\n"
```

- `--start -2000` – взять последние ~2000 секунд (~33 минуты).
- `--end now` – до текущего момента.

Для отчёта удобно использовать `net-30min.png` как пример графика сетевой активности за заданный короткий промежуток времени, где на одном графике одновременно виден входящий (In, зелёный) и исходящий (Out, синий) трафик.

