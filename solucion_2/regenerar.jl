# regenerar.jl — Vuelve a escribir los TXT de IO1Lab desde resultados/*_solucion.csv
# Uso: julia regenerar.jl
for f in ["datos", "simulador", "despacho", "constructivo", "asignacion", "busqueda", "recocido", "validador", "exportar"]
    include(f * ".jl")
end
include("leer_solucion.jl")

function regenerar(base)
    ins = leer_instancia("instancias/$base.txt")
    seq, par = leer_solucion("resultados/$(base)_solucion.csv")
    e = simular(ins, seq, par)
    errs = validar(ins, e)
    escribir_txt("resultados/$(base)_io1lab.txt", ins, e)
    println(base, ": ", round(objetivo(e), digits = 4), isempty(errs) ? "  factible" : "  ERRORES $errs")
end

foreach(regenerar, ["instancia_$(lpad(k, 2, "0"))" for k in 1:10])
