#!/bin/bash
# tarde.sh — 2 rondas de la v12 en 5 instancias antes de la corrida de las 22:30 (12/11/2026)
cd "$(dirname "$0")"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
mkdir -p logs
for r in 1 2; do
    echo "Ronda $r de 2 ($(date +%H:%M)): 07 09 08 05 04"
    for k in 07 09 08 05 04; do
        julia main.jl "instancias/instancia_$k.txt" 3300 "$((1100000 + r * 1000 + 10#$k))" > "logs/tarde_r${r}_$k.txt" 2>&1 &
    done
    wait
    grep -h "inicial:\|final:" logs/tarde_r${r}_*.txt | paste - -
done
echo "Listo ($(date +%H:%M))"
