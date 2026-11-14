# Propuesta — despacho por ciclos con asignación en línea (14/11/2026)

**Lo primero, porque es barato y ya está medido:** un constructivo nuevo (50 ms por solución) más 3 minutos
de la tabú v12 que ya tenemos da, desde cero y en un solo núcleo:

| Inst | Nuestra mejor | Líder | Constructivo v2 | Constructivo por ciclos | + guion de parámetros | + tabú v12 (170 s) |
|---|---|---|---|---|---|---|
| 08 | 1070.77 | 1032.81 | 1213.00 | 1064.22 (25 s al azar) | 1050.48 (75 s) | **1029.04** (desde 1050.48); 1044.85 (desde 1064.22) |
| 07 | 891.68 | 875.49 | 995.54 | 927.04 (25 s al azar) | 914.26 (75 s) | **886.73** (desde 914.26); 889.56 (desde 918.27) |
| 10 | 971.63 | 953.52 | — | 1016.87 (25 s al azar) | 1023.94 (75 s, solo 297 evaluaciones) | 985.74 (no mejora; solo 6807 iteraciones) |
| 06 | 747.52 | 739.48 | — | 789.76 (25 s al azar) | — | 756.11 (no mejora) |

- La **08 queda en 1029.04, por debajo del líder (1032.81)**, en unos 4 minutos de cómputo. La 07 baja de
  891.68 a 886.73. Las dos están validadas con `validar` (0 errores) y releídas con `leer_txt`.
- En la 10 y la 06 la prueba de 3 minutos **no** alcanza a nuestra mejor; la 10 seguía bajando cuando se
  acabó el tiempo. Ahí falta la corrida larga (ver plan).
- Es una sola semilla por caso: el tamaño del salto en la 08 (−41.7) no deja dudas, el de la 07 (−4.95)
  conviene repetirlo.
- Archivos: soluciones en `solucion_temporal/soluciones/` (y copiadas a `mejores/`); prototipo:
  `proto.jl` (constructivo), `t3.jl` (búsqueda al azar), `t6.jl` (guion). El constructivo completo está en el anexo.

## 1. Diagnóstico

### 1.1 La geometría manda: hay máquinas baratas y caras para los AGVs
En la 06–10 la planta es la misma (crece el número de máquinas): o y f están a 35 s, y las máquinas forman
dos ramas simétricas. Datos de la 08 (s):

| Máquinas | o → α | β → f | Ciclo de 2 lotes con la vecina | s de AGV por lote |
|---|---|---|---|---|
| 1, 2 (y 3, 4) | 12 / 19 | 37 / 29 | o→α1→β1→α2→β2→f→o = 12+3+5+3+29+35 = **87** | 43.5 |
| 2, 9 (y 4, 10) | 19 / 27 | 29 / 22 | o→α2→β2→α9→β9→f→o = **87** | 43.5 |
| 9, 5 (mixto) | 27 / 49 | 22 / 17 | **105** | 52.5 |
| 5, 6 (y 7, 8) | 49 / 57 | 17 / 24 | o→α5→β5→α6→β6→f→o = **119** | 59.5 |

- Los viajes ya tienen la forma correcta: en nuestra mejor 08, 69 de 87 viajes son (2 entregas, 2 retiros)
  y el número de pasadas por o (78) es el mínimo posible (n/C). La vuelta f→o (29.5 % del tiempo de AGV)
  **no se puede evitar**: cada pasada por f descarga a lo más C lotes. Lo que sí se elige es **a qué
  máquinas** va cada ciclo.
- Balance de flujo en la 08: las 10 máquinas piden 1 lote cada ~105 s (9.5 lotes por 100 s); 4 AGVs con
  ciclos de ~100 s entregan 8 por 100 s. **Sobran máquinas, faltan AGVs**: alguna máquina tiene que
  esperar. La pregunta es cuál.
- Cuenta fluida: tener siempre llenas las 6 máquinas cercanas (1–4, 9, 10) cuesta 2.5 AGVs (ciclos de
  87 s). Los 1.5 AGVs restantes alcanzan para tener las 4 lejanas (5–8) al 67 %.

### 1.2 Dónde se pierde en nuestra mejor 08 (1070.77)
Reparte la escasez de transporte **entre todas** las máquinas, también las baratas:

