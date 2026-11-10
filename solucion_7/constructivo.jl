# ============================================================
# constructivo.jl — Solución inicial por inserción voraz
# ============================================================
# 1. Ordena los lotes por su menor tiempo de proceso (regla SPT),
#    porque el objetivo es el promedio de finalización.
# 2. Inserta cada lote al final de la máquina compatible donde
#    la simulación da el menor tiempo total hasta ese momento.
# Siempre es factible: el simulador respeta todas las restricciones.

menor_proceso(ins, i) = minimum(tiempo_proceso(ins, i, j) for j in maquinas_compatibles(ins, i))

orden_spt(ins) = sortperm([menor_proceso(ins, i) for i in 1:num_lotes(ins)])

suma_finalizacion(e) = sum(filter(!isnan, e.c))

function costo_agregar(ins, seq, i, j, par)
    push!(seq[j], i)
    costo = suma_finalizacion(simular(ins, seq, par))
    pop!(seq[j])
    return costo
end

function mejor_maquina(ins, seq, i, par)
    opciones = maquinas_compatibles(ins, i)
    costos = [costo_agregar(ins, seq, i, j, par) for j in opciones]
    return opciones[argmin(costos)]
end

function solucion_inicial(ins, par = Parametros())
    seq = [Int[] for _ in 1:num_maquinas(ins)]
    for i in orden_spt(ins)
        push!(seq[mejor_maquina(ins, seq, i, par)], i)
    end
    return seq
end

# --- Zonas iniciales: cada AGV atiende un grupo de máquinas cercanas ---
costo_ruta(ins, j) = ins.tau[pos_o(ins), pos_alfa(ins, j)] + ins.tau[pos_beta(ins, j), pos_f(ins)]

function cercanas(ins, semilla, libres, n)
    orden = sort(libres, by = j -> ins.tau[pos_alfa(ins, semilla), pos_alfa(ins, j)])
    return orden[1:min(n, end)]
end

# Tamaños de zona: "parejo" reparte las J máquinas entre los K AGVs;
# "capacidad" da C máquinas por AGV (una por espacio de carga)
function tamanos_zona(ins, modo)
    J, K = num_maquinas(ins), ins.K
    modo == :capacidad && return fill(ins.C, K)
    return [div(J, K) + (a <= J % K ? 1 : 0) for a in 1:K]
end

# Semilla = máquina libre más barata de abastecer y retirar; se le suman las más cercanas
function zonas_iniciales(ins, modo = :parejo)
    J, zona = num_maquinas(ins), zeros(Int, num_maquinas(ins))
    libres, semillas = sort(1:J, by = j -> costo_ruta(ins, j)), Int[]
    for (a, n) in enumerate(tamanos_zona(ins, modo))
        (isempty(libres) || n == 0) && break
        grupo = cercanas(ins, libres[1], libres, n)
        zona[grupo] .= a
        push!(semillas, libres[1])
        libres = setdiff(libres, grupo)
    end
    for j in libres   # máquinas sobrantes: a la zona de la semilla más cercana
        zona[j] = argmin([ins.tau[pos_alfa(ins, s), pos_alfa(ins, j)] for s in semillas])
    end
    return zona
end

# Juegos de parámetros de despacho, medidos en múltiplos del viaje típico,
# con y sin zonas
function parametros_base(ins)
    s = escala_viaje(ins)
    zonas = (Int[], zonas_iniciales(ins, :parejo), zonas_iniciales(ins, :capacidad))
    return [Parametros(h * s, w, b, z) for h in (0.0, 0.5, 1.5),
            w in (0.0, 0.5, 1.0), b in 1:ins.C, z in zonas]
end

# Prueba cada juego de parámetros con dos constructivos (inserción voraz y
# asignación húngara) y se queda con la mejor solución
function mejor_inicial(ins)
    asig = solucion_asignacion(ins)
    candidatas = vec([(solucion_inicial(ins, p), p) for p in parametros_base(ins)])
    append!(candidatas, [(asig, p) for p in parametros_base(ins)])
    valores = [evaluar(ins, s, p) for (s, p) in candidatas]
    return candidatas[argmin(valores)]
end
