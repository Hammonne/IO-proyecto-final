# IO - Proyecto final

```
datos/        Instancias originales (.xlsx)
mejores/      MEJOR solución de cada instancia (la que se sube a IO1Lab) + tabla de qué versión la encontró
solucion_1/   Solución 1: lectura directa del Excel (main.jl)
solucion_2/   Solución 2: metaheurística con reglas de despacho para los AGVs
solucion_3/   Solución 3: plan explícito de viajes de AGVs + recocido con vecindades adaptativas
solucion_4/   Solución 4: ALNS (destrucción y reparación) + pulido local sobre el plan de la solución 3
solucion_5/   Solución 5: búsqueda tabú con lista de candidatos sobre el plan de la solución 3
solucion_6/   Solución 6: híbrido tabú (v5) + patadas de destrucción/reparación (ALNS de la v4)
solucion_7/   Solución 7: tabú con visitas + reoptimización exacta por ventanas (movimientos compuestos)
solucion_8/   Solución 8: secuencia de inserción de Yin y Hu (2026) + tabú de la v7
solucion_9/   Solución 9: path relinking entre soluciones élite + tabú de la v7
solucion_10/  Solución 10: multi-arranque desde las K mejores asignaciones a máquinas (Murty) + tabú
solucion_reglas_yampi/  Constructivo de reglas sin búsqueda (R1–R4 con excepciones S e Y), hecho por Yampi
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

**Solución 5** (búsqueda tabú; `cero` = parte de la solución constructiva, sin búsqueda previa)
```bash
cd solucion_5
julia main.jl instancias/instancia_03.txt 600 1 cero   # desde cero (para comparar métodos)
julia main.jl instancias/instancia_03.txt 600 1        # desde resultados/ si hay solución guardada
UN_NUCLEO=1 nohup caffeinate -i bash correr.sh 3600 1 > corrida.log 2>&1 &
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
- **3 operadores de reparación** por **inserción voraz**: cada lote se reinserta en su mejor
  posición evaluada con el decodificador completo (como la inserción voraz GIA de Yin y Hu, 2026,
  que evalúa cada posición con su simulador SIA):
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
- **En la corrida de 1 hora sí aparecieron:** la mejor solución de la **01 (326.66)** tiene 3
  viajes que pasan por f a mitad de camino, por ejemplo α10 → β9 → **f** → β12 → α7 → β10. El
  AGV deja un lote terminado en f sin descargar el lote que va a α7, que sigue a bordo. Leída
  con el decodificador de la v3 (sin visitas), esa misma solución vale 326.77, que es justo el
  valor al que llegó la v4 sin visitas en 10 rondas. Las demás instancias no usan visitas.

### Solución 5 — búsqueda tabú con lista de candidatos
Búsqueda local "de manual" sobre la misma representación, decodificador y 7 vecindades de la
solución 3 (Glover, 1986; Glover y Laguna, 1997).
- **Lista de candidatos:** revisar la vecindad completa no es viable (solo *intercambiar lotes*
  tiene ≈ 24 000 vecinos en la instancia 10, unos 2 s por iteración). En cada iteración se generan
  tantos vecinos al azar como lotes tiene la instancia (entre 30 y 200), con las vecindades
  ponderadas según lo que aprendió el recocido de la v3.
- **Movimiento:** se pasa al **mejor** candidato admisible aunque empeore la solución actual.
- **Memoria de corto plazo:** cada lote tiene una *huella*: máquina, lote anterior en la máquina y,
  para sus dos paradas, AGV y parada anterior en el viaje. Si un movimiento cambia la huella de un
  lote, la pareja (lote, huella vieja) queda tabú durante 2√n a 4√n iteraciones (tenencia
  aleatoria). Así se prohíbe deshacer el movimiento sin tener que guardar soluciones completas.
- **Aspiración:** un movimiento tabú se acepta si da una nueva mejor solución.
- **Diversificación:** si la mejor no mejora en el 10 % del tiempo, se parte de la mejor con
  3–8 movimientos aleatorios y se vacía la lista tabú.
