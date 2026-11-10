# ============================================================
# busqueda_secuencia.jl — Búsqueda sobre la secuencia de inserción
# ============================================================
# Como el SIA-ALNS de Yin y Hu (2026): recocido simulado (criterio de
# Metropolis) con selección adaptativa de movimientos por ruleta y
# premios 1.8 / 1.2 / 0.8 / 0.5 (nueva mejor / mejora / aceptada /
# rechazada; el premio a las rechazadas evita que los pesos colapsen).
# Movimientos sobre (asignación, Y):
#   S1 intercambiar dos tareas cercanas en Y
#   S2 mover una tarea a otra posición cercana
#   S3 cambiar un lote de máquina (su orden sale de Y)
#   S4 sacar un bloque de 2–6 tareas seguidas y reinsertarlo al inicio,
#      al final o en medio de Y (operadores de destrucción/reparación por
#      partes del paper: front-, latter- e inner-part)

const VENTANA_SECUENCIA = 10
const PREMIOS_SECUENCIA = (1.8, 1.2, 0.8, 0.5)

cercana(rng, k, n) = clamp(k + rand(rng, -VENTANA_SECUENCIA:VENTANA_SECUENCIA), 1, n)

function intercambiar_tareas(ins, s, rng)
    Y = copy(s.Y)
    k = rand(rng, eachindex(Y))
    k2 = cercana(rng, k, length(Y))
    Y[k], Y[k2] = Y[k2], Y[k]
    return SolSecuencia(s.asig, Y)
end

function mover_tarea(ins, s, rng)
    Y = copy(s.Y)
    k = rand(rng, eachindex(Y))
    t = popat!(Y, k)
    insert!(Y, cercana(rng, k, length(Y) + 1), t)
    return SolSecuencia(s.asig, Y)
end

function cambiar_maquina(ins, s, rng)
    asig, x = copy(s.asig), rand(rng, 1:num_lotes(ins))
    otras = setdiff(maquinas_compatibles(ins, x), asig[x])
    isempty(otras) && return s
    asig[x] = rand(rng, otras)
    return SolSecuencia(asig, s.Y)
end

function reinsertar_bloque(ins, s, rng)
    Y, L = copy(s.Y), rand(rng, 2:6)
    k = rand(rng, 1:length(Y)-L+1)
    bloque = Y[k:k+L-1]
    deleteat!(Y, k:k+L-1)
    destino = rand(rng, (1, length(Y) + 1, rand(rng, 1:length(Y)+1)))
    for (m, t) in enumerate(bloque)
        insert!(Y, destino + m - 1, t)
    end
    return SolSecuencia(s.asig, Y)
end

const MOVIMIENTOS_SECUENCIA = [intercambiar_tareas, mover_tarea, cambiar_maquina, reinsertar_bloque]
const NOMBRES_SECUENCIA = ["intercambiar_tareas", "mover_tarea", "cambiar_maquina", "reinsertar_bloque"]

# --- Recocido con ruleta adaptativa --------------------------------------

mutable struct EstadoSecuencia
    actual::Tuple{SolSecuencia,Float64}
    mejor::Tuple{SolSecuencia,Float64}
    mejor_plan::Tuple{Vector{Vector{Int}},Plan,Float64}
    ad::Adaptativo
    iter::Int
end

function EstadoSecuencia(ins, s)
    seq, plan, v = decodificar_secuencia(ins, s)
    return EstadoSecuencia((s, v), (s, v), (seq, plan, v), Adaptativo(length(MOVIMIENTOS_SECUENCIA)), 0)
end

function premio_secuencia(v2, val, mejor, aceptado)
    v2 < mejor - 1e-9 && return PREMIOS_SECUENCIA[1]
    v2 < val - 1e-9 && return PREMIOS_SECUENCIA[2]
    return aceptado ? PREMIOS_SECUENCIA[3] : PREMIOS_SECUENCIA[4]
end

function paso_secuencia!(st, ins, temp, rng)
    k = ruleta(st.ad, rng)
    s2 = MOVIMIENTOS_SECUENCIA[k](ins, st.actual[1], rng)
    seq, plan, v2 = decodificar_secuencia(ins, s2)
    aceptado = isfinite(v2) && aceptar_vecino(v2, st.actual[2], temp, rng)
    st.ad.puntos[k] += premio_secuencia(v2, st.actual[2], st.mejor[2], aceptado)
    st.ad.usos[k] += 1
    aceptado && (st.actual = (s2, v2))
    v2 < st.mejor[2] - 1e-9 && (st.mejor = (s2, v2); st.mejor_plan = (seq, plan, v2))
end

# Temperatura inicial: una solución 0.5 % peor se acepta con prob. 0.5
function busqueda_secuencia(ins, s, segundos; semilla = 1, mostrar = true)
    rng, inicio, fin = MersenneTwister(semilla), time(), time() + segundos
    st = EstadoSecuencia(ins, s)
    t0 = 0.005 * st.mejor[2] / log(2)
    while time() < fin
        paso_secuencia!(st, ins, temperatura(t0, t0 / 200, (time() - inicio) / segundos), rng)
        (st.iter += 1) % 100 == 0 && actualizar_pesos!(st.ad)
        mostrar && st.iter % 5000 == 0 && println("  iter $(st.iter): mejor ", round(st.mejor[2], digits = 2))
    end
    return st
end
