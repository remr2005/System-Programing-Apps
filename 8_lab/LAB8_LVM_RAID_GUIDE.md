# Лабораторная работа №8: LVM и программный RAID в GNU/Linux

Этот файл — пошаговый конспект по выполнению пунктов 1–12 с пояснением **каждой команды**: что делает и зачем нужна.

## Перед началом

Проверяем, что в ВМ видны дополнительные диски под лабораторную:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

- `lsblk` — показывает блочные устройства.
- `-o ...` — задает удобные колонки (имя, размер, тип, точка монтирования).
- Нужен, чтобы убедиться, что есть отдельные диски (`/dev/vdb`, `/dev/vdc`, `/dev/vdd`, `/dev/vde`) и не трогать системный диск.

---

## 1) Установка утилит LVM и RAID

```bash
sudo apt update
sudo apt install -y lvm2 mdadm
```

- `apt update` — обновляет индекс пакетов.
- `apt install lvm2 mdadm` — ставит:
  - `lvm2` (утилиты `pvcreate`, `vgcreate`, `lvcreate`, и др.),
  - `mdadm` (создание/обслуживание программных RAID).
- `-y` — автоматически подтверждает установку.

---

## 2) Пункты 1–4: PV, VG, LV, файловые системы

Используем:
- PV: `/dev/vdb /dev/vdc`
- VG: `vg_lab8`
- LV: `lv_data` (1G), `lv_logs` (512M)

```bash
sudo pvcreate /dev/vdb /dev/vdc
sudo vgcreate vg_lab8 /dev/vdb /dev/vdc
sudo lvcreate -n lv_data -L 1G vg_lab8
sudo lvcreate -n lv_logs -L 512M vg_lab8
sudo mkfs.ext4 /dev/vg_lab8/lv_data
sudo mkfs.ext4 /dev/vg_lab8/lv_logs
sudo mkdir -p /mnt/lv_data /mnt/lv_logs
sudo mount /dev/vg_lab8/lv_data /mnt/lv_data
sudo mount /dev/vg_lab8/lv_logs /mnt/lv_logs
```

Что делает каждая команда:

- `pvcreate /dev/vdb /dev/vdc`  
  Инициализирует диски как **Physical Volume** для LVM.

- `vgcreate vg_lab8 /dev/vdb /dev/vdc`  
  Создает **Volume Group** `vg_lab8`, объединяя два PV в общий пул пространства.

- `lvcreate -n lv_data -L 1G vg_lab8`  
  Создает логический том `lv_data` размером 1 ГиБ внутри `vg_lab8`.

- `lvcreate -n lv_logs -L 512M vg_lab8`  
  Создает второй LV под логи размером 512 МиБ.

- `mkfs.ext4 /dev/vg_lab8/lv_data` и `mkfs.ext4 /dev/vg_lab8/lv_logs`  
  Создает файловые системы ext4 на логических томах (иначе монтировать нельзя).

- `mkdir -p /mnt/lv_data /mnt/lv_logs`  
  Создает каталоги-точки монтирования.

- `mount ...`  
  Подключает тома в файловое дерево Linux.

---

## 3) Пункты 5–7: добавить новый PV, расширить LV и ФС

```bash
sudo pvcreate /dev/vdd
sudo vgextend vg_lab8 /dev/vdd
sudo lvextend -L +1G /dev/vg_lab8/lv_data
sudo resize2fs /dev/vg_lab8/lv_data
```

Пояснение:

- `pvcreate /dev/vdd` — подготавливает третий диск как PV.
- `vgextend vg_lab8 /dev/vdd` — добавляет новый PV в группу, увеличивая ее объем.
- `lvextend -L +1G ...` — увеличивает `lv_data` на 1 ГиБ.
- `resize2fs ...` — расширяет **файловую систему ext4** до нового размера LV.  
  Важно: увеличение LV само по себе не увеличивает размер ФС, нужен этот шаг.

Проверки:

```bash
sudo lvs
sudo vgs
df -h /mnt/lv_data
```

- `lvs` — показывает логические тома и их размеры.
- `vgs` — показывает группы томов и свободное/занятое место.
- `df -h` — показывает фактический размер смонтированной ФС.

---

## 4) Пункты 8–9: snapshot и резервная копия

```bash
sudo lvcreate -L 300M -s -n lv_data_snap /dev/vg_lab8/lv_data
sudo mkdir -p /mnt/lv_data_snap /backup
sudo mount -o ro /dev/vg_lab8/lv_data_snap /mnt/lv_data_snap
sudo tar -czf /backup/lv_data_backup_$(date +%F_%H-%M).tar.gz -C /mnt/lv_data_snap .
sudo umount /mnt/lv_data_snap
```

