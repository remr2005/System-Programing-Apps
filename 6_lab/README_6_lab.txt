Шаги для выполнения 6‑й лабораторной
====================================

Интерфейс: wlp2s0
При необходимости замени wlp2s0 на свой интерфейс во всех командах и файлах.

1. Подготовка каталогов и прав
------------------------------

mkdir -p /home/kemran/System-Programing-Apps/6_lab/html/mrtg
chmod +x /home/kemran/System-Programing-Apps/6_lab/iface_stats.sh
chmod +x /home/kemran/System-Programing-Apps/6_lab/update_rrd.sh

2. Проверка скрипта iface_stats.sh
----------------------------------

/home/kemran/System-Programing-Apps/6_lab/iface_stats.sh wlp2s0

Должно вывести две строки с числами (RX и TX байты).

3. Первый запуск mrtg
---------------------

sudo env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg
sudo env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg
sudo env LANG=C mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg

Потом:

xdg-open /home/kemran/System-Programing-Apps/6_lab/html/mrtg/wlp2s0.html

Сделай скриншот графика.

4. Добавление mrtg в cron
-------------------------

sudo crontab -e

Строка:

0-59/5 * * * * env LANG=C /usr/bin/mrtg /home/kemran/System-Programing-Apps/6_lab/mrtg.cfg

5. Создание RRD базы
--------------------

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

6. Обновление RRD (проверка)
----------------------------

sudo /home/kemran/System-Programing-Apps/6_lab/update_rrd.sh wlp2s0

7. Добавление обновления RRD в cron
-----------------------------------

sudo crontab -e

Строка:

*/5 * * * * /home/kemran/System-Programing-Apps/6_lab/update_rrd.sh wlp2s0

8. Генерация графика из RRD
---------------------------

Через 10–20 минут трафика:

cd /home/kemran/System-Programing-Apps/6_lab

rrdtool graph net.png -v "bytes/sec" --slope-mode --imgformat PNG \
 DEF:input=eth0.rrd:input:AVERAGE \
 DEF:output=eth0.rrd:output:AVERAGE \
 CDEF:output_neg=output,-1,* \
 AREA:input#32CD32:"In " \
 GPRINT:input:MAX:"Max\\: %6.1lf %S" \
 GPRINT:input:AVERAGE:"Average\\: %6.1lf %S" \
 GPRINT:input:LAST:"Current\\: %6.1lf %S\\n" \
 HRULE:0#000000 \
 AREA:output_neg#0033CC:"Out" \
 GPRINT:output:MAX:"Max\\: %6.1lf %S" \
 GPRINT:output:AVERAGE:"Average\\: %6.1lf %S" \
 GPRINT:output:LAST:"Current\\: %6.1lf %S\\n"

Открой результат:

xdg-open /home/kemran/System-Programing-Apps/6_lab/net.png

