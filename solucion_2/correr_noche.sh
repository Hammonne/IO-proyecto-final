#!/bin/bash
# ============================================================
# correr_noche.sh — Ejecuta la búsqueda en todas las instancias en paralelo
# ============================================================
# Uso (en la Terminal, dentro de la carpeta del proyecto):
#     caffeinate -i bash correr_noche.sh 2400 4
# 2400 = segundos por corrida, 4 = número de rondas.
# Cada ronda parte de la mejor solución guardada (arranque en caliente),
# así que las mejoras se acumulan. Solo se guarda una solución si es
# factible y mejor que la anterior.
# Los archivos para IO1Lab quedan en resultados/instancia_XX_io1lab.txt

cd "$(dirname "$0")"
SEGUNDOS=${1:-2400}
RONDAS=${2:-4}
mkdir -p logs

for ronda in $(seq 1 "$RONDAS"); do
    echo "Ronda $ronda de $RONDAS ($(date +%H:%M))"
    for k in 10 08 09 07 06 05 04 03 02 01; do
        julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$((ronda * 100 + 10#$k))" \
            > "logs/ronda${ronda}_$k.txt" 2>&1 &
    done
    wait
    grep -h "instancia_" logs/ronda${ronda}_*.txt
done

echo "Listo ($(date +%H:%M)). Mejores valores guardados:"
for k in 01 02 03 04 05 06 07 08 09 10; do
    echo "  $k: $(head -1 resultados/instancia_${k}_solucion.csv | cut -d, -f2)"
done
