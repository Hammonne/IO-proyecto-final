#!/bin/bash
# dia.sh — Corrida de día del 13/11: v12 en 06 04 10, y v12 con visitas en la 01
# Uso: nohup caffeinate -i bash dia.sh [rondas] [segundos] > dia.log 2>&1 &
# La 01 usa PESOS_VISITA=0.04 (activa insertar/quitar visitas y unir por o), porque su
# mejor solución tiene visitas a f y la v11/v12 nunca las movía. Logs: logs/dia_r<r>_<k>.txt
cd "$(dirname "$0")"
RONDAS=${1:-3}; SEG=${2:-3500}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
mkdir -p logs
for r in $(seq 1 "$RONDAS"); do
    echo "Ronda $r de $RONDAS ($(date +%H:%M)): 06 04 10 + 01 (visitas)"
    for k in 06 04 10 01; do
        pv=0.0; [ $k = 01 ] && pv=0.04
        PESOS_VISITA=$pv julia main.jl "instancias/instancia_$k.txt" "$SEG" "$((1400000 + r * 1000 + 10#$k))" \
            > "logs/dia_r${r}_$k.txt" 2>&1 &
    done
    wait
    for k in 06 04 10 01; do
        echo "  $k: $(awk -F': ' '/ inicial:/{print $2}' logs/dia_r${r}_$k.txt) -> $(awk -F': ' '/ final:/{print $2}' logs/dia_r${r}_$k.txt)"
    done
    sleep 120
done
echo "Listo ($(date +%H:%M))"
