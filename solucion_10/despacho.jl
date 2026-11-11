# ============================================================
# despacho.jl — Reglas para decidir los viajes de los AGVs
# ============================================================
# Cada vez que un AGV queda libre elige un viaje:
#   - abastecimiento: va a o, carga hasta C lotes y los deja en sus alfa_j
#   - retiro: recoge hasta C lotes de los beta_j y los lleva a f
# Se elige el trabajo que puede atenderse más pronto ("estimado").

viaje(ins, u, v) = ins.tau[u, v]

# Momento en que la máquina j quedará libre y necesitará su siguiente lote
function necesita_lote(e, j)
    k = e.n_abast[j]
    k == 0 && return 0.0
    for t in (e.salida[j][k], e.fin[j][k], e.inicio[j][k])
        desconocido(t) || return t
    end
    return Inf
end

# Máquinas que atiende el AGV a (todas si no hay zonas)
maquinas_de(par, a, ins) = isempty(par.zona) ? (1:num_maquinas(ins)) : findall(==(a), par.zona)

# Prioridad: cuanto antes la máquina necesita el lote, más urgente es
function candidatos_abastecer(e, ins, a, par)
    t0 = e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_o(ins))
    lista = Tuple{Float64,Int}[]
    for j in maquinas_de(par, a, ins)
        listo = listo_abastecer(e, j)
        desconocido(listo) && continue
        entrega = max(t0 + viaje(ins, pos_o(ins), pos_alfa(ins, j)), listo)
        espera = max(0.0, necesita_lote(e, j) - entrega)
        push!(lista, (entrega + par.peso_necesidad * espera, j))
    end
    return sort!(lista)
end

function candidatos_retirar(e, ins, a, par)
    lista = Tuple{Float64,Int}[]
    for j in maquinas_de(par, a, ins)
        listo = listo_retirar(e, j)
        desconocido(listo) && continue
        llegada = e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_beta(ins, j))
        push!(lista, (max(llegada, listo), j))
    end
    return sort!(lista)
end

# Toma el mejor candidato y agrega otros que estén listos poco después
function armar_lote(cands, C, holgura)
    primero = cands[1][1]
    return [j for (est, j) in cands[1:min(C, end)] if est <= primero + holgura]
end

# Ordena las visitas por vecino más cercano
function orden_cercano(ins, desde, maquinas, lugar)
    pendientes, orden = copy(maquinas), Int[]
    while !isempty(pendientes)
        idx = argmin([viaje(ins, desde, lugar(ins, j)) for j in pendientes])
        desde = lugar(ins, pendientes[idx])
        push!(orden, popat!(pendientes, idx))
    end
    return orden
end

function mover!(e, ins, a, destino)
    e.t_agv[a] += viaje(ins, e.pos_agv[a], destino)
    e.pos_agv[a] = destino
end

function dejar_en_alfa!(e, ins, a, j)
    mover!(e, ins, a, pos_alfa(ins, j))
    e.t_agv[a] = max(e.t_agv[a], listo_abastecer(e, j))   # espera si alfa_j está ocupado
    k = e.n_abast[j] += 1
    e.llegada[j][k] = e.t_agv[a]
    push!(e.ops, Operacion(a, :descarga, e.seq[j][k], e.pos_agv[a], e.t_agv[a]))
    propagar!(e, ins, j)
end

function recoger_de_beta!(e, ins, a, j)
    mover!(e, ins, a, pos_beta(ins, j))
    e.t_agv[a] = max(e.t_agv[a], listo_retirar(e, j))     # espera a que el lote esté listo
    k = e.n_retir[j] += 1
    e.recojo[j][k] = e.t_agv[a]
    push!(e.ops, Operacion(a, :carga, e.seq[j][k], e.pos_agv[a], e.t_agv[a]))
    propagar!(e, ins, j)
    return e.seq[j][k]
end

function abastecer!(e, ins, a, maquinas)
    mover!(e, ins, a, pos_o(ins))
    for j in maquinas
        lote = e.seq[j][e.n_abast[j]+1]
        push!(e.ops, Operacion(a, :carga, lote, pos_o(ins), e.t_agv[a]))
    end
    for j in orden_cercano(ins, pos_o(ins), maquinas, pos_alfa)
        dejar_en_alfa!(e, ins, a, j)
    end
end

function retirar!(e, ins, a, maquinas)
    orden = orden_cercano(ins, e.pos_agv[a], maquinas, pos_beta)
    lotes = [recoger_de_beta!(e, ins, a, j) for j in orden]
    mover!(e, ins, a, pos_f(ins))
    for i in lotes
        e.c[i] = e.t_agv[a]
        push!(e.ops, Operacion(a, :descarga, i, pos_f(ins), e.t_agv[a]))
    end
end

# Tras abastecer, aprovecha el viaje si hay lotes listos sin esperar
function retiro_oportunista!(e, ins, a, par)
    cands = candidatos_retirar(e, ins, a, par)
    listos = [j for (est, j) in cands if est <= e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_beta(ins, j))]
    isempty(listos) || retirar!(e, ins, a, listos[1:min(ins.C, end)])
end

function despachar_simple!(e, ins, a, par)
    ca, cr = candidatos_abastecer(e, ins, a, par), candidatos_retirar(e, ins, a, par)
    if !isempty(cr) && (isempty(ca) || cr[1][1] - par.sesgo_retiro <= ca[1][1])
        retirar!(e, ins, a, armar_lote(cr, ins.C, par.holgura))
    else
        abastecer!(e, ins, a, armar_lote(ca, ins.C, par.holgura))
        retiro_oportunista!(e, ins, a, par)
    end
