# leer_solucion.jl — Lee una solución guardada en resultados/*_solucion.csv

function leer_solucion(archivo)
    lineas = [split(l, ",") for l in readlines(archivo)]
    tiene_zona = lineas[3][1] == "zona"
    zona = tiene_zona ? parse.(Int, filter(!isempty, lineas[3][2:end])) : Int[]
    par = Parametros(parse.(Float64, lineas[2][2:4])..., zona)
    seq = [parse.(Int, filter(!isempty, l[2:end])) for l in lineas[(tiene_zona ? 4 : 3):end]]
    return seq, par
end

