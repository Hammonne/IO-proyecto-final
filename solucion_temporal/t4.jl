include("base.jl"); include("an_lib.jl")
for id in ARGS
ins = leer_instancia("s13/instancias/instancia_$id.txt")
seq, plan = leer_txt(ins, "res/instancia_$(id)_io1lab.txt")
analiza(ins, seq, plan, "proto$id")
end
