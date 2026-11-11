# ============================================================
# main.jl — Solución 9: path relinking entre soluciones élite + tabú
# ============================================================
# Uso:  julia main.jl instancias/instancia_01.txt [segundos] [semilla]
# Conjunto élite (soluciones buenas y distintas de la instancia):
#   - resultados/<instancia>_io1lab.txt (la mejor guardada)
#   - elite/*/<instancia>_io1lab.txt (soluciones de otras corridas o de
#     otros integrantes: cada subcarpeta de elite/ aporta una)
#   - si hay menos de TAM_ELITE_MIN, se completan con la tabú de la
#     solución 7 desde la solución constructiva con semillas distintas
# Luego, mientras haya tiempo: se elige un par (inicio, guía) del élite,
# se recorre el camino de relinking (relinking.jl) y se pulen con la tabú
# las mejores intermedias. Solo se guarda la solución si es factible y
# mejora la guardada.

for archivo in ("datos", "simulador", "despacho", "constructivo", "asignacion", "busqueda",
                "recocido", "validador", "exportar", "leer_solucion", "plan", "leer_txt",
                "vecindades", "busqueda_plan", "tabu", "ventanas", "relinking")
    include(joinpath(@__DIR__, archivo * ".jl"))
end

const TAM_ELITE_MIN, INTERMEDIAS_A_PULIR = 5, 2
const FRACCION_GENERAR, FRACCION_PULIDO = 0.05, 0.02

nombre_base(archivo) = splitext(basename(archivo))[1]
archivo_txt(base) = joinpath(@__DIR__, "resultados", "$(base)_io1lab.txt")

# --- Conjunto élite --------------------------------------------------------

function archivos_elite(base)
    dirs = isdir(joinpath(@__DIR__, "elite")) ? readdir(joinpath(@__DIR__, "elite"), join = true) : String[]
    candidatos = vcat([archivo_txt(base)], [joinpath(d, "$(base)_io1lab.txt") for d in dirs])
    return filter(isfile, candidatos)
end

function agregar_distinta!(elite, sol)
    isfinite(sol[3]) || return
    any(abs(e[3] - sol[3]) < 1e-6 for e in elite) && return
    push!(elite, sol)
end

function leer_elite(ins, base)
    elite = Elite[]
    for f in archivos_elite(base)
        seq, plan = leer_txt(ins, f)
        agregar_distinta!(elite, (seq, plan, evaluar_plan(ins, seq, plan)))
    end
    return elite
end

function completar_elite!(elite, ins, segundos, semilla)
    s0, p0 = mejor_inicial(ins)
    plan0 = plan_desde_estado(ins, simular(ins, s0, p0))
    for k in 1:TAM_ELITE_MIN
        length(elite) >= TAM_ELITE_MIN && break
        st = busqueda_tabu(ins, s0, plan0, segundos; semilla = semilla + k, mostrar = false)
        agregar_distinta!(elite, st.mejor)
    end
    return sort!(elite, by = last)
end

# --- Relinking + pulido ------------------------------------------------------

function relinking_y_pulir(ins, inicio, guia, segundos, semilla)
    mejor = (inicio[1], inicio[2], Inf)
    for c in intermedias(camino_relinking(ins, inicio, guia), inicio, guia, INTERMEDIAS_A_PULIR)
        st = busqueda_tabu(ins, c[1], c[2], segundos; semilla, mostrar = false)
        st.mejor[3] < mejor[3] && (mejor = st.mejor)
    end
    return mejor
end

# El inicio es siempre una de las 2 mejores; la guía, cualquier otra élite
function elegir_par(elite, rng)
    i = rand(rng, 1:min(2, length(elite)))
    j = rand(rng, setdiff(eachindex(elite), i))
    return elite[i], elite[j]
end

function path_relinking(ins, elite, segundos, semilla)
    rng, fin, ronda = MersenneTwister(semilla), time() + segundos, 0
    while time() < fin && length(elite) >= 2
        inicio, guia = elegir_par(elite, rng)
        c = relinking_y_pulir(ins, inicio, guia, FRACCION_PULIDO * segundos, semilla + (ronda += 1))
        println("  ronda $ronda: ", round(inicio[3], digits = 2), " -> ", round(guia[3], digits = 2),
                " : ", round(c[3], digits = 2), c[3] < elite[1][3] - 1e-9 ? "  NUEVA MEJOR" : "")
        agregar_distinta!(elite, c)
        sort!(elite, by = last)
    end
    return elite[1]
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

function main(archivo, segundos, semilla)
    ins, base = leer_instancia(archivo), nombre_base(archivo)
    elite = leer_elite(ins, base)
    println("$base: ", length(elite), " soluciones élite leídas: ", [round(e[3], digits = 2) for e in elite])
    completar_elite!(elite, ins, FRACCION_GENERAR * segundos, semilla)
    println("Élite: ", [round(e[3], digits = 2) for e in elite])
    seq, plan, valor = path_relinking(ins, elite, segundos - (time() - T_INICIO), semilla)
    println("$base final: ", round(valor, digits = 2))
    guardar_si_mejora(ins, base, seq, plan, valor)
end

const T_INICIO = time()
isempty(ARGS) && (println("Uso: julia main.jl instancias/instancia_01.txt [segundos] [semilla]"); exit())
main(ARGS[1], parse(Float64, get(ARGS, 2, "60")), parse(Int, get(ARGS, 3, "1")))
