# Descompone el valor de la mejor solución: asignación a máquinas vs transporte
D = ARGS[1]
for a in ("datos","simulador","despacho","constructivo","asignacion","busqueda","recocido","validador","exportar","leer_solucion","plan","leer_txt","vecindades","busqueda_plan","tabu","transporte")
    include(joinpath(D, a*".jl"))
end
lider = Dict("04"=>521.42,"05"=>590.33,"06"=>741.33,"07"=>877.81,"08"=>1065.64,"09"=>955.55,"10"=>969.80)
# costo "sin congestión" de unas secuencias: ΣC en máquinas desde 0 + ruta mínima de cada lote
function costo_sin_congestion(ins, seq)
    t = 0.0
    for j in eachindex(seq), (k, i) in enumerate(seq[j])
        t += (length(seq[j]) - k + 1) * tiempo_proceso(ins, i, j) + costo_ruta(ins, j)
    end
    return t / num_lotes(ins)
end
println(rpad("inst",5), rpad("nuestra",10), rpad("cota opt",10), rpad("cota nuestra asig",19), rpad("pierde asig",13), rpad("pierde transp",15), rpad("líder",9), "líder-cota")
for k in ARGS[2:end]
    ins = leer_instancia(joinpath(D, "instancias", "instancia_$k.txt"))
    seq, plan = leer_txt(ins, joinpath(D, "..", "mejores", "instancia_$(k)_io1lab.txt"))
    v = evaluar_plan(ins, seq, plan)
    opt = costo_sin_congestion(ins, solucion_asignacion(ins))
    nos = costo_sin_congestion(ins, seq)
    r(x) = string(round(x, digits = 2))
    println(rpad(k,5), rpad(r(v),10), rpad(r(opt),10), rpad(r(nos),19), rpad(r(nos-opt),13), rpad(r(v-nos),15), rpad(r(lider[k]),9), r(lider[k]-opt))
end
