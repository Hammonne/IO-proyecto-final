# ============================================================
# main.jl — Solución 3: búsqueda local sobre el plan explícito de AGVs
# ============================================================
# Uso:  julia main.jl instancias/instancia_01.txt [segundos] [semilla]
# Punto de partida (en este orden):
#   1. resultados/<instancia>_io1lab.txt si existe (mejor solución conocida)
#   2. si no, la solución 2: constructivos + reglas de despacho + recocido
# Solo se guarda la solución si es factible y mejora la guardada.

for archivo in ("datos", "simulador", "despacho", "constructivo", "asignacion", "busqueda",
                "recocido", "validador", "exportar", "leer_solucion", "plan", "leer_txt",
                "vecindades", "busqueda_plan")
    include(joinpath(@__DIR__, archivo * ".jl"))
end

nombre_base(archivo) = splitext(basename(archivo))[1]
archivo_txt(base) = joinpath(@__DIR__, "resultados", "$(base)_io1lab.txt")

# Solución inicial con el método de la solución 2 (reglas de despacho)
function inicial_por_reglas(ins, segundos)
    metodo = num_lotes(ins) <= 60 ? ils : buscar
    seq, par, _ = metodo(ins; segundos, semilla = 1, mostrar = false)
    return seq, plan_desde_estado(ins, simular(ins, seq, par))
end

function solucion_inicial_plan(ins, base, segundos)
    isfile(archivo_txt(base)) && return leer_txt(ins, archivo_txt(base))
    println("Sin solución previa: se construye con reglas de despacho")
    return inicial_por_reglas(ins, segundos)
end

valor_guardado(ins, base) = isfile(archivo_txt(base)) ? evaluar_plan(ins, leer_txt(ins, archivo_txt(base))...) : Inf

function guardar_si_mejora(ins, base, seq, plan, valor)
    e, ok = decodificar(ins, seq, plan)
    errs = ok ? validar(ins, e) : ["plan infactible"]
    isempty(errs) || return println("ERRORES: ", errs)
    valor < valor_guardado(ins, base) - 1e-9 || return println("No mejora la solución guardada")
    mkpath(joinpath(@__DIR__, "resultados"))
    escribir_txt(archivo_txt(base), ins, e)
    println("Guardada (factible y mejor que la anterior)")
end

function main(archivo, segundos, semilla)
    ins, base = leer_instancia(archivo), nombre_base(archivo)
    seq, plan = solucion_inicial_plan(ins, base, 0.3 * segundos)
    println("$base inicial: ", round(evaluar_plan(ins, seq, plan), digits = 2))
    b = recocido_plan(ins, seq, plan, segundos; semilla)
    seq, plan, valor = b.mejor
    println("$base final: ", round(valor, digits = 2))
    println("Pesos finales: ", join(["$n=$(round(w, digits = 2))" for (n, w) in zip(NOMBRES_VECINDADES, b.ad.pesos)], ", "))
    guardar_si_mejora(ins, base, seq, plan, valor)
end

isempty(ARGS) && (println("Uso: julia main.jl instancias/instancia_01.txt [segundos] [semilla]"); exit())
main(ARGS[1], parse(Float64, get(ARGS, 2, "60")), parse(Int, get(ARGS, 3, "1")))
