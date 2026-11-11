cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Documenta la tabú con varias semillas en la 01"
git push
