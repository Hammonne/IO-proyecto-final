cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Agrega la solución de reglas de Yampi"
git push
