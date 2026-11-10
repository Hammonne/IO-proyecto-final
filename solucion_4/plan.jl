# ============================================================
# plan.jl — Plan explícito de los AGVs y su decodificador
# ============================================================
# A diferencia de la solución 2 (donde reglas de despacho deciden los
# viajes), aquí cada AGV tiene una lista de VIAJES fijada por la solución:
#   plan[a] = [viaje_1, viaje_2, ...]
#   viaje   = paradas en orden; cada parada abastece un lote en su alfa_j
#             o retira un lote de su beta_j
# Ruta de un viaje: recorre sus paradas en orden. Además de las paradas
# en máquinas puede tener VISITAS explícitas a o y a f en cualquier punto:
#   - cada lote se carga en la última visita a o antes de su entrega
#     (al inicio del viaje hay una visita a o implícita si hace falta)
#   - cada lote retirado se descarga en la primera visita a f después de
#     recogerlo (al final del viaje hay una visita a f implícita si hace falta)
# Así se permiten rutas como o→α→β→o→α→β→f (volver a o con lotes
# terminados a bordo) u o→α→β→f→α (pasar por f a mitad de viaje).
# El decodificador calcula los tiempos de todo el sistema (camino más
# largo en el grafo de precedencias). Si hay un ciclo de esperas
# (bloqueo mutuo) o se supera la capacidad, el plan es infactible.

struct Parada
    abastece::Bool   # true: deja el lote en alfa_j; false: lo retira de beta_j
    lote::Int        # lote < 0: HUECO dejado por el lote -lote al destruir (ALNS)
                     # lote = 0: VISITA a o (abastece = true) o a f (false)
end

# Los huecos guardan el lugar de una parada en su viaje mientras el lote
# está fuera de la solución; el decodificador los salta.
es_real(p) = p.lote > 0
es_visita(p) = p.lote == 0
visita_o(p) = es_visita(p) && p.abastece
visita_f(p) = es_visita(p) && !p.abastece
const VISITA_O, VISITA_F = Parada(true, 0), Parada(false, 0)

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

# Lotes que se cargan en la visita a o ubicada en la posición k del viaje
# (k = 0: visita implícita al inicio): los que se entregan antes de la
# siguiente visita a o
function cargas_desde(viaje, k)
    lotes = Int[]
    for p in @view viaje[k+1:end]
        visita_o(p) && break
        p.abastece && es_real(p) && push!(lotes, p.lote)
    end
    return lotes
end

# Carga máxima a bordo a lo largo de la ruta del viaje
function carga_maxima(viaje)
    carga, terminados = length(cargas_desde(viaje, 0)), 0
    maxima = carga
    for (k, p) in enumerate(viaje)
        visita_o(p) && (carga += length(cargas_desde(viaje, k)))
        visita_f(p) && (carga -= terminados; terminados = 0)
        es_real(p) && (carga += p.abastece ? -1 : 1; terminados += p.abastece ? 0 : 1)
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

# Va a o y carga los lotes del tramo que empieza en la posición k
function visitar_o!(e, ins, a, cur, viaje, k)
    lotes = cargas_desde(viaje, k)
    isempty(lotes) && return
    mover_a!(cur, ins, pos_o(ins))
    for i in lotes
        push!(e.ops, Operacion(a, :carga, i, pos_o(ins), cur.t))
    end
end

# Va a f y descarga los lotes terminados a bordo (si los hay)
function visitar_f!(e, ins, a, cur)
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

# Atiende la parada actual del viaje: visita, hueco (se salta) o máquina
function atender_parada!(e, ins, ubic, a, cur, viaje)
    p = viaje[cur.parada]
    visita_o(p) && return visitar_o!(e, ins, a, cur, viaje, cur.parada)
    visita_f(p) && return visitar_f!(e, ins, a, cur)
    es_real(p) || return
    j, k = ubic[p.lote]
    desconocido(listo_parada(e, p, j, k)) && return :bloqueado
    atender!(e, ins, a, cur, p, j, k)
end

# Un paso del AGV a: devuelve :fin, :bloqueado o :avanzo
function paso!(e, ins, plan, ubic, a, cur)
    cur.viaje > length(plan[a]) && return :fin
    viaje = plan[a][cur.viaje]
    if cur.parada == 0
        visitar_o!(e, ins, a, cur, viaje, 0)
    elseif cur.parada > length(viaje)
        visitar_f!(e, ins, a, cur)
        cur.viaje, cur.parada = cur.viaje + 1, -1
    elseif atender_parada!(e, ins, ubic, a, cur, viaje) == :bloqueado
        return :bloqueado
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

# --- Reconstrucción del plan desde operaciones ---------------------
# A partir de las operaciones de un AGV (simuladas por la solución 2 o
# leídas de un TXT de IO1Lab) se rearma su plan. Un viaje se cierra
# cuando el AGV queda vacío (al pasar por o o al descargar en f); si pasa
# por o o por f llevando lotes, se agrega una VISITA explícita.

mutable struct Reconstruccion
    viajes::Vector{Viaje}
    actual::Viaje
    cargados::Int      # lotes a bordo que van a una máquina
    terminados::Int    # lotes a bordo que van a f
    ultimo::Symbol     # :o, :f o :maquina (para agrupar operaciones de una misma visita)
end

function cerrar_viaje!(r)
    isempty(r.actual) || push!(r.viajes, r.actual)
    r.actual = Parada[]
end

function llegar_a_o!(r)
    r.ultimo == :o && return
    r.cargados == 0 && r.terminados == 0 ? cerrar_viaje!(r) : push!(r.actual, VISITA_O)
end

function llegar_a_f!(r)
    r.ultimo == :f && return
    r.cargados == 0 ? cerrar_viaje!(r) : push!(r.actual, VISITA_F)
end

function procesar_op!(r, ins, op)
    if op.lugar == pos_o(ins)
        llegar_a_o!(r); r.cargados += 1; r.ultimo = :o
    elseif op.lugar == pos_f(ins)
        llegar_a_f!(r); r.terminados -= 1; r.ultimo = :f
    else
        abastece = op.tipo == :descarga
        push!(r.actual, Parada(abastece, op.lote))
        abastece ? (r.cargados -= 1) : (r.terminados += 1)
        r.ultimo = :maquina
    end
end

function viajes_de_agv(ins, ops, a)
    r = Reconstruccion(Viaje[], Parada[], 0, 0, :maquina)
    foreach(op -> procesar_op!(r, ins, op), filter(op -> op.agv == a, ops))
    cerrar_viaje!(r)
    return r.viajes
end

plan_desde_estado(ins, e) = [viajes_de_agv(ins, e.ops, a) for a in 1:ins.K]
