cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Ordena resultados por versión y agrega mejores/; 07, 08, 09 y 10 mejoran"
git push
