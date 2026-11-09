# ============================================================
# main.jl — Ejecuta el método completo sobre una instancia
# ============================================================
# Uso:  julia main.jl instancias/instancia_01.txt [segundos] [semilla]
# Sin argumentos resuelve la instancia de ejemplo del enunciado.
# Guarda en resultados/: secuencias por máquina, tiempos de cada lote
# y operaciones de los AGVs.

include("datos.jl")
include("simulador.jl")
include("despacho.jl")
include("constructivo.jl")
include("asignacion.jl")
include("busqueda.jl")
include("recocido.jl")
include("validador.jl")
include("exportar.jl")
include("leer_solucion.jl")

nombre_base(archivo) = isempty(archivo) ? "ejemplo" : splitext(basename(archivo))[1]

function guardar_secuencias(io, e, par, valor)
    println(io, "objetivo,", valor)
    println(io, "parametros,", par.holgura, ",", par.peso_necesidad, ",", par.sesgo_retiro)
    println(io, "zona,", join(par.zona, ","))
    for (j, s) in enumerate(e.seq)
        println(io, "maquina_$j,", join(s, ","))
    end
end

function guardar_lotes(io, e)
    println(io, "lote,maquina,llegada_alfa,inicio,fin,salida_beta,recojo,c")
    for j in eachindex(e.seq), k in eachindex(e.seq[j])
        fila = (e.seq[j][k], j, e.llegada[j][k], e.inicio[j][k], e.fin[j][k],
                e.salida[j][k], e.recojo[j][k], e.c[e.seq[j][k]])
        println(io, join(fila, ","))
    end
end

function guardar_operaciones(io, e)
    println(io, "agv,tipo,lote,ubicacion,tiempo")
    for op in e.ops
        println(io, "$(op.agv),$(op.tipo),$(op.lote),$(op.lugar),$(op.tiempo)")
    end
end

function guardar(base, ins, e, par, valor)
    mkpath("resultados")
    open(io -> guardar_secuencias(io, e, par, valor), "resultados/$(base)_solucion.csv", "w")
    open(io -> guardar_lotes(io, e), "resultados/$(base)_lotes.csv", "w")
    open(io -> guardar_operaciones(io, e), "resultados/$(base)_agv.csv", "w")
    escribir_txt("resultados/$(base)_io1lab.txt", ins, e)
end

# Valor de la mejor solución ya guardada (Inf si no hay)
function valor_guardado(base)
    archivo = "resultados/$(base)_solucion.csv"
    isfile(archivo) || return Inf
    return parse(Float64, split(readline(archivo), ",")[2])
end

# Arranque en caliente: si hay una solución guardada con zonas, se parte de ella
function solucion_previa(base)
    archivo = "resultados/$(base)_solucion.csv"
    isfile(archivo) && occursin("zona,", read(archivo, String)) || return nothing
    return leer_solucion(archivo)
end

function main(archivo, segundos, semilla)
    ins = isempty(archivo) ? instancia_ejemplo() : leer_instancia(archivo)
    # Instancias chicas: ILS (el descenso completo es barato). Grandes: recocido.
    metodo = num_lotes(ins) <= 60 ? ils : buscar
    seq, par, valor = metodo(ins; segundos, semilla, inicio = solucion_previa(nombre_base(archivo)))
    e = simular(ins, seq, par)
    errs = validar(ins, e)
    println("\n$(nombre_base(archivo)): ", round(valor, digits = 2), isempty(errs) ? "  (factible)" : "  ERRORES: $errs")
    if isempty(errs) && valor < valor_guardado(nombre_base(archivo)) - 1e-9
        guardar(nombre_base(archivo), ins, e, par, valor)
        println("Guardada (mejora la anterior)")
    end
end

main(get(ARGS, 1, ""), parse(Float64, get(ARGS, 2, "30")), parse(Int, get(ARGS, 3, "1")))
