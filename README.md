# IO - Proyecto final

```
datos/        Instancias originales (.xlsx)
solucion_1/   Solución 1: lectura directa del Excel (main.jl)
solucion_2/   Solución 2: metaheurística (constructivo + búsqueda local + recocido simulado)
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
