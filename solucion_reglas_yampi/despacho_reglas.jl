# ============================================================
# despacho_reglas.jl — Reglas R3 y R4 para los AGVs, con excepciones S y Y
# ============================================================
# Cada AGV libre hace un viaje completo: va a o, carga lotes, los deja en
# sus alfa_j, recoge lotes terminados en beta_j y termina en f.
#
#   R3 (espera): ir al destino más cercano; esperar allí solo si esperar
#                cuesta menos que ir al siguiente destino.
#   R4 (combinado): en cada máquina se deja un lote y se recoge el terminado
#                   si está listo sin esperar más de la holgura.
#
# Excepciones (se evalúan antes de cada elección de carga):
#   S = espera evitada: cuánto menos espera tiene este lote frente al de la regla base.
#   Y = ocio evitado: cuánto tiempo estaría ociosa la máquina si no se atiende ahora.
#   Se desvía de la regla base si  alfa·S + beta·Y − gamma·Δ > 0,
#   donde Δ es cuánto más tarde se entregaría frente a la regla base.

struct ParamsV5
    holgura::Float64          # tolerancia (s) para agrupar lotes en un viaje
    alfa::Float64             # peso de la espera evitada S
    beta::Float64             # peso del ocio evitado Y
    gamma::Float64            # costo de retrasar la entrega frente a la regla base
    factor_espera::Float64    # R3: esperar si la espera ≤ factor · distancia al alternativo
    zonas::Vector{Int}        # zonas[j] = AGV que atiende la máquina j (vacío = sin zonas)
end

ParamsV5() = ParamsV5(60.0, 1.0, 1.0, 1.0, 1.0, Int[])

distancia(ins, u, v) = ins.tau[u, v]

puede_atender(par, a, j) = isempty(par.zonas) || par.zonas[j] == a

terminado_v5(e) = sum(e.n_retir) == sum(length, e.seq)

# Instante desde el que la máquina j queda libre de su último lote
liberacion_maquina(e, j) = e.n_abast[j] == 0 ? 0.0 : e.fin[j][e.n_abast[j]]

# --- Entregas: lote siguiente de cada máquina con pendientes -----

# Cada opción es (llegada a alfa_j, espera en alfa_j, j)
function entregas_pendientes(e, ins, a, par)
    opciones = Tuple{Float64,Float64,Int}[]
    t_o = e.t_agv[a] + distancia(ins, e.pos_agv[a], pos_o(ins))
    for j in 1:num_maquinas(ins)
        e.n_abast[j] < length(e.seq[j]) || continue
        puede_atender(par, a, j) || continue
        listo = listo_abastecer(e, j)
        desconocido(listo) && continue            # el buffer aún depende de un retiro pendiente
        llegada = t_o + distancia(ins, pos_o(ins), pos_alfa(ins, j))
        espera = max(0.0, listo - llegada)
        push!(opciones, (llegada, espera, j))
    end
    return opciones
end

# R1/R2 + excepciones S y Y: elige hasta C máquinas para cargar en o
function elegir_carga(e, ins, a, par)
    opciones = entregas_pendientes(e, ins, a, par)
    isempty(opciones) && return Int[]
    inicio_de(o) = o[1] + o[2]
    ordenadas = sort(opciones; by = inicio_de)
    base = ordenadas[1]
    carga = [base[3]]
    for opcion in ordenadas[2:end]
        length(carga) >= ins.C && break
        llegada, espera, j = opcion
        Δ = inicio_de(opcion) - inicio_de(base)
        S = max(0.0, base[2] - espera)
        Y = max(0.0, inicio_de(opcion) - liberacion_maquina(e, j))
        desvio = par.alfa * S + par.beta * Y - par.gamma * Δ
        (Δ <= par.holgura || desvio > 0) && push!(carga, j)
    end
    return carga
end

# --- Destinos durante el viaje ----------------------------------

# Destinos posibles: (distancia, tipo, j, lugar, espera)
function destinos(e, ins, a, par, pendientes, puede_recoger, carga_a_bordo)
    t, pos = e.t_agv[a], e.pos_agv[a]
    opciones = Tuple{Float64,Symbol,Int,Int,Float64}[]
    for j in pendientes
        lugar = pos_alfa(ins, j)
        llegada = t + distancia(ins, pos, lugar)
        push!(opciones, (distancia(ins, pos, lugar), :entrega, j, lugar,
                         max(0.0, listo_abastecer(e, j) - llegada)))
    end
    if puede_recoger
        for j in 1:num_maquinas(ins)
            (e.n_retir[j] < e.n_abast[j] && puede_atender(par, a, j)) || continue
            lugar = pos_beta(ins, j)
            llegada = t + distancia(ins, pos, lugar)
            espera = max(0.0, listo_retirar(e, j) - llegada)
            # R4: recoger en el camino solo si no hay que esperar mucho
            sin_otro_trabajo = isempty(pendientes) && carga_a_bordo == 0
            (espera <= par.holgura || sin_otro_trabajo) &&
                push!(opciones, (distancia(ins, pos, lugar), :recogida, j, lugar, espera))
        end
    end
    return opciones
end

