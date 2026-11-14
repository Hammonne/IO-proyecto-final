# ============================================================
# tabu.jl — Búsqueda tabú con lista de candidatos sobre (secuencias, plan)
# ============================================================
# Búsqueda tabú (Glover, 1986; Glover y Laguna, 1997). En cada iteración:
#   1. Lista de candidatos: se generan unos vecinos al azar con las 7
#      vecindades de la solución 3 (revisar la vecindad completa cuesta
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
# Diversificación: si la mejor no mejora en una fracción ESTANCAMIENTO_TABU
# del tiempo, se reinicia desde la mejor y se vacía la lista tabú.
#
# Solución 12 (tabú iterada: Misevicius, 2005; ILS: Lourenço et al., 2003).
# En la corrida larga de la v11, 96 de 140 mejoras aparecieron en las
# primeras 20 000 iteraciones tras un reinicio, y los reinicios que volvían
# a la mejor sin saltar mejoraron el 40 % de las veces, frente al 6 % de los
# saltos grandes (> 20). Por eso:
#   1. ESTANCAMIENTO_TABU baja de 0.10 a 0.02: tramos de tabú cortos.
#   2. Al reiniciar, la mitad de las veces se vuelve a la mejor tal cual
#      (solo se vacía la lista tabú) y la otra mitad se aplica una
#      perturbación CHICA: 1–2 movimientos con las vecindades de la tabú
#      (PESOS_TABU, sin visitas) que no se alejen más de SALTO_MAX de la mejor.
#      (La perturbación de busqueda_plan.jl tenía un bug: el `break` corta los
#      dos bucles y aplicaba 1 movimiento de cualquier vecindad, con saltos
#      de hasta +321.)
#   3. Variante: PESOS_RUTEO (variable de entorno) da otro peso a las 3
#      vecindades de ruteo de la v11 (0.06 por defecto).

#
# Solución 13: búsqueda local guiada (Guided Local Search, Voudouris y Tsang, 1999)
# sobre la tabú iterada. Las mejores de la 01–03 son óptimos locales estrictos
# (v7) y la v12 no las mueve: la tabú siempre vuelve a la misma estructura.
#   - Rasgos (features): cada componente de la huella de un lote (máquina, lote
#     anterior en la máquina, AGV y parada anterior de su abastecimiento y de su
#     retiro): 6 rasgos por lote.
#   - Costo aumentado: h = g + λ·Σ p_f sobre los rasgos de la solución. La tabú
#     elige el mejor vecino según h; la mejor solución y la aspiración usan g.
#   - En cada reinicio (estancamiento) se penalizan los K rasgos de la MEJOR
#     solución con mayor utilidad c_f / (1 + p_f), donde c_f es el retraso por
#     transporte del lote (de transporte.jl), y se vuelve a la mejor. Así la
#     búsqueda sale por otra estructura, pero puede volver si mejora de verdad.
#   - λ = GLS_ALFA · g(inicial) / (6n) (como en el paper: α por el costo medio
#     por rasgo); K = max(2, GLS_FRAC · n). Variables de entorno GLS_ALFA (0.2)
#     y GLS_FRAC (0.1).

using Random

const ESTANCAMIENTO_TABU, LIMPIEZA_TABU = 0.02, 1000
const PROB_VOLVER, SALTO_MAX, MOVS_CHICOS = 0.5, 5.0, 1:2
num_candidatos(ins) = clamp(num_lotes(ins), 30, 200)
# Probabilidad de cada vecindad de la solución 3 al generar candidatos
# (según los pesos que aprendió el recocido: intercambiar lotes y dividir
# viaje son las que más mejoran)
# Solución 11: se agregan las 3 vecindades de ruteo de transporte.jl
# (posiciones 11–13; las 8–10 de visitas siguen sin usarse, como en la v5)
const PESO_RUTEO = parse(Float64, get(ENV, "PESOS_RUTEO", "0.06"))
# PESOS_VISITA (variable de entorno, 0 por defecto) activa las vecindades 8–10 de visitas
# intermedias a o y f; se usa en la 01, cuya mejor solución tiene visitas a f.
get_peso_bloque() = parse(Float64, get(ENV, "PESO_BLOQUE", "0.06"))
const PESO_VISITA = parse(Float64, get(ENV, "PESOS_VISITA", "0.0"))
const PESOS_TABU = [0.08, 0.08, 0.12, 0.22, 0.06, 0.32, 0.12, PESO_VISITA, PESO_VISITA, PESO_VISITA, PESO_RUTEO, PESO_RUTEO, PESO_RUTEO,
                    get_peso_bloque(), get_peso_bloque()]   # 14–15: bloques (bloques.jl)