- **Prueba corta** (40 s, misma solución constructiva de partida):

  | Instancia | Inicial | Recocido (v3) | Tabú (v5) |
  |---|---|---|---|
  | 01 | 331.75 | **326.85** | 328.46 |
  | 03 | 535.46 | 505.43 | **498.12** |
  | 07 | 995.54 | 946.48 | **932.10** |

  La tabú hace entre 20 y 100 veces menos iteraciones que el recocido, pero cada una es un
  mejor movimiento, por eso rinde mejor en las instancias medianas y grandes.
- **Prueba de 1 hora** partiendo de la mejor solución de la v4 (donde el ALNS ya no mejoraba):
  la 08 bajó de 1092.24 a **1090.72**; la 02 (409.44) y la 07 (906.69) no mejoraron.
- **Corridas largas de amigos (10–11/11/2026)**, siempre desde la mejor solución guardada:
  - 07: 1 ronda de 3500 s (semilla 71007, 105 448 iteraciones, 5 reinicios): de 905.90 (ALNS) a
    **901.93**. Aquí la tabú salió del óptimo local donde el ALNS ya no mejoraba.
  - 09 y 10: 6 rondas de 3500 s (semillas 50000+), unas 210 000–280 000 iteraciones por ronda. La
    09 baja en casi todas las rondas (958.69 → **958.59**) y la 10 en todas (993.00 → **990.62**;
    con una visita intermedia agregada por descenso, **990.47**). La 08 bajó de 1082.55 a 1080.90,
    pero en casa ya había llegado a 1080.08.
  - En cambio, la corrida de 6 horas de la v4 (ALNS) en la 01, 02 y 03 y de la v6 en la 07 no
    mejoró nada: más tiempo de ALNS ya no ayuda, la tabú sí.
- **Limitaciones:** las huellas solo miran al vecino anterior, así que algunos movimientos
  distintos comparten huella; la tenencia y el tamaño de la lista se fijaron con pocas pruebas.

### Solución 6 — híbrido: búsqueda tabú + patadas de destrucción/reparación
Combina lo que mejor hace cada método:
- **v5 (tabú):** intensifica bien, porque toma el mejor movimiento, pero su diversificación (3–8
  movimientos al azar) es débil.
- **v4 (ALNS):** diversifica bien, porque cambia muchos lotes a la vez, pero su pulido es un
  descenso corto y al final de las corridas largas todos sus operadores quedan con peso mínimo.

Esquema (tipo ILS, con la tabú como búsqueda local y el LNS como perturbación):
1. **Fase tabú:** la búsqueda de la v5 hasta que la mejor solución de la fase no mejora en el 3 %
   del tiempo total.
2. **Patada LNS:** se sacan q lotes y se reinsertan con los operadores de la v4, partiendo de la
   mejor global o de la mejor de la fase (50 % cada una). Se vacía la lista tabú.
3. **Aprendizaje:** la pareja (destrucción, reparación) usada recibe 33 puntos si la fase que abrió
   encontró una nueva mejor global y 9 si terminó mejor que la solución destruida (Ropke y
   Pisinger, 2006). Los pesos de la ruleta se actualizan cada 5 patadas.

Pruebas cortas (sin conclusión todavía):

| Prueba | Tabú (v5) | Híbrido (v6) |
|---|---|---|
| 03, 60 s desde la constructiva | 499.20 | **495.77** |
| 07, 60 s desde la constructiva | **930.48** | 936.52 |
| 08, 5 min desde la mejor (1090.72) | 1090.72 | 1090.72 |

En corridas cortas las patadas interrumpen a la tabú antes de que converja; el híbrido está
pensado para corridas largas que parten de una solución ya buena.

### Solución 7 — tabú + reoptimización exacta por ventanas
**Motivación.** Se revisaron **todos** los vecinos de las mejores soluciones de la 01 y la 03 con
6 tipos de movimiento: mover 1 parada, mover segmentos de 2–3 paradas seguidas (*Or-opt*, Or 1976),
mover las 2 paradas de un lote juntas (*pair relocation*, Nanry y Barnes 2000), intercambiar dos
lotes, y reubicar un lote en cualquier máquina y posición. Ninguno mejora: son **óptimos locales
estrictos**. Para salir de ahí hacen falta movimientos que cambien varias cosas a la vez.

