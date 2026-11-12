cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Documenta la corrida larga de la v11, el análisis de reinicios y el plan de la v12 (con fuentes); actualiza la tabla de mejores"
git push
