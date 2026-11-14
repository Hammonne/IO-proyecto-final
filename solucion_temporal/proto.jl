# Prototipo: constructivo "por ciclos" con asignación en línea (el AGV decide máquina y lote al cargar)
include("base.jl")
mutable struct Maq
    lotes::Vector{Int}; lleg::Vector{Float64}; ini::Vector{Float64}; fin::Vector{Float64}
    sal::Vector{Float64}; rec::Vector{Float64}; nrec::Int
end
Maq() = Maq(Int[], Float64[], Float64[], Float64[], Float64[], Float64[], 0)
copia(m::Maq) = Maq(copy(m.lotes), copy(m.lleg), copy(m.ini), copy(m.fin), copy(m.sal), copy(m.rec), m.nrec)
function propaga!(m, ins, j)
    for k in eachindex(m.lotes)
        if isnan(m.ini[k])
            prev = k == 1 ? 0.0 : m.sal[k-1]
            isnan(prev) && break
            m.ini[k] = max(m.lleg[k], prev); m.fin[k] = m.ini[k] + tiempo_proceso(ins, m.lotes[k], j)
        end
        if isnan(m.sal[k])
            prev = k == 1 ? 0.0 : m.rec[k-1]
            isnan(prev) || (m.sal[k] = max(m.fin[k], prev))
        end
    end
end
alfa_libre(m) = isempty(m.lotes) ? 0.0 : m.ini[end]
listo_retiro(m) = m.nrec + 1 > length(m.lotes) ? NaN : m.sal[m.nrec+1]
function entrega!(m, ins, j, i, t)
    push!(m.lotes, i); push!(m.lleg, t); foreach(v -> push!(v, NaN), (m.ini, m.fin, m.sal, m.rec)); propaga!(m, ins, j)
end
function retira!(m, ins, j, t)
    m.nrec += 1; m.rec[m.nrec] = t; propaga!(m, ins, j); return m.lotes[m.nrec]
end
Base.@kwdef mutable struct Par
    H::Float64 = 8.0      # espera máxima en beta para recoger
    D::Float64 = 12.0     # desvío máximo para un retiro extra
    rho::Float64 = 2.0    # castigo a procesar un lote en una máquina lenta para él
    wp::Float64 = 1.0     # valor de un retiro frente a una entrega
    psi::Float64 = 3.0    # castigo extra por segundo de espera del AGV
    spt::Float64 = 1.0    # peso del tamaño del lote al elegir
    theta::Float64 = 1e9  # una entrega vale menos si el lote va a esperar en alfa
    ruido::Float64 = 0.0
    W::Matrix{Float64} = ones(0, 0)   # preferencia máquina-tipo (multiplica la clave del lote)
    B::Vector{Float64} = Float64[]    # valor de abastecer cada máquina
end
# mejor lote libre para la máquina j
function elige_lote(ins, j, libres, usados, par, pmin)
    mejor, val = 0, Inf
    for i in libres
        (i in usados || !compatible(ins, i, j)) && continue
        p = tiempo_proceso(ins, i, j)
        v = (p / pmin[i])^par.rho * (par.spt * p + (1 - par.spt) * 100) * (1 + par.ruido * rand()) * (isempty(par.W) ? 1.0 : par.W[j, ins.r[i]])
        v < val && ((mejor, val) = (i, v))
    end
    return mejor
