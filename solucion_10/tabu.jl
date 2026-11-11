# ============================================================
# tabu.jl — Búsqueda tabú con lista de candidatos sobre (secuencias, plan)
# ============================================================
# Búsqueda tabú (Glover, 1986; Glover y Laguna, 1997). En cada iteración:
#   1. Lista de candidatos: se generan unos vecinos al azar con las 10
#      vecindades de la solución 4 (revisar la vecindad completa cuesta
#      segundos por iteración en las instancias grandes). Se generan tantos
#      como lotes (entre 30 y 200): en pruebas, las instancias chicas
#      rinden más con listas cortas (más iteraciones) y las grandes con
#      listas largas (mejores movimientos).
#   2. Se pasa al MEJOR vecino admisible, aunque empeore la solución
#      actual: así la búsqueda sale de los óptimos locales.
#   3. Memoria de corto plazo: cada lote tiene una HUELLA (máquina, lote
#      anterior en la máquina y, para sus dos paradas, AGV y parada anterior
#      en el viaje). Cuando un movimiento cambia la huella de un lote, la
#      pareja (lote, huella vieja) queda tabú durante unas iteraciones: se
#      prohíbe devolver el lote a donde estaba (deshacer el movimiento).
#   4. Criterio de aspiración: un movimiento tabú se acepta si da una
#      nueva mejor solución.
# Solución 7 — cuando la mejor no mejora en una fracción ESTANCAMIENTO_TABU
# del tiempo:
#   a) intensificación: descenso por ventanas exactas (ventanas.jl) sobre la
#      mejor solución; si mejora, la tabú sigue desde ahí;
#   b) si no mejora, diversificación: se parte de la mejor con una
#      perturbación aleatoria (3–8 movimientos).
# En ambos casos se vacía la lista tabú.

using Random

const ESTANCAMIENTO_TABU, LIMPIEZA_TABU = 0.10, 1000
num_candidatos(ins) = clamp(num_lotes(ins), 30, 200)
# Probabilidad de cada vecindad de la solución 3 al generar candidatos
# (según los pesos que aprendió el recocido: intercambiar lotes y dividir
# viaje son las que más mejoran)
# más las 3 vecindades de visitas intermedias a o/f de la solución 4 (la
# mejor solución de la instancia 01 usa visitas a f a mitad de viaje)
const PESOS_TABU = [0.07, 0.07, 0.11, 0.20, 0.05, 0.29, 0.11, 0.04, 0.03, 0.03]
# Solución 10: con SOLO_PLAN[] = true no se usan las vecindades que cambian
# lotes de máquina (6 = intercambiar lotes, 7 = reubicar lote): la
# asignación a máquinas queda fija y solo se optimizan los viajes de los AGVs
const PESOS_SOLO_PLAN = [0.12, 0.12, 0.15, 0.25, 0.10, 0.0, 0.0, 0.10, 0.08, 0.08]
const SOLO_PLAN = Ref(false)
pesos_tabu() = SOLO_PLAN[] ? PESOS_SOLO_PLAN : PESOS_TABU

const SolTabu = Tuple{Vector{Vector{Int}},Plan,Float64}
const Huella = NTuple{6,Int}

# --- Huellas de los lotes ------------------------------------------

codigo(p) = es_visita(p) ? 0 : (p.abastece ? p.lote : -p.lote)

function huellas_seq!(m, seq)
    for j in eachindex(seq), k in eachindex(seq[j])
        i = seq[j][k]
        m[i, 1], m[i, 2] = j, k == 1 ? 0 : seq[j][k-1]
    end
end

function huellas_plan!(m, plan)
    for a in eachindex(plan), v in plan[a], k in eachindex(v)
        es_real(v[k]) || continue
        c = v[k].abastece ? 3 : 5
        m[v[k].lote, c], m[v[k].lote, c+1] = a, k == 1 ? 0 : codigo(v[k-1])
    end
end

function huellas(seq, plan, n)
    m = zeros(Int, n, 6)
    huellas_seq!(m, seq)
    huellas_plan!(m, plan)
    return [ntuple(c -> m[i, c], 6) for i in 1:n]
end

cambiados(h1, h2) = [i for i in eachindex(h1) if h1[i] != h2[i]]

# Tenencia (iteraciones que dura un atributo tabú), crece con el tamaño
tenencia(n) = (t = round(Int, 2 * sqrt(n)); t:2t)

# --- Estado --------------------------------------------------------

mutable struct EstadoTabu
    actual::SolTabu
    huella::Vector{Huella}
    mejor::SolTabu
    lista::Dict{Tuple{Int,Huella},Int}   # (lote, huella) => iteración en que deja de ser tabú
    iter::Int
    t_mejora::Float64
    reinicios::Int
end

function EstadoTabu(ins, seq, plan)
    sol = (seq, plan, evaluar_plan(ins, seq, plan))
    h = huellas(seq, plan, num_lotes(ins))
    return EstadoTabu(sol, h, sol, Dict{Tuple{Int,Huella},Int}(), 0, time(), 0)
end

