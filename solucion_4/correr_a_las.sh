#!/bin/bash
# ============================================================
# correr_a_las.sh — Espera hasta una hora dada y luego lanza correr.sh
# ============================================================
# Uso:  nohup caffeinate -i bash correr_a_las.sh HH:MM SEGUNDOS RONDAS [instancias...] > programada.log 2>&1 &
# Ej.:  UN_NUCLEO=1 nohup caffeinate -i bash correr_a_las.sh 05:00 3600 3 01 02 03 07 08 > programada.log 2>&1 &
# caffeinate evita que la Mac se duerma mientras espera y mientras corre
# (la Mac debe estar enchufada y con la tapa abierta).
# Cancelar antes de que empiece:  pkill -f correr_a_las.sh

cd "$(dirname "$0")"
HORA=$1
shift
objetivo=$(date -j -f "%H:%M:%S" "$HORA:00" +%s)
ahora=$(date +%s)
[ "$objetivo" -le "$ahora" ] && objetivo=$((objetivo + 86400))   # si ya pasó, mañana
echo "Esperando hasta $(date -r "$objetivo" '+%Y-%m-%d %H:%M')"
sleep $((objetivo - ahora))
echo "Empieza: $(date '+%H:%M')"
bash correr.sh "$@"
