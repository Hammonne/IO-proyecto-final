# ============================================================
# asignacion.jl — Solución inicial exacta para R||ΣC con el método húngaro
# ============================================================
# Si se ignora el transporte, minimizar la suma de finalizaciones en
# máquinas paralelas no relacionadas es un problema de asignación
# (Horn, 1973; Bruno, Coffman y Sethi, 1974):
#   el lote i en la posición k CONTADA DESDE EL FINAL de la máquina j
#   retrasa a k lotes (él y los k-1 que van después), así que cuesta k·p_ij.
# A eso se suma el costo de ruta de la máquina (o -> alfa_j y beta_j -> f).
# Resolver la asignación da máquina y orden (SPT) a la vez.

# Método húngaro para matriz rectangular n x m (n <= m), costo mínimo.
# Devuelve fila_de_col[c] = fila asignada a la columna c (0 si ninguna).
function hungaro(costo)
    n, m = size(costo)
    u, v, p, camino = zeros(n + 1), zeros(m + 1), zeros(Int, m + 1), zeros(Int, m + 1)
    for i in 1:n
        hungaro_fila!(costo, u, v, p, camino, i)
    end
    return p[2:end]
end

function hungaro_fila!(costo, u, v, p, camino, i)
    m = size(costo, 2)
    p[1], j0 = i, 1
    minv, usado = fill(Inf, m + 1), falses(m + 1)
    while p[j0] != 0
        usado[j0] = true
        j0 = hungaro_paso!(costo, u, v, p, camino, minv, usado, j0)
    end
    hungaro_aumentar!(p, camino, j0)
end

function hungaro_paso!(costo, u, v, p, camino, minv, usado, j0)
    i0, delta, j1 = p[j0], Inf, 0
    for j in 2:size(costo, 2)+1
        usado[j] && continue
        cur = costo[i0, j-1] - u[i0+1] - v[j]
        cur < minv[j] && (minv[j] = cur; camino[j] = j0)
        minv[j] < delta && (delta = minv[j]; j1 = j)
    end
    for j in 1:length(minv)
        usado[j] ? (u[p[j]+1] += delta; v[j] -= delta) : (minv[j] -= delta)
    end
    return j1
end

function hungaro_aumentar!(p, camino, j0)
    while j0 != 1
        j1 = camino[j0]
        p[j0] = p[j1]
        j0 = j1
    end
end

# Columnas: (máquina j, posición desde el final k), con k <= kmax
function matriz_asignacion(ins, kmax)
    n, J = num_lotes(ins), num_maquinas(ins)
    cols = [(j, k) for j in 1:J for k in 1:kmax]
    costo = fill(1e9, n, length(cols))
    for i in 1:n, (c, (j, k)) in enumerate(cols)
        compatible(ins, i, j) || continue
        costo[i, c] = k * tiempo_proceso(ins, i, j) + costo_ruta(ins, j)
    end
    return costo, cols
end

function solucion_asignacion(ins)
    n, J = num_lotes(ins), num_maquinas(ins)
    costo, cols = matriz_asignacion(ins, min(n, 2 * ceil(Int, n / J) + 5))
    fila_de = hungaro(costo)
    seq = [Tuple{Int,Int}[] for _ in 1:J]
    for (c, i) in enumerate(fila_de)
        i == 0 && continue
        j, k = cols[c]
        push!(seq[j], (k, i))
    end
    return [[i for (k, i) in sort(s, rev = true)] for s in seq]   # k grande = va primero
end
