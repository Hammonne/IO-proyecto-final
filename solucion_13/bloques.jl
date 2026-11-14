# ============================================================
# bloques.jl — Solución 13: vecindades de BLOQUE entre máquinas
# ============================================================
# Diagnóstico (README, 12/11): en la 06–08 nuestra asignación a máquinas está
# 73–177 por lote sobre la óptima, y la tabú mueve lotes de a uno: cada cambio
# de máquina obliga a rehacer viajes, así que una asignación distinta en bloque
# queda fuera de alcance. Estas vecindades cambian varios lotes a la vez, pero
# se evalúan DENTRO de la tabú (lejos con criterio, no saltos a ciegas):
#   B1 mover_bloque        : L = 2–5 lotes seguidos de la máquina j1 pasan, en el
#                            mismo orden, a la máquina j2 (en una posición de
#                            tiempo parecida). Es el Or-opt (Or, 1976) entre máquinas.
#   B2 intercambiar_bloques: un bloque de 1–4 lotes de j1 se cambia por uno de
#                            1–4 lotes de j2 (CROSS-exchange, Taillard et al.,
#                            1997, aplicado a las máquinas en vez de a las rutas).
# En los dos, con probabilidad 1/2 las paradas de los AGVs QUEDAN DONDE ESTÁN
# (mismo viaje y orden; solo cambia a qué máquina va el AGV), y si no, se
# reinsertan junto a las del lote vecino en la nueva máquina, como en reubicar_lote.
# Peso de cada una: PESO_BLOQUE (variable de entorno, 0.06 por defecto).

const PROB_QUEDAN = parse(Float64, get(ENV, "PROB_QUEDAN", "0.5"))
const PESO_BLOQUE = parse(Float64, get(ENV, "PESO_BLOQUE", "0.06"))

# Posición en j2 de tiempo parecido a la posición k de j1
posicion_parecida(seq, j1, k, j2, rng) =
    clamp(round(Int, k / max(1, length(seq[j1])) * length(seq[j2])) + rand(rng, -1:1), 1, length(seq[j2]) + 1)

# Bloque al azar de largo en `largos` en la máquina j (rango de posiciones), o nothing
function bloque_al_azar(seq, j, largos, rng)
    n = length(seq[j]); n == 0 && return nothing
    L = min(rand(rng, largos), n)
    k = rand(rng, 1:n-L+1)
    return k:k+L-1
end

# Las paradas del bloque se sacan y se ponen como VIAJES PROPIOS (uno por parada,
# así nunca se excede la capacidad) en el AGV y lugar del viaje que atiende al
# lote vecino en la nueva máquina: justo antes del viaje del sucesor (se colocan
# del último al primero) o, si el bloque termina la máquina, justo después del
# viaje del antecesor (del primero al último).
function poner_viaje!(plan, vecino, despues, lote, abastece)
    if vecino == 0
        a = rand(eachindex(plan)); insert!(plan[a], rand(1:length(plan[a])+1), [Parada(abastece, lote)])
        return
    end
    a, v, _ = buscar_parada(plan, vecino, abastece)
    insert!(plan[a], v + despues, [Parada(abastece, lote)])
end

function reinsertar_bloque!(plan, seq, j, lotes)
    for x in lotes, abastece in (true, false)
        quitar_parada!(plan, x, abastece)
    end
    limpiar!(plan)
    k1, k2 = findfirst(==(first(lotes)), seq[j]), findfirst(==(last(lotes)), seq[j])
    if k2 < length(seq[j])
        for x in reverse(lotes), abastece in (true, false)
            k = findfirst(==(x), seq[j]); poner_viaje!(plan, seq[j][k+1], 0, x, abastece)
        end
    else
        for x in lotes, abastece in (true, false)
            k = findfirst(==(x), seq[j]); poner_viaje!(plan, k > 1 ? seq[j][k-1] : 0, 1, x, abastece)
        end
    end
end

function mover_bloque(ins, seq, plan, rng)
    origenes = [j for j in eachindex(seq) if length(seq[j]) >= 2]
    isempty(origenes) && return seq, plan
    j1 = rand(rng, origenes)
    r = bloque_al_azar(seq, j1, 2:5, rng)
    lotes = seq[j1][r]
    destinos = [j for j in eachindex(seq) if j != j1 && all(x -> compatible(ins, x, j), lotes)]
    isempty(destinos) && return seq, plan
    j2 = rand(rng, destinos)
    nueva = copiar_seq(seq)
    deleteat!(nueva[j1], r)
    k2 = posicion_parecida(seq, j1, first(r), j2, rng)
    k2 = min(k2, length(nueva[j2]) + 1)
    for (d, x) in enumerate(lotes)
        insert!(nueva[j2], k2 + d - 1, x)
    end
    rand(rng) < PROB_QUEDAN && return nueva, plan
    nuevo = copiar_plan(plan)
    reinsertar_bloque!(nuevo, nueva, j2, lotes)
    return nueva, limpiar!(nuevo)
end

function intercambiar_bloques(ins, seq, plan, rng)
    llenas = [j for j in eachindex(seq) if !isempty(seq[j])]
    length(llenas) < 2 && return seq, plan
    j1 = rand(rng, llenas); j2 = rand(rng, setdiff(llenas, j1))
    r1 = bloque_al_azar(seq, j1, 1:4, rng)
    k2 = min(posicion_parecida(seq, j1, first(r1), j2, rng), length(seq[j2]))
    L2 = min(rand(rng, 1:4), length(seq[j2]) - k2 + 1)
    r2 = k2:k2+L2-1
    b1, b2 = seq[j1][r1], seq[j2][r2]
    (all(x -> compatible(ins, x, j2), b1) && all(x -> compatible(ins, x, j1), b2)) || return seq, plan
    nueva = copiar_seq(seq)
    nueva[j1] = vcat(seq[j1][1:first(r1)-1], b2, seq[j1][last(r1)+1:end])
    nueva[j2] = vcat(seq[j2][1:first(r2)-1], b1, seq[j2][last(r2)+1:end])
    rand(rng) < PROB_QUEDAN && return nueva, plan
    nuevo = copiar_plan(plan)
    reinsertar_bloque!(nuevo, nueva, j2, b1)
    reinsertar_bloque!(nuevo, nueva, j1, b2)
    return nueva, limpiar!(nuevo)
end

push!(VECINDADES, mover_bloque, intercambiar_bloques)
push!(NOMBRES_VECINDADES, "mover_bloque", "intercambiar_bloques")
