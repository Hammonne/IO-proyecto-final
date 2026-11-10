# Solución 3 (Yampi) — Reglas básicas con excepciones por sincronización y aprovechamiento

Constructivo de reglas para el problema de programación de máquinas paralelas y AGVs.
No hay búsqueda aleatoria: cada decisión sale de una regla clara, y solo se desvía
de la regla cuando la evaluación de S (sincronización) o Y (aprovechamiento) lo justifica.

## Cómo correr

```bash
julia main.jl instancias/instancia_01.txt          # sin zonas
julia main.jl instancias/instancia_01.txt zonas    # con zonas por cercanía
bash correr.sh zonas                               # las diez instancias
```

Los archivos para IO1Lab quedan en `resultados/instancia_XX_io1lab.txt`.

## Reglas

| Regla | Qué decide | Dónde está |
|---|---|---|
| R1 | Cada lote va a la máquina compatible con mayor tasa. Dentro de cada fila, orden SPT (`q/v`). | `secuencias.jl` (`asignacion_inicial`) |
| R2 | Si una fila es más larga, se recorren sus lotes desde el último. Se pasa un lote a su siguiente máquina compatible solo si termina antes allí. | `secuencias.jl` (`balancear!`) |
| R3 | El AGV va al destino más cercano. Espera allí solo si la espera es menor que ir al siguiente destino (`espera ≤ factor · distancia`). | `despacho_reglas.jl` (`siguiente_destino`) |
| R4 | En cada máquina deja un lote y recoge el terminado si está listo sin esperar más de la holgura. | `despacho_reglas.jl` (`destinos`) |
| Zonas | Cada AGV atiende un bloque de máquinas, ordenadas por cercanía a `o`. Opcional. | `despacho_reglas.jl` (`zonas_por_cercania`) |

## Excepciones S y Y

Antes de elegir qué lotes cargar en `o`, se toma la regla base (el lote que puede
entregarse más pronto) y se evalúa cada alternativa:

- **S (espera evitada)**: `S = max(0, espera_base − espera_alternativa)`.
- **Y (ocio evitado)**: `Y = max(0, inicio_alternativa − liberación_de_la_máquina)`. Es el tiempo que la máquina estaría ociosa si no se la alimenta ahora.
- **Δ**: cuánto más tarde se entregaría la alternativa frente a la base.

Se desvía de la regla base cuando `α·S + β·Y − γ·Δ > 0`. Los pesos `α`, `β`, `γ` están en `ParamsV5`
(valor inicial 1.0). Una alternativa dentro de la holgura también se acepta sin evaluar S ni Y.

## Límites conocidos

- **Asignación fija**: R1 y R2 asignan los lotes antes de simular. No se reasigna un lote cuando su
  máquina más compatible está ocupada. Ese caso ("ir a una máquina no tan compatible") todavía no
  está implementado en el despacho; solo se evalúa en R2 con tiempos estimados.
- **Pesos sin calibrar**: `α`, `β`, `γ`, la holgura y el factor de R3 están en sus valores iniciales.
- **Sin búsqueda**: el resultado depende de las reglas. Si se quiere mejorar, el siguiente paso es
  buscar sobre estos parámetros, que es una vecindad justificada por la lógica del problema.
- **Probado en Julia**: el código se escribió sin ejecutarlo en el entorno de trabajo; hay que correrlo
  y validar con `validar` antes de usar los resultados.

## Archivos

- `main.jl`: flujo completo y salida TXT.
- `secuencias.jl`: R1 y R2.
- `despacho_reglas.jl`: R3, R4, S, Y y simulación de los viajes.
- `datos.jl`, `simulador.jl`, `validador.jl`, `exportar.jl`: copiados de la solución 3 del grupo.
- `instancias/`: instancias en texto.
- `correr.sh`: corre las diez instancias.