**Ventanas exactas** (idea de POPMUSIC, Taillard y Voss 2002, y de *dynasearch*, Congram et al.
2002): se fija toda la solución menos una ventana pequeña, y dentro de ella se prueban **todas**
las combinaciones.
- **Ventana de lotes:** 5 lotes que empiezan seguidos en el tiempo. Se prueban las 5! formas de
  repartirlos en sus lugares de máquina, con las paradas siguiendo al lote o quedándose en su
  lugar. Generaliza el intercambio de 2 lotes a ciclos de k lotes (intercambio cíclico, Ahuja
  et al. 2002).
- **Ventana de paradas:** 6 paradas seguidas en el tiempo, de cualquier AGV. Se prueban las 6!
  formas de repartirlas en sus lugares del plan; esto reordena viajes y pasa paradas entre AGVs
  a la vez.
- **Ventana conjunta:** cada reparto de 3 lotes combinado con cada reparto de 5 de sus paradas.

**Búsqueda.** Es la tabú de la v5 con las 10 vecindades de la v4 (incluye visitas, porque la
mejor solución de la 01 las usa). Cuando se estanca, primero hace un descenso por ventanas
sobre la mejor solución y, si no mejora, la perturba. Si la actual se aleja más de un 2 % de la
mejor, vuelve a la mejor: sin esa regla, la tabú acumulaba visitas cuyo retiro quedaba tabú, y
llegó a alejarse un 20 %.

**Resultados (honestos).**
- Las ventanas, aplicadas a las mejores soluciones de la 01 y la 03, no mejoran: también son
  óptimos locales para estos movimientos compuestos.
- La v7, corriendo 10 minutos en la 01 y 4 minutos en la 01 y la 03 desde la mejor solución, no
  mejora.
- Desde la solución constructiva (40 s) rinde parecido a la v5: 507.79 en la 03 y 933.09 en la
  07.
- **Conclusión:** en la 01 y la 03 la diferencia con el líder (0.06 y 0.52) parece venir de
  soluciones con una estructura distinta, no de un vecino cercano de las nuestras. Salir de ahí
  probablemente requiere partir de otras soluciones iniciales, por ejemplo con más rondas y
  semillas, que fue lo que funcionó en la 02.

### Solución 8 — secuencia de inserción (Yin y Hu, 2026) + tabú
**Idea del paper.** En Yin y Hu (2026), la solución entera es **una permutación de los trabajos**.
El vehículo que hace cada trabajo no se decide: lo toma el que lo atiende antes (su ec. 26), y el
orden de las grúas sale de la misma permutación. Es otro espacio de búsqueda, con otros óptimos
locales, y por eso se probó para la 01 y la 03.

**Adaptación** (`secuencia.jl`):
- **Solución:** (máquina de cada lote, secuencia Y de las 2n tareas "abastecer i" y "retirar i").
  El orden de cada máquina es el orden de sus abastecimientos en Y.
- **Decodificación** (análoga a su SIA): se recorre Y, y cada tarea se agrega al AGV y a la forma
  (viaje nuevo, al final del viaje en curso, o tras una visita a o/f) que da la menor suma de
  instantes de las tareas ya puestas. Los tiempos salen del decodificador exacto de la v4 aplicado
  al plan parcial.
- **Reparación** (análoga a su método A1): los retiros de cada máquina se reordenan según el orden
  de la máquina, y un retiro que aparece antes que su abastecimiento se atiende justo después.
- **Diferencia con el paper:** allí cada vehículo lleva 1 contenedor; aquí un AGV lleva hasta C
  lotes, y por eso existe la opción de sumar la tarea al viaje en curso.

**Búsqueda** (`busqueda_secuencia.jl`, como su SIA-ALNS): recocido con ruleta adaptativa y premios
1.8/1.2/0.8/0.5. Movimientos: intercambiar o mover tareas cercanas, cambiar un lote de máquina, y
reinsertar un bloque de tareas al inicio, al final o en medio (sus operadores por partes). Durante
el 30 % del tiempo se busca sobre la secuencia; el resto, la tabú de la v7 pule el resultado.

**Resultados (honestos): no mejora.**

