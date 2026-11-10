# ============================================================
# vecindades.jl — Movimientos sobre (secuencias, plan de AGVs)
# ============================================================
# V1 mover_parada      : una parada pasa a otro viaje/posición (mismo u otro AGV)
# V2 intercambiar_par. : dos paradas del mismo tipo cambian de lugar en el plan
# V3 fusionar_viajes   : dos viajes consecutivos de un AGV se hacen uno (multicarga)
# V4 dividir_viaje     : un viaje se parte en dos
# V5 mover_viaje       : un viaje completo pasa a otro AGV
# V6 intercambiar_lotes: dos lotes compatibles intercambian máquina/posición
#                        Y su lugar en el plan (los viajes no cambian de forma)
# V7 reubicar_lote     : un lote cambia de máquina/posición y sus paradas se
#                        reinsertan junto a las de sus nuevos vecinos
# V8 insertar_visita   : agrega una visita a o o a f en medio de un viaje
#                        (rutas o→α→β→o→… o pasar por f sin terminar el viaje)
# V9 quitar_visita     : elimina una visita intermedia a o o a f
# V10 unir_por_o       : une dos viajes seguidos de un AGV pasando por o, sin
#                        ir a f entre medio (lleva lotes terminados "de paseo")
# Los viajes candidatos se toman "cercanos en el tiempo": misma fracción
# del plan ± 2 viajes, porque mover una parada muy lejos casi siempre
# produce esperas largas o bloqueos mutuos.

copiar_plan(plan) = [[copy(v) for v in viajes] for viajes in plan]
copiar_seq(seq) = [copy(s) for s in seq]

# Quita los viajes que no tienen paradas en máquinas (vacíos o solo visitas)
tiene_paradas(v) = any(p -> !es_visita(p), v)
limpiar!(plan) = (foreach(viajes -> filter!(tiene_paradas, viajes), plan); plan)

function parada_aleatoria(plan, rng)
    a = rand(rng, [a for a in eachindex(plan) if any(!isempty, plan[a])])
    v = rand(rng, [v for v in eachindex(plan[a]) if !isempty(plan[a][v])])
    return a, v, rand(rng, eachindex(plan[a][v]))
end

# Viaje del AGV a2 que ocurre aproximadamente cuando el viaje v del AGV a
function viaje_cercano(plan, a, v, a2, rng)
    n2 = length(plan[a2])
    n2 == 0 && return 0
    centro = round(Int, v / max(1, length(plan[a])) * n2)
    return clamp(centro + rand(rng, -2:2), 1, n2)
end

# --- V1 ---------------------------------------------------------
function insertar_parada!(plan, a2, v2, p, rng)
    if v2 == 0 || rand(rng) < 0.1          # a veces como viaje propio
        insert!(plan[a2], clamp(v2, 1, length(plan[a2]) + 1), [p])
    else
        insert!(plan[a2][v2], rand(rng, 1:length(plan[a2][v2])+1), p)
    end
end

function mover_parada(seq, plan, rng)
    nuevo = copiar_plan(plan)
    a, v, k = parada_aleatoria(nuevo, rng)
    p = popat!(nuevo[a][v], k)
    a2 = rand(rng, eachindex(nuevo))
    insertar_parada!(nuevo, a2, viaje_cercano(nuevo, a, v, a2, rng), p, rng)
    return seq, limpiar!(nuevo)
end

# --- V2 ---------------------------------------------------------
function intercambiar_paradas(seq, plan, rng)
    nuevo = copiar_plan(plan)
    a, v, k = parada_aleatoria(nuevo, rng)
    a2 = rand(rng, eachindex(nuevo))
    v2 = viaje_cercano(nuevo, a, v, a2, rng)
    v2 == 0 && return seq, plan
    k2 = rand(rng, eachindex(nuevo[a2][v2]))
    nuevo[a][v][k], nuevo[a2][v2][k2] = nuevo[a2][v2][k2], nuevo[a][v][k]
    return seq, limpiar!(nuevo)     # un viaje pudo quedar solo con una visita
end

# --- V3 y V4 ----------------------------------------------------
function fusionar_viajes(seq, plan, rng)
    candidatos = [a for a in eachindex(plan) if length(plan[a]) >= 2]
    isempty(candidatos) && return seq, plan
    nuevo, a = copiar_plan(plan), rand(rng, candidatos)
    v = rand(rng, 1:length(nuevo[a])-1)
    append!(nuevo[a][v], popat!(nuevo[a], v + 1))
    return seq, nuevo
end

function dividir_viaje(seq, plan, rng)
    nuevo = copiar_plan(plan)
    a, v, k = parada_aleatoria(nuevo, rng)
    length(nuevo[a][v]) < 2 && return seq, plan
    corte = max(k, 2)
    insert!(nuevo[a], v + 1, nuevo[a][v][corte:end])
    resize!(nuevo[a][v], corte - 1)
    return seq, nuevo
end