| | Espera de abastecimiento, máquinas cercanas (1–4, 9, 10) | Lejanas (5–8) | Lotes en lejanas | Inicio medio de proceso | Makespan | s de AGV por lote |
|---|---|---|---|---|---|---|
| Nuestra mejor (1070.77) | 163, 43, 47, 309, 247, 345 = **1154 s** | 1046 s | 57 | 911.1 | 2032 | 51.2 |
| Nueva (1029.04) | 12, 19, 12, 19, 27, 27 = **116 s** | 2805 s | 36 | 866.6 | 2035 | 51.6 |

- El makespan y el trabajo total de los AGVs son **iguales**. La diferencia de 42 está en el **orden**: la
  nueva termina más lotes temprano (cuartil 25 % de c: 507 contra 575; mediana 1019 contra 1057).
- Es la regla de Smith (WSPT) aplicada al recurso cuello de botella: si cada ciclo de AGV es un "trabajo"
  que termina 2 lotes, conviene hacer primero los ciclos cortos (87 s) y dejar los largos (119 s) para
  cuando sobre AGV. Una máquina cercana parada es un ciclo barato desperdiciado.
- La 07 y la 10 ya tenían las cercanas casi sin espera (07: 13–46 s; 10: 12–28 s). Por eso ahí nos falta
  menos que en la 08, y lo que queda está en el arranque y en qué tipo de lote va a cada máquina.

### 1.3 Por qué la tabú no lo encuentra sola
- Las búsquedas parten de una asignación pensada para las máquinas (húngaro de R‖ΣC) y un despacho que
  atiende a la máquina más urgente. Pasar de "todas esperan un poco" a "las cercanas nunca, las lejanas
  mucho" exige reasignar unos 20 lotes y rehacer sus viajes: cientos de movimientos de un lote, casi todos
  peores en el camino (lo mismo que se vio con los bloques y con la 07 desde cero: 914).
- Cambiar solo la asignación no basta. Medí la inicial con `ASIG_BETA` y el despacho de la v2 en la 08:
  BETA = 20 → 1336.85; BETA = 40 → 1223.94; constructiva v2 → 1213.00. El constructivo por ciclos da
  1064.22. La diferencia la hace **la regla de despacho**, no la asignación previa.

## 2. Heurística propuesta (solución 14)

### 2.1 Idea
Invertir el orden de las decisiones. Hoy: asignar lotes a máquinas → decidir viajes. Propuesta: **el AGV
decide**. Cada vez que un AGV queda libre elige el ciclo (qué máquinas abastece, en qué orden, qué recoge)
que más rinde por segundo de AGV, y **recién al cargar en o** se decide qué lote va a cada máquina. La
asignación lote–máquina sale del transporte, no al revés. Es un despacho iniciado por el vehículo (Egbelu y
Tanchoco, 1984) con asignación en línea.

### 2.2 Constructivo por ciclos (solución inicial)
Simulación por eventos; siempre decide el AGV que queda libre antes.
1. **Candidatos:** todas las tuplas ordenadas de 0 a C máquinas distintas (con C = 3, solo ternas de
   máquinas vecinas: τ(β, α) ≤ 25 s). Tupla vacía = viaje solo de retiro.
2. **Simular el ciclo:** ir a o, cargar un lote por máquina de la tupla; en cada máquina, dejar el lote en
   α (esperando si el buffer sigue ocupado) y recoger el de β si estará listo a lo más H segundos después
   de llegar; si queda capacidad, retiros extra con desvío ≤ D; ir a f y volver a o.
3. **Lote para la máquina j:** el lote libre compatible que minimiza
   (p_ij / p_i^mín)^ρ · p_ij · W[j, tipo]: SPT, castigando las máquinas lentas para ese lote.
4. **Puntaje del ciclo** (se elige el mayor):
   (Σ_entregas B_j / (1 + w_j/θ) + w_p · retiros) / (duración + ψ · espera del AGV),
   con w_j = tiempo que el lote va a quedar en α antes de empezar. Así una entrega a una máquina parada
   vale 1 y una entrega adelantada vale menos; ψ castiga que el AGV espere; las cercanas ganan por duración.