| Prueba | 01 | 03 |
|---|---|---|
| Mejor actual | 326.66 | 476.44 |
| Mejor solución leída como secuencia y decodificada | 350.56 | 581.86 |
| Búsqueda sobre la secuencia (90 s) | 339.57 | 557.14 |
| v8 completa (5 min: secuencia + tabú) | 327.47 | 500.64 |

- La regla "el AGV que atiende antes" es **miope** con AGVs de varios lotes: no puede representar
  las buenas formas de armar viajes. Ni siquiera la mejor solución sobrevive a la decodificación.
- En el paper funciona porque cada vehículo lleva un solo contenedor, y ahí la regla casi no
  pierde nada.
- Además, la decodificación es lenta en las instancias grandes (40 ms por evaluación en la 07,
  frente a 0.1 ms del decodificador directo).
- **Conclusión:** para este problema conviene más el plan explícito de viajes (v3–v7) que la
  representación indirecta.

### Solución 9 — path relinking entre soluciones élite + tabú
**Motivación.** En la 01 y la 03 hay varias soluciones buenas pero **estructuralmente distintas**:
por ejemplo, 326.66 (con visitas a f) y 326.77 (sin visitas, de la corrida de la compañera). Las dos
son óptimos locales estrictos, así que ningún movimiento chico sale de ellas. Path relinking
(Glover, Laguna y Martí, 2000) explora el **camino entre dos óptimos**: transforma una solución
(inicio) en otra (guía) paso a paso y evalúa las soluciones intermedias, que combinan atributos de
ambas y están en zonas que ni la tabú ni el ALNS visitan.

**Método** (`relinking.jl`, `main.jl`):
- **Conjunto élite:** la mejor guardada (`resultados/`) más una solución por cada subcarpeta de
  `elite/` (`elite/amiga/`: corrida de la compañera; `elite/v3/`: solución 3). Si son menos de 5
  distintas, se completa con la tabú desde la solución constructiva usando otras semillas.
- **Atributos:** la *huella* de cada lote, la misma de la tabú (máquina y lote anterior; AGV y
  parada anterior de sus dos paradas).
- **Paso:** se transfiere un lote hacia la guía. Se pone en su máquina detrás del mismo lote que en
  la guía, y cada una de sus paradas detrás de la misma parada que en la guía.
- **Relinking voraz:** en cada paso se elige, entre los lotes que aún difieren, la transferencia
  que da la mejor solución intermedia. El camino termina cuando no quedan diferencias (o tras 2n
  pasos).
- **Pulido:** las 2 mejores intermedias (distintas de los extremos) se pulen con la tabú de la v7,
  y si la resultante es distinta entra al élite.
- **Selección del par:** el inicio es una de las 2 mejores del élite; la guía es cualquier otra.

**Resultados (honestos): no mejora** (10 minutos por instancia, 1 núcleo, 25 caminos cada una).

| Inst | Élite inicial | Élite al final | Mejor |
|---|---|---|---|
| 01 | 326.66, 326.77 (+ 327.45, 327.70 generadas) | + 326.76 y otras nuevas | 326.66 (sin cambio) |
| 03 | 476.44 (la de la compañera y la de la v3 eran la misma) + 4 generadas entre 502 y 512 | + 477.03, 477.91 | 476.44 (sin cambio) |

- El relinking sí encuentra soluciones **nuevas y cercanas** a la mejor (326.76 en la 01; 477.03
  en la 03), pero ninguna la supera.
- En la 03 el élite tenía poca diversidad buena: las soluciones generadas desde la constructiva son
  un 5–7 % peores y sirven poco de guía.
- **Limitación:** la transferencia de un lote solo copia su vecino anterior, no las visitas a o/f
  de la guía, así que el camino no siempre llega exactamente a la guía.

### Solución 10 — multi-arranque por asignaciones a máquinas (Murty) + tabú
**Motivación.** En la 01 nada mejora 326.66 partiendo de ella (ALNS, tabú con muchas semillas,
ventanas, relinking), así que la solución del líder debe tener **otra estructura**. Además, el
experimento del húngaro fijo mostró que la mejor asignación a máquinas *sin transporte* no es la
mejor *con* transporte. En vez de esperar a que la búsqueda llegue sola a otra estructura, se
recorren a propósito asignaciones distintas (multi-arranque, Martí, Resende y Ribeiro, 2013).

