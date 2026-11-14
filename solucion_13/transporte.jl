# ============================================================
# transporte.jl — Solución 11: movimientos de ruteo para los AGVs
#                 y elección guiada por el retraso del transporte
# ============================================================
# Diagnóstico: frente al líder perdemos sobre todo en las instancias donde
# manda el transporte (06, 07, 08, 10), y ahí lo que mejora es la tabú.
# Dos cambios sobre la tabú de la v5:
#
# 1. Elección guiada (idea de las vecindades de camino crítico, Nowicki y
#    Smutnicki, 1996): para la solución actual se mide cuánto retrasó el
#    transporte a cada lote:
#      abastecer = tiempo que su máquina esperó a que llegara (llegada - salida del anterior)
#      retirar   = tiempo desde que terminó hasta que llegó a f (c - fin)
#    Con probabilidad PROB_GUIADA, la parada que se mueve se elige con
#    ruleta según ese retraso (en vez de al azar uniforme).
#
# 2. Tres vecindades clásicas de ruteo de vehículos entre los 2 AGVs:
#    - cross_viajes: CROSS-exchange (Taillard et al., 1997) de tramos de
#      1–3 viajes completos entre dos AGVs (con 0 viajes = mover un tramo)
#    - dos_opt_estrella: 2-opt* (Potvin y Rousseau, 1995), intercambia las
#      colas de las listas de viajes de los dos AGVs desde viajes cercanos en el tiempo
#    - cruzar_colas: 2-opt* dentro de dos viajes: el final de un viaje pasa
#      al otro y viceversa
# Los planes infactibles (bloqueo o capacidad) los descarta evaluar_plan.

const PROB_GUIADA = 0.5
const RETRASO_ABAST = Ref(Float64[])     # por lote, de la solución actual de la tabú
const RETRASO_RETIRO = Ref(Float64[])

# --- 1. Retraso por transporte ------------------------------------------

function retraso_lote(e, j, k)
    previo = k == 1 ? 0.0 : e.salida[j][k-1]
    return max(0.0, e.llegada[j][k] - previo), e.c[e.seq[j][k]] - e.fin[j][k]
end

function actualizar_retrasos!(ins, seq, plan)
    e, ok = decodificar(ins, seq, plan)
    ok || return
    abast, retiro = zeros(num_lotes(ins)), zeros(num_lotes(ins))
    for j in eachindex(seq), k in eachindex(seq[j])
        abast[seq[j][k]], retiro[seq[j][k]] = retraso_lote(e, j, k)
    end
    RETRASO_ABAST[], RETRASO_RETIRO[] = abast, retiro
end

function ruleta(pesos, rng)
    r, acumulado = rand(rng) * sum(pesos), 0.0
    for (i, w) in enumerate(pesos)
        (acumulado += w) >= r && return i
    end
    return length(pesos)
end

# Parada (a, v, k) de un lote elegido por su retraso; nothing si no hay datos
function parada_guiada(plan, rng)
    abast, retiro = RETRASO_ABAST[], RETRASO_RETIRO[]
    isempty(abast) && return nothing
    total = abast .+ retiro
    lote = ruleta(total .+ 0.05 * sum(total) / length(total) .+ 1e-9, rng)
    abastece = rand(rng) * (total[lote] + 1e-9) < abast[lote]
    return buscar_parada(plan, lote, abastece)
end

# --- 2. Vecindades de ruteo ----------------------------------------------

otro_agv(plan, a, rng) = rand(rng, setdiff(eachindex(plan), a))

function cross_viajes(seq, plan, rng)
    length(plan) < 2 && return seq, plan
    nuevo = copiar_plan(plan)
    a, v, _ = parada_aleatoria(nuevo, rng)
    b = otro_agv(nuevo, a, rng)
    w = max(1, viaje_cercano(nuevo, a, v, b, rng))
    l1 = min(rand(rng, 1:3), length(nuevo[a]) - v + 1)
    l2 = min(rand(rng, 0:3), length(nuevo[b]) - w + 1)
    t1, t2 = nuevo[a][v:v+l1-1], nuevo[b][w:w+l2-1]
    nuevo[a] = vcat(nuevo[a][1:v-1], t2, nuevo[a][v+l1:end])
    nuevo[b] = vcat(nuevo[b][1:w-1], t1, nuevo[b][w+l2:end])
    return seq, nuevo
end

function dos_opt_estrella(seq, plan, rng)
    length(plan) < 2 && return seq, plan
    nuevo = copiar_plan(plan)
    a, v, _ = parada_aleatoria(nuevo, rng)
    b = otro_agv(nuevo, a, rng)
    w = clamp(viaje_cercano(nuevo, a, v, b, rng) - rand(rng, 0:1), 0, length(nuevo[b]))
    cola_a, cola_b = nuevo[a][v:end], nuevo[b][w+1:end]
    nuevo[a] = vcat(nuevo[a][1:v-1], cola_b)
    nuevo[b] = vcat(nuevo[b][1:w], cola_a)
    return seq, nuevo
end

function cruzar_colas(seq, plan, rng)
    nuevo = copiar_plan(plan)
    a, v, k = parada_aleatoria(nuevo, rng)
    b = rand(rng, eachindex(nuevo))
    w = viaje_cercano(nuevo, a, v, b, rng)
    (w == 0 || (b == a && w == v)) && return seq, plan
    t1, t2 = nuevo[a][v], nuevo[b][w]
    m = rand(rng, 0:length(t2))
    nuevo[a][v], nuevo[b][w] = vcat(t1[1:k-1], t2[m+1:end]), vcat(t2[1:m], t1[k:end])
    return seq, limpiar!(nuevo)
end

push!(VECINDADES, (ins, s, p, r) -> cross_viajes(s, p, r),
      (ins, s, p, r) -> dos_opt_estrella(s, p, r),
      (ins, s, p, r) -> cruzar_colas(s, p, r))
push!(NOMBRES_VECINDADES, "cross_viajes", "dos_opt_estrella", "cruzar_colas")
