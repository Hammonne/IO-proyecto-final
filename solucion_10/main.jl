# ============================================================
# main.jl — Solución 10: multi-arranque por asignaciones a máquinas
#           (K mejores de Murty) + tabú
# ============================================================
# Uso:  julia main.jl instancias/instancia_01.txt [segundos] [semilla] [seg_por_asignacion]
#
# Idea: en la 01 la mejor solución resiste a todas las búsquedas que parten de
# ella, así que la del líder debe tener OTRA estructura (otra asignación de
# lotes a máquinas). En vez de esperar a que la búsqueda llegue sola, se
# recorren a propósito asignaciones distintas:
#   1. Se listan las asignaciones a máquinas en orden de costo (murty.jl).
#   2. Fase 1: para cada una, plan inicial por reglas de despacho y tabú SOLO
#      sobre los viajes de los AGVs (máquinas fijas), seg_por_asignacion s.
#   3. Fase 2: las MEJORES_FASE2 mejores de la fase 1 se pulen con la tabú
#      completa (ya puede mover lotes entre máquinas).
# Solo se guarda la solución si es factible y mejora la guardada.

for archivo in ("datos", "simulador", "despacho", "constructivo", "asignacion", "busqueda",
                "recocido", "validador", "exportar", "leer_solucion", "plan", "leer_txt",
                "vecindades", "busqueda_plan", "tabu", "ventanas", "murty")
    include(joinpath(@__DIR__, archivo * ".jl"))
end

const K_ASIGNACIONES, MEJORES_FASE2, FRACCION_FASE1 = 1000, 3, 0.6

nombre_base(archivo) = splitext(basename(archivo))[1]
archivo_txt(base) = joinpath(@__DIR__, "resultados", "$(base)_io1lab.txt")
r2(x) = round(x, digits = 2)

# Plan de AGVs por reglas de despacho para una secuencia fija de máquinas
function plan_por_reglas(ins, seq)
    pars = parametros_base(ins)
    mejor = pars[argmin([evaluar(ins, seq, q) for q in pars])]
    return plan_desde_estado(ins, simular(ins, seq, mejor))
end

# --- Fase 1: tabú solo sobre los AGVs, una asignación a la vez -------------

function probar_asignacion(ins, seq, segundos, semilla)
    plan = plan_por_reglas(ins, seq)
    isfinite(evaluar_plan(ins, seq, plan)) || return (seq, plan, Inf)
    SOLO_PLAN[] = true
    st = busqueda_tabu(ins, seq, plan, segundos; semilla, mostrar = false)
    SOLO_PLAN[] = false
    return st.mejor
end

function fase1(ins, asignaciones, segundos, seg_por_asig, semilla)
    fin, resultados = time() + segundos, []
    for (r, (costo, seq)) in enumerate(asignaciones)
        time() + seg_por_asig > fin && break
        sol = probar_asignacion(ins, seq, seg_por_asig, semilla + r)
        println("  asignación $r (costo máquinas $(r2(costo))): ", r2(sol[3]))
        push!(resultados, sol)
    end
    return sort!(resultados, by = last)
end

# --- Fase 2: tabú completa sobre las mejores -------------------------------

function fase2(ins, candidatas, segundos, semilla)
    mejor = (candidatas[1][1], candidatas[1][2], Inf)
    for (k, c) in enumerate(candidatas)
        st = busqueda_tabu(ins, c[1], c[2], segundos; semilla = semilla + 100k, mostrar = false)
        println("  pulida $k: ", r2(c[3]), " -> ", r2(st.mejor[3]))
        st.mejor[3] < mejor[3] && (mejor = st.mejor)
    end
    return mejor
end

# --- Guardar -------------------------------------------------------------

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

function main(archivo, segundos, semilla, seg_por_asig)
    ins, base = leer_instancia(archivo), nombre_base(archivo)
    asignaciones = secuencias_distintas(ins, K_ASIGNACIONES)
    println("$base: ", length(asignaciones), " asignaciones distintas; guardada ", r2(valor_guardado(ins, base)))
    candidatas = fase1(ins, asignaciones, FRACCION_FASE1 * segundos, seg_por_asig, semilla)
    resto = segundos - (time() - T_INICIO)
    top = candidatas[1:min(MEJORES_FASE2, length(candidatas))]
    seq, plan, valor = fase2(ins, top, resto / length(top), semilla)
    println("$base final: ", r2(valor))
    guardar_si_mejora(ins, base, seq, plan, valor)
end

const T_INICIO = time()
isempty(ARGS) && (println("Uso: julia main.jl instancias/instancia_01.txt [segundos] [semilla] [seg_por_asignacion]"); exit())
main(ARGS[1], parse(Float64, get(ARGS, 2, "60")), parse(Int, get(ARGS, 3, "1")),
     parse(Float64, get(ARGS, 4, "20")))