const GLS_ALFA = parse(Float64, get(ENV, "GLS_ALFA", "0.2"))
const GLS_FRAC = parse(Float64, get(ENV, "GLS_FRAC", "0.1"))

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
    pen::Dict{Tuple{Int,Int,Int},Int}    # (lote, componente, valor) => penalización
    lambda::Float64
    pen_actual::Int                      # Σ p_f de los rasgos de la actual
end

function EstadoTabu(ins, seq, plan)
    sol = (seq, plan, evaluar_plan(ins, seq, plan))
    h = huellas(seq, plan, num_lotes(ins))
    n = num_lotes(ins)
    return EstadoTabu(sol, h, sol, Dict{Tuple{Int,Huella},Int}(), 0, time(), 0,
                      Dict{Tuple{Int,Int,Int},Int}(), GLS_ALFA * sol[3] / (6n), 0)
end

# --- Penalizaciones (búsqueda local guiada) ---------------------------

pen_lote(st, h, i) = sum(get(st.pen, (i, c, h[i][c]), 0) for c in 1:6)
pen_total(st, h) = isempty(st.pen) ? 0 : sum(pen_lote(st, h, i) for i in eachindex(h))

function penalizar!(st, ins)
    seq, plan, _ = st.mejor
    h = huellas(seq, plan, num_lotes(ins))
    actualizar_retrasos!(ins, seq, plan)
    abast, retiro = RETRASO_ABAST[], RETRASO_RETIRO[]
    isempty(abast) && return
    eps = 0.05 * (sum(abast) + sum(retiro)) / length(abast) + 1e-6
    rasgos = Tuple{Float64,Tuple{Int,Int,Int}}[]
    for i in eachindex(h), c in 1:6
        costo = (c <= 2 ? abast[i] + retiro[i] : c <= 4 ? abast[i] : retiro[i]) + eps
        f = (i, c, h[i][c])
        push!(rasgos, (costo / (1 + get(st.pen, f, 0)), f))
    end
    sort!(rasgos, by = first, rev = true)
    for (_, f) in rasgos[1:min(end, max(2, round(Int, GLS_FRAC * length(h))))]
        st.pen[f] = get(st.pen, f, 0) + 1
    end
end

es_tabu(st, h, lotes) = any(i -> get(st.lista, (i, h[i]), 0) > st.iter, lotes)
admisible(st, h, lotes, val) = !es_tabu(st, h, lotes) || val < st.mejor[3] - 1e-9

# --- Lista de candidatos ---------------------------------------------

function vecindad_tabu(rng)
    r, acumulado = rand(rng) * sum(PESOS_TABU), 0.0
    for (k, w) in enumerate(PESOS_TABU)
        (acumulado += w) >= r && return VECINDADES[k]
    end
    return VECINDADES[length(PESOS_TABU)]
end

function candidato(ins, sol, rng)
    seq, plan, _ = sol
    s2, p2 = vecindad_tabu(rng)(ins, seq, plan, rng)
    return (s2, p2, evaluar_plan(ins, s2, p2))
end

# Mejor vecino admisible de la lista. Las huellas solo se calculan para
# candidatos que mejoran al mejor encontrado hasta ahora en la lista.
# v13: se compara por costo aumentado g + λ·Σp (sin penalizaciones es igual a la v12).
function mejor_candidato(st, ins, rng)
    elegido, h_elegida, lotes_elegidos, aum, pen = nothing, st.huella, Int[], Inf, 0
    for _ in 1:num_candidatos(ins)
        c = candidato(ins, st.actual, rng)
        isfinite(c[3]) || continue
        isempty(st.pen) && c[3] >= aum && continue
        h = huellas(c[1], c[2], num_lotes(ins))
        lotes = cambiados(st.huella, h)
        (isempty(lotes) || !admisible(st, h, lotes, c[3])) && continue
        p = isempty(st.pen) ? 0 :
            st.pen_actual + sum(pen_lote(st, h, i) - pen_lote(st, st.huella, i) for i in lotes)
        a = c[3] + st.lambda * p
        a < aum || continue
        elegido, h_elegida, lotes_elegidos, aum, pen = c, h, lotes, a, p
    end
    return elegido, h_elegida, lotes_elegidos, pen
