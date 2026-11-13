#!/bin/bash
# ============================================================
# extra.sh — Usa los núcleos que libera seguir.sh cuando instancias pasan a descansar
# ============================================================
# Uso:  nohup caffeinate -i bash extra.sh > extra.log 2>&1 &
# Espera a que seguir.sh empiece la ronda 5 y lanza, según núcleos libres
# (NUCLEOS menos los julia que están corriendo), en este orden de prioridad:
#   07 desde cero, semilla 1   (¿llega a otro reparto de máquinas?)
#   03 con la v12              (nunca corrió con la v12)
#   07 desde cero, semilla 2
#   02 con la v12
# Cada tarea corre en su propia copia (extra/<tarea>/), en rondas de SEGUNDOS
# hasta HASTA (HH:MM). Las de "cero" parten de la constructiva en la primera
# ronda y luego siguen desde lo que guardaron. No toca resultados/ ni mejores/.
# Logs: extra/logs/<tarea>_r<ronda>.txt
# ============================================================

cd "$(dirname "$0")"
NUCLEOS=${NUCLEOS:-8}
SEGUNDOS=${SEGUNDOS:-3500}
HASTA=${HASTA:-06:30}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
hora() { date +%H:%M; }

echo "[$(hora)] Esperando a que seguir.sh empiece la ronda 5..."
while ! grep -q "Ronda 5" seguir.log && pgrep -f seguir.sh > /dev/null; do sleep 60; done
sleep 30
FIN=$(date -j -f "%H:%M" "$HASTA" +%s)
[ "$FIN" -lt "$(date +%s)" ] && FIN=$((FIN + 86400))

ocupados=$(pgrep -f "julia main.jl" | wc -l | tr -d ' ')
libres=$((NUCLEOS - ocupados))
echo "[$(hora)] julia corriendo: $ocupados -> núcleos libres: $libres"

tareas=""
for t in cero07a v12_03 cero07b v12_02; do
    [ "$libres" -le 0 ] && break
    tareas="$tareas $t"; libres=$((libres - 1))
done
[ -z "$tareas" ] && { echo "[$(hora)] No hay núcleos libres. Fin."; exit 0; }
echo "[$(hora)] Tareas:$tareas"

mkdir -p extra/logs
for t in $tareas; do
    d="extra/$t"; rm -rf "$d"; mkdir -p "$d/resultados"
    cp *.jl "$d/"; cp -R instancias "$d/"
    case $t in
        v12_03) cp ../mejores/instancia_03_io1lab.txt "$d/resultados/" ;;
        v12_02) cp ../mejores/instancia_02_io1lab.txt "$d/resultados/" ;;
    esac
done

inst() { case $1 in cero07a|cero07b) echo 07 ;; v12_03) echo 03 ;; v12_02) echo 02 ;; esac; }
semilla() { case $1 in cero07a) echo 1 ;; cero07b) echo 2 ;; v12_03) echo 3 ;; v12_02) echo 4 ;; esac; }

r=0
while [ $(( $(date +%s) + SEGUNDOS + 120 )) -le $FIN ]; do
    r=$((r + 1))
    echo "[$(hora)] Ronda $r:$tareas"
    for t in $tareas; do
        k=$(inst $t); s=$((1300000 + r * 1000 + $(semilla $t) * 100 + 10#$k))
        extra_arg=""; [ $r -eq 1 ] && [[ $t == cero* ]] && extra_arg=cero
        (cd "extra/$t" && julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$s" $extra_arg) \
            > "extra/logs/${t}_r$r.txt" 2>&1 &
    done
    wait
    for t in $tareas; do
        ini=$(awk -F': ' '/ inicial:/{print $2}' "extra/logs/${t}_r$r.txt")
        fin=$(awk -F': ' '/ final:/{print $2}' "extra/logs/${t}_r$r.txt")
        echo "  $t: $ini -> $fin"
    done
    sleep 120
done
echo "[$(hora)] Listo."
