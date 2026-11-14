#!/bin/bash
# corrida.sh — Despacho por ciclos completo en una instancia: guion por tramos (t6.jl) + tabú v12 con visitas
# Uso: bash corrida.sh <instancia> <semilla> [seg_guion] [seg_tabu]
# Trabaja en trabajo/<inst>_<semilla>/; el resultado queda en trabajo/<inst>_<semilla>/tabu/resultados/
cd "$(dirname "$0")"
K=$1; SEM=$2; SG=${3:-120}; ST=${4:-3300}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
W="trabajo/${K}_$SEM"; rm -rf "$W"; mkdir -p "$W/tabu/resultados"
cp base.jl proto.jl t6.jl "$W/"; ln -s ../../../solucion_13 "$W/s13"
(cd "$W" && SEM=$SEM SEG=$SG julia t6.jl "$K") > "$W/guion.log" 2>&1
cp ../solucion_13/*.jl "$W/tabu/"; cp -R ../solucion_13/instancias "$W/tabu/"
cp "$W/res3/instancia_${K}_io1lab.txt" "$W/tabu/resultados/"
(cd "$W/tabu" && GLS_ALFA=0 PESOS_VISITA=0.04 julia main.jl "instancias/instancia_$K.txt" "$ST" "$SEM") > "$W/tabu.log" 2>&1
echo "$K semilla $SEM: guion $(grep -o 'guion por tramos -> [0-9.]*' "$W/guion.log" | awk '{print $NF}') -> tabú $(awk -F': ' '/ final:/{print $2}' "$W/tabu.log")"
