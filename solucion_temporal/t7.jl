include("base.jl"); include("an_lib.jl")
for (id, f) in (("08", "guardar/instancia_08_io1lab_1029.04.txt"), ("07", "guardar/instancia_07_io1lab_886.73.txt"))
    ins = leer_instancia("s13/instancias/instancia_$id.txt"); seq, plan = leer_txt(ins, f)
    e, ok = decodificar(ins, seq, plan); println(id, " ", round(sum(e.c) / num_lotes(ins), digits = 2), " factible=", ok, " errores=", validar(ins, e))
    analiza(ins, seq, plan, id)
end