end

# --- Movimiento y memoria --------------------------------------------

function mover!(st, cand, h, lotes, pen, rng)
    rango = tenencia(length(h))
    for i in lotes
        st.lista[(i, st.huella[i])] = st.iter + rand(rng, rango)
    end
    st.actual, st.huella, st.pen_actual = cand, h, pen
    cand[3] < st.mejor[3] - 1e-9 && (st.mejor = cand; st.t_mejora = time())
end

function iteracion_tabu!(st, ins, rng)
    st.iter += 1
    actualizar_retrasos!(ins, st.actual[1], st.actual[2])   # para la elección guiada (v11)
    cand, h, lotes, pen = mejor_candidato(st, ins, rng)
    cand === nothing || mover!(st, cand, h, lotes, pen, rng)
end

olvidar_vencidos!(st) = filter!(par -> par.second > st.iter, st.lista)

# --- Diversificación -------------------------------------------------

# Perturbación chica: 1–2 movimientos de las vecindades de la tabú; cada uno
# se sortea hasta 20 veces hasta que sea factible y no se aleje más de
# SALTO_MAX de la mejor. Si ninguno sirve, queda la mejor tal cual.
function perturbar_chica(ins, mejor, rng)
    sol = mejor
    for _ in 1:rand(rng, MOVS_CHICOS)
        for _ in 1:20
            c = candidato(ins, sol, rng)
            if isfinite(c[3]) && c[3] <= mejor[3] + SALTO_MAX
                sol = c
                break
            end
        end
    end
    return sol
end

# v13: en vez de perturbar, se penalizan rasgos de la mejor y se vuelve a ella
# Con GLS_ALFA = 0 se comporta como la v12 (sin penalizaciones, reinicio chico)
# PATADA_BLOQUE (variable de entorno, 0 por defecto): probabilidad de que el reinicio
# parta de la mejor con un movimiento de bloque (bloques.jl) en vez del reinicio chico;
# (solo patadas que empeoran hasta 30); el tramo de tabú que sigue repara los viajes (iterated local search con patada de bloque).
const PATADA_BLOQUE = parse(Float64, get(ENV, "PATADA_BLOQUE", "0.0"))
function patada_bloque(ins, mejor, rng)
    for _ in 1:100
        f = rand(rng, Bool) ? mover_bloque : intercambiar_bloques
        s2, p2 = f(ins, mejor[1], mejor[2], rng)
        v = evaluar_plan(ins, s2, p2)
        isfinite(v) && mejor[3] + 1e-9 < v <= mejor[3] + 30 && return (s2, p2, v)
    end
    return mejor
end

function reiniciar_tabu!(st, ins, rng, mostrar)
    if GLS_ALFA > 0
        penalizar!(st, ins)
        st.actual = st.mejor
    else
        st.actual = rand(rng) < PATADA_BLOQUE ? patada_bloque(ins, st.mejor, rng) :
                    rand(rng) < PROB_VOLVER ? st.mejor : perturbar_chica(ins, st.mejor, rng)
    end
    st.huella = huellas(st.actual[1], st.actual[2], num_lotes(ins))
    st.pen_actual = pen_total(st, st.huella)
    empty!(st.lista)
    st.t_mejora, st.reinicios = time(), st.reinicios + 1
    mostrar && println("  reinicio $(st.reinicios): mejor ", round(st.mejor[3], digits = 2),
                       " -> parte de ", round(st.actual[3], digits = 2),
                       "  (rasgos penalizados: ", length(st.pen), ", Σp de la mejor: ", st.pen_actual, ")")
end

function mantenimiento!(st, ins, rng, segundos, fin, mostrar)
    st.iter % LIMPIEZA_TABU == 0 || return
    olvidar_vencidos!(st)
    estancada = time() - st.t_mejora > ESTANCAMIENTO_TABU * segundos
    estancada && fin - time() > 0.05 * segundos && reiniciar_tabu!(st, ins, rng, mostrar)
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
