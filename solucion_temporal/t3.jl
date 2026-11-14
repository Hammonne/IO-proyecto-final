include("proto.jl")
using Random
function azar(rng)
    Par(psi = rand(rng, (0.5, 1.0, 2.0, 4.0, 8.0, 30.0)), rho = rand(rng, (0.0, 0.5, 1.0, 2.0, 3.0)), H = rand(rng, (0.0, 3.0, 6.0, 10.0, 20.0)),
        theta = rand(rng, (15.0, 25.0, 35.0, 50.0, 70.0, 100.0, 150.0, 300.0)), wp = rand(rng, (0.3, 0.5, 0.75, 1.0, 1.5, 2.0)), D = rand(rng, (0.0, 5.0, 12.0, 25.0)), spt = rand(rng, (0.0, 0.5, 1.0)))
end
mkpath("res")
for id in ARGS
    ins = leer_instancia("s13/instancias/instancia_$id.txt"); rng = MersenneTwister(1)
    mejor = (Inf, Par(), nothing, nothing); t0 = time(); k = 0; vals = Float64[]
    while time() - t0 < 25
        par = azar(rng); seq, plan = construir(ins, par); v = evaluar_plan(ins, seq, plan); k += 1; push!(vals, v)
        v < mejor[1] && (mejor = (v, par, seq, plan))
    end
    v, par, seq, plan = mejor
    e, ok = decodificar(ins, seq, plan); errs = ok ? validar(ins, e) : ["infactible"]
    ref = evaluar_plan(ins, leer_txt(ins, "mejores/instancia_$(id)_io1lab.txt")...)
    println(id, ": mejor constructivo ", round(v, digits = 2), " (nuestra mejor ", round(ref, digits = 2), ")  de $k intentos, mediana ", round(sort(vals)[end÷2], digits = 1), " errores=", errs, "  ", length.(seq))
    println("    ", par)
    isempty(errs) && escribir_txt("res/instancia_$(id)_io1lab.txt", ins, e)
end
