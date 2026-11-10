# ============================================================
# reparacion.jl — Operadores de reparación del ALNS (inserción secuencial)
# ============================================================
# Los lotes quitados se reinsertan uno a uno (inserción secuencial, como
# el SIA de Yin y Hu, 2026). Insertar un lote x = elegir
#   (1) máquina compatible j y posición k en su secuencia, y
#   (2) dónde van sus dos paradas (abastecer en alfa_j, retirar en beta_j).
# Opciones para cada parada:
#   - un HUECO del mismo tipo: el lugar que dejó en su viaje un lote
#     quitado (así se reusa la estructura de transporte; con los huecos
#     propios, reinsertar un lote en su posición original recupera
#     exactamente la solución de partida)
#   - "junto": en el mismo viaje que la parada del lote vecino en la
#     máquina (antecesor o sucesor)
#   - "propio": como viaje nuevo al lado del viaje de ese vecino
# Etapa 1: cada (j, k) candidata se evalúa con la opción por defecto
#          (su propio hueco o, si no, "junto al antecesor").
# Etapa 2: para las mejores posiciones (hasta tener TOP_POSICIONES
#          factibles) se elige la mejor opción de la parada de abastecer y
#          luego la de retirar.
# Posiciones candidatas: cercanas a donde estaba el lote (misma fracción
# de la secuencia ± VENTANA_REPARACION), por la misma razón de cercanía
# en el tiempo que en las soluciones 2 y 3.
# El costo es la suma de c_i de los lotes ya insertados (la solución
# parcial se decodifica igual que una completa; los huecos se saltan).
#   R1 voraz aleatorio : orden aleatorio
#   R2 voraz SPT       : primero los lotes de menor tiempo de proceso
#   R3 arrepentimiento : primero el lote con mayor "regret-2" (diferencia
#                        entre su 2.ª y 1.ª mejor posición en la etapa 1)

const VENTANA_REPARACION, TOP_POSICIONES, MAX_INTENTOS = 4, 3, 12
const OPCIONES_VECINO = [(:junto, false), (:propio, false), (:junto, true), (:propio, true)]  # (tipo, usar sucesor)

function suma_parcial(ins, seq, plan)
    e, ok = decodificar(ins, seq, plan)
    return ok ? sum(c for c in e.c if !isnan(c); init = 0.0) : Inf
end

# Posiciones cercanas a la fracción de secuencia donde estaba el lote
function posiciones_candidatas(seq, j, fraccion)
    n = length(seq[j]) + 1
    centro = 1 + round(Int, fraccion * (n - 1))
    return max(1, centro - VENTANA_REPARACION):min(n, centro + VENTANA_REPARACION)
end

# --- Colocar una parada ------------------------------------------

function vecino_en_maquina(s, j, k, usar_sucesor)
    usar_sucesor && k < length(s[j]) && return s[j][k+1], 0   # antes de la del sucesor
    k > 1 && return s[j][k-1], 1                             # después de la del antecesor
    k < length(s[j]) && return s[j][k+1], 0
    return 0, 0
end

function junto_a_vecino!(p, s, j, k, x, abastece, propio, usar_sucesor)
    vecino, despues = vecino_en_maquina(s, j, k, usar_sucesor)
    nueva = Parada(abastece, x)
    vecino == 0 && return push!(p[argmin(length.(p))], [nueva])
    a, v, pos = buscar_parada(p, vecino, abastece)
    propio ? insert!(p[a], v + despues, [nueva]) : insert!(p[a][v], pos + despues, nueva)
end

function ocupar_hueco!(p, hueco, abastece, x)
    a, v, k = buscar_parada(p, hueco, abastece)
    p[a][v][k] = Parada(abastece, x)
end

# opcion = (:hueco, id), (:junto | :propio, usar_sucesor) o (:final, 0)
function colocar!(p, s, j, k, x, abastece, opcion)
    tipo, dato = opcion
    tipo == :hueco && return ocupar_hueco!(p, dato, abastece, x)
    tipo == :final && return push!(p[argmin(length.(p))], [Parada(abastece, x)])
    junto_a_vecino!(p, s, j, k, x, abastece, tipo == :propio, dato)
end

huecos(p, abastece) = [q.lote for viajes in p for v in viajes for q in v if q.lote < 0 && q.abastece == abastece]

function opciones_parada(p, abastece)
    return vcat([(:hueco, h) for h in huecos(p, abastece)], OPCIONES_VECINO)
end

opcion_defecto(p, x, abastece) = -x in huecos(p, abastece) ? (:hueco, -x) : (:junto, false)

function insertar_lote(seq, plan, x, j, k, op_abastecer, op_retirar)
    s, p = copiar_seq(seq), copiar_plan(plan)
    insert!(s[j], k, x)
    colocar!(p, s, j, k, x, true, op_abastecer)
    colocar!(p, s, j, k, x, false, op_retirar)
    return s, p
end

# --- Etapa 1: posiciones ------------------------------------------

