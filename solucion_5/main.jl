# ============================================================
# main.jl — Solución 5: búsqueda tabú sobre el plan de AGVs
# ============================================================
# Uso:  julia main.jl instancias/instancia_01.txt [segundos] [semilla] [cero]
# Método: búsqueda tabú con lista de candidatos (tabu.jl) durante todo el
# tiempo, con las mismas 7 vecindades y el mismo decodificador de la
# solución 3.
# Punto de partida:
#   - resultados/<instancia>_io1lab.txt si existe (mejor solución conocida)
#   - con "cero" como cuarto argumento (o si no hay archivo): solución
#     constructiva de la solución 2 (inserción voraz / asignación húngara +
#     reglas de despacho), SIN búsqueda previa. Sirve para comparar la
#     tabú con el recocido y el ALNS partiendo de lo mismo.
# Solo se guarda la solución si es factible y mejora la guardada.

for archivo in ("datos", "simulador", "despacho", "constructivo", "asignacion", "busqueda",
                "recocido", "validador", "exportar", "leer_solucion", "plan", "leer_txt",
                "vecindades", "busqueda_plan", "tabu")
    include(joinpath(@__DIR__, archivo * ".jl"))
end

nombre_base(archivo) = splitext(basename(archivo))[1]
archivo_txt(base) = joinpath(@__DIR__, "resultados", "$(base)_io1lab.txt")

function inicial_constructiva(ins)
    seq, par = mejor_inicial(ins)
    return seq, plan_desde_estado(ins, simular(ins, seq, par))
end

function solucion_inicial_plan(ins, base, desde_cero)
    !desde_cero && isfile(archivo_txt(base)) && return leer_txt(ins, archivo_txt(base))
    println("Se parte de la solución constructiva (reglas de despacho)")
    return inicial_constructiva(ins)
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

function main(archivo, segundos, semilla, desde_cero)
    ins, base = leer_instancia(archivo), nombre_base(archivo)
    seq, plan = solucion_inicial_plan(ins, base, desde_cero)
    println("$base inicial: ", round(evaluar_plan(ins, seq, plan), digits = 2))
    st = busqueda_tabu(ins, seq, plan, segundos; semilla)
    println("Tabú: ", st.iter, " iteraciones, ", st.reinicios, " reinicios")
    seq, plan, valor = st.mejor
    println("$base final: ", round(valor, digits = 2))
    guardar_si_mejora(ins, base, seq, plan, valor)
end

isempty(ARGS) && (println("Uso: julia main.jl instancias/instancia_01.txt [segundos] [semilla] [cero]"); exit())
main(ARGS[1], parse(Float64, get(ARGS, 2, "60")), parse(Int, get(ARGS, 3, "1")), get(ARGS, 4, "") == "cero")
