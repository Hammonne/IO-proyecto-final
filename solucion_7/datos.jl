# ============================================================
# datos.jl — Estructura de la instancia y funciones de acceso
# ============================================================
# Índices de ubicaciones en la matriz tau:
#   o = 1, alfa_j = 2j, beta_j = 2j + 1, f = 2J + 2

struct Instancia
    q::Vector{Float64}      # unidades de cada lote
    r::Vector{Int}          # tipo de producto de cada lote
    v::Matrix{Float64}      # v[j, r] tasa (0 = incompatible)
    C::Int                  # capacidad de cada AGV
    K::Int                  # número de AGVs
    tau::Matrix{Float64}    # tiempos de viaje entre ubicaciones
end

num_lotes(ins) = length(ins.q)
num_maquinas(ins) = size(ins.v, 1)

pos_o(ins) = 1
pos_alfa(ins, j) = 2j
pos_beta(ins, j) = 2j + 1
pos_f(ins) = 2 * num_maquinas(ins) + 2

compatible(ins, i, j) = ins.v[j, ins.r[i]] > 0
tiempo_proceso(ins, i, j) = ins.q[i] / ins.v[j, ins.r[i]]

maquinas_compatibles(ins, i) = [j for j in 1:num_maquinas(ins) if compatible(ins, i, j)]

# Escala típica de los viajes; sirve para ajustar los parámetros de despacho
escala_viaje(ins) = sum(ins.tau) / count(>(0), ins.tau)

# --- Lectura de instancias en texto (convertidas desde los .xlsx) ---
# Formato: "AGV K C", "LOTES n" + n filas "i r q",
#          "TASAS m" + m filas "j r v", "TIEMPOS L" + matriz L x L

function leer_bloque(lineas, pos)
    cabecera = split(lineas[pos])
    n = parse(Int, cabecera[2])
    return [split(l) for l in lineas[pos+1:pos+n]], pos + n + 1
end

function codificar_tipos(lotes, tasas)
    tipos = sort(unique(vcat([l[2] for l in lotes], [t[2] for t in tasas])))
    return Dict(t => k for (k, t) in enumerate(tipos))
end

function matriz_tasas(tasas, cod)
    J = maximum(parse(Int, t[1]) for t in tasas)
    v = zeros(J, length(cod))
    for t in tasas
        v[parse(Int, t[1]), cod[t[2]]] = parse(Float64, t[3])
    end
    return v
end

function leer_instancia(archivo)
    lineas = filter(!isempty, strip.(readlines(archivo)))
    K, C = parse.(Int, split(lineas[1])[2:3])
    lotes, pos = leer_bloque(lineas, 2)
    tasas, pos = leer_bloque(lineas, pos)
    filas, _ = leer_bloque(lineas, pos)
    cod = codificar_tipos(lotes, tasas)
    q = [parse(Float64, l[3]) for l in lotes]
    r = [cod[l[2]] for l in lotes]
    tau = permutedims(reduce(hcat, [parse.(Float64, f) for f in filas]))
    return Instancia(q, r, matriz_tasas(tasas, cod), C, K, tau)
end

# Instancia de ejemplo del enunciado (Sección 4.1), útil para probar
function instancia_ejemplo()
    q = [900, 1350, 1350, 900, 900, 1350, 1350, 900, 1350, 1350.0]
    r = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]          # A = 1, B = 2
    v = [5 0; 5 10/3; 10/3 5; 0 5]
    tau = [0 90 135 45 90 135 180 180 225 225
           90 0 45 45 90 135 180 180 225 225
           135 45 0 90 45 90 135 135 180 180
           45 45 90 0 45 90 135 135 180 180
           90 90 45 45 0 45 90 90 135 135
           135 135 90 90 45 0 45 45 90 90
           180 180 135 135 90 45 0 90 45 45
           180 180 135 135 90 45 90 0 45 135
           225 225 180 180 135 90 45 45 0 90
           225 225 180 180 135 90 45 135 90 0]
    return Instancia(q, r, float.(v), 1, 2, float.(tau))
end
