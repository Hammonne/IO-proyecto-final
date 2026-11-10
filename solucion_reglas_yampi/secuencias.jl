# ============================================================
# secuencias.jl — Reglas R1 y R2: asignación inicial y balance de filas
# ============================================================
# R1: cada lote va a la máquina compatible con mayor tasa.
#     Dentro de cada máquina se ordena por tiempo de proceso (SPT).
# R2: si una fila es más larga que otra, se recorren sus lotes desde el
#     último hacia el primero (k). Un lote se pasa a su siguiente máquina
#     compatible solo si termina antes allí ("vale la pena").

# Máquinas compatibles con el lote i, de mayor a menor tasa
function maquinas_por_tasa(ins, i)
    return sort(maquinas_compatibles(ins, i); by = j -> -ins.v[j, ins.r[i]])
end

# Ordena cada fila por tiempo de proceso (SPT)
function ordenar_spt!(ins, seq)
    for j in eachindex(seq)
        sort!(seq[j]; by = i -> tiempo_proceso(ins, i, j))
    end
    return seq
end

# R1: asignación inicial por mayor tasa
function asignacion_inicial(ins)
    seq = [Int[] for _ in 1:num_maquinas(ins)]
    for i in 1:num_lotes(ins)
        push!(seq[first(maquinas_por_tasa(ins, i))], i)
    end
    return ordenar_spt!(ins, seq)
end

# Tiempo total de trabajo que ya tiene asignado la máquina j
carga_fila(ins, seq, j) = sum(i -> tiempo_proceso(ins, i, j), seq[j]; init = 0.0)

# Pasar el lote i de j1 a j2 vale la pena si termina antes en j2 que en j1
function vale_la_pena(ins, seq, i, j1, j2)
    termina_en_j2 = carga_fila(ins, seq, j2) + tiempo_proceso(ins, i, j2)
    return termina_en_j2 < carga_fila(ins, seq, j1)
end

# Intenta pasar un lote de la fila j1 (desde el último). Devuelve true si lo hizo.
function mover_desde!(ins, seq, j1)
    for i in reverse(seq[j1]), j2 in maquinas_por_tasa(ins, i)
        (j2 == j1 || !vale_la_pena(ins, seq, i, j1, j2)) && continue
        filter!(!=(i), seq[j1])
        push!(seq[j2], i)
        return true
    end
    return false
end

# R2: repetir mientras haya filas que se puedan aliviar, empezando por la más larga
function balancear!(ins, seq)
    for _ in 1:(10 * num_lotes(ins))
        movido = false
        for j1 in sortperm(length.(seq); rev = true)
            movido = mover_desde!(ins, seq, j1)
            movido && break
        end
        movido || break
    end
    return ordenar_spt!(ins, seq)
end
