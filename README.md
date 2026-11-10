# IO - Proyecto final

```
datos/        Instancias originales (.xlsx)
solucion_1/   Solución 1: lectura directa del Excel (main.jl)
solucion_2/   Solución 2: metaheurística con reglas de despacho para los AGVs
solucion_3/   Solución 3: plan explícito de viajes de AGVs + recocido con vecindades adaptativas
solucion_4/   Solución 4: ALNS (destrucción y reparación) + pulido local sobre el plan de la solución 3
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

**Solución 4** (desde la app Terminal de macOS, con `nohup` para que no se corte)
```bash
cd solucion_4
nohup caffeinate -i bash correr.sh 3600 3 01 02 03 07 08 > corrida.log 2>&1 &   # instancias elegidas
nohup caffeinate -i bash correr.sh 2400 3 > corrida.log 2>&1 &                  # las 10
tail -f corrida.log            # ver avance
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

### Solución 4 — ALNS + arranques húngaros sobre el plan explícito
**Diagnóstico que la motiva.** Calculamos una cota inferior exacta: la asignación óptima de
R||ΣC con el método húngaro, sumando a cada lote su viaje mínimo o→α_j y β_j→f. Con ella
vemos dos tipos de instancias:
- **01–05:** las máquinas casi nunca esperan ni se bloquean, así que manda la asignación
  lote–máquina. Por ejemplo, en la 02 la cota es 392.6, el líder está en 404.0 y la v3 en 410.7.
- **06–10:** el gap frente a la cota es de 16–42 %, así que manda el transporte.

Los movimientos pequeños de la v3 no cambian de golpe la máquina, el orden y los viajes de
varios lotes, por eso quedaban estancados.

**Método.** ALNS (*Adaptive Large Neighborhood Search*, Ropke y Pisinger, 2006). En cada
iteración se **destruye** parte de la solución (se sacan q lotes), se **repara** reinsertándolos y
se **pule** con un descenso corto que usa las vecindades de la v3. q se sortea entre 2 y el 30 %
de los lotes (tope 30), sesgado hacia valores chicos.

- **Huecos.** Al sacar un lote, sus dos paradas quedan como *huecos* en sus viajes en vez de
  borrarse. Así se conserva la estructura del transporte, y reinsertar un lote en su lugar
  original recupera exactamente la solución.
  - Sin huecos, la reparación empeoraba un 25 % en mediana.
  - Con huecos, la mediana es 0 % y a veces mejora.
- **5 operadores de destrucción:**
  - *aleatorio*: q lotes al azar.
  - *relacionados* (Shaw, 1998): lotes cercanos en el tiempo y del mismo tipo.
  - *peores*: los lotes con más tiempo perdido, es decir máquina ociosa esperándolos más espera
    hasta llegar a f.
  - *viajes*: todos los lotes de varios viajes seguidos de un AGV.
  - *segmento*: lotes consecutivos de una máquina.
- **3 operadores de reparación** por **inserción secuencial** (como el SIA de Yin y Hu, 2026):
  *voraz aleatorio*, *voraz SPT* y *arrepentimiento* (regret-2). Para cada lote:
  1. Se prueban las posiciones cercanas a donde estaba (misma fracción de la secuencia ± 4), en
     todas sus máquinas compatibles. Cada posición se evalúa con la mejor de dos colocaciones
     baratas: sus huecos propios, o viajes propios junto al lote anterior.
  2. En las mejores posiciones (hasta tener 3 factibles) se elige la mejor ubicación de cada
     parada: cualquier hueco, el mismo viaje que el lote vecino, o un viaje propio al lado del suyo.
  3. Si ninguna posición es factible, el lote va al final de una máquina y de un AGV. Como nadie
     depende de él, esa inserción siempre es factible.
- **Selección adaptativa:** una ruleta para cada familia de operadores, con premios 33 / 9 / 13
  (nueva mejor / mejora la actual / aceptada) actualizados cada 25 iteraciones.
- **Aceptación:** criterio de Metropolis. La temperatura inicial hace que una solución 0.5 % peor
  se acepte con probabilidad 0.5, y luego baja de forma geométrica.
- **Pulido:** 300 movimientos pequeños que solo se aceptan si mejoran. Las vecindades se
  sortean con las probabilidades que aprendió la v3.
