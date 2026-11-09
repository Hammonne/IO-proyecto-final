
using XLSX

function main()
    ruta = joinpath(@__DIR__, "..", "datos", "instancia_01.xlsx")
    archivo = XLSX.readxlsx(ruta)


    tiempos = leer_tiempos(archivo)

    println("\n=== TIEMPOS DE TRANSPORTE ===")
    println("Almacen a maquina 1: ",
            tiempos[("o", "alpha_1")], " s")

    println("Almacen a maquina 3: ",
            tiempos[("o", "alpha_3")], " s")

    println("Salida maquina 3 a almacen final: ",
            tiempos[("beta_3", "f")], " s")

    println("Total de rutas registradas: ",
            length(tiempos))


    lotes = archivo["Lotes"]["A2:C100"]
    tasas = archivo["Tasas"]["A2:C100"]

    # Diccionario de velocidades
    velocidades = Dict{Tuple{Int,String},Float64}()

    for fila in 1:size(tasas, 1)
        j, r, v = tasas[fila, :]

        if ismissing(j) || ismissing(r) || ismissing(v)
            continue
        end

        velocidades[(Int(j), String(r))] = Float64(v)
    end

# GENERAR ASIGNACION INICIAL
asignacion, carga = generar_solucion_inicial(
    lotes, velocidades
)

println("\n=== ASIGNACION INICIAL ===")

for i in sort(collect(keys(asignacion)))
    println("Lote ", i,
            " -> Maquina ", asignacion[i])
end

println("\n=== CARGA POR MAQUINA ===")

for j in sort(collect(keys(carga)))
    println("Maquina ", j,
            ": ", round(carga[j], digits=2), " s")
end


    # ORDENAR LOTES POR MAQUINA
    secuencias = ordenar_lotes(
        lotes, asignacion, velocidades
    )

    println("\n=== SECUENCIAS POR MAQUINA ===")

    for j in sort(collect(keys(secuencias)))
        println("\nMaquina ", j)

        for (i, tiempo) in secuencias[j]
            println("  Lote ", i,
                    " | Procesamiento: ",
                    round(tiempo, digits=2), " s")
        end
    end

# Aqui puede continuar el codigo anterior

    println("=== TIEMPOS DE PROCESAMIENTO ===")
    println("Lote | Tipo | Maquina | Tiempo (s)")

    for fila in 1:size(lotes, 1)
        i, r, q = lotes[fila, :]

        if ismissing(i) || ismissing(r) || ismissing(q)
            continue
        end

        for j in 1:4
            clave = (j, String(r))

            if haskey(velocidades, clave)
                tiempo = Float64(q) / velocidades[clave]

                println(i, " | ", r, " | ", j,
                        " | ", round(tiempo, digits=2))
            end
        end
    end
end


# Leer matriz de tiempos de transporte
function leer_tiempos(archivo)
    hoja = archivo["Tiempos"]

    # Instancia 01: 10 ubicaciones
    datos = hoja["A1:K11"]

    ubicaciones = String.(datos[1, 2:end])
    tiempos = Dict{Tuple{String,String},Float64}()

    for fila in 2:size(datos, 1)
        origen = String(datos[fila, 1])

        for columna in 2:size(datos, 2)
            destino = ubicaciones[columna - 1]
            tiempo = Float64(datos[fila, columna])

            tiempos[(origen, destino)] = tiempo
        end
    end

    return tiempos
end

function generar_solucion_inicial(lotes, velocidades)
    carga = Dict{Int,Float64}()
    asignacion = Dict{Int,Int}()

    for (j, _) in keys(velocidades)
        carga[j] = 0.0
    end

    for fila in 1:size(lotes, 1)
        i, r, q = lotes[fila, :]

        if ismissing(i) || ismissing(r) || ismissing(q)
            continue
        end

        candidatos = []

        for ((j, tipo), velocidad) in velocidades
            if tipo == String(r)
                tiempo = Float64(q) / velocidad
                push!(candidatos, (carga[j] + tiempo, j, tiempo))
            end
        end

        if isempty(candidatos)
            error("No hay maquina compatible para el lote $i")
        end

        sort!(candidatos)
        _, mejor_maquina, tiempo = candidatos[1]

        asignacion[Int(i)] = mejor_maquina
        carga[mejor_maquina] += tiempo
    end

    return asignacion, carga
end


function ordenar_lotes(lotes, asignacion, velocidades)
    secuencias = Dict{Int,Vector{Tuple{Int,Float64}}}()

    for j in values(asignacion)
        secuencias[j] = Tuple{Int,Float64}[]
    end

    for fila in 1:size(lotes, 1)
        i, r, q = lotes[fila, :]

        if ismissing(i) || ismissing(r) || ismissing(q)
            continue
        end

        j = asignacion[Int(i)]
        tiempo = Float64(q) / velocidades[(j, String(r))]

        push!(secuencias[j], (Int(i), tiempo))
    end

    for secuencia in values(secuencias)
        sort!(secuencia, by = x -> (x[2], x[1]))
    end

    return secuencias
end

main()








