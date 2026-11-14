#!/bin/bash
# transporte08.sh — ¿Una asignación inicial que cuente el transporte lleva más abajo en la 08?
# Uso: nohup caffeinate -i bash transporte08.sh [segundos] [instancia] > transporte08.log 2>&1 &
# Espera a que termine portafolio.sh. Luego, desde cero (sin leer la mejor guardada), corre la v12
# con visitas (PESOS_VISITA=0.04, GLS_ALFA=0) partiendo de la asignación con BETA = 0 (control), 20, 40 y 80.
# Cada una en su copia (pruebas_transporte/b<BETA>/). Logs: pruebas_transporte/b<BETA>.txt
cd "$(dirname "$0")"
SEG=${1:-3500}; K=${2:-08}
while pgrep -f portafolio.sh > /dev/null; do sleep 60; done
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 GLS_ALFA=0 PESOS_VISITA=0.04
T=pruebas_transporte; mkdir -p $T
echo "Empieza $(date +%H:%M): instancia $K, $SEG s"
for b in 0 20 40 80; do
    d="$T/b${b}_$K"; rm -rf "$d"; mkdir -p "$d/resultados"; cp *.jl "$d/"; cp -R instancias "$d/"
    (cd "$d" && ASIG_BETA=$b julia main.jl "instancias/instancia_$K.txt" "$SEG" "$((2100000 + b))" cero) > "$T/b${b}_$K.txt" 2>&1 &
done
wait
for b in 0 20 40 80; do
    echo "  BETA=$b: $(awk -F': ' '/ inicial:/{print $2}' $T/b${b}_$K.txt) -> $(awk -F': ' '/ final:/{print $2}' $T/b${b}_$K.txt)"
done
echo "Listo $(date +%H:%M)  (nuestra mejor de la $K: $(awk -F'|' -v k=" $K " '$2==k{print $3}' ../mejores/README.md))"