# Costo de (j, k) con la mejor de dos colocaciones baratas: los huecos
# propios (recupera la solución original) o viajes propios junto al
# antecesor (casi nunca produce bloqueos mutuos)
function costo_posicion(ins, seq, plan, x, j, k)
    defecto = (opcion_defecto(plan, x, true), opcion_defecto(plan, x, false))
    seguro = ((:propio, false), (:propio, false))
    return min(suma_parcial(ins, insertar_lote(seq, plan, x, j, k, defecto...)...),
               suma_parcial(ins, insertar_lote(seq, plan, x, j, k, seguro...)...))
end

function evaluar_posiciones(ins, seq, plan, x, ref)
    opciones = Tuple{Float64,Int,Int}[]
    _, fraccion = ref[x]
    for j in maquinas_compatibles(ins, x), k in posiciones_candidatas(seq, j, fraccion)
        push!(opciones, (costo_posicion(ins, seq, plan, x, j, k), j, k))
    end
    return sort!(opciones)
end

# Último recurso: al final de una máquina y de un AGV nadie depende del
# lote, así que la inserción siempre es factible (aunque sea cara)
function insertar_al_final(ins, seq, plan, x)
    j = argmin(j -> length(seq[j]), maquinas_compatibles(ins, x))
    s, p = insertar_lote(seq, plan, x, j, length(seq[j]) + 1, (:final, 0), (:final, 0))
    return suma_parcial(ins, s, p), s, p
end

# --- Etapa 2: paradas ----------------------------------------------

# Mejor opción para una parada dejando fija la otra
function mejor_opcion(ins, seq, plan, x, j, k, fija, abastece)
    mejor = (Inf, opcion_defecto(plan, x, abastece))
    for op in opciones_parada(plan, abastece)
        ops = abastece ? (op, fija) : (fija, op)
        s, p = insertar_lote(seq, plan, x, j, k, ops...)
        c = suma_parcial(ins, s, p)
        c < mejor[1] && (mejor = (c, op))
    end
    return mejor
end

function mejor_en_posicion(ins, seq, plan, x, j, k)
    _, op_a = mejor_opcion(ins, seq, plan, x, j, k, opcion_defecto(plan, x, false), true)
    c, op_r = mejor_opcion(ins, seq, plan, x, j, k, op_a, false)
    return c, op_a, op_r
end

# Recorre las posiciones de mejor a peor hasta tener TOP_POSICIONES
# factibles (o MAX_INTENTOS probadas): una posición infactible con la
# opción por defecto puede ser factible con otra forma de colocar paradas
function mejor_insercion(ins, seq, plan, x, opciones)
    mejor, factibles = (Inf, seq, plan), 0
    for (_, j, k) in opciones[1:min(MAX_INTENTOS, end)]
        c, op_a, op_r = mejor_en_posicion(ins, seq, plan, x, j, k)
        isfinite(c) && (factibles += 1)
        c < mejor[1] && (mejor = (c, insertar_lote(seq, plan, x, j, k, op_a, op_r)...))
        factibles >= TOP_POSICIONES && break
    end
    return isinf(mejor[1]) ? insertar_al_final(ins, seq, plan, x) : mejor
end

# --- Operadores ------------------------------------------------------

function limpiar_huecos!(p)
    foreach(viajes -> foreach(v -> filter!(q -> q.lote >= 0, v), viajes), p)   # conserva las visitas
    return limpiar!(p)
end

function reparar_en_orden(ins, seq, plan, lotes, ref)
    for x in lotes
        c, seq, plan = mejor_insercion(ins, seq, plan, x, evaluar_posiciones(ins, seq, plan, x, ref))
        isinf(c) && return seq, plan, false
    end
    return seq, limpiar_huecos!(plan), true
end

reparar_aleatorio(ins, s, p, lotes, ref, rng) = reparar_en_orden(ins, s, p, shuffle(rng, lotes), ref)
reparar_spt(ins, s, p, lotes, ref, rng) = reparar_en_orden(ins, s, p, sort(lotes, by = x -> menor_proceso(ins, x)), ref)

# Regret-2: si solo queda una posición factible, el lote es urgente (Inf)
function arrepentimiento(opciones)
    length(opciones) < 2 && return Inf
    d = opciones[2][1] - opciones[1][1]
    return isnan(d) ? 0.0 : d
end

function reparar_arrepentimiento(ins, seq, plan, lotes, ref, rng)
    pendientes = copy(lotes)
    while !isempty(pendientes)
        evals = [evaluar_posiciones(ins, seq, plan, x, ref) for x in pendientes]
        idx = argmax([arrepentimiento(o) for o in evals])
        c, seq, plan = mejor_insercion(ins, seq, plan, pendientes[idx], evals[idx])
        isinf(c) && return seq, plan, false
        deleteat!(pendientes, idx)
    end
    return seq, limpiar_huecos!(plan), true
end

const REPARACION = [reparar_aleatorio, reparar_spt, reparar_arrepentimiento]
const NOMBRES_REPARACION = ["voraz_aleatorio", "voraz_spt", "arrepentimiento"]
