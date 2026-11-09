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
    v2 < b.mejor[3] - 1e-9 && (b.mejor = (s2, p2, v2))
end

function fin_de_segmento!(b, mostrar)
    actualizar_pesos!(b.ad)
    b.actual[3] > 1.02 * b.mejor[3] && (b.actual = b.mejor)   # vuelve a la mejor
    mostrar && b.iter % (500 * LARGO_SEGMENTO) == 0 &&
        println("  iter $(b.iter): mejor ", round(b.mejor[3], digits = 2))
end

# temperatura(t0, tf, avance) está en recocido.jl (enfriamiento geométrico)

function recocido_plan(ins, seq, plan, segundos; semilla = 1, mostrar = true)
    rng, inicio = MersenneTwister(semilla), time()
    val = evaluar_plan(ins, seq, plan)
    b = Busqueda((seq, plan, val), (seq, plan, val), Adaptativo(length(VECINDADES)), 0)
    t0, tf = 0.003 * val, 0.00002 * val
    while (avance = (time() - inicio) / segundos) < 1
        paso_busqueda!(b, ins, temperatura(t0, tf, avance), rng)
        (b.iter += 1) % LARGO_SEGMENTO == 0 && fin_de_segmento!(b, mostrar)
    end
    return b
end
