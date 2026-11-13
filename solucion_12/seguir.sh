#!/bin/bash
# ============================================================
# seguir.sh — Corrida larga de la v12 con reglas según si mejora o se estanca
# ============================================================
# Uso (lo deja esperando hasta la hora indicada):
#   cd ".../Proyecto_IO1/solucion_12"
#   INICIO=22:30 nohup caffeinate -i bash seguir.sh 04 05 06 07 08 09 10 > seguir.log 2>&1 &
#   tail -f seguir.log                                   (ver avance)
#   pkill -f seguir.sh; pkill -f "julia main.jl"         (detener todo)
#
# Qué hace:
#   0. Espera hasta la hora INICIO (si se da) y a que no quede otra corrida.
#   1. Enfriamiento de ENFRIAR segundos (y más si macOS limita la CPU por calor).
#   2. Rondas de SEGUNDOS hasta completar HORAS, con PAUSA entre rondas.
#      Cada instancia decide según su racha (rondas seguidas con mejora < UMBRAL):
#        racha 0-1  -> v12 (tabú iterada: tramos cortos + reinicios chicos) con otra semilla
#        racha 2-3  -> cambia a la v11 (misma tabú con reinicios cada 10 %), que
#                      parte de la mejor de la v12; si mejora, se copia de vuelta
#        racha >= 4 -> se da por convergida y descansa
#      Si una instancia mejora (con v12 o v11), su racha vuelve a 0.
#   La v11 corre en una copia (v11_trabajo/), no toca solucion_11/resultados.
#   (Antes el plan B era la v6, pero sus patadas grandes son justo lo que los
#   logs de la v11 mostraron que no sirve; ver README.)
# ============================================================

cd "$(dirname "$0")"
HORAS=${HORAS:-8}
SEGUNDOS=${SEGUNDOS:-3500}
ENFRIAR=${ENFRIAR:-0}
PAUSA=${PAUSA:-300}
UMBRAL=${UMBRAL:-0.05}
SEMILLA_BASE=${SEMILLA_BASE:-1200000}
INSTANCIAS=${*:-04 05 06 07 08 09 10}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
mkdir -p logs estado

hora() { date +%H:%M; }

limite_cpu() {
    local l; l=$(pmset -g therm 2>/dev/null | awk -F'= *' '/CPU_Speed_Limit/{print $2}')
    echo "${l:-100}"
}

enfriar() {
    [ "$1" -gt 0 ] && echo "[$(hora)] Enfriando $(( $1 / 60 )) min..." && sleep "$1"
    local extra=0
    while [ "$(limite_cpu)" -lt 100 ] && [ $extra -lt 1200 ]; do
        echo "[$(hora)] CPU limitada por calor ($(limite_cpu)%), espero 2 min más"
        sleep 120; extra=$((extra + 120))
    done
}

# --- 0. Esperar la hora de inicio y a que no haya otra corrida ----
if [ -n "$INICIO" ]; then
    objetivo=$(date -j -f "%H:%M" "$INICIO" +%s)
    [ "$objetivo" -lt "$(date +%s)" ] && objetivo=$((objetivo + 86400))
    echo "[$(hora)] Esperando hasta las $INICIO..."
    while [ "$(date +%s)" -lt "$objetivo" ]; do sleep 30; done
fi
while pgrep -f "correr.sh|prueba_v12.sh" > /dev/null || pgrep -f "julia main.jl" > /dev/null; do
    sleep 60
done
FIN=$(( $(date +%s) + HORAS * 3600 ))

# --- copia de trabajo de la v11 ----------------------------------
rm -rf v11_trabajo; mkdir -p v11_trabajo/resultados
cp ../solucion_11/*.jl v11_trabajo/; cp -R instancias v11_trabajo/

for k in $INSTANCIAS; do echo 0 > "estado/racha_$k"; done
echo "[$(hora)] Empieza: $INSTANCIAS ($HORAS h, rondas de $SEGUNDOS s)"
enfriar "$ENFRIAR"

# --- 2. Rondas ---------------------------------------------------
ronda=0
while true; do
    if [ $(( $(date +%s) + SEGUNDOS + 120 )) -gt $FIN ]; then
        echo "[$(hora)] No alcanza el tiempo para otra ronda."; break
    fi
    ronda=$((ronda + 1))
    activas=""
    for k in $INSTANCIAS; do
        racha=$(cat "estado/racha_$k")
        semilla=$((SEMILLA_BASE + ronda * 1000 + 10#$k))
        log="logs/ronda${ronda}_$k.txt"
        if [ "$racha" -ge 4 ]; then
            echo no > "estado/metodo_$k"
        elif [ "$racha" -ge 2 ]; then
            cp "resultados/instancia_${k}_io1lab.txt" v11_trabajo/resultados/
            (cd v11_trabajo && julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$semilla") > "$log" 2>&1 &
            echo v11 > "estado/metodo_$k"; activas="$activas $k(v11)"
        else
            julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$semilla" > "$log" 2>&1 &
            echo v12 > "estado/metodo_$k"; activas="$activas $k(v12)"
        fi
    done
    if [ -z "$activas" ]; then
        echo "[$(hora)] Todas las instancias convergieron. Fin."; break
    fi
    echo "[$(hora)] Ronda $ronda:$activas"
    wait

    for k in $INSTANCIAS; do
        [ "$(cat estado/metodo_$k)" = no ] && continue
        log="logs/ronda${ronda}_$k.txt"
        ini=$(awk -F': ' '/ inicial:/{print $2}' "$log")
        fin=$(awk -F': ' '/ final:/{print $2}' "$log")
        racha=$(cat "estado/racha_$k")
        if [ -z "$fin" ]; then
            echo "  $k: sin resultado (revisar $log)"; continue
        fi
        if [ "$(cat estado/metodo_$k)" = v11 ] && grep -q "Guardada" "$log"; then
            cp "v11_trabajo/resultados/instancia_${k}_io1lab.txt" resultados/
        fi
        mejora=$(awk -v a="$ini" -v b="$fin" 'BEGIN{printf "%.2f", a-b}')
        if awk -v m="$mejora" -v u="$UMBRAL" 'BEGIN{exit !(m >= u)}'; then
            racha=0; estado="mejoró"
        else
            racha=$((racha + 1)); estado="estancada ($racha)"
        fi
        echo $racha > "estado/racha_$k"
        echo "  $k ($(cat estado/metodo_$k)): $ini -> $fin  (−$mejora)  $estado"
    done
    enfriar "$PAUSA"
done

echo "[$(hora)] Listo. Mejor valor de estas rondas por instancia:"
for k in $INSTANCIAS; do
    echo "  $k: $(grep -h ' final:' logs/ronda*_$k.txt 2>/dev/null | awk -F': ' '{print $2}' | sort -n | head -1)"
done
