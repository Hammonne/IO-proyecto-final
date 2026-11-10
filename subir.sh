#!/bin/bash
# subir.sh — Sube los cambios del proyecto a GitHub
cd "$(dirname "$0")"
git add .
git status --short
git commit -m "Solución 4: ALNS con huecos, arranques húngaros y documentación"
git push