# R3: ir al más cercano; esperar allí solo si la espera es menor que ir al siguiente
function siguiente_destino(e, ins, a, par, pendientes, puede_recoger, carga_a_bordo)
    opciones = destinos(e, ins, a, par, pendientes, puede_recoger, carga_a_bordo)
    isempty(opciones) && return nothing
    ordenadas = sort(opciones; by = o -> o[1])
    cercano = ordenadas[1]
    length(ordenadas) == 1 && return cercano
    alternativo = ordenadas[2]
    espera_cercano = cercano[5]
    esperar = espera_cercano <= par.factor_espera * distancia(ins, cercano[4], alternativo[4])
    return esperar ? cercano : alternativo
end

# --- Acciones del AGV ------------------------------------------

function mover_agv!(e, ins, a, destino)
    e.t_agv[a] += distancia(ins, e.pos_agv[a], destino)
    e.pos_agv[a] = destino
end

function entregar!(e, ins, a, j)
    mover_agv!(e, ins, a, pos_alfa(ins, j))
    e.t_agv[a] = max(e.t_agv[a], listo_abastecer(e, j))
    e.n_abast[j] += 1
    k = e.n_abast[j]
    e.llegada[j][k] = e.t_agv[a]
    push!(e.ops, Operacion(a, :descarga, e.seq[j][k], pos_alfa(ins, j), e.t_agv[a]))
    e.carga_agv[a] -= 1
    propagar!(e, ins, j)
end

# Devuelve el lote recogido
function recoger!(e, ins, a, j)
    mover_agv!(e, ins, a, pos_beta(ins, j))
    e.t_agv[a] = max(e.t_agv[a], listo_retirar(e, j))
    e.n_retir[j] += 1
    k = e.n_retir[j]
    e.recojo[j][k] = e.t_agv[a]
    lote = e.seq[j][k]
    push!(e.ops, Operacion(a, :carga, lote, pos_beta(ins, j), e.t_agv[a]))
    e.carga_agv[a] += 1
    propagar!(e, ins, j)
    return lote
end

function descargar_en_f!(e, ins, a, abordo)
    isempty(abordo) && return
    mover_agv!(e, ins, a, pos_f(ins))
    for i in abordo
        e.c[i] = e.t_agv[a]
        push!(e.ops, Operacion(a, :descarga, i, pos_f(ins), e.t_agv[a]))
    end
    e.carga_agv[a] -= length(abordo)
end

# --- Viaje completo de un AGV -----------------------------------

function viaje_reglas!(e, ins, a, par)
    carga = elegir_carga(e, ins, a, par)
    if !isempty(carga)
        mover_agv!(e, ins, a, pos_o(ins))
        for j in carga
            push!(e.ops, Operacion(a, :carga, e.seq[j][e.n_abast[j] + 1], pos_o(ins), e.t_agv[a]))
        end
        e.carga_agv[a] += length(carga)
    end
    pendientes, abordo = copy(carga), Int[]
    while true
        puede_recoger = e.carga_agv[a] < ins.C
        d = siguiente_destino(e, ins, a, par, pendientes, puede_recoger, e.carga_agv[a])
        d === nothing && break
        if d[2] == :entrega
            entregar!(e, ins, a, d[3])
            filter!(!=(d[3]), pendientes)
        else
            push!(abordo, recoger!(e, ins, a, d[3]))
        end
    end
    descargar_en_f!(e, ins, a, abordo)
end

# --- Simulación completa ----------------------------------------

# Hay trabajo posible para el AGV a (entregas o recogidas en su zona)
hay_trabajo(e, ins, a, par) =
    any(j -> puede_atender(par, a, j) && (e.n_abast[j] < length(e.seq[j]) || e.n_retir[j] < e.n_abast[j]),
        1:num_maquinas(ins))

# Un AGV libre hace un viaje. Si no pudo hacer nada:
#   - sin trabajo en su zona: queda fuera del reparto (Inf);
#   - con trabajo pendiente pero aún no disponible: espera a que avance otro AGV.
function simular_reglas(ins, seq, par; limite = 10_000_000)
    e = estado_inicial(ins, seq)
    iteraciones = 0
    while !terminado_v5(e)
        iteraciones += 1
        iteraciones > limite && error("La simulación no avanza")
        a = argmin(e.t_agv)
        isinf(e.t_agv[a]) && error("Quedan lotes sin ningún AGV que los atienda")
        n_antes = length(e.ops)
        viaje_reglas!(e, ins, a, par)
        length(e.ops) > n_antes && continue
        if hay_trabajo(e, ins, a, par)
            otros = [e.t_agv[b] for b in eachindex(e.t_agv) if b != a && !isinf(e.t_agv[b])]
            e.t_agv[a] = isempty(otros) ? error("Bloqueo sin salida") : max(e.t_agv[a], minimum(otros)) + 1e-6
        else
            e.t_agv[a] = Inf
        end
    end
    return e
end

# Zonas por cercanía: las máquinas más cercanas a o van al AGV 1, y así sucesivamente
function zonas_por_cercania(ins)
    J = num_maquinas(ins)
    orden = sortperm([distancia(ins, pos_o(ins), pos_alfa(ins, j)) for j in 1:J])
    zonas = zeros(Int, J)
    for (r, j) in enumerate(orden)
        zonas[j] = clamp(cld(r * ins.K, J), 1, ins.K)
    end
    return zonas
end
