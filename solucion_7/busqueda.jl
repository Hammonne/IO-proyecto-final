# ============================================================
# busqueda.jl — Búsqueda local iterada (ILS)
# ============================================================
# Solución = (seq, par): secuencia de lotes por máquina y
# parámetros de la regla de despacho de los AGVs.
# Vecindades:
#   N1 reubicar: saca un lote y lo inserta en otra posición o máquina compatible
#   N2 intercambiar: intercambia dos lotes (misma u otra máquina, si son compatibles)
#   N3 parámetros: modifica un parámetro de despacho
# Método: descenso de primera mejora + perturbación + aceptación tipo recocido.

using Random

# --- Movimientos sobre las secuencias -------------------------

function reubicar(seq, j1, k1, j2, k2)
    nueva = deepcopy(seq)
    lote = popat!(nueva[j1], k1)
    insert!(nueva[j2], min(k2, length(nueva[j2]) + 1), lote)
    return nueva
end

function intercambiar(seq, j1, k1, j2, k2)
    nueva = deepcopy(seq)
    nueva[j1][k1], nueva[j2][k2] = seq[j2][k2], seq[j1][k1]
    return nueva
end

# Vecindad restringida: en instancias grandes un lote solo se mueve a
# posiciones "cercanas en el tiempo" (posición relativa parecida ± ventana).
# Moverlo muy lejos casi nunca mejora el promedio y multiplica la vecindad.
ventana(ins) = num_lotes(ins) <= 60 ? typemax(Int) ÷ 2 : 6

function posiciones_cercanas(seq, j1, k1, j2, w, extra)
    n1, n2 = length(seq[j1]), length(seq[j2]) + extra
    centro = n1 <= 1 ? 1 : round(Int, 1 + (k1 - 1) * (n2 - 1) / (n1 - 1))
    return max(1, centro - w):min(n2, centro + w)
end

function movs_reubicar(ins, seq)
    movs, w = Tuple{Symbol,Int,Int,Int,Int}[], ventana(ins)
    for j1 in eachindex(seq), k1 in eachindex(seq[j1]), j2 in maquinas_compatibles(ins, seq[j1][k1])
        for k2 in posiciones_cercanas(seq, j1, k1, j2, w, j1 == j2 ? 0 : 1)
            (j1, k1) == (j2, k2) || push!(movs, (:reubicar, j1, k1, j2, k2))
        end
    end
    return movs
end

function intercambio_valido(ins, seq, j1, k1, j2, k2)
    (j1, k1) >= (j2, k2) && return false
    return compatible(ins, seq[j1][k1], j2) && compatible(ins, seq[j2][k2], j1)
end

function movs_intercambiar(ins, seq)
    movs, w = Tuple{Symbol,Int,Int,Int,Int}[], ventana(ins)
    for j1 in eachindex(seq), k1 in eachindex(seq[j1]), j2 in eachindex(seq)
        for k2 in intersect(eachindex(seq[j2]), posiciones_cercanas(seq, j1, k1, j2, w, 0))
            intercambio_valido(ins, seq, j1, k1, j2, k2) && push!(movs, (:intercambiar, j1, k1, j2, k2))
        end
    end
    return movs
end

function aplicar(seq, mov)
    tipo, j1, k1, j2, k2 = mov
    return tipo == :reubicar ? reubicar(seq, j1, k1, j2, k2) : intercambiar(seq, j1, k1, j2, k2)
end

# --- Movimientos sobre los parámetros de despacho --------------

function vecinos_parametros(ins, p)
    h, w, b, z, s = p.holgura, p.peso_necesidad, p.sesgo_retiro, p.zona, 0.4 * escala_viaje(ins)
    return vcat([Parametros(max(0.0, h + d), w, b, z) for d in (-s, s)],
                [Parametros(h, clamp(w + d, 0.0, 1.0), b, z) for d in (-0.25, 0.25)],
                [Parametros(h, w, clamp(b + d, 1, ins.C), z) for d in (-1, 1)],
                vecinos_zona(ins, p))
end

# Cambiar una máquina a la zona de otro AGV
function vecinos_zona(ins, p)
    isempty(p.zona) && return Parametros[]
    vecinos = Parametros[]
    for j in eachindex(p.zona), a in 1:ins.K
        a == p.zona[j] && continue
        z = copy(p.zona); z[j] = a
        push!(vecinos, con_zona(p, z))
    end
    return vecinos
end

# --- Descenso de primera mejora --------------------------------

function mejora_en_secuencias(ins, seq, par, valor, rng)
    movs = shuffle!(rng, vcat(movs_reubicar(ins, seq), movs_intercambiar(ins, seq)))
    for mov in movs
        nueva = aplicar(seq, mov)
        v = evaluar(ins, nueva, par)
        v < valor - 1e-9 && return (nueva, v)
    end
    return nothing
end

function mejora_en_parametros(ins, seq, par, valor)
    for p in vecinos_parametros(ins, par)
        v = evaluar(ins, seq, p)
        v < valor - 1e-9 && return (p, v)
    end
    return nothing
end

function descenso(ins, seq, par, valor, rng, limite)
    while time() < limite
        m = mejora_en_secuencias(ins, seq, par, valor, rng)
        m === nothing || ((seq, valor) = m; continue)
        m = mejora_en_parametros(ins, seq, par, valor)
        m === nothing && break
        par, valor = m
    end
    return seq, par, valor
end

# --- Perturbación (diversificación) ----------------------------

function reubicacion_aleatoria(ins, seq, rng)
    j1 = rand(rng, [j for j in eachindex(seq) if !isempty(seq[j])])
    k1 = rand(rng, eachindex(seq[j1]))
    j2 = rand(rng, maquinas_compatibles(ins, seq[j1][k1]))
    return reubicar(seq, j1, k1, j2, rand(rng, 1:length(seq[j2]) + 1))
end

function perturbar(ins, seq, par, fuerza, rng)
    for _ in 1:fuerza
        seq = reubicacion_aleatoria(ins, seq, rng)
    end
    rand(rng) < 0.3 && (par = rand(rng, vecinos_parametros(ins, par)))
    return seq, par
end

# --- ILS --------------------------------------------------------

# Acepta mejoras siempre y empeoramientos pequeños con probabilidad (recocido)
aceptar(nuevo, actual, temp, rng) = nuevo < actual || rand(rng) < exp((actual - nuevo) / temp)

function ils(ins; segundos = 60.0, semilla = 1, mostrar = true, inicio = nothing)
    rng, limite = MersenneTwister(semilla), time() + segundos
    seq, par = inicio === nothing ? mejor_inicial(ins) : inicio
    seq, par, val = descenso(ins, seq, par, evaluar(ins, seq, par), rng, limite)
    mejor, temp = (seq, par, val), 0.01 * val
    mostrar && println("Inicial + descenso: ", round(val, digits = 2))
    while time() < limite
        s2, p2 = perturbar(ins, seq, par, rand(rng, 2:4), rng)
        s2, p2, v2 = descenso(ins, s2, p2, evaluar(ins, s2, p2), rng, limite)
        aceptar(v2, val, temp, rng) && ((seq, par, val) = (s2, p2, v2))
        val < mejor[3] && (mejor = (seq, par, val); mostrar && println("Mejora: ", round(val, digits = 2)))
        temp *= 0.995
    end
    return mejor
end
