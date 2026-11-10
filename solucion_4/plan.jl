# ============================================================
# plan.jl — Plan explícito de los AGVs y su decodificador
# ============================================================
# A diferencia de la solución 2 (donde reglas de despacho deciden los
# viajes), aquí cada AGV tiene una lista de VIAJES fijada por la solución:
#   plan[a] = [viaje_1, viaje_2, ...]
#   viaje   = paradas en orden; cada parada abastece un lote en su alfa_j
#             o retira un lote de su beta_j
# Ruta de un viaje: si abastece algo, va a o y carga esos lotes; recorre
# sus paradas en orden; si retiró algo, termina en f y lo descarga.
# El decodificador calcula los tiempos de todo el sistema (camino más
# largo en el grafo de precedencias). Si hay un ciclo de esperas
# (bloqueo mutuo) o se supera la capacidad, el plan es infactible.

struct Parada
    abastece::Bool   # true: deja el lote en alfa_j; false: lo retira de beta_j
    lote::Int        # lote < 0: HUECO dejado por el lote -lote al destruir (ALNS)
end

# Los huecos guardan el lugar de una parada en su viaje mientras el lote
# está fuera de la solución; el decodificador los salta.
es_real(p) = p.lote > 0

const Viaje = Vector{Parada}
const Plan = Vector{Vector{Viaje}}

mutable struct Cursor
    viaje::Int               # viaje actual del AGV
    parada::Int              # 0 = viaje sin empezar
    t::Float64
    pos::Int
    retirados::Vector{Int}   # lotes a bordo que van a f
end

# Posición (máquina, orden) de cada lote según las secuencias
function ubicar_lotes(seq)
    ubic = Dict{Int,Tuple{Int,Int}}()
    for j in eachindex(seq), k in eachindex(seq[j])
        ubic[seq[j][k]] = (j, k)
    end
    return ubic
end

# Carga máxima a bordo durante el viaje (se carga todo lo que abastece en o)
function carga_maxima(viaje)
    carga = count(p -> p.abastece && es_real(p), viaje)
    maxima = carga
    for p in Iterators.filter(es_real, viaje)
        carga += p.abastece ? -1 : 1
        maxima = max(maxima, carga)
    end
    return maxima
end

capacidad_ok(ins, plan) = all(carga_maxima(v) <= ins.C for viajes in plan for v in viajes)

# --- Pasos del decodificador -----------------------------------

function mover_a!(cur, ins, destino)
    cur.t += ins.tau[cur.pos, destino]
    cur.pos = destino
end

function iniciar_viaje!(e, ins, a, cur, viaje)
    any(p -> p.abastece && es_real(p), viaje) || return
    mover_a!(cur, ins, pos_o(ins))
    for p in Iterators.filter(es_real, viaje)
        p.abastece && push!(e.ops, Operacion(a, :carga, p.lote, pos_o(ins), cur.t))
    end
end

function cerrar_viaje!(e, ins, a, cur)
    isempty(cur.retirados) && return
    mover_a!(cur, ins, pos_f(ins))
    for i in cur.retirados
        e.c[i] = cur.t
        push!(e.ops, Operacion(a, :descarga, i, pos_f(ins), cur.t))
    end
    empty!(cur.retirados)
end

# Instante desde el que se puede atender la parada (NaN = aún desconocido)
function listo_parada(e, p, j, k)
    p.abastece || return e.salida[j][k]           # el lote debe estar en beta_j
    return k == 1 ? 0.0 : e.inicio[j][k-1]        # alfa_j se libera al iniciar el anterior
end

function atender!(e, ins, a, cur, p, j, k)
    mover_a!(cur, ins, p.abastece ? pos_alfa(ins, j) : pos_beta(ins, j))
    cur.t = max(cur.t, listo_parada(e, p, j, k))
    tipo = p.abastece ? :descarga : :carga
    push!(e.ops, Operacion(a, tipo, p.lote, cur.pos, cur.t))
    p.abastece ? (e.llegada[j][k] = cur.t) : (e.recojo[j][k] = cur.t; push!(cur.retirados, p.lote))
    propagar!(e, ins, j)
end

# Un paso del AGV a: devuelve :fin, :bloqueado o :avanzo
function paso!(e, ins, plan, ubic, a, cur)
    cur.viaje > length(plan[a]) && return :fin
    viaje = plan[a][cur.viaje]
    if cur.parada == 0
        iniciar_viaje!(e, ins, a, cur, viaje)
    elseif cur.parada > length(viaje)
        cerrar_viaje!(e, ins, a, cur)
        cur.viaje, cur.parada = cur.viaje + 1, -1
    elseif es_real(viaje[cur.parada])
        p = viaje[cur.parada]
        j, k = ubic[p.lote]
        desconocido(listo_parada(e, p, j, k)) && return :bloqueado
        atender!(e, ins, a, cur, p, j, k)
    end
    cur.parada += 1
    return :avanzo
end

# Avanza al AGV hasta que termine o quede esperando a otro recurso
function avanzar!(e, ins, plan, ubic, a, cur)
    avanzo = false
    while (r = paso!(e, ins, plan, ubic, a, cur)) == :avanzo
        avanzo = true
    end
    return avanzo, r == :fin
end

# Decodifica el plan: devuelve el estado y si es factible
function decodificar(ins, seq, plan)
    e, ubic = estado_inicial(ins, seq), ubicar_lotes(seq)
    cursores = [Cursor(1, 0, 0.0, pos_o(ins), Int[]) for _ in 1:ins.K]
    capacidad_ok(ins, plan) || return e, false
    while true
        resultados = [avanzar!(e, ins, plan, ubic, a, cursores[a]) for a in 1:ins.K]
        all(last, resultados) && return e, true
        any(first, resultados) || return e, false    # nadie avanza: bloqueo mutuo
    end
end

function evaluar_plan(ins, seq, plan)
    e, ok = decodificar(ins, seq, plan)
    return ok ? sum(e.c) / num_lotes(ins) : Inf
end

# --- Conversión desde la solución 2 ----------------------------
# Reconstruye los viajes a partir de las operaciones simuladas por las
# reglas de despacho: un viaje se cierra al descargar en f o al volver a o.

function parada_de_op(ins, op)
    op.tipo == :descarga && op.lugar != pos_f(ins) && return Parada(true, op.lote)
    op.tipo == :carga && op.lugar != pos_o(ins) && return Parada(false, op.lote)
    return nothing
end

function viajes_de_agv(ins, ops, a)
    viajes, actual = Viaje[], Parada[]
    for op in filter(op -> op.agv == a, ops)
        cierra = op.lugar == pos_f(ins) || (op.lugar == pos_o(ins) && op.tipo == :carga)
        cierra && !isempty(actual) && (push!(viajes, actual); actual = Parada[])
        p = parada_de_op(ins, op)
        p === nothing || push!(actual, p)
    end
    isempty(actual) || push!(viajes, actual)
    return viajes
end

plan_desde_estado(ins, e) = [viajes_de_agv(ins, e.ops, a) for a in 1:ins.K]