# --- V5 ---------------------------------------------------------
function mover_viaje(seq, plan, rng)
    ins_K = length(plan)
    ins_K < 2 && return seq, plan
    nuevo = copiar_plan(plan)
    a, v, _ = parada_aleatoria(nuevo, rng)
    a2 = rand(rng, setdiff(1:ins_K, a))
    destino = max(1, viaje_cercano(nuevo, a, v, a2, rng))
    insert!(nuevo[a2], min(destino, length(nuevo[a2]) + 1), popat!(nuevo[a], v))
    return seq, nuevo
end

# --- V6 ---------------------------------------------------------
renombrar(p, x, y) = p.lote == x ? Parada(p.abastece, y) : p.lote == y ? Parada(p.abastece, x) : p

function intercambiar_lotes(ins, seq, plan, rng)
    x, y, ubic = rand(rng, 1:num_lotes(ins)), rand(rng, 1:num_lotes(ins)), ubicar_lotes(seq)
    j1, k1 = ubic[x]
    j2, k2 = ubic[y]
    (x == y || !compatible(ins, x, j2) || !compatible(ins, y, j1)) && return seq, plan
    nueva = copiar_seq(seq)
    nueva[j1][k1], nueva[j2][k2] = y, x
    return nueva, [[renombrar.(v, x, y) for v in viajes] for viajes in plan]
end

# --- V7 ---------------------------------------------------------
function buscar_parada(plan, lote, abastece)
    for a in eachindex(plan), v in eachindex(plan[a]), k in eachindex(plan[a][v])
        p = plan[a][v][k]
        p.lote == lote && p.abastece == abastece && return a, v, k
    end
end

quitar_parada!(plan, lote, abastece) = ((a, v, k) = buscar_parada(plan, lote, abastece); deleteat!(plan[a][v], k))

# Inserta la parada del lote justo antes de la del sucesor en la máquina
# (o justo después de la del antecesor si es el último)
function reinsertar!(plan, s, j, k, lote, abastece)
    vecino, despues = k < length(s[j]) ? (s[j][k+1], 0) : (k > 1 ? (s[j][k-1], 1) : (0, 0))
    vecino == 0 && return push!(plan[1], [Parada(abastece, lote)])
    a, v, pos = buscar_parada(plan, vecino, abastece)
    insert!(plan[a][v], pos + despues, Parada(abastece, lote))
end

function reubicar_lote(ins, seq, plan, rng)
    x = rand(rng, 1:num_lotes(ins))
    nueva, nuevo = copiar_seq(seq), copiar_plan(plan)
    j1, k1 = ubicar_lotes(seq)[x]
    deleteat!(nueva[j1], k1)
    j2 = rand(rng, maquinas_compatibles(ins, x))
    k2 = clamp(k1 + rand(rng, -2:2), 1, length(nueva[j2]) + 1)
    insert!(nueva[j2], k2, x)
    for abastece in (true, false)
        quitar_parada!(nuevo, x, abastece)
        reinsertar!(nuevo, nueva, j2, k2, x, abastece)
    end
    return nueva, limpiar!(nuevo)
end

# --- V8, V9 y V10: visitas intermedias a o y f ----------------------
function insertar_visita(seq, plan, rng)
    nuevo = copiar_plan(plan)
    a, v, k = parada_aleatoria(nuevo, rng)
    insert!(nuevo[a][v], k + rand(rng, 0:1), rand(rng, (VISITA_O, VISITA_F)))
    return seq, nuevo
end

function visitas(plan)
    return [(a, v, k) for a in eachindex(plan) for v in eachindex(plan[a])
            for k in eachindex(plan[a][v]) if es_visita(plan[a][v][k])]
end

function quitar_visita(seq, plan, rng)
    lista = visitas(plan)
    isempty(lista) && return seq, plan
    nuevo, (a, v, k) = copiar_plan(plan), rand(rng, lista)
    deleteat!(nuevo[a][v], k)
    return seq, limpiar!(nuevo)
end

function unir_por_o(seq, plan, rng)
    candidatos = [a for a in eachindex(plan) if length(plan[a]) >= 2]
    isempty(candidatos) && return seq, plan
    nuevo, a = copiar_plan(plan), rand(rng, candidatos)
    v = rand(rng, 1:length(nuevo[a])-1)
    append!(nuevo[a][v], vcat([VISITA_O], popat!(nuevo[a], v + 1)))
    return seq, nuevo
end

# Lista de vecindades (todas con la firma (ins, seq, plan, rng))
const VECINDADES = [
    (ins, s, p, r) -> mover_parada(s, p, r),
    (ins, s, p, r) -> intercambiar_paradas(s, p, r),
    (ins, s, p, r) -> fusionar_viajes(s, p, r),
    (ins, s, p, r) -> dividir_viaje(s, p, r),
    (ins, s, p, r) -> mover_viaje(s, p, r),
    intercambiar_lotes,
    reubicar_lote,
    (ins, s, p, r) -> insertar_visita(s, p, r),
    (ins, s, p, r) -> quitar_visita(s, p, r),
    (ins, s, p, r) -> unir_por_o(s, p, r),
]
const NOMBRES_VECINDADES = ["mover_parada", "intercambiar_paradas", "fusionar_viajes",
                            "dividir_viaje", "mover_viaje", "intercambiar_lotes", "reubicar_lote",
                            "insertar_visita", "quitar_visita", "unir_por_o"]
