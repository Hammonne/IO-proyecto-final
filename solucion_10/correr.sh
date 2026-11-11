#!/bin/bash
# ============================================================
# correr.sh — Ejecuta la solución 10 (asignaciones de Murty + tabú) en varias rondas
# ============================================================
# Uso:   bash correr.sh SEGUNDOS RONDAS [instancias...]
#   bash correr.sh 3500 2 01      -> la 01, 2 rondas de 3500 s
# Segundos de tabú por asignación (fase 1): SEG_ASIG=60 bash correr.sh ... (60 por defecto)
#
# Recomendado: lanzarlo desde la app Terminal de macOS (no desde VS Code)
# con nohup, para que siga corriendo aunque se cierre la ventana:
#   cd ".../Proyecto_IO1/solucion_10"
#   nohup caffeinate -i bash correr.sh 3500 2 01 > corrida.log 2>&1 &
# Ver el avance:  tail -f corrida.log      Detenerlo:  pkill -f "julia main.jl"
#
# Cada ronda parte de la mejor solución guardada y usa otra semilla.
# Nunca se corre la misma instancia dos veces a la vez (escriben al mismo
# archivo). Con más de 8 instancias la Mac va más lenta (8 núcleos).
#
# Un solo núcleo: UN_NUCLEO=1 bash correr.sh ...  -> las instancias se
# corren una tras otra (tarda instancias × rondas × SEGUNDOS en total).

cd "$(dirname "$0")"
SEGUNDOS=${1:-2400}
RONDAS=${2:-3}
shift $(( $# < 2 ? $# : 2 ))
INSTANCIAS=${*:-01 02 03 04 05 06 07 08 09 10}
mkdir -p logs
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1

for ronda in $(seq 1 "$RONDAS"); do
    echo "Ronda $ronda de $RONDAS ($(date +%H:%M)): $INSTANCIAS"
    for k in $INSTANCIAS; do
        julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$((${SEMILLA_BASE:-0} + ronda * 1000 + 10#$k))" "${SEG_ASIG:-60}" \
            > "logs/ronda${ronda}_$k.txt" 2>&1 &
        [ "${UN_NUCLEO:-0}" = 1 ] && wait      # una instancia a la vez
    done
    wait
    grep -h "final:" logs/ronda${ronda}_*.txt
done
echo "Listo ($(date +%H:%M))"
