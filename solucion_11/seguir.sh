#!/bin/bash
# ============================================================
# seguir.sh — Continúa la corrida larga con reglas según si mejora o se estanca
# ============================================================
# Uso (desde la app Terminal, NO desde VS Code):
#   cd ".../Proyecto_IO1/solucion_11"
#   nohup caffeinate -i bash seguir.sh > seguir.log 2>&1 &
#   tail -f seguir.log            (ver avance)
#   pkill -f seguir.sh; pkill -f "julia main.jl"   (detener todo)
#
# Qué hace:
#   0. Espera a que termine la corrida actual (correr.sh).
#   1. Enfriamiento: ENFRIAR segundos sin correr nada (y más si macOS
#      reporta que está bajando la velocidad de la CPU por calor).
#   2. Rondas de SEGUNDOS hasta completar HORAS, con PAUSA entre rondas.
#      En cada ronda, cada instancia decide según su racha (rondas seguidas
#      que mejoró menos de UMBRAL):
#        racha 0-1  -> sigue mejorando: v11 con otra semilla
#        racha 2-3  -> estancada: cambia de método, v6 (tabú + patadas ALNS)
#                      partiendo de la mejor de la v11; si mejora, se copia
#                      de vuelta a resultados/ de la v11
#        racha >= 4 -> se da por convergida y descansa (menos calor)
#      Si una instancia mejora (con v11 o v6) su racha vuelve a 0.
#   La v6 corre en una copia (v6_trabajo/), no toca solucion_6/resultados.
# ============================================================

cd "$(dirname "$0")"
HORAS=${HORAS:-8}
SEGUNDOS=${SEGUNDOS:-3500}
ENFRIAR=${ENFRIAR:-1200}      # 20 min antes de empezar
PAUSA=${PAUSA:-300}           # 5 min entre rondas
UMBRAL=${UMBRAL:-0.05}        # mejora mínima para no contar como estancada
SEMILLA_BASE=${SEMILLA_BASE:-800000}
INSTANCIAS=${*:-06 07 08 10 04 09}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
mkdir -p logs estado

hora() { date +%H:%M; }

# Velocidad de CPU permitida por macOS (100 = sin limitar por calor)
limite_cpu() {
    local l; l=$(pmset -g therm 2>/dev/null | awk -F'= *' '/CPU_Speed_Limit/{print $2}')
    echo "${l:-100}"
}

enfriar() {   # $1 = segundos mínimos
    echo "[$(hora)] Enfriando $(( $1 / 60 )) min..."
    sleep "$1"
    local extra=0
    while [ "$(limite_cpu)" -lt 100 ] && [ $extra -lt 1200 ]; do
        echo "[$(hora)] CPU limitada por calor ($(limite_cpu)%), espero 2 min más"
        sleep 120; extra=$((extra + 120))
    done
}

# --- 0. Esperar a que termine la corrida actual -----------------
while pgrep -f "correr.sh" > /dev/null || pgrep -f "julia main.jl" > /dev/null; do
    sleep 60
done
echo "[$(hora)] Terminó la corrida anterior:"
grep -h "final:" logs/ronda8_*.txt 2>/dev/null
INICIO=$(date +%s)
FIN=$((INICIO + HORAS * 3600))

# --- copia de trabajo de la v6 -----------------------------------
rm -rf v6_trabajo; mkdir -p v6_trabajo/resultados
cp ../solucion_6/*.jl v6_trabajo/; cp -R ../solucion_6/instancias v6_trabajo/

for k in $INSTANCIAS; do echo 0 > "estado/racha_$k"; done

enfriar "$ENFRIAR"

# --- 2. Rondas ---------------------------------------------------
ronda=0
while true; do
    ahora=$(date +%s)
    if [ $((ahora + SEGUNDOS + 120)) -gt $FIN ]; then
        echo "[$(hora)] No alcanza el tiempo para otra ronda."; break
    fi
    ronda=$((ronda + 1))
    activas=""
    for k in $INSTANCIAS; do
        racha=$(cat "estado/racha_$k")
        semilla=$((SEMILLA_BASE + ronda * 1000 + 10#$k))
        log="logs/seguir${ronda}_$k.txt"
        if [ "$racha" -ge 4 ]; then
            echo no > "estado/metodo_$k"; continue
        elif [ "$racha" -ge 2 ]; then
            cp "resultados/instancia_${k}_io1lab.txt" v6_trabajo/resultados/
            (cd v6_trabajo && julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$semilla") > "$log" 2>&1 &
            echo v6 > "estado/metodo_$k"; activas="$activas $k(v6)"
        else
            julia main.jl "instancias/instancia_$k.txt" "$SEGUNDOS" "$semilla" > "$log" 2>&1 &
            echo v11 > "estado/metodo_$k"; activas="$activas $k(v11)"
        fi
    done
    if [ -z "$activas" ]; then
        echo "[$(hora)] Todas las instancias convergieron. Fin."; break
    fi
    echo "[$(hora)] Ronda $ronda:$activas"
    wait

    # --- evaluar la ronda ---
    for k in $INSTANCIAS; do
        log="logs/seguir${ronda}_$k.txt"
        [ "$(cat estado/metodo_$k)" = no ] && continue
        ini=$(awk -F': ' '/ inicial:/{print $2}' "$log")
        fin=$(awk -F': ' '/ final:/{print $2}' "$log")
        racha=$(cat "estado/racha_$k")
        if [ -z "$fin" ]; then
            echo "  $k: sin resultado (revisar $log)"; continue
        fi
        if [ "$(cat estado/metodo_$k)" = v6 ] && grep -q "Guardada" "$log"; then
            cp "v6_trabajo/resultados/instancia_${k}_io1lab.txt" resultados/   # la v6 mejoró: pasa a la v11
        fi
        mejora=$(awk -v a="$ini" -v b="$fin" 'BEGIN{printf "%.2f", a-b}')
        if awk -v m="$mejora" -v u="$UMBRAL" 'BEGIN{exit !(m >= u)}'; then
            racha=0; estado="mejoró"
        else
            racha=$((racha + 1)); estado="estancada ($racha)"
        fi
        echo $racha > "estado/racha_$k"
        echo "  $k: $ini -> $fin  (−$mejora)  $estado"
    done
    enfriar "$PAUSA"
done

echo "[$(hora)] Listo. Mejor valor de estas rondas por instancia:"
for k in $INSTANCIAS; do
    echo "  $k: $(grep -h ' final:' logs/seguir*_$k.txt 2>/dev/null | awk -F': ' '{print $2}' | sort -n | head -1)"
done
