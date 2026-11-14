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
solucion_11/  Solución 11: tabú de la v5 + vecindades de ruteo entre AGVs (CROSS, 2-opt*) y elección guiada por retrasos
solucion_12/  Solución 12: tabú de la v11 con tramos cortos y reinicios chicos (tabú iterada) + corrida adaptativa v12/v11
solucion_13/  Solución 13: tabú iterada de la v12 + búsqueda local guiada (penalización de rasgos)
solucion_temporal/  Prototipo: despacho por ciclos con asignación en línea + guion de parámetros (ver solucion_temporal/propuesta.md)
solucion_reglas_yampi/  Constructivo de reglas sin búsqueda (R1–R4 con excepciones S e Y), hecho por Yampi
  instancias/   Instancias convertidas a .txt
  resultados/   Soluciones generadas y archivos para IO1Lab
```

## Nuestro método central

**Búsqueda tabú iterada sobre un plan explícito de viajes de AGVs** (solución 12, código en `solucion_13/`),
con una solución inicial de **despacho por ciclos** (`solucion_temporal/`).

1. **Representación:** secuencia de lotes por máquina + lista de viajes de cada AGV (paradas de entrega y
   retiro, y visitas a o y f). Un decodificador (camino más largo) calcula los tiempos lo antes posible.
2. **Solución inicial:** cada AGV, al quedar libre, elige el ciclo (qué máquinas abastece y qué retira) que
   más rinde por segundo de AGV; el lote se asigna a su máquina al cargarlo en o. Los parámetros de esa
   regla se ajustan por tramos con una búsqueda local corta (el "guion").
3. **Búsqueda local:** tabú con lista de candidatos y vecindades de máquinas (mover/intercambiar lotes),
   de viajes (mover/intercambiar paradas, fusionar/dividir viajes, visitas) y de ruteo entre AGVs
   (CROSS, 2-opt\*); tramos cortos con reinicio desde la mejor y perturbación pequeña (tabú iterada).

Las versiones 1–11 y 13 son la historia de cómo se llegó a este método. La 01–03 se alcanzaron con el
ALNS de la v4, y la tabú no las mejoró. Detalle en "¿Cuál es el mejor modelo?" y "Mejores valores".

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
- **Corrida larga (01, 2 rondas de 3500 s, 60 s por asignación, 34 asignaciones por ronda):** la
  mejor de la fase 1 es 326.77 (asignaciones 2 y 4) y después de pulir, **326.76**. No mejora
  326.66: las asignaciones más lejanas (12 en adelante) quedan en 327 o más. En la 01 la mejor
  solución usa una de las 4 primeras asignaciones y la diferencia con el líder está en los AGVs.

### Solución 11 — tabú + vecindades de ruteo entre AGVs + elección guiada por retrasos
**Motivación (empírica).** Frente al líder (GHI) perdemos sobre todo en las instancias donde manda
el transporte: 06 (−12.9), 07 (−24.1), 08 (−14.3) y 10 (−20.7), con gaps de 15–40 % sobre la cota
de solo máquinas, contra 1–3 % en la 01–05. Ahí lo que mejora es la tabú (v5) y no el ALNS. Pero
las vecindades de la v5 solo mueven **una parada o un viaje completo**: ninguna intercambia
**tramos** de viajes entre los dos AGVs, que es lo más usado en ruteo de vehículos.

**Método** (`transporte.jl`, sobre la tabú de la v5):
- **Tres vecindades de ruteo** entre los AGVs:
  - *CROSS-exchange* (Taillard et al., 1997): intercambia tramos de 1–3 viajes completos entre dos
    AGVs (un tramo vacío equivale a mover un tramo).
  - *2-opt\** (Potvin y Rousseau, 1995): intercambia las colas de las listas de viajes de los dos
    AGVs, cortando en viajes cercanos en el tiempo.
  - *Cruzar colas*: 2-opt\* entre dos viajes; el final de uno pasa al otro y viceversa.
- **Elección guiada por retrasos** (idea de las vecindades de camino crítico, Nowicki y Smutnicki,
  1996): en cada iteración se decodifica la solución actual y se mide, para cada lote, cuánto lo
  retrasó el transporte: lo que su máquina esperó a que llegara (llegada − salida del anterior) y lo
  que tardó desde que terminó hasta llegar a f (c − fin). La mitad de las veces la parada que se
  mueve se elige con ruleta según ese retraso, en vez de al azar.
- Todo lo demás es igual a la v5 (lista de candidatos, huellas, aspiración, reinicios).

**Comparación justa con la v5** (desde la mejor guardada, 300 s, mismas semillas, 1 núcleo cada una):

| Inst | Inicio | v5 sem 1 | v5 sem 2 | **v11 sem 1** | **v11 sem 2** |
|---|---|---|---|---|---|
| 06 | 754.24 | 754.24 | 754.24 | **753.09** | **751.30** |
| 07 | 901.93 | 901.25 | 900.34 | **898.20** | **899.68** |

- La v11 gana en las 4 comparaciones, con casi las mismas iteraciones (las vecindades nuevas no
  son más caras). En la 06 la v5 no se mueve en 5 minutos; la v11 baja 1–3 puntos.
- Nuevas mejores: **06 = 751.30** y **07 = 898.20**.

**¿Por qué la v11 rinde más que la v5? (comparación del código, 12/11/2026)** La mecánica de la
tabú es **idéntica** en las dos: misma memoria (huellas de cada lote: máquina y lote anterior; AGV
y parada anterior de sus dos paradas), misma tenencia (2√n a 4√n), misma aspiración, misma lista de
candidatos (tantos vecinos como lotes, entre 30 y 200) y mismos reinicios. Lo único que cambia es
**qué vecinos se miran**:
- **Movimientos más grandes, pero evaluados.** Las vecindades de la v5 mueven una parada o un viaje
  entero. Un CROSS-exchange o un 2-opt\* equivale a 2–3 de esos movimientos seguidos cuyos pasos
  intermedios suelen empeorar, un camino que la tabú rara vez toma. La v11 lo hace en un paso, y
  solo si es el mejor candidato de la lista.
- **La guía por retrasos afecta a todas las vecindades que mueven una parada** (`vecindades.jl`),
  no solo a las nuevas: la mitad de los candidatos tocan los lotes que más atrasa el transporte.
  Es la idea de camino crítico [21]: no gastar candidatos en lo que no causa el atraso.
- **Costo casi nulo:** hace prácticamente las mismas iteraciones por segundo que la v5.
- **Evidencia:** además de la tabla de arriba (4 de 4 comparaciones con los mismos 5 minutos), en
  la 07 la v5 corrió 6 horas (6 rondas de 3500 s, corrida del amigo A) desde 901.93 y llegó a
  899.77; la v11 llegó a 898.20 en 5 minutos desde el mismo punto.

### Corrida larga de la v11 y plan siguiente (12/11/2026)
**Corrida:** v11 desde la mejor guardada, 8 rondas de 3500 s (semillas 70xxxx, una nueva por ronda),
6 instancias en paralelo (1 núcleo cada una), del 11/11 22:08 al 12/11 05:56.

| Inst | Inicio | R1 | R2 | R3 | R4 | R5 | R6 | R7 | **R8** |
|---|---|---|---|---|---|---|---|---|---|
| 04 | 525.92 | 525.92 | 525.92 | 525.52 | 525.16 | 523.98 | 523.84 | 523.75 | **523.74** |
| 06 | 751.30 | 750.57 | 749.07 | 748.95 | 748.95 | 748.87 | 748.84 | 748.84 | **748.73** |
| 07 | 898.20 | 896.42 | 896.28 | 896.18 | 896.15 | 896.10 | 894.27 | 893.56 | **892.68** |
| 08 | 1079.92 | 1077.92 | 1074.79 | 1074.37 | 1074.22 | 1072.28 | 1071.29 | 1071.29 | **1071.07** |
| 09 | 958.59 | 957.46 | 956.92 | 956.90 | 956.76 | 956.61 | 955.31 | 955.07 | **954.27** |
| 10 | 990.47 | 983.47 | 974.74 | 974.57 | 972.18 | 972.10 | 972.09 | 972.05 | **972.05** |

**Análisis de los 48 logs: ¿cuándo mejora la tabú?** La tabú reinicia (desde la mejor, con una
perturbación, vaciando la lista tabú) cuando pasa el 10 % del tiempo (350 s) sin mejorar.

- **Las mejoras llegan justo después de un reinicio:** de 140 mejoras registradas, 96 aparecen en
  las primeras 20 000 iteraciones del tramo. En la 04 un tramo dura unas 200 000 iteraciones; lo
  demás es la solución actual deambulando 3–6 puntos por encima de la mejor sin encontrar nada.
- **El salto del reinicio importa, y conviene que sea chico:**

  | Perturbación al reiniciar (sobre la mejor) | Tramos que mejoraron |
  |---|---|
  | 0 (vuelve a la mejor y solo vacía la lista tabú) | 50 de 122 (40 %) |
  | chica (< 5) | 13 de 57 (22 %) |
  | media (5–20) | 7 de 67 (10 %) |
  | grande (> 20, hasta +321) | 7 de 104 (6 %) |

- **Bug en la perturbación** (`busqueda_plan.jl`, `perturbar_plan`): `for _ in 1:rand(MOVS_PATADA), _ in 1:20`
  con `break` corta los **dos** bucles en Julia, así que se aplica **un solo** movimiento (no 3–8),
  elegido entre las 10 vecindades al azar, incluidas las de visitas que la tabú no usa (pesos 0). De
  ahí los saltos enormes.

**¿Más lejos o más cerca? Dos cosas distintas.** La v11 ganó a la v5 con movimientos **más grandes**
(CROSS-exchange de tramos de 1–3 viajes y 2-opt\* de colas). Pero esos movimientos están **dentro**
de la tabú: entran a la lista de candidatos y se aplican solo si son el mejor vecino, y además se
eligen guiados por los retrasos. Es la idea de las vecindades grandes (VLSN [13]) y de combinar
vecindades de distinto tamaño (VNS [23]): **vecindades más ricas, evaluadas.** El salto del
reinicio, en cambio, es **al azar y se acepta sin mirar**: si es grande, rompe la estructura buena
y equivale casi a empezar de nuevo. La búsqueda local iterada [4] y la tabú iterada [22]
recomiendan justo eso: perturbaciones pequeñas desde la mejor y tramos de búsqueda cortos. Los datos
de arriba lo confirman. Así que no hay contradicción: **moverse lejos con criterio sirve; saltar
lejos a ciegas no.**

**Qué ya se había probado (v3–v10) y cómo encaja con esto:**
- **Tramos cortos con saltos grandes = v6.** El híbrido de la v6 ya corta la tabú cuando se estanca
  el 3 % del tiempo, pero reinicia con una patada LNS (saca y reinserta hasta el 30 % de los lotes).
  En la 07 no mejoró en 6 horas, y en la 08 bajó solo 0.16 en una ronda. Coincide con la tabla de
  arriba: el salto grande es lo que falla, no los tramos cortos. La v12 prueba lo que falta: tramos
  cortos con saltos **chicos**.
- **Volver a la mejor si la actual se aleja más del 2 %** ya existe en la v7–v10
  (`MAX_ALEJAMIENTO`), pero la v11 parte de la v5 y no la tiene. En la v11 la actual deambula
  0.3–0.7 % por encima de la mejor, así que con esa regla casi nunca se activaría. Los reinicios
  más frecuentes de la v12 cumplen ese papel.
- **El bug de la perturbación está en todas las versiones (v3–v11):** todas comparten
  `busqueda_plan.jl`. Donde este README dice "3–8 movimientos al azar" (v3, v5), en la práctica
  fue **1** movimiento.
- **El tamaño de la lista de candidatos y la tenencia** se fijaron "con pocas pruebas" (v5,
  limitaciones). No se cambian en la v12 para medir un solo efecto a la vez; se podrían probar
  después.
- **Ojo con `seguir.sh`:** su plan B para instancias estancadas es la v6 (patadas grandes), que
  los datos ponen en duda. Si la v12 gana la prueba, el plan B debería ser la v12 o volver a la
  mejor con otra semilla.

**Plan (v12 = v11 con estos cambios), a probar antes de otra corrida larga:**
1. **Tramos cortos (tabú iterada [22], ILS [4]):** reiniciar tras el 2 % del tiempo sin mejorar
   (70 s) en vez del 10 % (350 s): unas 5 veces más reinicios en la misma hora.
2. **Perturbación chica y con las vecindades de la tabú [4]:** 1–2 movimientos con `PESOS_TABU`
   (sin visitas); si el salto queda a más de +5 de la mejor, se descarta y se sortea otro.
3. **Mezcla de reinicios:** la mitad vuelve a la mejor tal cual (solo vacía la lista tabú, el caso
   que más rindió: 40 %) y la otra mitad con la perturbación chica.
4. **Variante:** más peso a las vecindades de ruteo (de 0.06 a 0.12 cada una), porque son las que
   hicieron ganar a la v11.

**Prueba:** v11 contra v12 contra v12 + ruteo, con las mismas semillas, en la 07 y la 09 (las que
seguían mejorando en la ronda 8), 2 rondas de 30 min. Si la v12 gana, reemplaza a la v11 en
`seguir.sh` (rondas adaptativas: sigue con otra semilla mientras mejore; si se estanca 2 rondas,
cambia a la v6; si se estanca 4, descansa). No se cambia el tamaño de la lista de candidatos ni se
agrandan las perturbaciones: los datos no lo apoyan.

### Solución 12 — tabú iterada: tramos cortos y reinicios chicos
Es la v11 con los 3 cambios del plan de arriba (`solucion_12/tabu.jl`): reinicio tras el 2 % del
tiempo sin mejorar; al reiniciar, la mitad de las veces vuelve a la mejor tal cual y la otra mitad
aplica 1–2 movimientos de la tabú que no se alejen más de 5 de la mejor (esto reemplaza la
perturbación con el bug); `PESOS_RUTEO` cambia el peso de las vecindades de ruteo.

**Prueba** (`prueba_v12.sh`): v11, v12 y v12r (ruteo 0.12) desde `mejores/`, mismas semillas, 2 rondas
de 1800 s; cada variante sigue desde lo suyo en la ronda 2.

| Inst | Partida | v11 R1 | v12 R1 | v12r R1 | v11 R2 | v12 R2 | v12r R2 |
|---|---|---|---|---|---|---|---|
| 07 | 892.68 | 892.50 | **892.15** | **892.15** | 892.50 | 891.99 | **891.97** |
| 09 | 954.27 | 953.59 | **953.48** | 953.89 | **953.30** | 953.47 | 953.76 |
| Reinicios por ronda | | 8–9 | 39–45 | 39–45 | | | |

- **Resultado mixto:** la v12 gana en la 07 (0.5 menos que la v11 en 1 hora) y la v11 en la 09 (0.17
  menos). Con 2 instancias y 1 semilla no hay un ganador claro; las dos mejoran en todas las
  corridas. Más peso al ruteo (v12r) no muestra un efecto consistente.
- **Nuevas mejores:** **07 = 891.97** (v12r) y **09 = 953.30** (v11).
- **Corrida corta de la tarde** (v12, 5 instancias, 2 rondas de 3300 s): bajan las 5: 04 = 523.69,
  05 = 590.66, 07 = 891.79, 08 = 1070.84, 09 = 952.85 (unos 45 reinicios por ronda).
- **Decisión para la corrida larga** (`solucion_12/seguir.sh`): como ninguna domina, se alternan. Cada
  instancia corre la v12 mientras mejore; si se estanca 2 rondas pasa a la v11 (con su dinámica de
  reinicios cada 10 %) y si mejora vuelve a la v12; tras 4 rondas sin mejora descansa. Reemplaza al
  plan B anterior (v6), cuyas patadas grandes los datos ponen en duda.

### Diagnóstico: ¿dónde está la diferencia en la 04–10? (12/11/2026)
Para cada mejor solución se separa su valor en tres partes (`solucion_12/diagnostico.jl`; uso:
`julia diagnostico.jl "$PWD" 04 05 06` desde `solucion_12/`; misma fórmula que la cota de la v4): **cota sin congestión** = ΣC de las máquinas
procesando desde 0, sin esperas, más la ruta mínima o→α_j + β_j→f de cada lote, dividido por n.

| Inst | Nuestra | Cota óptima (húngaro) | Cota de nuestra asignación | Se paga en asignación | Se paga en congestión | Líder | Líder − cota |
|---|---|---|---|---|---|---|---|
| 04 | 523.69 | 509.55 | 515.27 | 5.72 | 8.42 | 521.42 | 11.87 |
| 05 | 590.66 | 578.28 | 580.77 | 2.49 | 9.89 | 590.33 | 12.05 |
| 06 | 748.73 | 647.24 | 720.70 | 73.46 | 28.03 | 741.33 | 94.09 |
| 07 | 891.79 | 711.02 | 826.28 | 115.26 | 65.50 | 877.81 | 166.79 |
| 08 | 1070.84 | 767.44 | 943.97 | 176.53 | 126.88 | 1065.64 | 298.20 |
| 09 | 952.85 | 828.50 | 916.35 | 87.85 | 36.50 | 955.55 | 127.05 |
| 10 | 972.05 | 847.10 | 925.07 | 77.97 | 46.97 | 969.80 | 122.70 |

- **04 y 05:** casi todo es congestión (8–10) y la asignación está cerca de la óptima. El líder
  está en la misma zona; ahí basta con seguir puliendo (05: falta 0.33).
- **06–10:** nuestras soluciones se alejan **mucho** de la asignación óptima a máquinas (73–177
  por lote) para que 2 AGVs alcancen a atender: es un compromiso, no un error (como en la 01, la
  asignación óptima a máquinas sola es peor con transporte). El líder también está a 94–298 de la
  cota, así que el compromiso es inevitable; la pregunta es **qué asignación** usa.
- **Implicación:** la tabú mueve lotes de a uno, y cada cambio de máquina obliga a rehacer viajes;
  en la 07 la asignación es 115 peor que la óptima y la tabú solo la ajusta en el margen. Una
  asignación **distinta en bloque** (otra forma de repartir los lotes entre máquinas) es difícil
  de alcanzar con movimientos de un lote. Por eso, para la 06–08 se plantea:
  1. **Multi-arranque desde cero con la v12** (argumento `cero`, 2–3 semillas, 1 h en la 07):
     ¿llega a otra asignación con valor parecido o mejor? Es barato y usa código existente.
  2. **Si llega cerca pero con otra estructura:** path relinking (v9) entre esa y nuestra mejor.
  3. **Si no:** un movimiento de bloque que reasigne varios lotes de una máquina a otra y rehaga
     sus viajes (a diseñar).
  La 04, 05, 09 y 10 siguen con la corrida adaptativa de la v12.

### Corrida de la noche con la v12 (12–13/11/2026)
`solucion_12/seguir.sh` (22:30–05:54, 7 instancias, rondas de 3500 s; v12 mientras mejore, v11 tras
2 rondas estancada, descanso tras 4) y `solucion_12/extra.sh`, que desde las 02:45 usó los núcleos
liberados (3 rondas de 3500 s, cada tarea en su copia `solucion_12/extra/`).

| Inst | Antes | Después | Rondas | Comentario |
|---|---|---|---|---|
| 04 | 523.69 | **523.22** | 6 | baja con la v12 en las rondas 1–2; la v11 solo saca 0.02 |
| 05 | 590.66 | 590.66 | 4 | sin cambio |
| 06 | 748.73 | **747.83** | 7 | la que más baja (−0.90), siempre con la v12 |
| 07 | 891.79 | **891.72** | 4 | −0.07 |
| 08 | 1070.84 | **1070.79** | 4 | −0.05 |
| 09 | 952.85 | 952.85 | 4 | sin cambio |
| 10 | 972.05 | **971.94** | 5 | −0.11 con la v12; la v11 no mejora |
| 02 (extra) | 405.59 | 405.59 | 3 | primera vez con la v12, sin cambio |
| 03 (extra) | 476.44 | 476.44 | 3 | primera vez con la v12, sin cambio |

- **La v11 no destrabó ninguna instancia** en 9 rondas de instancia: todas las mejoras vienen de la
  v12. Para la próxima, la alternancia con la v11 no aporta.
- **02 y 03:** los reinicios chicos de la v12 tampoco salen del óptimo local (ver v7: óptimos
  estrictos). Hace falta cambiar el criterio de búsqueda, no solo cómo se reinicia → v13.

**07 desde cero (paso 1 del plan de arriba).** v12 con `cero`, 2 semillas, 3 rondas de 3500 s:

| Semilla | Constructiva | Ronda 1 | Ronda 2 | Ronda 3 | Lotes en otra máquina que en la mejor |
|---|---|---|---|---|---|
| a | 995.54 | 914.08 | 913.97 | 913.97 | 66 de 125 |
| b | 995.54 | 914.25 | 913.93 | **913.90** | 58 de 125 |

- En 1 hora llega a ~914 y después se estanca, **22 por encima** de nuestra mejor (891.72), que
  salió de muchas horas de ALNS + tabú.
- Las dos semillas llegan a valores casi iguales con **asignaciones muy distintas** (58 lotes
  cambian de máquina entre ellas): hay muchos valles de calidad parecida, y la tabú se queda en el
  primero que encuentra.
- Según el plan, como no llega cerca, el path relinking (paso 2) tiene poca expectativa (además la
  v9 no mejoró en la 01 y la 03). Queda el paso 3: un movimiento de bloque.

### Corrida de día (13/11/2026): v12 en 06/04/10, v12 con visitas en la 01 y prueba de la v13
3 rondas de 3500 s (`solucion_12/dia.sh`) y 2 rondas de 3500 s para la v13 (`solucion_13/prueba_v13.sh`),
6 núcleos.

| Inst | Método | Antes | Después |
|---|---|---|---|
| 04 | v12 | 523.22 | **523.20** |
| 06 | v12 | 747.83 | 747.83 |
| 10 | v12 | 971.94 | **971.84** |
| 01 | v12 con visitas (`PESOS_VISITA=0.04`) | 326.66 | 326.66 |
| 03 | v13 | 476.44 | 476.44 |
| 02 | v13 | 405.59 | 405.59 |

- **01 con visitas:** la mejor de la 01 tiene 3 viajes que pasan por f a mitad de camino, pero desde
  la v5 la tabú tenía en 0 el peso de las vecindades de visitas (insertar/quitar visita, unir por o).
  `solucion_12/tabu.jl` ahora acepta `PESOS_VISITA` (0 por defecto). Con visitas y las vecindades de
  ruteo de la v11 (nunca usadas en la 01), 3 h y 3 semillas: sin cambio.

**Corrida rápida (13/11, 15:46–16:16, 8 núcleos, `solucion_13/rapido.sh`).** Variantes en paralelo
sobre las más cercanas al líder: v12 con ruteo 0.12, v13 con `GLS_ALFA=0.1` y v12 con visitas.

| Inst | v12 ruteo 0.12 | v13 α = 0.1 | v12 con visitas |
|---|---|---|---|
| 05 (590.66) | 590.66 | 590.66 | 590.66 |
| 04 (523.20) | 523.17 | 523.18 | **523.17** (523.168) |
| 10 (971.84) | **971.80** | 971.84 | — |

Nota: el decodificador (`plan.jl`) ya da los tiempos óptimos para los órdenes fijados (camino más largo,
todo lo antes posible); con un objetivo regular como ΣC no hay nada que ganar retrasando a los AGVs.
Las mejoras solo pueden venir de cambiar los órdenes.

### Solución 13 — tabú iterada + búsqueda local guiada
**Motivación.** Las mejores de la 01–03 son óptimos locales estrictos (v7), y ni la tabú con muchas
semillas (v5), ni la v12, ni el ALNS, ni el path relinking las mueven: la búsqueda siempre vuelve a la
misma estructura. La búsqueda local guiada (*Guided Local Search*, Voudouris y Tsang, 1999 [24])
cambia el paisaje en vez de los movimientos.

**Método** (`solucion_13/tabu.jl`, sobre la v12):
- **Rasgos:** los 6 componentes de la huella de cada lote (máquina, lote anterior en la máquina, AGV y
  parada anterior del abastecimiento y del retiro).
- **Costo aumentado:** h = g + λ·Σ p_f. La tabú elige el mejor vecino según h; la mejor solución y la
  aspiración usan el valor real g.
- **Penalización:** en cada reinicio (2 % del tiempo sin mejorar) se suma 1 a los K = máx(2, 0.1·n)
  rasgos de la mejor con mayor utilidad c_f / (1 + p_f), con c_f = retraso por transporte del lote, y
  se vuelve a la mejor. λ = 0.2 · g / (6n), como en el paper (α por el costo medio por rasgo).
  Variables de entorno `GLS_ALFA` y `GLS_FRAC`.

**Resultado (honesto): no mejora.** En la 03 (3.4 millones de iteraciones y 47 reinicios por ronda) la
búsqueda sí se aleja: la solución actual tiene mediana 504 (máximo 531) frente a 476.44 de la mejor;
o sea, recorre otras estructuras, y ninguna es mejor. Lo mismo en la 02 (7.2 millones de iteraciones).

**Vecindades de bloque** (`solucion_13/bloques.jl`, prueba `bloques.sh`, 13/11 17:25–18:23, 7 núcleos,
`GLS_ALFA=0`). Para la 06–08, donde el diagnóstico muestra que la asignación a máquinas está lejos de la
óptima y la tabú mueve lotes de a uno:
- **mover_bloque:** 2–5 lotes seguidos pasan, en el mismo orden, a otra máquina (Or-opt, Or 1976, entre
  máquinas). **intercambiar_bloques:** un bloque de 1–4 lotes se cambia por otro de otra máquina
  (CROSS-exchange, Taillard et al. 1997 [19], aplicado a máquinas).
- Las paradas de los AGVs quedan donde estaban (`PROB_QUEDAN`) o se reinsertan como viajes propios
  junto al viaje del lote vecino. Sin esa reparación solo 29 de cada 2000 vecinos eran factibles en la
  07 (bloqueos entre AGVs y máquinas); con ella, unos 210, pero el 10 % mejor empeora +15 a +23.
- Variantes: bloques dentro de la tabú con peso 0.06 y 0.15 (`PESO_BLOQUE`), y patada de bloque (hasta
  +30) en el 50 % de los reinicios (`PATADA_BLOQUE`), contra la v12 sola como control.

| Inst | Control (v12) | Bloques 0.06 | Bloques 0.15 | Patada |
|---|---|---|---|---|
| 07 (891.72) | 891.72 | 891.72 | 891.72 | 891.72 |
| 08 (1070.79) | 1070.79 | 1070.79 | — | 1070.79 |

- **Inconcluso:** en 1 hora ninguna mejora, ni el control. Se dejan como una variante más en la corrida
  larga (`solucion_13/portafolio.sh`, que rota base / ruteo / visitas / bloques por ronda).
- En el mismo rato, la v12 con ruteo 0.12 bajó la **10 a 971.76**.

**Corrida por portafolio** (`solucion_13/portafolio.sh`, 13/11 18:25 – 14/11 05:07, 7 núcleos, 6 rondas de
3500 s). v12 (código de la v13 con `GLS_ALFA=0`) en la 04–10; en cada ronda cada instancia usa otra variante
(base, ruteo 0.12, visitas 0.04, bloques 0.06 + patada 0.3) y otra semilla.

| Inst | Antes | Después | Mejoras (ronda: variante) |
|---|---|---|---|
| 04 | 523.17 | **522.93** | 2: visitas |
| 05 | 590.66 | 590.66 | — |
| 06 | 747.83 | **747.69** | 2: base · 4: visitas |
| 07 | 891.72 | **891.68** | 2: ruteo |
| 08 | 1070.79 | **1070.77** | 2: visitas |
| 09 | 952.85 | **952.33** | 1: visitas · 2: bloques · 5: visitas |
| 10 | 971.76 | **971.63** | 2: base · 4: visitas · 5: bloques |

- **Visitas es la variante que más mejoras dio** (6 de 13), aunque en la v5–v12 su peso estaba en 0: las
  visitas intermedias a o y f no solo sirven en la 01. Los bloques dieron 2 mejoras chicas (09, 10).
- Rotar variantes da más que repetir la misma: con la misma cantidad de CPU, la corrida adaptativa
  v12/v11 de la noche anterior dejó de mejorar en la ronda 3–4.
- La 05 no se movió con ninguna variante.

### Análisis de la 08: los AGVs son el cuello de botella (14/11/2026)
El 13/11 a las 19:09 el líder (GHI) subió las 10 instancias en 2 minutos y bajó mucho donde manda el
transporte (08: 1065.64 → 1032.81; 10: 969.80 → 953.52). Para entender dónde se pierde, se midió cómo
usan su tiempo los AGVs en nuestra mejor 08 (1070.77; n = 155, 10 máquinas, K = 4, C = 2):

| Tiempo de los AGVs | s | % |
|---|---|---|
| Viajando con carga | 5031 | 63.4 |
| Viajando vacíos | 2822 | 35.6 |
| Esperando | 83 | 1.0 |

- Los AGVs están ocupados el **99 %** del tiempo, y las máquinas esperan abastecimiento 2199 s en total
  (13 % del tiempo de proceso). El transporte es el cuello de botella.
- De lo vacío, **2345 s son vueltas f → o** (67 de 35 s). Con C = 2 el ciclo típico es: cargar 2 en o →
  dejarlos → recoger 2 terminados → f → volver vacío. Las visitas intermedias a o (pasar por o con
  terminados a bordo) ahorran parte de esas vueltas, lo que explica por qué la variante de visitas fue
  la que más mejoró en el portafolio.
- **No todas las máquinas cuestan lo mismo en transporte:** o → α + β → f es 48–49 s en las máquinas 1–4,
  9 y 10, 66 s en la 5 y la 7, y **81 s en la 6 y la 8** (cerca de f, lejos de o). Les asignamos 57 de
  155 lotes a las máquinas 5–8.
- **Hipótesis:** con AGVs saturados, cada segundo de AGV retrasa a los lotes que vienen después, así que
  la asignación debería pesar el transporte mucho más de lo que lo pesa la del húngaro (que lo cuenta
  una vez por lote). Nuestras búsquedas parten de asignaciones pensadas para las máquinas y la tabú las
  ajusta de a un lote.

**Experimento** (`solucion_13/asig_transporte.jl`, `transporte08.sh`): asignación inicial por el método
húngaro con costo k·p_ij + BETA·(τ[o, α_j] + τ[β_j, f]) (variable `ASIG_BETA`, con `cero`), y v12 con
visitas desde ahí. Con BETA = 40 las máquinas 6 y 8 bajan de 13 y 21 a 4 y 8 lotes; con BETA = 80 quedan
vacías. Se comparan BETA = 0 (control), 20, 40 y 80, 1 hora cada una.

**Resultado del experimento con BETA (08, 1 h, BETA = 40):** 1223.94 → **1115.22**, muy peor que 1070.77.
Con el despacho de la v2, la asignación previa no ayuda: la diferencia la hace la regla de despacho (ver
la propuesta de abajo). Se cancelaron las corridas con BETA = 0, 20 y 80.

### Despacho por ciclos con asignación en línea (14/11/2026)
Detalle completo en `solucion_temporal/propuesta.md` y prototipo en `solucion_temporal/`.
- **Diagnóstico:** en nuestra 08 los viajes ya tienen buena forma (69 de 87 son 2 entregas + 2 retiros),
  pero las máquinas baratas para los AGVs (1–4, 9, 10; ciclo de 87 s por par de lotes) esperan
  abastecimiento 1154 s mientras los AGVs atienden a las caras (5–8; 119 s). Faltan AGVs: entregan ~8
  lotes por 100 s y las máquinas piden ~9.5, así que alguna máquina debe esperar; conviene que sean las
  lejanas.
- **Constructivo por ciclos:** decide el AGV. Cuando queda libre elige el ciclo (qué entregar y qué
  recoger) que más rinde por segundo de AGV, y el lote se asigna a su máquina recién al cargarlo en o.
- **Búsqueda en dos niveles:** primero sobre un "guion" de parámetros del constructivo por tramos
  (cambiar el tramo final reconstruye toda la cola), luego la tabú v12 con visitas sobre el plan.
- **Resultados del prototipo** (≈ 4 min, 1 núcleo, desde cero): **08 = 1029.04** (antes 1070.77; líder 1032.81)
  y **07 = 886.73** (antes 891.68). En 3 minutos la 10 (985.74) y la 06 (756.11) aún no alcanzan las nuestras.
  Ambas soluciones pasan nuestro validador y están en `mejores/`.
- Siguiente paso: correr el método completo (guion 120 s + tabú 3300 s) en la 10, 07, 06 y 08 con otras
  semillas (`solucion_temporal/corrida.sh`, `cola.sh`).
- **Primera corrida completa:** 10, semilla 7: guion 1020.72 → tabú (55 min)
  **963.16**, mejor que la nuestra (971.09). Validada y copiada a `mejores/`. Confirma el método en
  una instancia donde el prototipo no había llegado.
- **Cuatro corridas más** (guion 120 s + tabú 3300 s, 14/11 11:00–11:56), todas validadas:

  | Inst | Semilla | Guion | Tabú | Antes |
  |---|---|---|---|---|
  | 08 | 14 | 1046.98 | **1028.85** | 1029.04 |
  | 07 | 11 | 916.32 | **882.23** | 886.73 |
  | 07 | 12 | 916.13 | 885.30 | 886.73 |
  | 06 | 13 | 789.02 | 748.44 | 747.50 (no mejora) |

  Las mejoras se copiaron a `mejores/`. En la 07 y la 08 dos semillas distintas llegan a valores
  parecidos, así que el método es estable. En la 06 queda cerca pero no mejora.

#### Revisión de confiabilidad (14/11/2026)
- **Soluciones:** 07, 08 y 10 se revalidaron con el validador de `solucion_12/`, código independiente
  del prototipo: 0 errores, todos los lotes, mismos valores (886.7333, 1029.03956, 963.16253).
- **Diagnóstico recalculado** (`analiza` sobre la 08): coinciden los ciclos de 87/87/105/119 s, las esperas
  de las cercanas en la nueva (12, 19, 12, 19, 27, 27 = 116 s) y de las lejanas (2805 s), los 36 lotes
  en lejanas, el inicio medio (866.6), el makespan (2035) y los cuartiles. En la vieja 08 (1070.79,
  la del último commit) las cercanas esperan 1096 s (la propuesta midió 1154 s sobre la 1070.77; es otro archivo).
- **Matiz:** la "demanda de 9.5 lotes por 100 s" usa los tiempos de proceso de la solución
  (≈ 106 s por lote); con la máquina más rápida de cada lote serían ≈ 11. La conclusión (faltan AGVs)
  se mantiene en ambos casos.
- **Fuentes:** las 7 existen y los datos (autores, revista, volumen, páginas) son correctos. Uso de cada una:
  - Egbelu y Tanchoco [25] (despacho iniciado por el vehículo) y Storer, Wu y Vaccari [26] (buscar en el
    espacio de la heurística) son base directa del método.
  - Smith [27] (WSPT) es una **analogía**: el teorema es para una máquina, no para ciclos de AGV.
  - Bilge y Ulusoy [5] y Savelsbergh y Sol [29] son contexto.
  - Ruiz y Stützle (voraz iterado) y Duin y Voß [28] (piloto) son mejoras **no implementadas**.
- **Aporte propio** (no está en ningún paper): la fórmula de puntaje del ciclo, la asignación
  del lote al cargarlo en o y la combinación de los tres niveles.
- **Pendiente para el informe:** el prototipo tiene funciones de 30–40 líneas (hay que partirlas en ≤ 15
  líneas) y hay una sola semilla por instancia en las pruebas del prototipo.

**Conclusión para la 01–03.** Ya se probaron: más semillas, vecinos más lejanos (ventanas exactas,
destrucción del 30 %, path relinking), aceptar peores (recocido, tabú), otras asignaciones (Murty),
visitas y cambiar el paisaje (búsqueda local guiada). Todo vuelve a 326.66, 405.59 y 476.44. Es
probable que estén muy cerca de lo mejor que alcanzan estas representaciones; la diferencia con el
líder (0.06, 2.24 y 3.40) podría necesitar un modelo distinto (por ejemplo, otra forma de decidir los
tiempos de los AGVs), no otra metaheurística sobre el mismo.

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
  1 núcleo): 405.59 y 476.44, sin cambio. En la corrida larga de la 03 (2 rondas de 3500 s) y de
  la 09 (2 rondas), tampoco hay cambio: 476.44 y 958.59.

## ¿Cuál es el mejor modelo? (resumen al 13/11/2026)

**El mejor modelo en general es la solución 12** (`solucion_12/`): búsqueda tabú iterada sobre el plan
explícito de viajes de los AGVs, con las vecindades de ruteo entre AGVs de la v11. Encontró la mejor
solución actual de **7 de las 10 instancias** (04–10), y es la única versión que siguió mejorando en
las últimas corridas.

| Pieza | De qué versión viene | Por qué está |
|---|---|---|
| Representación: máquina y orden de cada lote + lista explícita de viajes por AGV, con visitas a o y f | v3 (+ visitas de la v4) | Decide las dos capas a la vez; el decodificador da los tiempos óptimos (camino más largo) para esos órdenes |
| Solución de partida | v2 (húngaro + despacho) → v4 (ALNS) | El ALNS lleva rápido a una buena zona; en la 01–03 sus soluciones siguen siendo las mejores |
| Búsqueda tabú con lista de candidatos, huellas por lote y aspiración | v5 | Salió de óptimos locales donde el ALNS se estancaba (07: 905.90 → 901.93) |
| Vecindades de ruteo (CROSS, 2-opt\*, cruzar colas) y elección guiada por retrasos | v11 | Las que más mejoraron en la 04–10 |
| Tramos cortos (2 %) y reinicios chicos desde la mejor | v12 | Los logs mostraron que las mejoras llegan justo después de reiniciar, y que los saltos grandes no sirven |

**Por grupo de instancias:**
- **01–03 (chicas):** las mejores siguen siendo las del **ALNS (v4)**. Desde ahí nada las mejoró:
  tabú con muchas semillas, ventanas exactas (v7), secuencia (v8), path relinking (v9), Murty (v10),
  v12 con visitas y búsqueda local guiada (v13).
- **04–10 (medianas y grandes):** **v12**, partiendo de la mejor guardada. Variantes útiles por
  variable de entorno: `PESOS_RUTEO=0.12` (10) y `PESOS_VISITA=0.04` (04).

**Lo que no funcionó** (para no repetirlo): patadas grandes de destrucción/reparación (v6), la
representación por secuencia (v8), path relinking (v9), alternar con la v11 (0 mejoras en 9 rondas de
instancia) y la búsqueda local guiada (v13: explora otras estructuras, pero ninguna es mejor).

**Cómo correrlo:** `cd solucion_12 && julia main.jl instancias/instancia_07.txt 3500 <semilla>` (parte de
`resultados/` y solo guarda si mejora). Para varias instancias en paralelo, `seguir.sh` o `dia.sh`.

## Mejores valores (14/11/2026)

Mejor solución factible de cada instancia (todas en `mejores/`). "Líder" es el mejor valor del
ranking de IO1Lab el 13/11 a las 19:11 (grupo GHI; ese día subió las 10 instancias en 2 minutos, con
saltos grandes en la 08 (−32.8) y la 10 (−16.3)). Recordatorio del enunciado: el puntaje va por **terciles**
entre todos los grupos (0.6 / 0.3 / 0 por instancia), no por el primer lugar.

| Inst | Mejor valor | Método | Líder IO1Lab (13/11) | Estado |
|---|---|---|---|---|
| 01 | 326.66 | v4 (ALNS) | 326.60 | falta 0.06 |
| 02 | 405.59 | v4 (ALNS sin visitas, 10 rondas, corrida de la compañera) | 403.35 | falta 2.24 |
| 03 | 476.44 | v3/v4 | 469.44 | falta 7.00 |
| 04 | 522.88 | v12 (portafolio, 14/11) | 520.47 | falta 2.41 |
| 05 | 590.66 | v12 (2 rondas de 3300 s, 12/11 tarde) | 588.60 | falta 2.06 |
| 06 | 747.50 | v12 con bloques (portafolio, 14/11) | 739.48 | falta 8.02 |
| 07 | 882.23 | despacho por ciclos + guion + tabú v12 (semilla 11) | 875.49 | falta 6.74 |
| 08 | 1028.85 | despacho por ciclos + guion + tabú v12 (semilla 14) | 1032.81 | **gana por 3.96** |
| 09 | 952.28 | v12 con visitas (portafolio, 14/11) | 951.60 | falta 0.68 |
| 10 | 963.16 | despacho por ciclos + guion + tabú 55 min (semilla 7) | 953.52 | falta 9.64 |

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
| 11 | [9], [10], [19], [20], [21] | [9]–[10]: tabú de la v5 · [19]: CROSS-exchange · [20]: 2-opt\* · [21]: elegir los movimientos en la parte crítica (aquí, los lotes más retrasados por el transporte) |
| 12 | [4], [13], [22], [23] | [22]: tabú iterada (tramos cortos + reinicio desde la mejor) · [4]: perturbaciones pequeñas de ILS · [13], [23]: vecindades grandes evaluadas dentro de la búsqueda (no saltos al azar) |
| 13 | [9], [10], [22], [24] | [24]: búsqueda local guiada (rasgos, utilidad, costo aumentado, λ) · [22]: tabú iterada de la v12 · [9]–[10]: tabú |
| Despacho por ciclos | [5], [25]–[29] | [25]: despacho iniciado por el vehículo · [26]: búsqueda sobre los parámetros de la heurística (guion) · [27]: orden WSPT (analogía) · [28]: método piloto (pendiente) · [29], [5]: contexto de recogida y entrega y del problema integrado · voraz iterado de Ruiz y Stützle (pendiente) |

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
19. Taillard, É., Badeau, P., Gendreau, M., Guertin, F. y Potvin, J.-Y. (1997). A tabu search heuristic for the vehicle routing problem with soft time windows. *Transportation Science*, 31(2), 170–186.
20. Potvin, J.-Y. y Rousseau, J.-M. (1995). An exchange heuristic for routeing problems with time windows. *Journal of the Operational Research Society*, 46(12), 1433–1446.
21. Nowicki, E. y Smutnicki, C. (1996). A fast taboo search algorithm for the job shop problem. *Management Science*, 42(6), 797–813.
22. Misevicius, A. (2005). A tabu search algorithm for the quadratic assignment problem. *Computational Optimization and Applications*, 30(1), 95–111.
23. Mladenović, N. y Hansen, P. (1997). Variable neighborhood search. *Computers & Operations Research*, 24(11), 1097–1100.
24. Voudouris, C. y Tsang, E. (1999). Guided local search and its application to the traveling salesman problem. *European Journal of Operational Research*, 113(2), 469–499.
25. Egbelu, P. J. y Tanchoco, J. M. A. (1984). Characterization of automatic guided vehicle dispatching rules. *International Journal of Production Research*, 22(3), 359–374.
26. Storer, R. H., Wu, S. D. y Vaccari, R. (1992). New search spaces for sequencing problems with application to job shop scheduling. *Management Science*, 38(10), 1495–1509.
27. Smith, W. E. (1956). Various optimizers for single-stage production. *Naval Research Logistics Quarterly*, 3(1–2), 59–66.
28. Duin, C. y Voß, S. (1999). The pilot method: a strategy for heuristic repetition with application to the Steiner problem in graphs. *Networks*, 34(3), 181–191.
29. Savelsbergh, M. W. P. y Sol, M. (1995). The general pickup and delivery problem. *Transportation Science*, 29(1), 17–29.

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