5. El resultado se convierte al plan explícito (`seq`, `plan`) y se evalúa con `decodificar`, que solo
   puede adelantar tiempos. Fue factible en todas las pruebas (el AGV nunca entrega si no conoce cuándo se
   libera α).

Parámetros: ψ, ρ, H, θ, w_p, D (globales), B_j (por máquina) y W[j, tipo].

### 2.3 Búsqueda local, nivel 1: sobre el guion de parámetros
- **Representación indirecta:** un *guion* = un juego de parámetros para cada decisión de despacho (la
  decisión número 1, 2, …). El constructivo es el decodificador. Es búsqueda en el espacio de la heurística
  (Storer, Wu y Vaccari, 1992).
- **Vecindad:** elegir un punto m del guion y un tramo [m, m₂] (hasta el final la mitad de las veces),
  y perturbar ahí 1–3 parámetros (factor log-normal). Cambiar el tramo final equivale a **conservar el
  prefijo de la solución y reconstruir toda la cola**: el movimiento de bloque que le falta a la tabú.
- **Aceptación:** mejor o igual (escalada estocástica). En el prototipo, 75 s dejan la 08 en 1050.48
  (25 s de parámetros al azar, sin tramos, daban 1064.22).
- **Diversificación:** varias semillas dan guiones y asignaciones distintas (arranques para el nivel 2).

### 2.4 Búsqueda local, nivel 2: tabú v12 sobre el plan explícito
Sin cambios: `GLS_ALFA=0 PESOS_VISITA=0.04`, desde la solución del nivel 1. Pule lo que el despacho no ve
(visitas a o y f, cruces entre AGVs, la cola). En la 08 saca 21 puntos en 170 s.

### 2.5 Nivel 3 (después): voraz iterado sobre la cola
Destruir desde un instante T (se conserva todo viaje iniciado antes de T), reconstruir con el constructivo
con parámetros perturbados y pulir con tabú corta; aceptar si mejora (*iterated greedy*, Ruiz y Stützle,
2007). Necesita cargar un plan explícito cualquiera en el estado del constructivo; por eso va al final.

### 2.6 Por qué debería cerrar la diferencia
- Ataca la causa medida (ciclos baratos desperdiciados), no la vecindad.
- Ya pasó al líder en la 08 y a nuestra mejor en la 07 con un prototipo sin afinar.
- El salto del líder del 13/11 (grande en 08 y 10, casi nulo en 01 y 09) es compatible con un cambio de
  este tipo. Es una conjetura: no sé qué hizo.

## 3. Plan de implementación

| Paso | Qué | Dónde | Tiempo |
|---|---|---|---|
| 0 | Validar en IO1Lab y copiar a `mejores/` la 08 (1029.04) y la 07 (886.73) | archivos de arriba | 10 min |
| 1 | `solucion_14/` = copia de `solucion_13/` + `ciclos.jl` (constructivo) + `guion.jl` (nivel 1) | del anexo, partido en funciones de ≤ 15 líneas | 2–3 h |
| 2 | `main.jl`: argumento `ciclos` → nivel 1 (S₁ s) → tabú (resto) → guarda si mejora | `solucion_inicial_plan` | 30 min |
| 3 | Corrida: 06, 07, 08, 10 (y 09), 4 semillas del nivel 1 de 120 s; tabú de 1 h desde las 2 mejores | `ciclos.sh`, copia por tarea como `transporte08.sh` | 1 noche |
| 4 | Mejoras del constructivo (abajo) | `ciclos.jl` | según resultados |
| 5 | Nivel 3 | `cola.jl` | si queda tiempo |

Funciones de `ciclos.jl` (cada una corta): `propaga!`, `alfa_libre`, `listo_retiro`, `entrega!`, `retira!`,
`elige_lote`, `lotes_de_tupla`, `visitar_maquina!`, `retiro_extra!`, `ciclo`, `puntaje`, `mejor_ciclo`,
`tuplas`, `construir`. `guion.jl`: `vecino_parametros`, `vecino_guion`, `escalar_guion`.

**Mejoras del constructivo, por orden de valor esperado** (vistas en las soluciones del prototipo):
1. **Cola:** el constructivo solo termina con makespan 2258 en la 08 (la tabú lo baja a 2035) y hace 13–17
   viajes de un solo retiro. Al final faltan reglas: juntar retiros, no volver a o si no quedan lotes.
