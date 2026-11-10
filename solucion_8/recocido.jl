# ============================================================
# recocido.jl — Recocido simulado sobre las mismas vecindades
# ============================================================
# En instancias grandes un descenso completo revisa ~20 000 jugadas
# antes de terminar. El recocido evalúa UNA jugada aleatoria por paso
# (reubicar, intercambiar o cambiar un parámetro/zona) y la acepta si
# mejora, o si empeora con probabilidad exp(-Δ/T). T baja con el tiempo:
# al inicio diversifica (acepta empeoramientos), al final intensifica.

function lote_aleatorio(seq, rng)
    j = rand(rng, [j for j in eachindex(seq) if !isempty(seq[j])])
    return j, rand(rng, eachindex(seq[j]))
end

function reubicar_aleatorio(ins, seq, rng)
    j1, k1 = lote_aleatorio(seq, rng)
    j2 = rand(rng, maquinas_compatibles(ins, seq[j1][k1]))
    k2 = rand(rng, posiciones_cercanas(seq, j1, k1, j2, min(ventana(ins), 8), j1 == j2 ? 0 : 1))
    return reubicar(seq, j1, k1, j2, k2)
end

function intercambiar_aleatorio(ins, seq, rng)
    j1, k1 = lote_aleatorio(seq, rng)
    j2 = rand(rng, maquinas_compatibles(ins, seq[j1][k1]))
    pos = intersect(eachindex(seq[j2]), posiciones_cercanas(seq, j1, k1, j2, min(ventana(ins), 8), 0))
    isempty(pos) && return seq
    k2 = rand(rng, pos)
    compatible(ins, seq[j2][k2], j1) || return seq
    return intercambiar(seq, j1, k1, j2, k2)
end

function movimiento_aleatorio(ins, seq, par, rng)
    r = rand(rng)
    r < 0.45 && return reubicar_aleatorio(ins, seq, rng), par
    r < 0.92 && return intercambiar_aleatorio(ins, seq, rng), par
    return seq, rand(rng, vecinos_parametros(ins, par))
end

# Temperatura geométrica según la fracción de tiempo transcurrida
temperatura(t0, tf, avance) = t0 * (tf / t0)^avance

function recocido(ins, seq, par, val, rng, segundos; mostrar = true)
    inicio, mejor = time(), (seq, par, val)
    t0, tf = 0.002 * val, 0.00003 * val
    while (avance = (time() - inicio) / segundos) < 1
        s2, p2 = movimiento_aleatorio(ins, seq, par, rng)
        v2 = evaluar(ins, s2, p2)
        aceptar(v2, val, temperatura(t0, tf, avance), rng) && ((seq, par, val) = (s2, p2, v2))
        if val < mejor[3] - 1e-9
            mejor = (seq, par, val)
            mostrar && println("  recocido: ", round(val, digits = 2))
        end
    end
    return mejor
end

# Método completo: inicial -> recocido (85% del tiempo) -> descenso final
# inicio = (seq, par) de una corrida anterior para continuar desde ahí
function buscar(ins; segundos = 60.0, semilla = 1, mostrar = true, inicio = nothing)
    rng, limite = MersenneTwister(semilla), time() + segundos
    seq, par = inicio === nothing ? mejor_inicial(ins) : inicio
    val = evaluar(ins, seq, par)
    mostrar && println("Inicial: ", round(val, digits = 2))
    seq, par, val = recocido(ins, seq, par, val, rng, 0.85 * (limite - time()); mostrar)
    seq, par, val = descenso(ins, seq, par, val, rng, limite)
    mostrar && println("Final (tras descenso): ", round(val, digits = 2))
    return seq, par, val
end
