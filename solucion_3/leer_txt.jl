# ============================================================
# leer_txt.jl — Reconstruye secuencias y plan desde un TXT de IO1Lab
# ============================================================
# Permite partir de cualquier solución ya enviada a la plataforma,
# sin depender de la versión del código que la generó.

function indice_lugar(ins, nombre)
    nombre == "o" && return pos_o(ins)
    nombre == "f" && return pos_f(ins)
    j = parse(Int, nombre[2:end])
    return nombre[1] == 'a' ? pos_alfa(ins, j) : pos_beta(ins, j)
end

function operacion_txt(ins, campos)
    a = parse(Int, campos[1][4:end])
    tipo = campos[3] == "PICKUP" ? :carga : :descarga
    return Operacion(a, tipo, parse(Int, campos[4]), indice_lugar(ins, campos[5]), parse(Float64, campos[7]))
end

function leer_txt(ins, archivo)
    seq, ops = [Int[] for _ in 1:num_maquinas(ins)], Operacion[]
    for linea in readlines(archivo)[2:end]
        campos = split(linea, ";")
        if campos[3] == "PROCESS"
            push!(seq[parse(Int, campos[1][2:end])], parse(Int, campos[4]))
        elseif campos[3] in ("PICKUP", "DELIVER")
            push!(ops, operacion_txt(ins, campos))
        end
    end
    return seq, [viajes_de_agv(ins, ops, a) for a in 1:ins.K]
end