es_tabu(st, h, lotes) = any(i -> get(st.lista, (i, h[i]), 0) > st.iter, lotes)
admisible(st, h, lotes, val) = !es_tabu(st, h, lotes) || val < st.mejor[3] - 1e-9

# --- Lista de candidatos ---------------------------------------------

function vecindad_tabu(rng)
    pesos = pesos_tabu()
    r, acumulado = rand(rng) * sum(pesos), 0.0
    for (k, w) in enumerate(pesos)
        (acumulado += w) >= r && return VECINDADES[k]
    end
    return VECINDADES[findlast(>(0), pesos)]
end

function candidato(ins, sol, rng)
    seq, plan, _ = sol
    s2, p2 = vecindad_tabu(rng)(ins, seq, plan, rng)
    return (s2, p2, evaluar_plan(ins, s2, p2))
end

# Mejor vecino admisible de la lista. Las huellas solo se calculan para
# candidatos que mejoran al mejor encontrado hasta ahora en la lista.
function mejor_candidato(st, ins, rng)
    elegido, h_elegida, lotes_elegidos = nothing, st.huella, Int[]
    for _ in 1:num_candidatos(ins)
        c = candidato(ins, st.actual, rng)
        (isfinite(c[3]) && (elegido === nothing || c[3] < elegido[3])) || continue
        h = huellas(c[1], c[2], num_lotes(ins))
        lotes = cambiados(st.huella, h)
        (isempty(lotes) || !admisible(st, h, lotes, c[3])) && continue
        elegido, h_elegida, lotes_elegidos = c, h, lotes
    end
    return elegido, h_elegida, lotes_elegidos
end

# --- Movimiento y memoria --------------------------------------------

function mover!(st, cand, h, lotes, rng)
    rango = tenencia(length(h))
    for i in lotes
        st.lista[(i, st.huella[i])] = st.iter + rand(rng, rango)
    end
    st.actual, st.huella = cand, h
    cand[3] < st.mejor[3] - 1e-9 && (st.mejor = cand; st.t_mejora = time())
end

# Si la actual se aleja más de un MAX_ALEJAMIENTO de la mejor, vuelve a la
# mejor (sin borrar la lista tabú): evita que la búsqueda se pierda, por
# ejemplo acumulando visitas a o/f cuyo retiro quedó tabú
const MAX_ALEJAMIENTO = 0.02

function volver_si_lejos!(st, ins)
    st.actual[3] > (1 + MAX_ALEJAMIENTO) * st.mejor[3] || return
    st.actual = st.mejor
    st.huella = huellas(st.mejor[1], st.mejor[2], num_lotes(ins))
end

function iteracion_tabu!(st, ins, rng)
    st.iter += 1
    cand, h, lotes = mejor_candidato(st, ins, rng)
    cand === nothing || mover!(st, cand, h, lotes, rng)
    volver_si_lejos!(st, ins)
end

olvidar_vencidos!(st) = filter!(par -> par.second > st.iter, st.lista)

# --- Diversificación -------------------------------------------------

const FRACCION_VENTANAS = 0.03   # tope de tiempo de cada descenso por ventanas

function intensificar_o_perturbar(st, ins, rng, segundos)
    SOLO_PLAN[] && return perturbar_plan(ins, st.mejor, rng), false
    c = descenso_ventanas(ins, st.mejor, time() + FRACCION_VENTANAS * segundos)
    c[3] < st.mejor[3] - 1e-9 || return perturbar_plan(ins, st.mejor, rng), false
    st.mejor, st.t_mejora = c, time()
    return c, true
end

function reiniciar_tabu!(st, ins, rng, segundos, mostrar)
    st.actual, mejoro = intensificar_o_perturbar(st, ins, rng, segundos)
    mostrar && mejoro && println("  ventanas: nueva mejor ", round(st.mejor[3], digits = 2))
    st.huella = huellas(st.actual[1], st.actual[2], num_lotes(ins))
    empty!(st.lista)
    st.t_mejora, st.reinicios = time(), st.reinicios + 1
    mostrar && println("  reinicio $(st.reinicios): mejor ", round(st.mejor[3], digits = 2),
                       " -> parte de ", round(st.actual[3], digits = 2))
end

function mantenimiento!(st, ins, rng, segundos, fin, mostrar)
    st.iter % LIMPIEZA_TABU == 0 || return
    olvidar_vencidos!(st)
    estancada = time() - st.t_mejora > ESTANCAMIENTO_TABU * segundos
    estancada && fin - time() > 0.05 * segundos && reiniciar_tabu!(st, ins, rng, segundos, mostrar)
    mostrar && st.iter % (20 * LIMPIEZA_TABU) == 0 &&
        println("  iter $(st.iter): mejor ", round(st.mejor[3], digits = 2),
                "  actual ", round(st.actual[3], digits = 2))
end

function busqueda_tabu(ins, seq, plan, segundos; semilla = 1, mostrar = true)
    rng, fin = MersenneTwister(semilla), time() + segundos
    st = EstadoTabu(ins, seq, plan)
    while time() < fin
        iteracion_tabu!(st, ins, rng)
        mantenimiento!(st, ins, rng, segundos, fin, mostrar)
    end
    return st
end
