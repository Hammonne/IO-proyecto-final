# ============================================================
# secuencia.jl — Representación por SECUENCIA DE INSERCIÓN (Yin y Hu, 2026)
# ============================================================
# En Yin y Hu (2026) toda la solución es una permutación de los trabajos
# (el orden en que los vehículos los atienden); qué vehículo hace cada
# trabajo NO se decide: lo toma el que lo atiende antes (eq. 26), y el
# orden de las grúas se deduce de la misma permutación. Adaptación:
#   - tareas: abastecer el lote i (t = +i) y retirarlo (t = −i): 2n tareas
#   - solución = (máquina de cada lote, secuencia Y de las 2n tareas)
#   - el orden de cada máquina = orden de sus abastecimientos en Y
#   - decodificación (análoga a su SIA): se recorre Y y cada tarea se
#     agrega al AGV y a la forma (viaje nuevo, al final del último viaje o
#     tras una visita a o/f) en que se atiende ANTES. Los tiempos se
#     calculan con el decodificador exacto de la solución 4 sobre el plan
#     parcial, así que respeta buffers, bloqueo y capacidad.
#   - reparación (análoga a su método A1): los retiros de cada máquina se
#     reordenan para seguir el orden de la máquina, y un retiro que aparece
#     antes que su abastecimiento se atiende justo después de este.
# Diferencia con el paper: allí cada vehículo lleva 1 contenedor; aquí un
# AGV lleva hasta C lotes, por eso existe la opción de agregar la tarea al
# viaje en curso.

struct SolSecuencia
    asig::Vector{Int}    # máquina de cada lote
    Y::Vector{Int}       # secuencia de inserción de las 2n tareas
end

function secuencias_de(ins, s)
    seq = [Int[] for _ in 1:num_maquinas(ins)]
    for t in s.Y
        t > 0 && push!(seq[s.asig[t]], t)
    end
    return seq
end

# --- Reparación de la secuencia (análoga a A1) ---------------------------

function ordenar_retiros(s, seq)
    Y = copy(s.Y)
    for j in eachindex(seq)
        lugares = [k for (k, t) in enumerate(Y) if t < 0 && s.asig[-t] == j]
        for (m, k) in enumerate(lugares)
            Y[k] = -seq[j][m]
        end
    end
    return Y
end

function orden_tareas(ins, s, seq)
    hecho, orden, espera = falses(num_lotes(ins)), Int[], Set{Int}()
    for t in ordenar_retiros(s, seq)
        t < 0 && !hecho[-t] && (push!(espera, -t); continue)
        push!(orden, t)
        t > 0 || continue
        hecho[t] = true
        t in espera && (delete!(espera, t); push!(orden, -t))
    end
    return orden
end

# --- Decodificación (análoga al SIA) ------------------------------------

# Formas de agregar la tarea t al AGV a: al final de su último viaje,
# tras una visita a o (abastecer) o a f (retirar), o como viaje nuevo
function opciones(plan, a, t)
    p, out = Parada(t > 0, abs(t)), Plan[]
    for extra in (Parada[], [t > 0 ? VISITA_O : VISITA_F])
        isempty(plan[a]) && break
        q = copiar_plan(plan)
        append!(q[a][end], vcat(extra, [p]))
        push!(out, q)
    end
    q = copiar_plan(plan)
    push!(q[a], [p])
    return push!(out, q)
end

function instante(e, seq, t)
    j, k = ubicar_lotes(seq)[abs(t)]
    return t > 0 ? e.llegada[j][k] : e.recojo[j][k]
end

# Criterio para elegir la opción: suma de los instantes de TODAS las
# tareas ya agregadas (no solo la nueva), para no elegir una opción que
# atienda antes la tarea nueva pero retrase a otras (bloqueos en máquinas)
suma_instantes(e) = sum(x for v in (e.llegada, e.recojo) for m in v for x in m if !isnan(x); init = 0.0)

const CRITERIO = Ref(:suma)
costo_opcion(e, seq, t) = CRITERIO[] == :suma ? suma_instantes(e) : instante(e, seq, t)

function agregar_tarea(ins, seqp, plan, t)
    mejor, tmin = plan, Inf
    for a in 1:ins.K, p in opciones(plan, a, t)
        e, ok = decodificar(ins, seqp, p)
        ok || continue
        x = costo_opcion(e, seqp, t)
        x < tmin - 1e-9 && ((mejor, tmin) = (p, x))
    end
    return mejor, isfinite(tmin)
end

# Devuelve (secuencias, plan, valor); valor = Inf si alguna tarea no cabe
function decodificar_secuencia(ins, s)
    seq = secuencias_de(ins, s)
    seqp, plan = [Int[] for _ in seq], Plan([Viaje[] for _ in 1:ins.K])
    for t in orden_tareas(ins, s, seq)
        t > 0 && push!(seqp[s.asig[t]], t)
        plan, ok = agregar_tarea(ins, seqp, plan, t)
        ok || return seq, plan, Inf
    end
    return seq, plan, evaluar_plan(ins, seq, plan)
end

# --- Secuencia inicial a partir de una solución (seq, plan) ---------------

function secuencia_desde(ins, seq, plan)
    e, _ = decodificar(ins, seq, plan)
    asig, tareas = zeros(Int, num_lotes(ins)), Tuple{Float64,Int}[]
    for j in eachindex(seq), (k, i) in enumerate(seq[j])
        asig[i] = j
        push!(tareas, (e.llegada[j][k], i), (e.recojo[j][k], -i))
    end
    return SolSecuencia(asig, last.(sort(tareas)))
end
