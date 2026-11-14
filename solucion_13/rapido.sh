#!/bin/bash
# rapido.sh — 30 min en paralelo con variantes distintas sobre 05, 04 y 10 (6 núcleos)
# Cada tarea corre en su copia (rapido/<tarea>/) desde mejores/. Logs: rapido/<tarea>.txt
#   r  = v12 con más peso al ruteo (PESOS_RUTEO=0.12) -> en solucion_12
#   g  = v13 con búsqueda local guiada suave (GLS_ALFA=0.1)
cd "$(dirname "$0")"
SEG=${1:-1750}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
rm -rf rapido; mkdir -p rapido
for k in 05 04 10; do
    for v in r g; do
        d="rapido/${v}_$k"; mkdir -p "$d/resultados"
        if [ $v = r ]; then cp ../solucion_12/*.jl "$d/"; else cp *.jl "$d/"; fi
        cp -R instancias "$d/"; cp "../mejores/instancia_${k}_io1lab.txt" "$d/resultados/"
        (cd "$d" && PESOS_RUTEO=$([ $v = r ] && echo 0.12 || echo 0.06) GLS_ALFA=0.1 \
            julia main.jl "instancias/instancia_$k.txt" "$SEG" "$((1600000 + 10#$k * 10 + ${#v}))") > "rapido/${v}_$k.txt" 2>&1 &
    done
done
echo "Empieza $(date +%H:%M)"; wait
for k in 05 04 10; do for v in r g; do
    echo "  ${v}_$k: $(awk -F': ' '/ inicial:/{print $2}' rapido/${v}_$k.txt) -> $(awk -F': ' '/ final:/{print $2}' rapido/${v}_$k.txt)"
done; done
echo "Listo $(date +%H:%M)"
