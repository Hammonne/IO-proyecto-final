# Mejores soluciones (las que se suben a IO1Lab)

Aquí está la mejor solución factible de cada instancia, sin importar qué versión la encontró.
Cada carpeta `solucion_X/resultados/` guarda lo que encontró **esa** versión.

| Inst | Valor | Encontrada con | Origen |
|---|---|---|---|
| ejemplo | 1044.00 | v3 (recocido) | `solucion_3/resultados/` |
| 01 | 326.66 | v4 (ALNS con visitas) | `solucion_4/resultados/` |
| 02 | 405.59 | v4 sin visitas, 10 rondas (corrida de la compañera) | `solucion_4/resultados/` |
| 03 | 476.44 | v3 / v4 | `solucion_4/resultados/` |
| 04 | 522.88 | v12 (portafolio, 14/11) | `solucion_13/resultados/` |
| 05 | 590.66 | v12 (2 rondas de 3300 s, 12/11 tarde) | `solucion_12/resultados/` |
| 06 | 747.50 | v12 con bloques (portafolio, 14/11) | `solucion_13/resultados/` |
| 07 | 882.23 | despacho por ciclos + guion + tabú v12 (semilla 11, 14/11) | `solucion_temporal/soluciones/` |
| 08 | 1028.85 | despacho por ciclos + guion + tabú v12 (semilla 14, 14/11) | `solucion_temporal/soluciones/` |
| 09 | 952.28 | v12 con visitas (portafolio, 14/11) | `solucion_13/resultados/` |
| 10 | 963.16 | despacho por ciclos + guion + tabú (semilla 7, 14/11) | `solucion_temporal/corrida.sh 10 7` |

Todas se validaron con `validador.jl` (factibles) antes de subirlas.

Para seguir mejorando una instancia con otra versión, se copia el archivo de aquí a la carpeta
`resultados/` de esa versión: cada versión parte de su propio archivo y solo lo reemplaza si mejora.
