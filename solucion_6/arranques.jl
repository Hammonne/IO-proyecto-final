# ============================================================
# arranques.jl — Nuevos puntos de partida: asignación húngara perturbada
# ============================================================
# Diversificación "lejana": en instancias donde las máquinas son el
# cuello de botella (p. ej. 01–02: máquinas casi sin ocio ni bloqueo) la
# solución puede quedar atrapada en una mala asignación lote–máquina que
# ni el ALNS logra cambiar. Se construye entonces un punto de partida
# nuevo en otra región:
#   1. Asignación exacta de R||ΣC (método húngaro, Horn 1973; Bruno et al.
#      1974) con los tiempos de proceso multiplicados por un ruido
#      aleatorio de ±RUIDO_HUNGARO: da asignaciones distintas pero buenas.
#   2. Viajes de AGVs con las reglas de despacho de la solución 2 (se
#      prueban todos sus juegos de parámetros y se toma el mejor).
#   3. Recocido de la solución 3 durante unos segundos para ajustar el plan.

const RUIDO_HUNGARO = 0.15

# Ruido por par (lote, máquina): perturba qué máquina conviene a cada lote
function matriz_perturbada(ins, rng)
    n, J = num_lotes(ins), num_maquinas(ins)
    costo, cols = matriz_asignacion(ins, min(n, 2 * ceil(Int, n / J) + 5))
    ruido = 1 .+ RUIDO_HUNGARO .* (2 .* rand(rng, n, J) .- 1)
    for i in 1:n, (c, (j, _)) in enumerate(cols)
        costo[i, c] *= ruido[i, j]
    end
    return costo, cols
end

# Posición contada desde el final -> secuencia (k grande va primero)
function secuencias_desde_asignacion(fila_de, cols, J)
    seq = [Tuple{Int,Int}[] for _ in 1:J]
    for (c, i) in enumerate(fila_de)
        i == 0 && continue
        j, k = cols[c]
        push!(seq[j], (k, i))
    end
    return [[i for (_, i) in sort(s, rev = true)] for s in seq]
end

function plan_por_reglas(ins, seq)
    pars = parametros_base(ins)
    mejor = pars[argmin([evaluar(ins, seq, p) for p in pars])]
    return plan_desde_estado(ins, simular(ins, seq, mejor))
end

function arranque_hungaro(ins, rng, segundos_pulido)
    costo, cols = matriz_perturbada(ins, rng)
    seq = secuencias_desde_asignacion(hungaro(costo), cols, num_maquinas(ins))
    plan = plan_por_reglas(ins, seq)
    b = recocido_plan(ins, seq, plan, segundos_pulido; semilla = rand(rng, 1:10^6), mostrar = false)
    return b.mejor
end
