cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Corrida de la noche con la v12: mejoran 04 06 07 08 10; 02 y 03 sin cambio; 07 desde cero llega a 913.90 con otra asignación"
git push
