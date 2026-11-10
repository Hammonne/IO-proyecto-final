#!/bin/bash
# subir.sh — Sube los cambios del proyecto a GitHub
cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Solución 3: diversificación, resultados de 4 rondas y documentación en README"
git push
