# ============================================================
# validador.jl — Verifica de forma independiente que una solución
# simulada cumpla todas las restricciones del enunciado
# ============================================================

const TOL = 1e-6

function errores_agv(ins, ops, a)
    errs, lugar, t, carga = String[], pos_o(ins), 0.0, 0
    for op in filter(op -> op.agv == a, ops)
        op.tiempo + TOL < t + ins.tau[lugar, op.lugar] && push!(errs, "AGV $a: viaje imposible hacia lote $(op.lote)")
        carga += op.tipo == :carga ? 1 : -1
        (carga < 0 || carga > ins.C) && push!(errs, "AGV $a: carga $carga fuera de [0, C]")
        lugar, t = op.lugar, op.tiempo
    end
    return errs
end

function errores_flujo(ins, e, j, k)
    i, errs = e.seq[j][k], String[]
    ops = filter(op -> op.lote == i, e.ops)
    esperado = [pos_o(ins), pos_alfa(ins, j), pos_beta(ins, j), pos_f(ins)]
    [op.lugar for op in ops] == esperado || push!(errs, "Lote $i: recorrido incorrecto")
    length(ops) == 4 || return errs
    ops[2].tiempo > e.inicio[j][k] + TOL && push!(errs, "Lote $i: empieza antes de llegar")
    ops[3].tiempo + TOL < e.salida[j][k] && push!(errs, "Lote $i: recogido antes de salir")
    abs(ops[4].tiempo - e.c[i]) > TOL && push!(errs, "Lote $i: c_i no coincide")
    return errs
end

function errores_maquina(ins, e, j)
    errs, s = String[], e.seq[j]
    for k in eachindex(s)
        p = tiempo_proceso(ins, s[k], j)
        abs(e.fin[j][k] - e.inicio[j][k] - p) > TOL && push!(errs, "M$j: duración incorrecta")
        e.salida[j][k] + TOL < e.fin[j][k] && push!(errs, "M$j: sale antes de terminar")
        k == 1 && continue
        e.inicio[j][k] + TOL < e.salida[j][k-1] && push!(errs, "M$j: procesos superpuestos o máquina bloqueada")
        e.llegada[j][k] + TOL < e.inicio[j][k-1] && push!(errs, "M$j: buffer de entrada ocupado")
        e.salida[j][k] + TOL < e.recojo[j][k-1] && push!(errs, "M$j: buffer de salida ocupado")
    end
    return errs
end

function errores_asignacion(ins, seq)
    errs = String[]
    sort(vcat(seq...)) == 1:num_lotes(ins) || push!(errs, "Cada lote debe asignarse exactamente una vez")
    for j in eachindex(seq), i in seq[j]
        compatible(ins, i, j) || push!(errs, "Lote $i incompatible con M$j")
    end
    return errs
end

function validar(ins, e)
    errs = errores_asignacion(ins, e.seq)
    for a in 1:ins.K
        append!(errs, errores_agv(ins, e.ops, a))
    end
    for j in eachindex(e.seq)
        append!(errs, errores_maquina(ins, e, j))
        foreach(k -> append!(errs, errores_flujo(ins, e, j, k)), eachindex(e.seq[j]))
    end
    return errs
end
