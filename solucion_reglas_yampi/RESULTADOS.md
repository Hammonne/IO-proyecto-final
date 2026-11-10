# Resultados — solución 3 (Yampi), reglas R1–R4 con excepciones S y Y

Promedio de tiempos de finalización Σc_i/|I| (segundos) por instancia.
Todas las soluciones pasaron el validador independiente (validar en main.jl).

| Instancia | Modo sin zonas | Modo con zonas |
|---|---|---|
| 01 | 723.40 | 492.28 |
| 02 | 1148.95 | 844.47 |
| 03 | 1459.49 | 1220.72 |
| 04 | 1237.99 | 1002.42 |
| 05 | 1161.81 | 1218.04 |
| 06 | 1643.60 | 1651.24 |
| 07 | 1829.63 | 1920.30 |
| 08 | 2390.48 | 2456.80 |
| 09 | 2296.07 | 2403.10 |
| 10 | 2288.60 | 2578.20 |

Archivos en formato IO1Lab:
- resultados/sin/instancia_XX_io1lab.txt
- resultados/zonas/instancia_XX_io1lab.txt

Reproducir: `bash correr.sh sin` y `bash correr.sh zonas` (Julia 1.13 o superior, sin paquetes externos).

Comparación de referencia (solución 3 del grupo, mismas instancias): 326.77 en la 01 y 998.97 en la 10.
Las reglas no igualan a la búsqueda del grupo; la diferencia más grande aparece en las instancias 06 a 10.
