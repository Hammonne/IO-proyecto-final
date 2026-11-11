cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Documenta el experimento de fijar la asignación óptima a máquinas en la 01"
git push