**Método** (`murty.jl`, `main.jl`):
- **K mejores asignaciones:** con la matriz del método húngaro de la v2 (lote → máquina y posición
  contada desde el final, costo k·p_ij), el algoritmo de **Murty (1968)** lista las asignaciones en
  orden de costo: parte el espacio en subproblemas con pares forzados y prohibidos y resuelve cada
  uno con el húngaro. Se guardan las secuencias por máquina distintas (hasta 1000; en la 01 tarda
  menos de 1 s).
- **Fase 1 (60 % del tiempo):** para cada asignación, en orden, plan inicial por reglas de despacho
  y **tabú solo sobre los viajes de los AGVs** (sin las vecindades que cambian lotes de máquina, ni
  en las patadas), `SEG_ASIG` segundos cada una (60 por defecto).
- **Fase 2 (40 %):** las 3 mejores de la fase 1 se pulen con la tabú completa (v7), que ya puede
  mover lotes entre máquinas.
- **Diagnóstico:** nuestra mejor solución de la 01 usa **exactamente la 2.ª mejor asignación** de
  Murty. En la 02 sus lotes por máquina coinciden con la asignación 56; en la 03, con ninguna de las
  1000 primeras (ahí el transporte pesa más y la asignación se aleja de la de solo máquinas).

**Mini prueba (01, 150 s, 10 s por asignación, 1 núcleo).** Desde cero, sin leer la mejor guardada:

| Asignación de Murty | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Tabú solo AGVs (10 s) | 328.10 | 326.95 | 328.23 | **326.77** | 328.28 | 328.87 | 329.66 | 329.65 |

- Después de pulir las 3 mejores con la tabú completa: **326.76** (no mejora 326.66, pero llega en
  2.5 minutos desde cero a 0.1 de nuestra mejor).
- La asignación 4 llega a 326.77 con una estructura **distinta** de la de nuestra mejor (que es la 2):
  la idea sirve para encontrar soluciones buenas en otras zonas. Falta la corrida larga (60 s por
  asignación, ~35 asignaciones por ronda).

### Experimento: ¿conviene fijar la asignación óptima a máquinas? (instancia 01)
La mejor solución de la 01 (326.66) se diferencia de la asignación **óptima a máquinas** (método
húngaro para R‖ΣC, sin transporte) solo en dos lotes: el 9 y el 16 están intercambiados entre las
máquinas 2 y 3. Se probó si, fijando esa asignación óptima y optimizando solo los viajes de los
AGVs, se podía bajar del líder (326.60).

- **Método:** máquinas fijas en la asignación del húngaro; plan inicial por reglas de despacho
  (331.75); tabú de la v9 con solo las vecindades del plan (mover/intercambiar paradas,
  fusionar/dividir/mover viajes y visitas). Las perturbaciones tampoco cambian las máquinas.
  4 semillas de 8 minutos.
- **Resultado:**

  | | Máquinas (ΣC/n sin transporte) | Agregado por el transporte | Total |
  |---|---|---|---|
  | Nuestra mejor | 290.045 | 36.614 | **326.66** |
  | Asignación óptima a máquinas (mejor de 4 semillas) | 289.818 | 38.19 | 328.00 |

- **Conclusión:** la asignación óptima a máquinas gana 0.23 en la parte de máquinas, pero el
  transporte le agrega 1.6 más por lote: con el 16 primero en la máquina 2 y el 9 en la 3, los
  viajes de los AGVs se combinan peor. **Optimizar máquinas y transporte por separado no lleva al
  mejor total.** Esto justifica decidir las dos capas a la vez (v3–v9) y no en dos etapas (como la
  solución 2 o un enfoque "primero asignar y luego transportar").

### Experimento: tabú con varias semillas en la 01 (11/11/2026)
En la 07 la tabú de la v5 sí logró salir del óptimo local del ALNS: con una semilla nueva (71007)
bajó de 905.90 a **901.93** en una sola ronda de 3500 s (105 448 iteraciones y 5 reinicios). Por
eso se repitió la idea en la 01, donde solo faltan 0.06 para el líder.

