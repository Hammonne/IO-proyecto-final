include("proto.jl"); include("an_lib.jl")
ins = leer_instancia("s13/instancias/instancia_08.txt")
seq, plan = construir(ins, Par(psi=30.0,rho=1.0,H=10.0))
analiza(ins, seq, plan, "proto08")
e,_=decodificar(ins,seq,plan)
# duración y máquinas de cada viaje del AGV 1
for a in 1:2
  println("AGV $a: ", join([join([(p.abastece ? "a" : "b")*string(ubicar_lotes(seq)[p.lote][1]) for p in v],"-") for v in plan[a]],"  "))
end
