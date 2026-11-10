# ============================================================
# alns.jl — Búsqueda de vecindario grande adaptativa (ALNS) + pulido local
# ============================================================
# Esquema de Ropke y Pisinger (2006), aplicado como en Yin y Hu (2026)
# (ALNS con aceptación de recocido sobre un problema integrado de
# máquinas, vehículos y buffers limitados). En cada iteración:
#   1. Se elige un operador de destrucción y uno de reparación por ruleta
#      (pesos adaptativos, uno para cada familia).
#   2. Se sacan q lotes y se reinsertan (vecindad GRANDE: cambia a la vez
#      máquina, orden y viajes de varios lotes; los movimientos pequeños de
#      la solución 3 no pueden salir de esos óptimos locales).
#   3. Pulido: descenso aleatorio corto con las vecindades pequeñas de la
#      solución 3 (intensificación alrededor de la nueva solución).
#   4. Aceptación tipo recocido simulado (Metropolis).
#   5. Premio a los operadores: 33 si da nueva mejor, 9 si mejora la
#      actual, 13 si es aceptada sin mejorar (valores de Ropke y Pisinger).
# Diversificación: conjunto élite con las mejores soluciones distintas.
# Si la mejor no mejora en una fracción ESTANCAMIENTO_ALNS del tiempo, se
# reinicia: desde una asignación húngara perturbada (arranques.jl) o desde
# una solución élite al azar con una destrucción doble.

const SIGMA_MEJOR, SIGMA_MEJORA, SIGMA_ACEPTA = 33.0, 9.0, 13.0
const SEGMENTO_ALNS, TAM_ELITE, ESTANCAMIENTO_ALNS = 25, 6, 0.08
const Q_MIN, FRACCION_Q, Q_TOPE = 2, 0.3, 30
const ITER_PULIDO = 300
# Probabilidad de cada vecindad pequeña en el pulido; se fijaron según
# los pesos que aprendió la solución 3 (intercambiar lotes y dividir viaje
# fueron las que más mejoraron) más un 15 % para las vecindades de visitas
const PESOS_PULIDO = [0.05, 0.05, 0.10, 0.20, 0.05, 0.35, 0.05, 0.06, 0.04, 0.05]

const Solucion = Tuple{Vector{Vector{Int}},Plan,Float64}

mutable struct EstadoALNS
    actual::Solucion
    mejor::Solucion
    elite::Vector{Solucion}
    destruir::Adaptativo
    reparar::Adaptativo
    iter::Int
    t_mejora::Float64
    reinicios::Int
end

function EstadoALNS(ins, seq, plan)
    sol = (seq, plan, evaluar_plan(ins, seq, plan))
    return EstadoALNS(sol, sol, [sol], Adaptativo(length(DESTRUCCION)),
                      Adaptativo(length(REPARACION)), 0, time(), 0)
end

q_max(ins) = clamp(round(Int, FRACCION_Q * num_lotes(ins)), 4, Q_TOPE)
# Sesgado a destrucciones chicas (baratas, intensifican) pero con
# destrucciones grandes de vez en cuando (hasta 30 % de los lotes, como
# en Ropke y Pisinger) para escapar de óptimos locales profundos
tamano_destruccion(ins, rng) = Q_MIN + floor(Int, rand(rng)^2 * (q_max(ins) - Q_MIN + 1))

# --- Pulido local ------------------------------------------------

function vecindad_ponderada(rng)
    r, acumulado = rand(rng) * sum(PESOS_PULIDO), 0.0
    for (k, w) in enumerate(PESOS_PULIDO)
        (acumulado += w) >= r && return VECINDADES[k]
    end
    return VECINDADES[end]
end

function pulir(ins, sol, rng)
    seq, plan, val = sol
    isfinite(val) || return sol
    for _ in 1:ITER_PULIDO
        s2, p2 = vecindad_ponderada(rng)(ins, seq, plan, rng)
        v2 = evaluar_plan(ins, s2, p2)
        v2 < val - 1e-9 && ((seq, plan, val) = (s2, p2, v2))
    end
    return seq, plan, val
end

# --- Destruir + reparar + pulir ----------------------------------

function destruir_y_reparar(ins, sol, d, r, q, rng)
    seq, plan, _ = sol
    e, _ = decodificar(ins, seq, plan)
    lotes = DESTRUCCION[d](ins, seq, plan, e, q, rng)
    s, p, ref = quitar_lotes(seq, plan, lotes)
    s, p, ok = REPARACION[r](ins, s, p, lotes, ref, rng)
    return ok ? (s, p, evaluar_plan(ins, s, p)) : (s, p, Inf)