2. **Reserva de tipos:** en la 07 la máquina 5 (solo tipo 1, la más rápida) se queda sin lotes en 1287 s
   porque las cercanas se los comen. Guardar para cada máquina de un solo tipo su cuota.
3. **Velocidad con C = 3:** 0.25 s por construcción en la 10 (297 evaluaciones en 75 s contra 1673 en la
   08). Copiar solo las máquinas tocadas ya se hace; falta podar ternas y no recalcular lotes.
4. **Visitas a o y f dentro del ciclo** (hoy solo las pone la tabú).
5. **Mirar un paso adelante** (método piloto, Duin y Voß, 1999) en vez del puntaje miope.

## 4. Qué esperar y cómo medirlo
- **08:** ≤ 1029 ya; con 1 h de tabú y varias semillas, 1015–1025.
- **07:** 886.73 ya; objetivo < 880 (líder 875.49). Depende de la mejora 2.
- **10 y 06:** en 3 min quedan a 14 y 9 de nuestra mejor. Objetivo: igualarla en 1 h; si no, no se usa ahí.
- **09 y 01–05:** no esperar nada; el constructivo solo queda 3–6 % arriba (03: 503.24; 04: 541.58;
  05: 616.71; 09: 1014.87) y ahí el transporte no manda igual.
- **Medición:** misma tabla que arriba por instancia y semilla: valor del constructivo, tras el nivel 1,
  tras 170 s y tras 1 h de tabú; control = v12 desde `mejores/` con la misma hora. Mirar además la espera
  de abastecimiento de las máquinas cercanas (debe quedar en 12–27 s por máquina).

## 5. Riesgos
- **Una semilla por caso.** La 08 es concluyente; la 07, la 06 y la 10 hay que repetirlas.
- **El valle nuevo puede estancarse** encima del actual en la 06 y la 10, como en "07 desde cero". Se
  conserva siempre `mejores/`.
- **Muchos parámetros** (unos 35 por tramo en la 08). No es sobreajuste (cada instancia se resuelve sola), pero en
  el informe hay que presentarlo como búsqueda local sobre los parámetros del despacho.
- **Reglas del curso:** el prototipo tiene funciones de 30–40 líneas; hay que partirlas. No usa solvers.
- **El líder puede seguir bajando;** el puntaje es por terciles, así que la 08 y la 07 ya suman.

## Fuentes
- Egbelu, P. J. y Tanchoco, J. M. A. (1984). Characterization of automatic guided vehicle dispatching rules. *International Journal of Production Research*, 22(3), 359–374.
- Bilge, Ü. y Ulusoy, G. (1995). A time window approach to simultaneous scheduling of machines and material handling system in an FMS. *Operations Research*, 43(6), 1058–1070.
- Smith, W. E. (1956). Various optimizers for single-stage production. *Naval Research Logistics Quarterly*, 3, 59–66.
- Storer, R. H., Wu, S. D. y Vaccari, R. (1992). New search spaces for sequencing problems with application to job shop scheduling. *Management Science*, 38(10), 1495–1509.
- Ruiz, R. y Stützle, T. (2007). A simple and effective iterated greedy algorithm for the permutation flowshop scheduling problem. *European Journal of Operational Research*, 177(3), 2033–2049.
- Duin, C. y Voß, S. (1999). The pilot method: a strategy for heuristic repetition with application to the Steiner problem in graphs. *Networks*, 34(3), 181–191.
- Savelsbergh, M. W. P. y Sol, M. (1995). The general pickup and delivery problem. *Transportation Science*, 29(1), 17–29.

## Resumen en 5 líneas
1. En la 08 perdíamos por dejar esperar a las máquinas baratas para los AGVs (1154 s), no por los viajes.
2. Propuesta: el AGV elige el ciclo que más rinde por segundo y el lote se asigna al cargar en o.
3. Encima, búsqueda local sobre un guion de parámetros por tramos y luego la tabú v12 de siempre.
4. Medido desde cero en ~4 min y 1 núcleo: 08 = 1029.04 (líder 1032.81), 07 = 886.73 (nuestra 891.68).
5. En la 06 y la 10 aún no alcanza a nuestra mejor en 3 min; falta la corrida larga y afinar la cola.

