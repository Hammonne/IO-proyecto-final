# Mejores soluciones (las que se suben a IO1Lab)

Aquí está la mejor solución factible de cada instancia, sin importar qué versión la encontró.
Cada carpeta `solucion_X/resultados/` guarda lo que encontró **esa** versión.

| Inst | Valor | Encontrada con | Origen |
|---|---|---|---|
| ejemplo | 1044.00 | v3 (recocido) | `solucion_3/resultados/` |
| 01 | 326.66 | v4 (ALNS con visitas) | `solucion_4/resultados/` |
| 02 | 405.59 | v4 sin visitas, 10 rondas (corrida de la compañera) | `solucion_4/resultados/` |
| 03 | 476.44 | v3 / v4 | `solucion_4/resultados/` |
| 04 | 523.74 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |
| 05 | 590.90 | origen desconocido (zip `resultados_heuristica_local`, 12/11), partiendo de la 591.34 de la v4 | solo en `mejores/` |
| 06 | 748.73 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |
| 07 | 892.68 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |
| 08 | 1071.07 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |
| 09 | 954.27 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |
| 10 | 972.05 | v11 (tabú + ruteo entre AGVs, 8 rondas de 3500 s, semillas 70xxxx, 12/11) | `solucion_11/resultados/` |

Todas se validaron con `validador.jl` (factibles) antes de subirlas.

Para seguir mejorando una instancia con otra versión, se copia el archivo de aquí a la carpeta
`resultados/` de esa versión: cada versión parte de su propio archivo y solo lo reemplaza si mejora.
