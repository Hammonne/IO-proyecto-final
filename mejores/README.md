# Mejores soluciones (las que se suben a IO1Lab)

Aquí está la mejor solución factible de cada instancia, sin importar qué versión la encontró.
Cada carpeta `solucion_X/resultados/` guarda lo que encontró **esa** versión.

| Inst | Valor | Encontrada con | Origen |
|---|---|---|---|
| ejemplo | 1044.00 | v3 (recocido) | `solucion_3/resultados/` |
| 01 | 326.66 | v4 (ALNS con visitas) | `solucion_4/resultados/` |
| 02 | 405.59 | v4 sin visitas, 10 rondas (corrida de la compañera) | `solucion_4/resultados/` |
| 03 | 476.44 | v3 / v4 | `solucion_4/resultados/` |
| 04 | 525.92 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/` |
| 05 | 591.34 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/` |
| 06 | 754.24 | v4 sin visitas (corrida de la compañera) | `solucion_4/resultados/` |
| 07 | 905.90 | v4 (ALNS con visitas), partiendo de la 906.57 de la v6 | `solucion_4/resultados/` |
| 08 | 1080.41 | v5 (tabú) | `solucion_5/resultados/` |
| 09 | 958.74 | v5 (tabú, corrida de la compañera) | `solucion_5/resultados/` |
| 10 | 993.16 | v5 (tabú, corrida de la compañera: 993.29) + 2 visitas intermedias agregadas por descenso | `solucion_5/resultados/` tiene la 993.29 |

Todas se validaron con `validador.jl` (factibles) antes de subirlas.

Para seguir mejorando una instancia con otra versión, se copia el archivo de aquí a la carpeta
`resultados/` de esa versión: cada versión parte de su propio archivo y solo lo reemplaza si mejora.
