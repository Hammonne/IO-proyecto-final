# ============================================================
# ventanas.jl — Reoptimización exacta por ventanas (movimientos compuestos)
# ============================================================
# Las soluciones de las instancias 01 y 03 resultaron ser óptimos locales
# ESTRICTOS: ningún vecino de las vecindades simples (ni mover segmentos de
# paradas, ni mover las dos paradas de un lote) las mejora. Para salir hay
# que cambiar varias cosas A LA VEZ. Idea de POPMUSIC (Taillard y Voss,
# 2002) y de dynasearch (Congram, Potts y van de Velde, 2002): se fija toda
# la solución salvo una "ventana" pequeña y se prueban TODAS las
# combinaciones dentro de ella (vecindad grande explorada en forma exacta).
#   W1 ventana de lotes   : k lotes que empiezan seguidos en el tiempo; se
#                           prueban todas las formas de repartirlos en sus k
#                           lugares de máquina (k!), con las paradas que los
#                           siguen o que se quedan en su lugar (renombradas).
#                           Generaliza el intercambio de 2 lotes a ciclos de
#                           k lotes (intercambio cíclico, Ahuja et al., 2002).
#   W2 ventana de paradas : w paradas seguidas en el tiempo (de cualquier
#                           AGV); se prueban todas las formas de repartirlas
#                           en sus w lugares del plan (w!): reordena viajes y
#                           pasa paradas entre AGVs al mismo tiempo.
#   W3 ventana conjunta   : cada reparto de W1 combinado con cada reparto de
#                           W2 sobre las paradas de esos mismos lotes.

const K_LOTES, W_PARADAS, K_CONJUNTA, W_CONJUNTA = 5, 6, 3, 5

function permutaciones(n)
    n == 1 && return [[1]]
    out = Vector{Int}[]
    for p in permutaciones(n - 1), pos in 1:n
        q = copy(p)
        insert!(q, pos, n)
        push!(out, q)
    end
    return out
end

const PERMUTACIONES = Dict(n => permutaciones(n) for n in 1:7)

# --- Orden temporal de lotes y paradas -----------------------------------

function lotes_en_orden(e, seq)
    lista = [(e.inicio[j][k], seq[j][k]) for j in eachindex(seq) for k in eachindex(seq[j])]
    return last.(sort(lista))
end

function paradas_en_orden(e, seq, plan)
    ubic, lista = ubicar_lotes(seq), Tuple{Float64,Int,Int,Int}[]
    for a in eachindex(plan), v in eachindex(plan[a]), k in eachindex(plan[a][v])
        p = plan[a][v][k]
        es_real(p) || continue                  # las visitas a o/f no tienen lote
        j, pos = ubic[p.lote]
        push!(lista, (p.abastece ? e.llegada[j][pos] : e.recojo[j][pos], a, v, k))
    end
    sort!(lista)
    return [(a, v, k) for (_, a, v, k) in lista]
end

# --- W1: repartir k lotes en sus k lugares de máquina --------------------

# El lugar del lote lotes[i] pasa a tenerlo lotes[perm[i]]
function permutar_lotes(ins, seq, plan, lotes, perm, renombrar_plan)
    ub, s = ubicar_lotes(seq), copiar_seq(seq)
    nuevo = Dict(lotes[i] => lotes[perm[i]] for i in eachindex(lotes))
    for x in lotes
        j, k = ub[x]
        compatible(ins, nuevo[x], j) || return nothing
        s[j][k] = nuevo[x]
    end
    renombrar_plan || return s, plan
    return s, [[[Parada(q.abastece, get(nuevo, q.lote, q.lote)) for q in v] for v in vs] for vs in plan]
end

# --- W2: repartir w paradas en sus w lugares del plan --------------------

function permutar_paradas(plan, lugares, perm)
    p, orig = copiar_plan(plan), [plan[a][v][k] for (a, v, k) in lugares]
    for (i, (a, v, k)) in enumerate(lugares)
        p[a][v][k] = orig[perm[i]]
    end
    return p
end

function mejor_reparto_paradas(ins, seq, plan, lugares, mejor)
    for perm in PERMUTACIONES[length(lugares)]
        p = permutar_paradas(plan, lugares, perm)
        v = evaluar_plan(ins, seq, p)
        v < mejor[3] - 1e-9 && (mejor = (seq, p, v))
    end
    return mejor
end

# --- Ventanas sobre una solución --------------------------------------

function mejor_reparto_lotes(ins, sol, lotes)
    seq, plan, mejor = sol[1], sol[2], sol
    for perm in PERMUTACIONES[length(lotes)], renombrar_plan in (false, true)
        r = permutar_lotes(ins, seq, plan, lotes, perm, renombrar_plan)
        r === nothing && continue
        v = evaluar_plan(ins, r...)
        v < mejor[3] - 1e-9 && (mejor = (r[1], r[2], v))
    end
    return mejor
end

# Lugares en el plan de las paradas de unos lotes (los primeros w en el tiempo)
function lugares_de(orden_paradas, plan, lotes, w)
    es_de(l) = plan[l[1]][l[2]][l[3]].lote in lotes
    return filter(es_de, orden_paradas)[1:min(w, end)]
end

function mejor_conjunta(ins, sol, e, lotes)
    seq, plan, mejor = sol[1], sol[2], sol
    lugares = lugares_de(paradas_en_orden(e, seq, plan), plan, lotes, W_CONJUNTA)
    for perm in PERMUTACIONES[length(lotes)], renombrar_plan in (false, true)
        r = permutar_lotes(ins, seq, plan, lotes, perm, renombrar_plan)
        r === nothing && continue
        mejor = mejor_reparto_paradas(ins, r[1], r[2], lugares, mejor)
    end
    return mejor
end

# --- Barrido: recorre todas las ventanas, acepta la primera mejora ---------

ventana(lista, i, k) = lista[i:min(i + k - 1, end)]

function barrer_lotes(ins, sol, k, conjunta)
    e, _ = decodificar(ins, sol[1], sol[2])
    orden = lotes_en_orden(e, sol[1])
    for i in 1:length(orden)-k+1
        lotes = ventana(orden, i, k)
        c = conjunta ? mejor_conjunta(ins, sol, e, lotes) : mejor_reparto_lotes(ins, sol, lotes)
        c[3] < sol[3] - 1e-9 && return c
    end
    return sol
end

function barrer_paradas(ins, sol, w)
    e, _ = decodificar(ins, sol[1], sol[2])
    orden = paradas_en_orden(e, sol[1], sol[2])
    for i in 1:length(orden)-w+1
        c = mejor_reparto_paradas(ins, sol[1], sol[2], ventana(orden, i, w), sol)
        c[3] < sol[3] - 1e-9 && return c
    end
    return sol
end

# Un barrido de cada tipo de ventana; devuelve la solución (mejorada o no)
function barrido_ventanas(ins, sol)
    for paso in (s -> barrer_lotes(ins, s, K_LOTES, false), s -> barrer_paradas(ins, s, W_PARADAS),
                 s -> barrer_lotes(ins, s, K_CONJUNTA, true))
        c = paso(sol)
        c[3] < sol[3] - 1e-9 && return c
    end
    return sol
end

# Descenso por ventanas: repite barridos mientras haya mejora (o hasta el límite)
function descenso_ventanas(ins, sol, fin)
    while time() < fin
        c = barrido_ventanas(ins, sol)
        c[3] < sol[3] - 1e-9 || return sol
        sol = c
    end
    return sol
end