Пояснение:

- `lvcreate -s` — создает snapshot (`lv_data_snap`) исходного LV.
- `-L 300M` — выделяет COW-область под snapshot (можно подобрать по объему изменений).
- `mount -o ro` — монтирует snapshot только для чтения, чтобы backup был консистентным.
- `tar -czf ... -C ... .` — архивирует содержимое snapshot в `/backup`.
- `umount` — корректно отмонтирует snapshot.

Для отчета:

```bash
ls -lh /backup
```

---

## 5) Пункт 10: RAID0 из двух LVM-томов

```bash
sudo lvcreate -n lv_r0_a -L 700M vg_lab8
sudo lvcreate -n lv_r0_b -L 700M vg_lab8
sudo mdadm --create /dev/md0 --level=0 --raid-devices=2 \
  /dev/vg_lab8/lv_r0_a /dev/vg_lab8/lv_r0_b
sudo mkfs.ext4 /dev/md0
sudo mkdir -p /mnt/md0
sudo mount /dev/md0 /mnt/md0
```

Пояснение:

- Создаются 2 LV одинакового размера.
- `mdadm --create /dev/md0 --level=0` — собирает RAID0 (striping, без отказоустойчивости).
- `--raid-devices=2` — количество устройств в массиве.
- Затем создается ext4 и массив монтируется как обычный диск.

---

## 6) Пункт 11: RAID1 из двух LVM-томов + проверка статуса

```bash
sudo lvcreate -n lv_r1_a -L 700M vg_lab8
sudo lvcreate -n lv_r1_b -L 700M vg_lab8
sudo mdadm --create /dev/md1 --level=1 --raid-devices=2 \
  /dev/vg_lab8/lv_r1_a /dev/vg_lab8/lv_r1_b
sudo mkfs.ext4 /dev/md1
sudo mkdir -p /mnt/md1
sudo mount /dev/md1 /mnt/md1
```

Если `mdadm` спрашивает `Continue creating array?`, ответить `yes` (это стандартное подтверждение).

Проверка состояния:

```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md0
sudo mdadm --detail /dev/md1
```

- `/proc/mdstat` — краткий текущий статус всех md-массивов (в т.ч. синхронизация RAID1).
- `mdadm --detail` — подробная информация по конкретному массиву.

---

## 7) Пункт 12: автомонтирование RAID при старте

### 7.1 Сохранить конфиг mdadm

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

- `mdadm --detail --scan` — генерирует описание массивов (`ARRAY ...`).
- `tee -a` — добавляет эти строки в `/etc/mdadm/mdadm.conf`.
- `update-initramfs -u` — обновляет initramfs, чтобы массивы поднимались на ранней стадии загрузки.

### 7.2 Добавить md0/md1 в `/etc/fstab`

Узнать UUID:

```bash
sudo blkid /dev/md0 /dev/md1
```

Добавить в `/etc/fstab`:

```fstab
UUID=<UUID_md0>  /mnt/md0  ext4  defaults,nofail  0  2
UUID=<UUID_md1>  /mnt/md1  ext4  defaults,nofail  0  2
```

Пояснение:

- `UUID=...` — надежнее, чем `/dev/md0` (имена устройств могут меняться).
- `defaults` — стандартные опции монтирования.
- `nofail` — не валит загрузку, если устройство временно недоступно.
- `0 2` — параметры dump/fsck.

Проверка:

```bash
sudo mount -a
df -h | grep -E 'md0|md1'
```

- `mount -a` — применяет все записи из `fstab` сразу (без ребута).
- `df -h` — подтверждает, что `/mnt/md0` и `/mnt/md1` смонтированы.

---

## Что фиксировать в отчете после каждого этапа

Минимальный набор команд-скриншотов:

```bash
lsblk -f
sudo pvs
sudo vgs
sudo lvs
cat /proc/mdstat
sudo mdadm --detail /dev/md0
sudo mdadm --detail /dev/md1
df -h
```

И приложить:

- фрагмент `/etc/fstab` с `md0` и `md1`,
- фрагмент `/etc/mdadm/mdadm.conf` с `ARRAY ...`,
- вывод `ls -lh /backup` (для пункта с snapshot/backup).

---

## Короткий вывод для отчета

В ходе работы были освоены операции LVM: создание PV/VG/LV, расширение группы и логического тома, расширение файловой системы, создание snapshot и резервное копирование. Также были созданы и проверены программные RAID-массивы уровней 0 и 1 с использованием `mdadm`. Выполнена настройка автоподнятия массивов и их автомонтирования при загрузке системы.
