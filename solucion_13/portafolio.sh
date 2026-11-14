#!/bin/bash
# portafolio.sh — Corrida larga con la v12 (código de la v13 con GLS_ALFA=0) rotando variantes
# Uso: nohup caffeinate -i bash portafolio.sh [rondas] [segundos] [instancias] > portafolio.log 2>&1 &
# Cada ronda, cada instancia usa una variante distinta (rota con la ronda) y una semilla nueva:
#   base    : v12 tal cual
#   ruteo   : PESOS_RUTEO=0.12  (mejoró la 10)
#   visitas : PESOS_VISITA=0.04 (mejoró la 04)
#   bloques : PESO_BLOQUE=0.06 y PATADA_BLOQUE=0.3
# Parte de resultados/ (copiado de mejores/) y cada instancia guarda solo si mejora.
cd "$(dirname "$0")"
RONDAS=${1:-6}; SEG=${2:-3500}; INST=${3:-04 05 06 07 08 09 10}
DESDE=${DESDE:-1}          # para continuar: DESDE=<ronda> (la rotación y las semillas siguen desde ahí)
PREFIJO=${PREFIJO:-port}   # nombre de los logs
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 GLS_ALFA=0
read -ra VARIANTES <<< "${VARIANTES:-base ruteo visitas bloques}"   # lista rotativa (variable de entorno)
NV=${#VARIANTES[@]}
mkdir -p logs
for r in $(seq "$DESDE" "$RONDAS"); do
    linea=""
    i=0
    for k in $INST; do
        v=${VARIANTES[$(( (r + i) % NV ))]}; i=$((i + 1))
        pr=0.06; pv=0.0; pb=0; pp=0
        case $v in ruteo) pr=0.12 ;; visitas) pv=0.04 ;; bloques) pb=0.06; pp=0.3 ;; esac
        PESOS_RUTEO=$pr PESOS_VISITA=$pv PESO_BLOQUE=$pb PATADA_BLOQUE=$pp \
            julia main.jl "instancias/instancia_$k.txt" "$SEG" "$((2000000 + r * 1000 + 10#$k))" > "logs/${PREFIJO}_r${r}_$k.txt" 2>&1 &
        echo $v > "logs/${PREFIJO}_r${r}_$k.var"; linea="$linea $k($v)"
    done
    echo "Ronda $r de $RONDAS ($(date +%H:%M)):$linea"
    wait
    for k in $INST; do
        echo "  $k ($(cat logs/${PREFIJO}_r${r}_$k.var)): $(awk -F': ' '/ inicial:/{print $2}' logs/${PREFIJO}_r${r}_$k.txt) -> $(awk -F': ' '/ final:/{print $2}' logs/${PREFIJO}_r${r}_$k.txt)"
    done
    sleep 120
done
echo "Listo ($(date +%H:%M))"
