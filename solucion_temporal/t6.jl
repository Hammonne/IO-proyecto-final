# Búsqueda local sobre un GUION de parámetros por tramos (los parámetros cambian a lo largo de la construcción)
include("proto.jl")
using Random
function vecino(rng, p, ins)
    q = deepcopy(p)
    for _ in 1:rand(rng, 1:3)
        c = rand(rng, 1:10); f = exp(0.35 * randn(rng))
        if c == 1; q.psi *= f elseif c == 2; q.rho = max(0, q.rho + 0.5 * randn(rng)) elseif c == 3; q.H = max(0, q.H + 4 * randn(rng))
        elseif c == 4; q.theta *= f elseif c == 5; q.wp *= f elseif c == 6; q.D = max(0, q.D + 4 * randn(rng))
        elseif c <= 8; j = rand(rng, 1:num_maquinas(ins)); q.B[j] *= exp(0.15 * randn(rng))
        else j = rand(rng, 1:num_maquinas(ins)); r = rand(rng, findall(>(0), ins.v[j, :])); q.W[j, r] *= f end
    end
    return q
end
valor(ins, g) = evaluar_plan(ins, construir(ins, g)...)
function escalar(ins, p0, seg, rng, L)
    p = deepcopy(p0); p.W = ones(size(ins.v)); p.B = ones(num_maquinas(ins))
    g = [p for _ in 1:L]; v = valor(ins, g); t0 = time(); k = 0
    while time() - t0 < seg
        m = rand(rng) < 0.3 ? 1 : rand(rng, 1:L); m2 = rand(rng) < 0.5 ? L : min(L, m + rand(rng, 0:10))
        q = vecino(rng, g[m], ins); h = copy(g); h[m:m2] .= Ref(q)
        w = valor(ins, h); k += 1
        w <= v && ((g, v) = (h, w))
    end
    return g, v, k
end
mkpath("res3")
for id in ARGS
    ins = leer_instancia("s13/instancias/instancia_$id.txt"); rng = MersenneTwister(parse(Int, get(ENV, "SEM", "5")))
    p0 = Par(psi = 3.0, rho = 2.0, H = 3.0, theta = 70.0, wp = 1.0, D = 0.0)
    L = ceil(Int, 1.3 * num_lotes(ins) / ins.C)
    g, v, k = escalar(ins, p0, parse(Float64, get(ENV, "SEG", "60")), rng, L)
    seq, plan = construir(ins, g); e, ok = decodificar(ins, seq, plan); errs = validar(ins, e)
    println(id, ": guion por tramos -> ", round(v, digits = 2), " en $k evaluaciones; errores=", errs, " ", length.(seq))
    escribir_txt("res3/instancia_$(id)_io1lab.txt", ins, e)
end
