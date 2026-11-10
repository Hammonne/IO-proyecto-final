# ============================================================
# main.jl — Solución 3 (Yampi): reglas básicas con excepciones S y Y
# ============================================================
# Uso:   julia main.jl instancias/instancia_01.txt [sin|zonas]
# Flujo:
#   1. R1: asignación inicial por mayor tasa + orden SPT dentro de cada fila
#   2. R2: balance de filas (desde el último lote de la fila más larga)
#   3. R3/R4 + excepciones S y Y: simulación de los viajes de los AGVs
#   4. Validación independiente con validador.jl
#   5. Escritura del TXT de IO1Lab en resultados/
# Sin búsqueda: es un constructivo de reglas. "zonas" activa la asignación
# de máquinas por zona a cada AGV.

for archivo in ("datos", "simulador", "validador", "exportar",
                "secuencias", "despacho_reglas")
    include(joinpath(@__DIR__, archivo * ".jl"))
end

nombre_base(archivo) = splitext(basename(archivo))[1]

function resolver(archivo, modo)
    ins = leer_instancia(archivo)
    seq = asignacion_inicial(ins)
    balancear!(ins, seq)
    zonas = modo == "zonas" ? zonas_por_cercania(ins) : Int[]
    par = ParamsV5(60.0, 1.0, 1.0, 1.0, 1.0, zonas)
    return ins, simular_reglas(ins, seq, par)
end

function main(archivo, modo)
    ins, e = resolver(archivo, modo)
    errores = validar(ins, e)
    if !isempty(errores)
        println("La solución NO es factible:")
        foreach(println, first(errores, 10))
        return
    end
    promedio = sum(e.c) / num_lotes(ins)
    println(nombre_base(archivo), " (", modo, "): promedio = ", round(promedio, digits = 2))
    salida = joinpath(@__DIR__, "resultados", modo)
    mkpath(salida)
    escribir_txt(joinpath(salida, "$(nombre_base(archivo))_io1lab.txt"), ins, e)
end

if abspath(PROGRAM_FILE) == @__FILE__
    isempty(ARGS) && (println("Uso: julia main.jl instancias/instancia_01.txt [sin|zonas]"); exit())
    main(ARGS[1], get(ARGS, 2, "sin"))
end
