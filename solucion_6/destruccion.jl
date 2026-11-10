# ============================================================
# destruccion.jl — Operadores de destrucción del ALNS
# ============================================================
# Cada operador elige q lotes para sacar de la solución (de su máquina
# y sus dos paradas del plan de AGVs). Luego un operador de reparación
# los vuelve a insertar. Firma común: (ins, seq, plan, e, q, rng) -> lotes
#   D1 aleatorio    : q lotes al azar (diversificación pura)
#   D2 relacionados : lotes que se procesan cerca en el tiempo y son del
#                     mismo tipo (Shaw, 1998): al reinsertarlos juntos se
#                     pueden reordenar entre sí y entre máquinas
#   D3 peores       : lotes con más tiempo perdido (máquina ociosa esperando
#                     su llegada + espera desde que termina hasta llegar a f)
#                     (worst removal, Ropke y Pisinger, 2006)
#   D4 viajes       : todos los lotes de varios viajes seguidos de un AGV
#                     (rehace un tramo completo del transporte)
#   D5 segmento     : un tramo de lotes consecutivos de una máquina

const POTENCIA_SHAW, POTENCIA_PEORES = 6.0, 3.0

# Elige q elementos de una lista ordenada, sesgado hacia los primeros:
# índice = piso(u^p · tamaño), u uniforme (Ropke y Pisinger, 2006)
function elegir_sesgado(candidatos, q, potencia, rng)
    restantes, elegidos = collect(candidatos), Int[]
    while length(elegidos) < q && !isempty(restantes)
        idx = 1 + floor(Int, rand(rng)^potencia * length(restantes))
        push!(elegidos, popat!(restantes, idx))
    end
    return elegidos
end

# Inicio de proceso y tiempo perdido de cada lote en la solución actual
function tiempos_lote(e, seq, n)
    inicio, perdido = zeros(n), zeros(n)
    for j in eachindex(seq), k in eachindex(seq[j])
        i, libre = seq[j][k], k == 1 ? 0.0 : e.salida[j][k-1]
        inicio[i] = e.inicio[j][k]
        perdido[i] = max(0.0, e.llegada[j][k] - libre) + (e.c[i] - e.fin[j][k])
    end
    return inicio, perdido
end

quitar_aleatorios(ins, seq, plan, e, q, rng) = shuffle(rng, 1:num_lotes(ins))[1:min(q, end)]

function quitar_relacionados(ins, seq, plan, e, q, rng)
    inicio, _ = tiempos_lote(e, seq, num_lotes(ins))
    x, escala = rand(rng, 1:num_lotes(ins)), escala_viaje(ins)
    relacion(y) = abs(inicio[y] - inicio[x]) / escala + (ins.r[y] == ins.r[x] ? 0.0 : 1.0)
    return elegir_sesgado(sort(1:num_lotes(ins), by = relacion), q, POTENCIA_SHAW, rng)
end

function quitar_peores(ins, seq, plan, e, q, rng)
    _, perdido = tiempos_lote(e, seq, num_lotes(ins))
    return elegir_sesgado(sortperm(perdido, rev = true), q, POTENCIA_PEORES, rng)
end

function quitar_viajes(ins, seq, plan, e, q, rng)
    a = rand(rng, [a for a in eachindex(plan) if !isempty(plan[a])])
    v, lotes = rand(rng, eachindex(plan[a])), Int[]
    while v <= length(plan[a]) && length(unique(lotes)) < q
        append!(lotes, [p.lote for p in plan[a][v] if es_real(p)])
        v += 1
    end
    return unique(lotes)[1:min(q, end)]
end

function quitar_segmento(ins, seq, plan, e, q, rng)
    j = rand(rng, [j for j in eachindex(seq) if !isempty(seq[j])])
    k = rand(rng, eachindex(seq[j]))
    return seq[j][k:min(k + q - 1, end)]
end

const DESTRUCCION = [quitar_aleatorios, quitar_relacionados, quitar_peores, quitar_viajes, quitar_segmento]
const NOMBRES_DESTRUCCION = ["aleatorio", "relacionados", "peores", "viajes", "segmento"]

# Posición de referencia de cada lote quitado: su máquina, la fracción de
# la secuencia donde estaba (para buscar posiciones cercanas en el tiempo)
function referencias(seq, quitados)
    ref = Dict{Int,Tuple{Int,Float64}}()
    for j in eachindex(seq)
        quedan = 0
        for x in seq[j]
            x in quitados ? (ref[x] = (j, quedan / max(1, length(seq[j]) - 1))) : (quedan += 1)
        end
    end
    return ref
end

# Saca los lotes de las secuencias; sus paradas quedan como HUECOS en sus
# viajes, para que la reparación pueda reusar la estructura de transporte
function quitar_lotes(seq, plan, lotes)
    quitados = Set(lotes)
    s, p, ref = copiar_seq(seq), copiar_plan(plan), referencias(seq, quitados)
    foreach(m -> filter!(x -> !(x in quitados), m), s)
    for viajes in p, v in viajes, k in eachindex(v)
        v[k].lote in quitados && (v[k] = Parada(v[k].abastece, -v[k].lote))
    end
    return s, p, ref
end
