# ============================================================
# exportar.jl — Escribe la solución en el formato TXT de IO1Lab
# ============================================================
# recurso;orden;accion;lote;ubicacion;destino;inicio
# Máquinas: una línea PROCESS por lote. AGVs: PICKUP, DELIVER y MOVE.
# Un MOVE empieza justo después de la última acción del AGV;
# las esperas quedan como huecos al llegar al destino.

function nombre_lugar(ins, u)
    u == pos_o(ins) && return "o"
    u == pos_f(ins) && return "f"
    return (iseven(u) ? "a" : "b") * string(u ÷ 2)
end

tiempo_txt(t) = isinteger(t) ? string(Int(t)) : string(t)

function lineas_maquinas(e)
    lineas = String[]
    for j in eachindex(e.seq), k in eachindex(e.seq[j])
        push!(lineas, "M$j;$k;PROCESS;$(e.seq[j][k]);;;$(tiempo_txt(e.inicio[j][k]))")
    end
    return lineas
end

function linea_movimiento(ins, a, orden, desde, hasta, t)
    return "AGV$a;$orden;MOVE;;$(nombre_lugar(ins, desde));$(nombre_lugar(ins, hasta));$(tiempo_txt(t))"
end

function linea_servicio(ins, a, orden, op)
    accion = op.tipo == :carga ? "PICKUP" : "DELIVER"
    return "AGV$a;$orden;$accion;$(op.lote);$(nombre_lugar(ins, op.lugar));;$(tiempo_txt(op.tiempo))"
end

function lineas_agv(ins, e, a)
    lineas, lugar, t, orden = String[], pos_o(ins), 0.0, 0
    for op in filter(op -> op.agv == a, e.ops)
        if op.lugar != lugar
            push!(lineas, linea_movimiento(ins, a, orden += 1, lugar, op.lugar, t))
        end
        push!(lineas, linea_servicio(ins, a, orden += 1, op))
        lugar, t = op.lugar, op.tiempo
    end
    return lineas
end

function escribir_txt(archivo, ins, e)
    open(archivo, "w") do io
        println(io, "recurso;orden;accion;lote;ubicacion;destino;inicio")
        foreach(l -> println(io, l), lineas_maquinas(e))
        for a in 1:ins.K
            foreach(l -> println(io, l), lineas_agv(ins, e, a))
        end
    end
end
