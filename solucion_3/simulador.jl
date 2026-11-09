# ============================================================
# simulador.jl — Decodificador: secuencias de máquinas -> programa completo
# ============================================================
# Una solución es seq[j] = lista ordenada de lotes de la máquina j.
# El simulador decide los viajes de los AGVs con reglas de despacho
# y calcula los tiempos de cada lote. Para el k-ésimo lote de j:
#   llegada[k]  : entrega en el buffer de entrada alfa_j
#   inicio[k]   = max(llegada[k], salida[k-1])
#   fin[k]      = inicio[k] + p
#   salida[k]   = max(fin[k], recojo[k-1])   (pasa al buffer beta_j)
#   recojo[k]   : un AGV lo retira de beta_j
# Con esto se respetan buffers de capacidad 1 y el bloqueo.

struct Operacion
    agv::Int
    tipo::Symbol        # :carga o :descarga
    lote::Int
    lugar::Int          # índice de ubicación en tau
    tiempo::Float64
end

mutable struct Estado
    seq::Vector{Vector{Int}}
    llegada::Vector{Vector{Float64}}
    inicio::Vector{Vector{Float64}}
    fin::Vector{Vector{Float64}}
    salida::Vector{Vector{Float64}}
    recojo::Vector{Vector{Float64}}
    n_abast::Vector{Int}      # lotes ya llevados a cada máquina
    n_retir::Vector{Int}      # lotes ya retirados de cada máquina
    t_agv::Vector{Float64}
    pos_agv::Vector{Int}
    carga_agv::Vector{Int}    # lotes a bordo de cada AGV
    c::Vector{Float64}        # tiempo de finalización de cada lote
    ops::Vector{Operacion}
end

desconocido(x) = isnan(x)

function vectores_nan(seq)
    return [fill(NaN, length(s)) for s in seq]
end

function estado_inicial(ins, seq)
    J, K = num_maquinas(ins), ins.K
    v() = vectores_nan(seq)
    return Estado(seq, v(), v(), v(), v(), v(), zeros(Int, J), zeros(Int, J),
                  zeros(K), fill(pos_o(ins), K), zeros(Int, K), fill(NaN, num_lotes(ins)), Operacion[])
end

# --- Propagación de tiempos en una máquina --------------------

function calcular_inicio!(e, ins, j, k)
    previo = k == 1 ? 0.0 : e.salida[j][k-1]
    (desconocido(e.llegada[j][k]) || desconocido(previo)) && return
    e.inicio[j][k] = max(e.llegada[j][k], previo)
    e.fin[j][k] = e.inicio[j][k] + tiempo_proceso(ins, e.seq[j][k], j)
end

function calcular_salida!(e, j, k)
    previo = k == 1 ? 0.0 : e.recojo[j][k-1]
    (desconocido(e.fin[j][k]) || desconocido(previo)) && return
    e.salida[j][k] = max(e.fin[j][k], previo)
end

function propagar!(e, ins, j)
    for k in 1:length(e.seq[j])
        desconocido(e.inicio[j][k]) && calcular_inicio!(e, ins, j, k)
        desconocido(e.salida[j][k]) && calcular_salida!(e, j, k)
    end
end

# --- Trabajos disponibles para los AGVs ------------------------

# Abastecer el siguiente lote de j: el buffer alfa_j se libera
# cuando el lote anterior empieza a procesarse.
function listo_abastecer(e, j)
    k = e.n_abast[j] + 1
    k > length(e.seq[j]) && return NaN
    return k == 1 ? 0.0 : e.inicio[j][k-1]
end

# Retirar el siguiente lote de j: debe estar ya en beta_j.
function listo_retirar(e, j)
    k = e.n_retir[j] + 1
    k > e.n_abast[j] && return NaN
    return e.salida[j][k]
end
