#!/bin/bash
# cola.sh — Lanza las corridas del despacho por ciclos: una ya, y el resto cuando termine portafolio.sh (respeta 5 núcleos)
cd "$(dirname "$0")"
bash corrida.sh 10 7 &
while pgrep -f portafolio.sh > /dev/null; do sleep 60; done
echo "portafolio terminó $(date +%H:%M); lanzo 4 más"
bash corrida.sh 07 11 & bash corrida.sh 07 12 & bash corrida.sh 06 13 & bash corrida.sh 08 14 &
wait
echo "Listo $(date +%H:%M)"