end

# --- Conjunto élite (soluciones distintas para reiniciar) ---------

function actualizar_elite!(st, cand)
    isfinite(cand[3]) || return
    any(abs(s[3] - cand[3]) < 1e-6 for s in st.elite) && return
    push!(st.elite, cand)
    sort!(st.elite, by = last)
    length(st.elite) > TAM_ELITE && pop!(st.elite)
end

# --- Aceptación y premios -----------------------------------------

function puntaje(v2, val, mejor, aceptado)
    v2 < mejor - 1e-9 && return SIGMA_MEJOR
    v2 < val - 1e-9 && return SIGMA_MEJORA
    return aceptado && abs(v2 - val) > 1e-9 ? SIGMA_ACEPTA : 0.0
end

function registrar!(st, cand, temp, rng)
    v2, val = cand[3], st.actual[3]
    aceptado = isfinite(v2) && aceptar_vecino(v2, val, temp, rng)
    p = isfinite(v2) ? puntaje(v2, val, st.mejor[3], aceptado) : 0.0
    aceptado && (st.actual = cand)
    v2 < st.mejor[3] - 1e-9 && (st.mejor = cand; st.t_mejora = time())
    actualizar_elite!(st, cand)
    return p
end

function premiar!(ad, k, p)
    ad.puntos[k] += p
    ad.usos[k] += 1
end

function iteracion_alns!(st, ins, temp, rng)
    d, r = ruleta(st.destruir, rng), ruleta(st.reparar, rng)
    cand = destruir_y_reparar(ins, st.actual, d, r, tamano_destruccion(ins, rng), rng)
    p = registrar!(st, pulir(ins, cand, rng), temp, rng)
    premiar!(st.destruir, d, p)
    premiar!(st.reparar, r, p)
end

# --- Diversificación: reinicios -----------------------------------
# Con probabilidad P_ARRANQUE_NUEVO se parte de una asignación húngara
# perturbada (otra región del espacio, ver arranques.jl); si no, de una
# solución élite al azar con una destrucción del doble de tamaño.

const P_ARRANQUE_NUEVO, FRACCION_ARRANQUE = 0.5, 0.02

function reinicio_elite(st, ins, rng)
    base = rand(rng, st.elite)
    d, r = rand(rng, eachindex(DESTRUCCION)), rand(rng, eachindex(REPARACION))
    cand = destruir_y_reparar(ins, base, d, r, 2 * q_max(ins), rng)
    return isfinite(cand[3]) ? pulir(ins, cand, rng) : base
end

function reiniciar!(st, ins, rng, segundos)
    nuevo = rand(rng) < P_ARRANQUE_NUEVO
    st.actual = nuevo ? arranque_hungaro(ins, rng, FRACCION_ARRANQUE * segundos) : reinicio_elite(st, ins, rng)
    st.actual[3] < st.mejor[3] - 1e-9 && (st.mejor = st.actual)
    actualizar_elite!(st, st.actual)
    st.t_mejora, st.reinicios = time(), st.reinicios + 1
end

function fin_de_segmento_alns!(st, ins, rng, segundos, fin, mostrar)
    (st.iter += 1) % SEGMENTO_ALNS == 0 || return
    actualizar_pesos!(st.destruir)
    actualizar_pesos!(st.reparar)
    estancado = time() - st.t_mejora > ESTANCAMIENTO_ALNS * segundos
    estancado && fin - time() > 0.1 * segundos && reiniciar!(st, ins, rng, segundos)
    mostrar && st.iter % (40 * SEGMENTO_ALNS) == 0 &&
        println("  ALNS iter $(st.iter): mejor ", round(st.mejor[3], digits = 2),
                "  actual ", round(st.actual[3], digits = 2))
end

# Temperatura inicial: una solución 0.5 % peor se acepta con prob. 0.5
function alns(ins, seq, plan, segundos; semilla = 1, mostrar = true)
    rng, inicio, fin = MersenneTwister(semilla), time(), time() + segundos
    st = EstadoALNS(ins, seq, plan)
    t0 = 0.005 * st.mejor[3] / log(2)
    while time() < fin
        temp = temperatura(t0, t0 / 200, (time() - inicio) / segundos)
        iteracion_alns!(st, ins, temp, rng)
        fin_de_segmento_alns!(st, ins, rng, segundos, fin, mostrar)
    end
    return st
end
