#!/bin/bash
# ============================================================
# correr.sh — Ejecuta la solución de reglas en las diez instancias
# ============================================================
# Uso (desde esta carpeta):  bash correr.sh [sin|zonas]
cd "$(dirname "$0")"
MODO=${1:-sin}
for k in 01 02 03 04 05 06 07 08 09 10; do
    julia main.jl "instancias/instancia_$k.txt" "$MODO"
done