- **Diversificación:**
  - Conjunto **élite** con las 6 mejores soluciones distintas.
  - Si no hay mejora en el 8 % del tiempo, se **reinicia**:
    - La mitad de las veces desde un **arranque húngaro perturbado** (`arranques.jl`): la
      asignación óptima de R||ΣC con tiempos de proceso con ruido de ±15 % (asignaciones
      distintas pero buenas), viajes con las reglas de la v2, y luego el 2 % del tiempo de
      recocido de la v3.
    - La otra mitad desde una solución élite con una destrucción del doble de tamaño.
  - Cada ronda de `correr.sh` usa otra semilla.
- **Intensificación final:** el último 15 % del tiempo corre el recocido de la v3 desde la mejor
  solución.
- **Pruebas cortas:**
  - Instancia 08: de 1092.96 a 1092.26 en 3 minutos.
  - Instancia 02: de 410.68 a 409.65 en 5 minutos. Partir solo del húngaro llegó a 408.13 en
    90 s.
  - Instancia 03: sin cambios en 5 minutos.
- **Limitaciones:**
  - Cada iteración cuesta cientos de decodificaciones.
  - Los parámetros (q, premios, ruido, tiempos) salen de la literatura y de pruebas cortas, sin
    calibración sistemática.
  - Muchas reparaciones devuelven exactamente la misma solución, que no recibe premio. Por eso
    los pesos tienden al mínimo y la selección se vuelve casi uniforme.

**Rutas generales con visitas intermedias a o y f.** Antes, cada viaje pasaba por o solo al
inicio y por f solo al final. Ahora un viaje puede incluir *visitas* explícitas a o o a f en
cualquier punto:
- Cada lote se carga en la última visita a o antes de su entrega y se descarga en la primera
  visita a f después de recogerlo. La capacidad se controla a lo largo de toda la ruta.
- Esto permite, por ejemplo, **volver a o con lotes terminados a bordo**
  (o→α₁→β₁→o→α₂→β₂→f), lo que ahorra el viaje f→o, o **pasar por f a mitad de viaje** cuando
  queda de camino.
- Tres vecindades nuevas: *insertar visita*, *quitar visita* y *unir dos viajes pasando por o*
  (este último no va a f entre los dos viajes).
- El lector de `.txt` reconstruye las visitas, así que estas soluciones también sirven como
  punto de partida.
- Las soluciones anteriores siguen siendo válidas sin cambios: el espacio de soluciones solo
  se amplía.
- Limitación: el decodificador es un poco más lento (≈ 90 µs por evaluación en la instancia 08,
  frente a ≈ 60 µs).
- Resultado en pruebas de 10 minutos (instancias 02, 03, 07 y 08): ninguna de las mejores
  soluciones usó visitas intermedias. En estas instancias esas rutas no parecen convenir, o
  hacen falta corridas más largas para encontrarlas. La 02 bajó de 409.65 a 409.56 por otros
  movimientos.

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
- Shaw, P. (1998). Using constraint programming and local search methods to solve vehicle routing problems. En *Principles and Practice of Constraint Programming (CP-98)*, LNCS 1520, 417–431. Springer.
- Ropke, S. y Pisinger, D. (2006). An adaptive large neighborhood search heuristic for the pickup and delivery problem with time windows. *Transportation Science*, 40(4), 455–472.

**Revisadas (problemas relacionados)**
- Integrated scheduling problem of multi-load AGVs and parallel machines considering the recovery process (2025). *Swarm and Evolutionary Computation*. https://www.sciencedirect.com/science/article/abs/pii/S2210650225000197
- Joint scheduling of parallel machines and AGVs with sequence-dependent setup times in a matrix workshop. *Computers & Industrial Engineering*. https://www.sciencedirect.com/science/article/abs/pii/S0360835223006459
- Scheduling of no buffer job shop cells with blocking constraints and AGVs. *Applied Soft Computing*. https://www.sciencedirect.com/science/article/abs/pii/S1568494614003937
- An ACO–SA algorithm for a multiload AGVs workshop scheduling problem with limited buffer capacity (2023). *Processes*, 11(3), 861. https://doi.org/10.3390/pr11030861
- Critical-path-based VND for the joint scheduling of FJSP and AGVs (2025). *Mathematics*, 13(23), 3883. https://doi.org/10.3390/math13233883
- Yin, Y. Q. y Hu, Z. H. (2026). Integrated scheduling of multiple handling equipment at an automated container terminal with apron and block buffer zones. *Flexible Services and Manufacturing Journal*. https://doi.org/10.1007/s10696-026-09680-7 (solo se revisó el resumen; inspira la reparación por inserción secuencial de la solución 4)
