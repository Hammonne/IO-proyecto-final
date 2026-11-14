# Búsqueda local sobre los parámetros del constructivo (escalada estocástica)
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
valor(ins, p) = evaluar_plan(ins, construir(ins, p)...)
function escalar(ins, p0, seg, rng)
    p = deepcopy(p0); isempty(p.W) && (p.W = ones(size(ins.v))); isempty(p.B) && (p.B = ones(num_maquinas(ins)))
    v = valor(ins, p); t0 = time(); k = 0
    while time() - t0 < seg
        q = vecino(rng, p, ins); w = valor(ins, q); k += 1
        w <= v && ((p, v) = (q, w))
    end
    return p, v, k
end
mkpath("res2")
for id in ARGS
    ins = leer_instancia("s13/instancias/instancia_$id.txt"); rng = MersenneTwister(5)
    p0 = Par(psi = 3.0, rho = 2.0, H = 3.0, theta = 70.0, wp = 1.0, D = 0.0)
    p, v, k = escalar(ins, p0, parse(Float64, get(ENV, "SEG", "60")), rng)
    seq, plan = construir(ins, p); e, ok = decodificar(ins, seq, plan); errs = validar(ins, e)
    println(id, ": inicio ", round(valor(ins, p0), digits = 2), " -> ", round(v, digits = 2), " en $k evaluaciones; errores=", errs, " ", length.(seq))
    escribir_txt("res2/instancia_$(id)_io1lab.txt", ins, e)
end