end
# simula un ciclo desde (pos, t): entrega en las máquinas de tupla, recoge lo que haya; devuelve todo
function ciclo(ins, M, libres, pos, t, tupla, par, pmin)
    Mc = Dict{Int,Maq}(); paradas = Parada[]; usados = Int[]; np = 0; t0 = t; esp = 0.0; vd = 0.0
    maq(j) = get!(() -> copia(M[j]), Mc, j)
    lotes = Int[]
    for j in tupla
        i = elige_lote(ins, j, libres, lotes, par, pmin); i == 0 && return nothing
        push!(lotes, i)
    end
    isempty(tupla) || (t += ins.tau[pos, 1]; pos = 1)
    for (j, i) in zip(tupla, lotes)
        m = maq(j); al = alfa_libre(m); isnan(al) && return nothing
        lle = t + ins.tau[pos, pos_alfa(ins, j)]; esp += max(0.0, al - lle); t = max(lle, al); pos = pos_alfa(ins, j)
        w = length(m.lotes) == 0 ? 0.0 : max(0.0, m.fin[end] - t)
        vd += (isempty(par.B) ? 1.0 : par.B[j]) / (1 + w / par.theta)
        entrega!(m, ins, j, i, t); push!(paradas, Parada(true, i))
        lr = listo_retiro(m)
        if !isnan(lr) && lr <= t + ins.tau[pos, pos_beta(ins, j)] + par.H
            lle = t + ins.tau[pos, pos_beta(ins, j)]; esp += max(0.0, lr - lle); t = max(lle, lr); pos = pos_beta(ins, j)
            push!(paradas, Parada(false, retira!(m, ins, j, t))); np += 1
        end
    end
    while np < ins.C     # retiros extra
        best, bt = 0, Inf
        for j in 1:num_maquinas(ins)
            m = haskey(Mc, j) ? Mc[j] : M[j]; lr = listo_retiro(m); isnan(lr) && continue
            tj = max(t + ins.tau[pos, pos_beta(ins, j)], lr)
            extra = tj + ins.tau[pos_beta(ins, j), pos_f(ins)] - (t + ins.tau[pos, pos_f(ins)])
            (np > 0 || !isempty(tupla)) && extra > par.D && continue
            tj < bt && ((best, bt) = (j, tj))
        end
        best == 0 && break
        esp += max(0.0, bt - t - ins.tau[pos, pos_beta(ins, best)]); t = bt; pos = pos_beta(ins, best); push!(paradas, Parada(false, retira!(maq(best), ins, best, t))); np += 1
    end
    (isempty(tupla) && np == 0) && return nothing
    np > 0 && (t += ins.tau[pos, pos_f(ins)]; pos = pos_f(ins))
    return (Mc = Mc, paradas = paradas, lotes = lotes, np = np, t = t, pos = pos, esp = esp, vd = vd)
end
function tuplas(ins, J, C)
    T = [Int[]]
    for a in 1:J; push!(T, [a]); end
    for a in 1:J, b in 1:J; a != b && push!(T, [a, b]); end
    if C >= 3
        for a in 1:J, b in 1:J, c in 1:J
            (a != b && b != c && a != c) || continue
            ins.tau[pos_beta(ins, a), pos_alfa(ins, b)] <= 25 && ins.tau[pos_beta(ins, b), pos_alfa(ins, c)] <= 25 && push!(T, [a, b, c])
        end
    end
    return T
end
construir(ins, par::Par) = construir(ins, [par])
function construir(ins, guion::Vector{Par})
    J, n = num_maquinas(ins), num_lotes(ins)
    pmin = [minimum(tiempo_proceso(ins, i, j) for j in maquinas_compatibles(ins, i)) for i in 1:n]
    M = [Maq() for _ in 1:J]; libres = Set(1:n); T = tuplas(ins, J, ins.C)
    tA = zeros(ins.K); posA = fill(1, ins.K); plan = [Viaje[] for _ in 1:ins.K]; hechos = 0
    dec = 0
    while hechos < n
        dec += 1; par = guion[min(dec, end)]
        a = argmin(tA); mejor, mv = nothing, -Inf
        for tup in T
            (length(tup) > length(libres)) && continue
            r = ciclo(ins, M, libres, posA[a], tA[a], tup, par, pmin); r === nothing && continue
            quedan = length(libres) - length(r.lotes)
            dur = r.t - tA[a] + (quedan > 0 && r.pos == pos_f(ins) ? ins.tau[pos_f(ins), 1] : 0.0)
            v = (r.vd + par.wp * r.np) / max(dur + par.psi * r.esp, 1e-6)
            v > mv && ((mejor, mv) = (r, v))
        end
        mejor === nothing && error("sin candidatos")
        for (j, m) in mejor.Mc; M[j] = m; end
        setdiff!(libres, mejor.lotes); hechos += mejor.np
        push!(plan[a], mejor.paradas); tA[a] = mejor.t; posA[a] = mejor.pos
    end
    return [m.lotes for m in M], plan
end
if abspath(PROGRAM_FILE) == @__FILE__
    for id in ARGS
        ins = leer_instancia("s13/instancias/instancia_$id.txt")
        t = @elapsed (seq, plan) = construir(ins, Par())
        println(id, " constructivo por ciclos: ", round(evaluar_plan(ins, seq, plan), digits = 2), "  (", round(t, digits = 2), " s)  lotes/máq: ", length.(seq))
    end
end
