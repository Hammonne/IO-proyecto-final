cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Método central (tabú iterada + despacho por ciclos): 08 = 1028.85 (pasa al líder), 07 = 882.23, 10 = 963.16; mejoras de 04 06 09; solución 13 y carpeta temporal del despacho por ciclos"
git push
