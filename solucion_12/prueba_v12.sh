#!/bin/bash
# ============================================================
# prueba_v12.sh — Compara v11, v12 y v12 + ruteo con las mismas semillas
# ============================================================
# Uso:  nohup caffeinate -i bash prueba_v12.sh [segundos] [rondas] ["instancias"] > pruebas/prueba.log 2>&1 &
#       (por defecto: 1800 s, 2 rondas, instancias "07 09")
# Cada variante corre en su propia copia (pruebas/trabajo/<variante>/), que
# parte de la solución de mejores/. Entre rondas, cada variante sigue desde
# lo que ella misma guardó. Las 3 variantes usan las mismas semillas.
#   v11  : la tabú de la v11 tal cual
#   v12  : tramos cortos (2 %) + reinicios chicos
#   v12r : v12 con el doble de peso en las vecindades de ruteo (PESOS_RUTEO=0.12)
# Logs: pruebas/<variante>_r<ronda>_<inst>.txt
# No toca resultados/ de ninguna versión ni mejores/.

cd "$(dirname "$0")"
SEG=${1:-1800}
RONDAS=${2:-2}
INST=${3:-07 09}
T=pruebas/trabajo
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1

rm -rf "$T"
for v in v11 v12 v12r; do
    mkdir -p "$T/$v/resultados"
    if [ "$v" = v11 ]; then src=../solucion_11; else src=.; fi
    cp "$src"/*.jl "$T/$v/"
    cp -R instancias "$T/$v/"
    for k in $INST; do cp "../mejores/instancia_${k}_io1lab.txt" "$T/$v/resultados/"; done
done

for r in $(seq 1 "$RONDAS"); do
    echo "Ronda $r de $RONDAS ($(date +%H:%M)), $SEG s: $INST"
    for v in v11 v12 v12r; do
        peso=0.06; [ "$v" = v12r ] && peso=0.12
        for k in $INST; do
            (cd "$T/$v" && PESOS_RUTEO=$peso julia main.jl "instancias/instancia_$k.txt" "$SEG" "$((900000 + r * 1000 + 10#$k))") \
                > "pruebas/${v}_r${r}_$k.txt" 2>&1 &
        done
    done
    wait
    for k in $INST; do
        linea="  $k:"
        for v in v11 v12 v12r; do
            val=$(awk -F': ' '/ final:/{print $2}' "pruebas/${v}_r${r}_$k.txt")
            rei=$(awk '/^Tabú:/{print $4}' "pruebas/${v}_r${r}_$k.txt")
            linea="$linea  $v=$val ($rei reinicios)"
        done
        echo "$linea"
    done
done
echo "Listo ($(date +%H:%M))"
