# ============================================================
# relinking.jl — Path relinking entre soluciones élite
# ============================================================
# Path relinking (Glover, Laguna y Martí, 2000): dadas dos buenas
# soluciones distintas, INICIO y GUÍA, se transforma la inicio en la guía
# paso a paso y se evalúan las soluciones intermedias del camino. Esas
# intermedias combinan atributos de ambos óptimos locales y caen en zonas
# que la tabú y el ALNS no visitan (en la 01 y la 03 se comprobó que las
# mejores soluciones son óptimos locales estrictos de todas las vecindades).
# Atributos de un lote = su HUELLA de la tabú (máquina y lote anterior en
# la máquina; AGV y parada anterior de sus dos paradas). Un paso transfiere
# un lote: lo deja en la máquina y detrás del mismo lote que en la guía, y
# pone cada parada detrás de la misma parada que en la guía. Relinking
# voraz: en cada paso se elige, entre los lotes que aún difieren, la
# transferencia que da la mejor solución intermedia.

const Elite = Tuple{Vector{Vector{Int}},Plan,Float64}

# --- Transferir un lote hacia la guía ------------------------------------

function anterior_en_maquina(seq, x)
    for j in eachindex(seq), k in eachindex(seq[j])
        seq[j][k] == x && return j, k, (k == 1 ? 0 : seq[j][k-1])
    end
end

function mover_en_maquina!(s, gs, x)
    jg, kg, y = anterior_en_maquina(gs, x)
    j, k, _ = anterior_en_maquina(s, x)
    deleteat!(s[j], k)
    pos = y == 0 ? 1 : something(findfirst(==(y), s[jg]), min(kg, length(s[jg]) + 1) - 1) + 1
    insert!(s[jg], min(pos, length(s[jg]) + 1), x)
end

# Parada real anterior a la posición k en el viaje (salta visitas a o/f)
function anterior_real(viaje, k)
    for m in k-1:-1:1
        es_real(viaje[m]) && return viaje[m]
    end
    return nothing
end

function poner_como_en_guia!(p, gp, x, abastece)
    a, v, k = buscar_parada(gp, x, abastece)
    q = anterior_real(gp[a][v], k)
    lugar = q === nothing ? nothing : buscar_parada(p, q.lote, q.abastece)
    lugar === nothing && return insert!(p[a], clamp(v, 1, length(p[a]) + 1), [Parada(abastece, x)])
    a2, v2, k2 = lugar
    insert!(p[a2][v2], k2 + 1, Parada(abastece, x))
end

function transferir(s, p, gs, gp, x)
    s2, p2 = copiar_seq(s), copiar_plan(p)
    mover_en_maquina!(s2, gs, x)
    for abastece in (true, false)
        quitar_parada!(p2, x, abastece)
        poner_como_en_guia!(p2, gp, x, abastece)
    end
    return s2, limpiar!(p2)
end

# --- Camino de relinking voraz -------------------------------------------

diferentes(ins, s, p, hg) = cambiados(huellas(s, p, num_lotes(ins)), hg)

function mejor_transferencia(ins, s, p, gs, gp, pendientes)
    mejor = (s, p, Inf, pendientes[1])
    for x in pendientes
        s2, p2 = transferir(s, p, gs, gp, x)
        v = evaluar_plan(ins, s2, p2)
        v < mejor[3] && (mejor = (s2, p2, v, x))
    end
    mejor[3] == Inf && (mejor = (transferir(s, p, gs, gp, pendientes[1])..., Inf, pendientes[1]))
    return mejor
end

# Devuelve las soluciones intermedias factibles del camino inicio -> guía
function camino_relinking(ins, inicio, guia)
    s, p = inicio[1], inicio[2]
    hg, hechos, camino = huellas(guia[1], guia[2], num_lotes(ins)), Set{Int}(), Elite[]
    for _ in 1:2*num_lotes(ins)
        pendientes = setdiff(diferentes(ins, s, p, hg), hechos)
        isempty(pendientes) && break
        s, p, v, x = mejor_transferencia(ins, s, p, guia[1], guia[2], pendientes)
        push!(hechos, x)
        isfinite(v) && push!(camino, (s, p, v))
    end
    return camino
end

# Intermedias que no son (casi) iguales a los extremos, de mejor a peor
function intermedias(camino, inicio, guia, k)
    distinta(c) = abs(c[3] - inicio[3]) > 1e-6 && abs(c[3] - guia[3]) > 1e-6
    return sort(filter(distinta, camino), by = last)[1:min(k, end)]
end