end

# --- Rondas: o -> (alfa_j, beta_j)... -> f ----------------------
# El AGV carga varios lotes en o y, en cada máquina visitada, deja el
# lote en alfa_j y aprovecha para recoger el lote terminado en beta_j
# (que está al lado). Así cada viaje lleva carga en casi todos los tramos.

a_bordo(e, a) = e.carga_agv[a]

# Recoge en beta_j si hay espacio y el lote está listo sin esperar más de "holgura"
function recoger_si_conviene!(e, ins, a, j, par, lotes)
    a_bordo(e, a) >= ins.C && return
    listo = listo_retirar(e, j)
    llegada = e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_beta(ins, j))
    (desconocido(listo) || listo > llegada + par.holgura) && return
    push!(lotes, recoger_de_beta!(e, ins, a, j))
    e.carga_agv[a] += 1
end

function llevar_a_f!(e, ins, a, lotes)
    isempty(lotes) && return
    mover!(e, ins, a, pos_f(ins))
    for i in lotes
        e.c[i] = e.t_agv[a]
        push!(e.ops, Operacion(a, :descarga, i, pos_f(ins), e.t_agv[a]))
    end
    e.carga_agv[a] = 0
end

# Completa la carga con lotes listos en otros beta antes de ir a f
function completar_retiros!(e, ins, a, par, lotes)
    while a_bordo(e, a) < ins.C
        cands = [(est, j) for (est, j) in candidatos_retirar(e, ins, a, par)
                 if est <= e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_beta(ins, j)) + par.holgura]
        isempty(cands) && return
        recoger_si_conviene!(e, ins, a, cands[1][2], sin_limite(par), lotes)
    end
end

function ronda!(e, ins, a, maquinas, par)
    mover!(e, ins, a, pos_o(ins))
    for j in maquinas
        push!(e.ops, Operacion(a, :carga, e.seq[j][e.n_abast[j]+1], pos_o(ins), e.t_agv[a]))
    end
    e.carga_agv[a] = length(maquinas)
    lotes = Int[]
    for j in orden_cercano(ins, pos_o(ins), maquinas, pos_alfa)
        dejar_en_alfa!(e, ins, a, j)
        e.carga_agv[a] -= 1
        recoger_si_conviene!(e, ins, a, j, par, lotes)
    end
    completar_retiros!(e, ins, a, par, lotes)
    llevar_a_f!(e, ins, a, lotes)
end

function viaje_retiro!(e, ins, a, cr, par)
    lotes = Int[]
    recoger_si_conviene!(e, ins, a, cr[1][2], sin_limite(par), lotes)
    completar_retiros!(e, ins, a, par, lotes)
    llevar_a_f!(e, ins, a, lotes)
end

# Lotes que ya estarán listos cuando el AGV llegue a su beta (sin esperar)
function retiros_listos(e, ins, a, cr)
    llegada(j) = e.t_agv[a] + viaje(ins, e.pos_agv[a], pos_beta(ins, j))
    return [(est, j) for (est, j) in cr if est <= llegada(j) + 1e-9]
end

# Regla: si hay suficientes lotes listos (o nada que abastecer) se hace un
# viaje de retiro; si no, una ronda de abastecimiento que también recoge.
# Un AGV nunca va a esperar a un beta si tiene trabajo útil que hacer.
function despachar!(e, ins, a, par)
    ca, cr = candidatos_abastecer(e, ins, a, par), candidatos_retirar(e, ins, a, par)
    listos = retiros_listos(e, ins, a, cr)
    umbral = clamp(round(Int, par.sesgo_retiro), 1, ins.C)
    if !isempty(listos) && (isempty(ca) || length(listos) >= umbral)
        viaje_retiro!(e, ins, a, listos, par)
    elseif !isempty(ca)
        ronda!(e, ins, a, armar_lote(ca, ins.C, par.holgura), par)
    elseif !isempty(cr)
        viaje_retiro!(e, ins, a, cr, par)
    else
        e.t_agv[a] = Inf          # su zona ya no tiene trabajo pendiente
    end
end

# --- Simulación completa --------------------------------------

terminado(e) = sum(e.n_retir) == sum(length, e.seq)

# Parámetros de la regla de despacho (la búsqueda local también los ajusta)
struct Parametros
    holgura::Float64          # cuánto más tarde puede estar listo un lote para ir en el mismo viaje
    peso_necesidad::Float64   # 0 = abastecer lo antes posible; 1 = justo a tiempo
    sesgo_retiro::Float64     # lotes listos mínimos para hacer un viaje solo de retiro (1..C)
    zona::Vector{Int}         # zona[j] = AGV que atiende la máquina j (vacío = todos atienden todo)
end

Parametros(h, w, b) = Parametros(h, w, b, Int[])
Parametros() = Parametros(60.0, 0.0, 1.0)
sin_limite(p) = Parametros(Inf, p.peso_necesidad, p.sesgo_retiro, p.zona)
con_zona(p, zona) = Parametros(p.holgura, p.peso_necesidad, p.sesgo_retiro, zona)

function simular(ins, seq, par = Parametros())
    e = estado_inicial(ins, seq)
    while !terminado(e)
        a = argmin(e.t_agv)
        isinf(e.t_agv[a]) && error("Hay lotes en máquinas que ningún AGV atiende")
        despachar!(e, ins, a, par)
    end
    return e
end

# Promedio de finalización de los lotes asignados (permite soluciones parciales)
function objetivo(e)
    asignados = filter(!isnan, e.c)
    return sum(asignados) / length(asignados)
end
evaluar(ins, seq, par = Parametros()) = objetivo(simular(ins, seq, par))
