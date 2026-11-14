include("proto.jl")
for id in ARGS
    ins = leer_instancia("s13/instancias/instancia_$id.txt")
    res = []
    for psi in (1.0, 3.0, 8.0, 30.0), rho in (1.0, 3.0), H in (0.0, 10.0), theta in (1e9, 200.0, 100.0, 50.0, 25.0), wp in (0.5, 1.0, 2.0), D in (0.0, 12.0)
        par = Par(psi = psi, rho = rho, H = H, theta = theta, wp = wp, D = D)
        seq, plan = construir(ins, par)
        push!(res, (evaluar_plan(ins, seq, plan), par, length.(seq)))
    end
    sort!(res, by = first)
    for r in res[1:6]; println(id, " ", round(r[1], digits = 2), " psi=", r[2].psi, " rho=", r[2].rho, " H=", r[2].H, " theta=", r[2].theta, " wp=", r[2].wp, " D=", r[2].D, " ", r[3]); end
    println(id, " mediana ", round(res[end÷2][1], digits = 2), " peor ", round(res[end][1], digits = 2), "  n=", length(res))
    if length(ARGS) == 1
        p = parametros_base(ins); s0, par0 = mejor_inicial(ins)
        println("constructiva v2: ", round(evaluar(ins, s0, par0), digits = 2))
        for b in (20.0, 40.0); s, pl = inicial_transporte(ins, b); println("asig transporte BETA=$b: ", round(evaluar_plan(ins, s, pl), digits = 2), " ", length.(s)); end
    end
end