- **Método:** v5 (tabú) desde la mejor solución (326.66); 3 copias en paralelo con semillas
  distintas (bases 130000, 140000 y 150000), 2 rondas de 3500 s cada una (unas 6 horas de CPU en
  total).
- **Resultado:** las 6 corridas terminan en **326.66**; ninguna mejora.
- **Conclusión:** en la 01, 326.66 resiste el ALNS, la tabú con 6 semillas nuevas (y las
  anteriores), las ventanas exactas de la v7 y el húngaro fijo. A diferencia de la 07, más
  semillas y más tiempo alrededor de esta solución no alcanzan: la del líder probablemente tiene
  otra estructura (otra asignación a máquinas o a AGVs) que no es vecina de la nuestra.
- **Mini prueba en la 02 y la 03** (lo que funcionó en la 07: v5 desde la mejor guardada, 120 s,
  1 núcleo): 405.59 y 476.44, sin cambio. Falta la corrida larga (2 rondas de 3500 s).

## Mejores valores (11/11/2026)

Mejor solución factible de cada instancia y dónde está. "Líder" es el mejor valor del ranking de
IO1Lab el 11/11 a las 13:45 (el grupo GHI subió las 10 instancias entre 13:33 y 13:45).

| Inst | Mejor valor | Método | Archivo | Líder IO1Lab | Estado |
|---|---|---|---|---|---|
| 01 | 326.66 | v4 (ALNS) | `solucion_4/resultados/instancia_01_io1lab.txt` | 326.60 (GHI) | falta 0.06 |
| 02 | 405.59 | v4 (ALNS sin visitas, 10 rondas, corrida de la compañera) | `solucion_4/resultados/instancia_02_io1lab.txt` | 403.35 (GHI) | falta 2.24 |
| 03 | 476.44 | v3/v4 | `solucion_4/resultados/instancia_03_io1lab.txt` | 473.04 (GHI) | falta 3.40 |
| 04 | 525.92 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/instancia_04_io1lab.txt` | 521.42 (GHI) | falta 4.50 |
| 05 | 591.34 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/instancia_05_io1lab.txt` | 590.33 (GHI) | falta 1.01 |
| 06 | 754.24 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/instancia_06_io1lab.txt` | 741.33 (GHI) | falta 12.91 |
| 07 | 901.93 | v5 (tabú, 1 ronda de 3500 s, semilla 71007, corrida de una amiga) partiendo de la 905.90 de la v4 | `mejores/instancia_07_io1lab.txt` | 877.81 (GHI) | falta 24.12 |
| 08 | 1080.08 | v5 (tabú) | `mejores/instancia_08_io1lab.txt` | 1065.64 (GHI) | falta 14.44 |
| 09 | 958.59 | v5 (tabú, 6 rondas de 3500 s, corrida de un amigo) | `mejores/instancia_09_io1lab.txt` | 955.55 (GHI) | falta 3.04 |
| 10 | 990.47 | v5 (tabú, 6 rondas de 3500 s, corrida de un amigo: 990.62) + 1 visita intermedia agregada por descenso | `mejores/instancia_10_io1lab.txt` | 969.80 (GHI) | falta 20.67 |

La carpeta `mejores/` tiene la mejor solución de cada instancia (todas validadas como factibles). Cada `solucion_X/resultados/` guarda lo que encontró esa versión.

## Resultados (promedio de finalización, s)

| Instancia | Solución 2 | Solución 3 | Solución 4 (mejor actual) |
|---|---|---|---|
| ejemplo | 1102.50 | 1044.00 | 1044.00 |
| 01 | 330.10 | 326.77 | 326.66 |
| 02 | 416.45 | 410.68 | 409.44 |
| 03 | 478.07 | 476.44 | 476.44 |
| 04 | 531.00 | 526.40 | 526.40 |
| 05 | 601.34 | 591.40 | 591.40 |
| 06 | 759.10 | 754.42 | 754.42 |
| 07 | 910.12 | 906.70 | 906.69 |
| 08 | 1108.86 | 1092.96 | 1083.76 (con la tabú de la v5) |
| 09 | 1002.51 | 964.36 | 964.36 |
| 10 | 1091.61 | 998.97 | 998.97 |

La columna de la solución 4 es la mejor solución guardada en `solucion_4/resultados/` (cada corrida parte de la anterior).
La solución de ejemplo del enunciado da 1062 s.

## Papers usados en cada solución

Los números corresponden a la lista de referencias de abajo.

| Solución | Papers | Para qué se usó |
|---|---|---|
| 1 | — | Solo reglas simples (carga mínima + SPT), sin literatura |
| 2 | [1], [2], [3], [4] | [1]–[2]: asignación exacta R‖ΣC con el método húngaro (solución inicial) · [3]: recocido simulado · [4]: ILS |
| 3 | [3], [4], [5], [7] | [5]: representación en dos capas máquinas + vehículos · [3]: recocido simulado · [7]: ruleta adaptativa de vecindades · [4]: perturbaciones tipo ILS |
| 4 | [1], [2], [3], [5], [6], [7], [8] | [7]: esquema ALNS (destrucción/reparación, premios 33/9/13, eliminación de los peores) · [6]: eliminación de lotes relacionados (Shaw) · [8]: ALNS con recocido para un problema integrado con buffers limitados, e inserción voraz evaluada con simulación · [1]–[2]: reinicios desde asignaciones húngaras perturbadas · [3]: aceptación de Metropolis · [5]: misma representación de la v3 |
| 5 | [5], [9], [10] | [9]–[10]: búsqueda tabú (lista tabú por atributos, aspiración, lista de candidatos) · [5]: misma representación de la v3 |
| 6 | [5], [6], [7], [8], [9], [10] | [9]–[10]: búsqueda tabú como búsqueda local · [7]: destrucción/reparación y ruleta adaptativa como perturbación · [6], [8]: operadores de la v4 · [5]: misma representación |
| 7 | [5], [9], [10], [11], [12], [13], [14], [15] | [9]–[10]: búsqueda tabú · [11]: ventanas exactas (POPMUSIC) · [12]: *dynasearch* · [13]: intercambio cíclico (VLSN) · [14]–[15]: Or-opt y movimiento de pares, usados en la revisión exhaustiva |
| 8 | [8], [7], [9], [10] | [8]: secuencia de inserción, decodificación SIA, reparación A1 y operadores por partes · [7]: ruleta adaptativa · [9]–[10]: tabú para pulir |
| 9 | [9], [10], [16] | [16]: path relinking entre soluciones élite · [9]–[10]: tabú para pulir las intermedias |
| 10 | [1], [2], [9], [10], [17], [18] | [17]: K mejores asignaciones (Murty) · [1]–[2]: matriz de asignación R‖ΣC · [18]: multi-arranque · [9]–[10]: tabú solo sobre los AGVs y luego completa |

## Referencias

**Usadas en el método**
1. Horn, W. A. (1973). Minimizing average flow time with parallel machines. *Operations Research*, 21(3), 846–847.
2. Bruno, J., Coffman, E. G. y Sethi, R. (1974). Scheduling independent tasks to reduce mean finishing time. *Communications of the ACM*, 17(7), 382–387.
3. Kirkpatrick, S., Gelatt, C. D. y Vecchi, M. P. (1983). Optimization by simulated annealing. *Science*, 220(4598), 671–680.
4. Lourenço, H. R., Martin, O. C. y Stützle, T. (2003). Iterated local search. En *Handbook of Metaheuristics*, 320–353. Springer.
5. Bilge, Ü. y Ulusoy, G. (1995). A time window approach to simultaneous scheduling of machines and material handling system in an FMS. *Operations Research*, 43(6), 1058–1070.
6. Shaw, P. (1998). Using constraint programming and local search methods to solve vehicle routing problems. En *Principles and Practice of Constraint Programming (CP-98)*, LNCS 1520, 417–431. Springer.
7. Ropke, S. y Pisinger, D. (2006). An adaptive large neighborhood search heuristic for the pickup and delivery problem with time windows. *Transportation Science*, 40(4), 455–472.
8. Yin, Y. Q. y Hu, Z. H. (2026). Integrated scheduling of multiple handling equipment at an automated container terminal with apron and block buffer zones. *Flexible Services and Manufacturing Journal*. https://doi.org/10.1007/s10696-026-09680-7
9. Glover, F. (1986). Future paths for integer programming and links to artificial intelligence. *Computers & Operations Research*, 13(5), 533–549.
10. Glover, F. y Laguna, M. (1997). *Tabu Search*. Kluwer Academic Publishers.
11. Taillard, É. D. y Voss, S. (2002). POPMUSIC — Partial optimization metaheuristic under special intensification conditions. En *Essays and Surveys in Metaheuristics*, 613–629. Springer.
12. Congram, R. K., Potts, C. N. y van de Velde, S. L. (2002). An iterated dynasearch algorithm for the single-machine total weighted tardiness scheduling problem. *INFORMS Journal on Computing*, 14(1), 52–67.
13. Ahuja, R. K., Ergun, Ö., Orlin, J. B. y Punnen, A. P. (2002). A survey of very large-scale neighborhood search techniques. *Discrete Applied Mathematics*, 123, 75–102.
14. Or, I. (1976). *Traveling salesman-type combinatorial problems and their relation to the logistics of regional blood banking*. Tesis doctoral, Northwestern University.
15. Nanry, W. P. y Barnes, J. W. (2000). Solving the pickup and delivery problem with time windows using reactive tabu search. *Transportation Research Part B*, 34(2), 107–121.
16. Glover, F., Laguna, M. y Martí, R. (2000). Fundamentals of scatter search and path relinking. *Control and Cybernetics*, 29(3), 653–684.
17. Murty, K. G. (1968). An algorithm for ranking all the assignments in order of increasing cost. *Operations Research*, 16(3), 682–687.
18. Martí, R., Resende, M. G. C. y Ribeiro, C. C. (2013). Multi-start methods for combinatorial optimization. *European Journal of Operational Research*, 226(1), 1–8.

**Revisadas (problemas relacionados, no usadas directamente)**
- Zheng, Y., Xiao, Y. y Seo, Y. (2014). A tabu search algorithm for simultaneous machine/AGV scheduling problem. *International Journal of Production Research*, 52(19), 5748–5763.
- Ruiz, R. y Stützle, T. (2007). A simple and effective iterated greedy algorithm for the permutation flowshop scheduling problem. *European Journal of Operational Research*, 177(3), 2033–2049.
- Rodriguez, F. J., Lozano, M., Blum, C. y García-Martínez, C. (2013). An iterated greedy algorithm for the large-scale unrelated parallel machines scheduling problem. *Computers & Operations Research*, 40(7), 1829–1841.
- Burke, E. K. y Bykov, Y. (2017). The late acceptance hill-climbing heuristic. *European Journal of Operational Research*, 258(1), 70–78.
- Dumez, D., Tilk, C., Irnich, S., Lehuédé, F., et al. (2021). Hybridizing large neighborhood search and exact methods for generalized vehicle routing problems with time windows. *EURO Journal on Transportation and Logistics*, 10, 100040. (Combinación de rutas con un modelo exacto: descartada porque necesita un solver.)
- Integrated scheduling problem of multi-load AGVs and parallel machines considering the recovery process (2025). *Swarm and Evolutionary Computation*. https://www.sciencedirect.com/science/article/abs/pii/S2210650225000197
- Joint scheduling of parallel machines and AGVs with sequence-dependent setup times in a matrix workshop. *Computers & Industrial Engineering*. https://www.sciencedirect.com/science/article/abs/pii/S0360835223006459
- Scheduling of no buffer job shop cells with blocking constraints and AGVs. *Applied Soft Computing*. https://www.sciencedirect.com/science/article/abs/pii/S1568494614003937
- An ACO–SA algorithm for a multiload AGVs workshop scheduling problem with limited buffer capacity (2023). *Processes*, 11(3), 861. https://doi.org/10.3390/pr11030861
- Critical-path-based VND for the joint scheduling of FJSP and AGVs (2025). *Mathematics*, 13(23), 3883. https://doi.org/10.3390/math13233883
