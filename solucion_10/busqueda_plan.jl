# ============================================================
# busqueda_plan.jl — Recocido simulado con selección adaptativa de vecindades
# ============================================================
# En cada paso se elige una vecindad por ruleta según su peso, se genera
# un vecino aleatorio y se acepta con el criterio de Metropolis.
# Los pesos se actualizan por segmentos según el éxito reciente de cada
# vecindad (esquema adaptativo de Ropke y Pisinger, 2006): las que más
# mejoran se usan más. Si la solución actual se aleja demasiado de la
# mejor, se vuelve a la mejor (intensificación).

using Random

const PREMIO_MEJOR, PREMIO_MEJORA, PREMIO_ACEPTA = 5.0, 2.0, 0.5
const LARGO_SEGMENTO, REACCION = 300, 0.2

mutable struct Adaptativo
    pesos::Vector{Float64}
    puntos::Vector{Float64}
    usos::Vector{Int}
end

Adaptativo(n) = Adaptativo(ones(n), zeros(n), zeros(Int, n))

function ruleta(ad, rng)
    r, acumulado = rand(rng) * sum(ad.pesos), 0.0
    for (k, w) in enumerate(ad.pesos)
        (acumulado += w) >= r && return k
    end
    return length(ad.pesos)
end

function actualizar_pesos!(ad)
    for k in eachindex(ad.pesos)
        ad.usos[k] == 0 && continue
        ad.pesos[k] = (1 - REACCION) * ad.pesos[k] + REACCION * ad.puntos[k] / ad.usos[k]
        ad.pesos[k] = max(ad.pesos[k], 0.05)    # ninguna vecindad desaparece
    end
    fill!(ad.puntos, 0.0); fill!(ad.usos, 0)
end

aceptar_vecino(nuevo, actual, temp, rng) = nuevo < actual || rand(rng) < exp((actual - nuevo) / temp)

function premio(v2, val, mejor, aceptado)
    v2 < mejor - 1e-9 && return PREMIO_MEJOR
    v2 < val - 1e-9 && return PREMIO_MEJORA
    return aceptado ? PREMIO_ACEPTA : 0.0
end

mutable struct Busqueda
    actual::Tuple{Vector{Vector{Int}},Plan,Float64}
    mejor::Tuple{Vector{Vector{Int}},Plan,Float64}
    ad::Adaptativo
    iter::Int
    t_mejora::Float64    # instante de la última mejora de la mejor solución
    t_ciclo::Float64     # inicio del ciclo de enfriamiento actual
    patadas::Int         # perturbaciones fuertes aplicadas
end

function Busqueda(seq, plan, val)
    t = time()
    return Busqueda((seq, plan, val), (seq, plan, val), Adaptativo(length(VECINDADES)), 0, t, t, 0)
end

# Un paso: vecino aleatorio, aceptación y premio a la vecindad usada
function paso_busqueda!(b, ins, temp, rng)
    seq, plan, val = b.actual
    k = ruleta(b.ad, rng)
    s2, p2 = VECINDADES[k](ins, seq, plan, rng)
    v2 = evaluar_plan(ins, s2, p2)
    aceptado = isfinite(v2) && aceptar_vecino(v2, val, temp, rng)
    b.ad.puntos[k] += premio(v2, val, b.mejor[3], aceptado)
    b.ad.usos[k] += 1
    aceptado && (b.actual = (s2, p2, v2))
    v2 < b.mejor[3] - 1e-9 && (b.mejor = (s2, p2, v2); b.t_mejora = time())
end

function fin_de_segmento!(b, mostrar)
    actualizar_pesos!(b.ad)
    b.actual[3] > 1.02 * b.mejor[3] && (b.actual = b.mejor)   # vuelve a la mejor
    mostrar && b.iter % (500 * LARGO_SEGMENTO) == 0 &&
        println("  iter $(b.iter): mejor ", round(b.mejor[3], digits = 2))
end

# --- Diversificación: perturbación fuerte + recalentamiento ------
# Si la mejor solución no mejora durante una fracción ESTANCAMIENTO del
# tiempo total, se parte de la mejor y se aplican entre 3 y 8 movimientos
# aleatorios factibles (sin importar si empeoran). Luego se reinicia el
# enfriamiento desde una temperatura menor (RECALENTAR * t0), para que el
# recocido explore alrededor de esa nueva solución (esquema tipo ILS).

const ESTANCAMIENTO, RECALENTAR, MOVS_PATADA = 0.15, 0.5, 3:8

# Con SOLO_PLAN[] (solución 10) la patada tampoco cambia lotes de máquina
vecindades_patada() = SOLO_PLAN[] ? VECINDADES[[1, 2, 3, 4, 5, 8, 9, 10]] : VECINDADES

function perturbar_plan(ins, sol, rng)
    seq, plan, val = sol
    for _ in 1:rand(rng, MOVS_PATADA), _ in 1:20          # hasta 20 intentos por movimiento
        s2, p2 = rand(rng, vecindades_patada())(ins, seq, plan, rng)
        v2 = evaluar_plan(ins, s2, p2)
        isfinite(v2) && ((seq, plan, val) = (s2, p2, v2); break)
    end
    return seq, plan, val
end

estancada(b, segundos) = time() - b.t_mejora > ESTANCAMIENTO * segundos

function patear!(b, ins, rng, mostrar)
    b.actual = perturbar_plan(ins, b.mejor, rng)
    b.t_mejora = b.t_ciclo = time()
    b.patadas += 1
    mostrar && println("  patada $(b.patadas): mejor ", round(b.mejor[3], digits = 2),
                       " -> parte de ", round(b.actual[3], digits = 2))
end

# Temperatura dentro del ciclo actual (el primero empieza más caliente)
function temperatura_ciclo(b, t0, tf, fin)
    avance = (time() - b.t_ciclo) / max(fin - b.t_ciclo, 1e-9)
    return temperatura(b.patadas == 0 ? t0 : RECALENTAR * t0, tf, min(avance, 1.0))
end

function recocido_plan(ins, seq, plan, segundos; semilla = 1, mostrar = true)
    rng, fin = MersenneTwister(semilla), time() + segundos
    val = evaluar_plan(ins, seq, plan)
    b, t0, tf = Busqueda(seq, plan, val), 0.003 * val, 0.00002 * val
    while time() < fin
        paso_busqueda!(b, ins, temperatura_ciclo(b, t0, tf, fin), rng)
        (b.iter += 1) % LARGO_SEGMENTO == 0 || continue
        fin_de_segmento!(b, mostrar)
        estancada(b, segundos) && fin - time() > 0.1 * segundos && patear!(b, ins, rng, mostrar)
    end
    return b
end
