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

## Heurísticas de cada solución

### Solución 1 — borrador
- Asignación voraz por carga mínima (*list scheduling*) + orden SPT en cada máquina.
- No modela los AGVs ni calcula el objetivo; solo funciona con `instancia_01`.

### Solución 2 — reglas de despacho + búsqueda local
- **Soluciones iniciales:** inserción voraz con orden SPT, y asignación exacta del problema R||ΣC
  con el método húngaro, ignorando el transporte (Horn, 1973; Bruno, Coffman y Sethi, 1974).
- **AGVs:** reglas de despacho (rondas o → α_j/β_j → f, prioridad por urgencia, vecino más
  cercano, zonas por AGV) con 3 parámetros ajustables.
- **Vecindades:** reubicar lote, intercambiar lotes, cambiar parámetros/zonas.
- **Búsqueda:** ILS para instancias de ≤ 60 lotes; recocido simulado + descenso para las grandes.

### Solución 3 — plan explícito de AGVs (la mejor)
- **Representación en dos capas:** secuencia de lotes por máquina + lista explícita de viajes por
  AGV (cada viaje = paradas "abastecer α_j" o "retirar β_j"). Inspirada en las codificaciones
  máquina/vehículo de la programación simultánea de máquinas y AGVs (Bilge y Ulusoy, 1995).
- **Decodificador:** calcula los tiempos como camino más largo en el grafo de precedencias
  (buffers de 1 lote y bloqueo). Detecta bloqueos mutuos y exceso de capacidad → infactible.
- **Solución inicial:** la mejor solución conocida (`resultados/*_io1lab.txt`), o la solución 2.
- **7 vecindades:** mover parada, intercambiar paradas, fusionar viajes, dividir viaje,
  mover viaje a otro AGV, intercambiar lotes (con su lugar en el plan), reubicar lote.
  Los destinos se limitan a viajes "cercanos en el tiempo".
- **Búsqueda:** recocido simulado con selección adaptativa de vecindades por ruleta
  (pesos por segmento, esquema de Ropke y Pisinger, 2006), retorno a la mejor si la actual
  se aleja > 2 %, y diversificación tipo ILS: si no mejora en el 15 % del tiempo, perturba
  la mejor con 3–8 movimientos aleatorios y recalienta.
- **Hallazgo:** las vecindades que más mejoran son *intercambiar lotes* y *dividir viaje*;
  *mover parada* y *mover viaje* casi nunca mejoran.

## Resultados (promedio de finalización, s)

| Instancia | Solución 2 | Solución 3 | Mejora |
|---|---|---|---|
| ejemplo | 1102.50 | 1044.00 | −5.3 % |
| 01 | 330.10 | 326.77 | −1.0 % |
| 02 | 416.45 | 410.68 | −1.4 % |
| 03 | 478.07 | 476.44 | −0.3 % |
| 04 | 531.00 | 526.40 | −0.9 % |
| 05 | 601.34 | 591.40 | −1.7 % |
| 06 | 759.10 | 754.42 | −0.6 % |
| 07 | 910.12 | 906.70 | −0.4 % |
| 08 | 1108.86 | 1092.96 | −1.4 % |
| 09 | 1002.51 | 964.36 | −3.8 % |
| 10 | 1091.61 | 998.97 | −8.5 % |

La solución de ejemplo del enunciado da 1062 s.

## Referencias

**Usadas en el método**
- Bilge, Ü. y Ulusoy, G. (1995). A time window approach to simultaneous scheduling of machines and material handling system in an FMS. *Operations Research*, 43(6), 1058–1070.
- Bruno, J., Coffman, E. G. y Sethi, R. (1974). Scheduling independent tasks to reduce mean finishing time. *Communications of the ACM*, 17(7), 382–387.
- Horn, W. A. (1973). Minimizing average flow time with parallel machines. *Operations Research*, 21(3), 846–847.
- Ropke, S. y Pisinger, D. (2006). An adaptive large neighborhood search heuristic for the pickup and delivery problem with time windows. *Transportation Science*, 40(4), 455–472.

**Revisadas (problemas relacionados)**
- Integrated scheduling problem of multi-load AGVs and parallel machines considering the recovery process (2025). *Swarm and Evolutionary Computation*. https://www.sciencedirect.com/science/article/abs/pii/S2210650225000197
- Joint scheduling of parallel machines and AGVs with sequence-dependent setup times in a matrix workshop. *Computers & Industrial Engineering*. https://www.sciencedirect.com/science/article/abs/pii/S0360835223006459
- Scheduling of no buffer job shop cells with blocking constraints and AGVs. *Applied Soft Computing*. https://www.sciencedirect.com/science/article/abs/pii/S1568494614003937
- An ACO–SA algorithm for a multiload AGVs workshop scheduling problem with limited buffer capacity (2023). *Processes*, 11(3), 861. https://doi.org/10.3390/pr11030861
- Critical-path-based VND for the joint scheduling of FJSP and AGVs (2025). *Mathematics*, 13(23), 3883. https://doi.org/10.3390/math13233883
- Yin, Y. Q. y Hu, Z. H. (2026). Integrated scheduling of multiple handling equipment at an automated container terminal with apron and block buffer zones. *Flexible Services and Manufacturing Journal*. https://doi.org/10.1007/s10696-026-09680-7 (solo se revisó el resumen)
