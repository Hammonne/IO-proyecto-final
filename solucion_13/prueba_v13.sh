#!/bin/bash
# prueba_v13.sh — Prueba de la v13 (tabú iterada + búsqueda local guiada) en la 03 y la 02
# Uso: nohup caffeinate -i bash prueba_v13.sh [rondas] [segundos] > prueba.log 2>&1 &
# Parte de resultados/ (copiado de mejores/); solo guarda si mejora. Logs: logs/r<r>_<k>.txt
cd "$(dirname "$0")"
RONDAS=${1:-2}; SEG=${2:-3500}; INST="03 02"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
mkdir -p logs
for r in $(seq 1 "$RONDAS"); do
    echo "Ronda $r de $RONDAS ($(date +%H:%M)): $INST  (GLS_ALFA=${GLS_ALFA:-0.2})"
    for k in $INST; do
        julia main.jl "instancias/instancia_$k.txt" "$SEG" "$((1500000 + r * 1000 + 10#$k))" > "logs/r${r}_$k.txt" 2>&1 &
    done
    wait
    for k in $INST; do
        echo "  $k: $(awk -F': ' '/ inicial:/{print $2}' logs/r${r}_$k.txt) -> $(awk -F': ' '/ final:/{print $2}' logs/r${r}_$k.txt)"
    done
    sleep 120
done
echo "Listo ($(date +%H:%M))"
