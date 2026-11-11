# ============================================================
# murty.jl — Las K mejores asignaciones de lotes a máquinas (Murty, 1968)
# ============================================================
# La asignación de asignacion.jl (método húngaro para R||ΣC, sin transporte)
# da la MEJOR asignación de lotes a (máquina, posición). Pero la mejor
# solución de la 01 no usa esa asignación: usa una "casi óptima" (dos lotes
# intercambiados), porque combina mejor los viajes de los AGVs.
# Murty (1968) lista las asignaciones en orden de costo: 1.ª, 2.ª, 3.ª...
# Se parte el espacio de soluciones en subproblemas con pares forzados y
# prohibidos, y cada subproblema se resuelve con el húngaro.
# Aquí se usa solo para generar PUNTOS DE PARTIDA distintos para la tabú
# (multi-arranque); la búsqueda sigue siendo local.

const PROHIBIDO = 1e9
const Par = Tuple{Int,Int}                     # (lote, columna = (máquina, posición))

pares(fila_de) = [(i, c) for (c, i) in enumerate(fila_de) if i != 0]
costo_total(costo, fila_de) = sum(costo[i, c] for (i, c) in pares(fila_de))

function forzar!(C, (i, c))
    v = C[i, c]
    C[i, :] .= PROHIBIDO
    C[:, c] .= PROHIBIDO
    C[i, c] = v
end

# Resuelve el subproblema; nothing si es infactible
function resolver_nodo(costo, forzados, prohibidos)
    C = copy(costo)
    foreach(((i, c),) -> C[i, c] = PROHIBIDO, prohibidos)
    foreach(par -> forzar!(C, par), forzados)
    fila_de = hungaro(C)
    val = costo_total(C, fila_de)
    return val < PROHIBIDO / 2 ? (val, fila_de) : nothing
end

# Partición de Murty: el hijo t fuerza los pares libres 1..t-1 y prohíbe el t
function hijos(costo, fila_de, forzados, prohibidos)
    libres = setdiff(pares(fila_de), forzados)
    salida = []
    for t in eachindex(libres)
        F, P = vcat(forzados, libres[1:t-1]), vcat(prohibidos, [libres[t]])
        r = resolver_nodo(costo, F, P)
        r === nothing || push!(salida, (r..., F, P))
    end
    return salida
end

function k_mejores_asignaciones(costo, K)
    raiz = resolver_nodo(costo, Par[], Par[])
    cola, salida = [(raiz..., Par[], Par[])], []
    while !isempty(cola) && length(salida) < K
        val, fila_de, F, P = popat!(cola, argmin(first.(cola)))
        push!(salida, (val, fila_de))
        append!(cola, hijos(costo, fila_de, F, P))
    end
    return salida
end

# Secuencias por máquina (k grande = va primero), como en asignacion.jl
function seq_desde_asignacion(cols, fila_de, J)
    seq = [Tuple{Int,Int}[] for _ in 1:J]
    for (i, c) in pares(fila_de)
        j, k = cols[c]
        push!(seq[j], (k, i))
    end
    return [[i for (k, i) in sort(s, rev = true)] for s in seq]
end

# Varias asignaciones dan la misma secuencia (posiciones con huecos):
# se quedan solo las secuencias distintas, en orden de costo
function secuencias_distintas(ins, K)
    n, J = num_lotes(ins), num_maquinas(ins)
    costo, cols = matriz_asignacion(ins, min(n, 2 * ceil(Int, n / J) + 5))
    vistas, salida = Set{Vector{Vector{Int}}}(), []
    for (val, fila_de) in k_mejores_asignaciones(costo, K)
        s = seq_desde_asignacion(cols, fila_de, J)
        s in vistas || (push!(vistas, s); push!(salida, (val, s)))
    end
    return salida
end
