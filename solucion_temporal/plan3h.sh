#!/bin/bash
# plan3h.sh — 3 rondas de ~1 h con el despacho por ciclos (guion + tabú v12), 5 núcleos.
# Ronda: lista "inst:semilla:seg_guion"; el tabú usa el resto hasta ~3420 s.
# Log: plan3h.log (una línea por corrida). Resultados en trabajo/<inst>_<semilla>/tabu/resultados/
cd "$(dirname "$0")"
ronda() {
    echo "[$(date +%H:%M)] Ronda $1: ${*:2}"
    for t in "${@:2}"; do
        IFS=: read k s g <<< "$t"
        bash corrida.sh "$k" "$s" "$g" $((3420 - g)) &
    done
    wait
}
ronda 1 07:21:120 07:22:120 10:23:300 10:24:300 06:25:120
ronda 2 07:31:120 07:32:120 10:33:300 10:34:300 06:35:120
ronda 3 07:41:120 10:42:300 06:43:120 04:44:120 05:45:120
echo "[$(date +%H:%M)] Listo"
