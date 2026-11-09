# IO - Proyecto final

```
datos/        Instancias originales (.xlsx)
solucion_1/   Solución 1: lectura directa del Excel (main.jl)
solucion_2/   Solución 2: metaheurística con reglas de despacho para los AGVs
solucion_3/   Solución 3: plan explícito de viajes de AGVs + recocido con vecindades adaptativas
  instancias/   Instancias convertidas a .txt
  resultados/   Soluciones generadas y archivos para IO1Lab
```

## Cómo correr

**Solución 1**
```bash
julia solucion_1/main.jl
```

**Solución 2** (desde su carpeta)
```bash
cd solucion_2
julia main.jl instancias/instancia_01.txt [segundos] [semilla]
```

**Solución 3** (parte de `resultados/*_io1lab.txt`; solo guarda si mejora)
```bash
cd solucion_3
julia main.jl instancias/instancia_01.txt [segundos] [semilla]
caffeinate -i bash correr_noche.sh 2400 4   # todas las instancias
```
