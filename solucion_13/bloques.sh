#!/bin/bash
# bloques.sh — Prueba de 1 h de las vecindades de bloque (bloques.jl) en la 07 y la 08
# Cada variante en su copia (pruebas_bloques/<var>_<k>/) desde mejores/. GLS apagada (GLS_ALFA=0).
#   ctl : v12 tal cual (PESO_BLOQUE=0)                    -> control
#   b06 : bloques dentro de la tabú, peso 0.06 cada una
#   b15 : bloques dentro de la tabú, peso 0.15 cada una
#   pat : patada de bloque en el 50 % de los reinicios (PATADA_BLOQUE=0.5), sin bloques en la tabú
cd "$(dirname "$0")"
SEG=${1:-3500}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 GLS_ALFA=0
T=pruebas_bloques; rm -rf $T; mkdir -p $T
correr() {  # var inst peso patada
    d="$T/$1_$2"; mkdir -p "$d/resultados"; cp *.jl "$d/"; cp -R instancias "$d/"
    cp "../mejores/instancia_$2_io1lab.txt" "$d/resultados/"
    (cd "$d" && PESO_BLOQUE=$3 PATADA_BLOQUE=$4 julia main.jl "instancias/instancia_$2.txt" "$SEG" "$((1800000 + 10#$2))") > "$T/$1_$2.txt" 2>&1 &
}
correr ctl 07 0 0;  correr b06 07 0.06 0;  correr b15 07 0.15 0;  correr pat 07 0 0.5
correr ctl 08 0 0;  correr b06 08 0.06 0;  correr pat 08 0 0.5
echo "Empieza $(date +%H:%M)"; wait
for f in $T/*.txt; do
    echo "  $(basename $f .txt): $(awk -F': ' '/ inicial:/{print $2}' $f) -> $(awk -F': ' '/ final:/{print $2}' $f)  $(grep '^Tabú' $f)"
done
echo "Listo $(date +%H:%M)"
