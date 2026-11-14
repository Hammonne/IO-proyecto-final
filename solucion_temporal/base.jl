for a in ("datos","simulador","despacho","constructivo","asignacion","busqueda","recocido","validador","exportar","leer_solucion","plan","leer_txt","vecindades","busqueda_plan","tabu","transporte","bloques","asig_transporte")
    include(joinpath(@__DIR__,"s13",a*".jl"))
end
using Printf
cargar(id) = (ins=leer_instancia(joinpath(@__DIR__,"s13","instancias","instancia_$id.txt")); (ins, leer_txt(ins, joinpath(@__DIR__,"mejores","instancia_$(id)_io1lab.txt"))...))
nombre(ins,u) = u==1 ? "o" : u==pos_f(ins) ? "f" : (iseven(u) ? "a" : "b")
