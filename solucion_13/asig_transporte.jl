# ============================================================
# asig_transporte.jl — Solución 13: asignación inicial que cuenta el transporte
# ============================================================
# Análisis de la 08 (README, 14/11): los AGVs están ocupados el 99 % del tiempo
# y son el cuello de botella; ir a las máquinas 6 y 8 cuesta 81 s de AGV por
# lote (o -> alfa + beta -> f), frente a 48 s de la 2. Cuando los AGVs están
# saturados, cada segundo de AGV retrasa a los lotes que vienen después, no
# solo al propio lote. La asignación húngara de R||ΣC (asignacion.jl) cuenta
# el viaje una sola vez; aquí pesa BETA veces:
#   costo(i, j, k) = k·p_ij + BETA · (tau[o, alfa_j] + tau[beta_j, f])
# Con BETA ≈ n / (2K) el viaje "retrasa" a la mitad de los lotes de un AGV.
# Variable de entorno ASIG_BETA; se usa con "cero" (main.jl).

ruta_lote(ins, j) = ins.tau[pos_o(ins), pos_alfa(ins, j)] + ins.tau[pos_beta(ins, j), pos_f(ins)]

function matriz_asignacion_beta(ins, kmax, beta)
    n, J = num_lotes(ins), num_maquinas(ins)
    cols = [(j, k) for j in 1:J for k in 1:kmax]
    costo = fill(1e9, n, length(cols))
    for i in 1:n, (c, (j, k)) in enumerate(cols)
        compatible(ins, i, j) || continue
        costo[i, c] = k * tiempo_proceso(ins, i, j) + beta * ruta_lote(ins, j)
    end
    return costo, cols
end

function asignacion_transporte(ins, beta)
    n, J = num_lotes(ins), num_maquinas(ins)
    costo, cols = matriz_asignacion_beta(ins, min(n, 3 * ceil(Int, n / J) + 5), beta)
    seq = [Tuple{Int,Int}[] for _ in 1:J]
    for (c, i) in enumerate(hungaro(costo))
        i == 0 || push!(seq[cols[c][1]], (cols[c][2], i))
    end
    return [[i for (k, i) in sort(s, rev = true)] for s in seq]
end

# Mejor plan de AGVs (reglas de despacho de la solución 2) para esa asignación
function inicial_transporte(ins, beta)
    seq = asignacion_transporte(ins, beta)
    par = argmin(p -> evaluar(ins, seq, p), parametros_base(ins))
    return seq, plan_desde_estado(ins, simular(ins, seq, par))
end