## Anexo: prototipo del constructivo (`proto.jl`)
Usa `datos.jl`, `simulador.jl`, `plan.jl` de la solución 13. Parámetros de partida usados en las pruebas:
`Par(psi = 3.0, rho = 2.0, H = 3.0, theta = 70.0, wp = 1.0, D = 0.0)`, `W` y `B` en 1.

```julia
mutable struct Maq
    lotes::Vector{Int}; lleg::Vector{Float64}; ini::Vector{Float64}; fin::Vector{Float64}
    sal::Vector{Float64}; rec::Vector{Float64}; nrec::Int
end
Maq() = Maq(Int[], Float64[], Float64[], Float64[], Float64[], Float64[], 0)
copia(m::Maq) = Maq(copy(m.lotes), copy(m.lleg), copy(m.ini), copy(m.fin), copy(m.sal), copy(m.rec), m.nrec)
function propaga!(m, ins, j)
    for k in eachindex(m.lotes)
        if isnan(m.ini[k])
            prev = k == 1 ? 0.0 : m.sal[k-1]
            isnan(prev) && break
            m.ini[k] = max(m.lleg[k], prev); m.fin[k] = m.ini[k] + tiempo_proceso(ins, m.lotes[k], j)
        end
        if isnan(m.sal[k])
            prev = k == 1 ? 0.0 : m.rec[k-1]
            isnan(prev) || (m.sal[k] = max(m.fin[k], prev))
        end
    end
end
alfa_libre(m) = isempty(m.lotes) ? 0.0 : m.ini[end]
listo_retiro(m) = m.nrec + 1 > length(m.lotes) ? NaN : m.sal[m.nrec+1]
function entrega!(m, ins, j, i, t)
    push!(m.lotes, i); push!(m.lleg, t); foreach(v -> push!(v, NaN), (m.ini, m.fin, m.sal, m.rec)); propaga!(m, ins, j)
end
function retira!(m, ins, j, t)
    m.nrec += 1; m.rec[m.nrec] = t; propaga!(m, ins, j); return m.lotes[m.nrec]
end
Base.@kwdef mutable struct Par
    H::Float64 = 8.0      # espera máxima en beta para recoger
    D::Float64 = 12.0     # desvío máximo para un retiro extra
    rho::Float64 = 2.0    # castigo a procesar un lote en una máquina lenta para él
    wp::Float64 = 1.0     # valor de un retiro frente a una entrega
    psi::Float64 = 3.0    # castigo extra por segundo de espera del AGV
    spt::Float64 = 1.0    # peso del tamaño del lote al elegir
    theta::Float64 = 1e9  # una entrega vale menos si el lote va a esperar en alfa
    ruido::Float64 = 0.0
    W::Matrix{Float64} = ones(0, 0)   # preferencia máquina-tipo (multiplica la clave del lote)
    B::Vector{Float64} = Float64[]    # valor de abastecer cada máquina
end
# mejor lote libre para la máquina j
function elige_lote(ins, j, libres, usados, par, pmin)
    mejor, val = 0, Inf
    for i in libres
        (i in usados || !compatible(ins, i, j)) && continue
        p = tiempo_proceso(ins, i, j)
        v = (p / pmin[i])^par.rho * (par.spt * p + (1 - par.spt) * 100) * (1 + par.ruido * rand()) * (isempty(par.W) ? 1.0 : par.W[j, ins.r[i]])
        v < val && ((mejor, val) = (i, v))
    end
    return mejor
end
# simula un ciclo desde (pos, t): entrega en las máquinas de tupla, recoge lo que haya; devuelve todo
function ciclo(ins, M, libres, pos, t, tupla, par, pmin)
    Mc = Dict{Int,Maq}(); paradas = Parada[]; usados = Int[]; np = 0; t0 = t; esp = 0.0; vd = 0.0
    maq(j) = get!(() -> copia(M[j]), Mc, j)
    lotes = Int[]
    for j in tupla
        i = elige_lote(ins, j, libres, lotes, par, pmin); i == 0 && return nothing
        push!(lotes, i)
    end
    isempty(tupla) || (t += ins.tau[pos, 1]; pos = 1)
    for (j, i) in zip(tupla, lotes)
        m = maq(j); al = alfa_libre(m); isnan(al) && return nothing
        lle = t + ins.tau[pos, pos_alfa(ins, j)]; esp += max(0.0, al - lle); t = max(lle, al); pos = pos_alfa(ins, j)
        w = length(m.lotes) == 0 ? 0.0 : max(0.0, m.fin[end] - t)
        vd += (isempty(par.B) ? 1.0 : par.B[j]) / (1 + w / par.theta)
        entrega!(m, ins, j, i, t); push!(paradas, Parada(true, i))
        lr = listo_retiro(m)
        if !isnan(lr) && lr <= t + ins.tau[pos, pos_beta(ins, j)] + par.H
            lle = t + ins.tau[pos, pos_beta(ins, j)]; esp += max(0.0, lr - lle); t = max(lle, lr); pos = pos_beta(ins, j)
            push!(paradas, Parada(false, retira!(m, ins, j, t))); np += 1
        end
    end
    while np < ins.C     # retiros extra
        best, bt = 0, Inf
        for j in 1:num_maquinas(ins)
            m = haskey(Mc, j) ? Mc[j] : M[j]; lr = listo_retiro(m); isnan(lr) && continue
            tj = max(t + ins.tau[pos, pos_beta(ins, j)], lr)
            extra = tj + ins.tau[pos_beta(ins, j), pos_f(ins)] - (t + ins.tau[pos, pos_f(ins)])
            (np > 0 || !isempty(tupla)) && extra > par.D && continue
            tj < bt && ((best, bt) = (j, tj))
        end
        best == 0 && break
        esp += max(0.0, bt - t - ins.tau[pos, pos_beta(ins, best)]); t = bt; pos = pos_beta(ins, best); push!(paradas, Parada(false, retira!(maq(best), ins, best, t))); np += 1
    end
    (isempty(tupla) && np == 0) && return nothing
    np > 0 && (t += ins.tau[pos, pos_f(ins)]; pos = pos_f(ins))
    return (Mc = Mc, paradas = paradas, lotes = lotes, np = np, t = t, pos = pos, esp = esp, vd = vd)
end
function tuplas(ins, J, C)
    T = [Int[]]
    for a in 1:J; push!(T, [a]); end
    for a in 1:J, b in 1:J; a != b && push!(T, [a, b]); end
    if C >= 3
        for a in 1:J, b in 1:J, c in 1:J
            (a != b && b != c && a != c) || continue
            ins.tau[pos_beta(ins, a), pos_alfa(ins, b)] <= 25 && ins.tau[pos_beta(ins, b), pos_alfa(ins, c)] <= 25 && push!(T, [a, b, c])
        end
    end
    return T
end
construir(ins, par::Par) = construir(ins, [par])
function construir(ins, guion::Vector{Par})
    J, n = num_maquinas(ins), num_lotes(ins)
    pmin = [minimum(tiempo_proceso(ins, i, j) for j in maquinas_compatibles(ins, i)) for i in 1:n]
    M = [Maq() for _ in 1:J]; libres = Set(1:n); T = tuplas(ins, J, ins.C)
    tA = zeros(ins.K); posA = fill(1, ins.K); plan = [Viaje[] for _ in 1:ins.K]; hechos = 0
    dec = 0
    while hechos < n
        dec += 1; par = guion[min(dec, end)]
        a = argmin(tA); mejor, mv = nothing, -Inf
        for tup in T
            (length(tup) > length(libres)) && continue
            r = ciclo(ins, M, libres, posA[a], tA[a], tup, par, pmin); r === nothing && continue
            quedan = length(libres) - length(r.lotes)
            dur = r.t - tA[a] + (quedan > 0 && r.pos == pos_f(ins) ? ins.tau[pos_f(ins), 1] : 0.0)
            v = (r.vd + par.wp * r.np) / max(dur + par.psi * r.esp, 1e-6)
            v > mv && ((mejor, mv) = (r, v))
        end
        mejor === nothing && error("sin candidatos")
        for (j, m) in mejor.Mc; M[j] = m; end
        setdiff!(libres, mejor.lotes); hechos += mejor.np
        push!(plan[a], mejor.paradas); tA[a] = mejor.t; posA[a] = mejor.pos
    end
    return [m.lotes for m in M], plan
end
```
