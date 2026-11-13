cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Agrega la solución 12 (tabú iterada) con su prueba y una corrida de 2 h (04 05 07 08 09 mejoran); diagnóstico asignación vs congestión y plan para la 06-08"
git push
