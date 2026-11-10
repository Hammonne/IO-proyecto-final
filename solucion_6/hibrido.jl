# ============================================================
# hibrido.jl — Búsqueda tabú + destrucción/reparación del ALNS
# ============================================================
# Hallazgo de las soluciones 4 y 5:
#   - la tabú (v5) intensifica bien (siempre toma el mejor movimiento),
#     pero cuando se estanca la saca una patada aleatoria débil;
#   - el ALNS (v4) diversifica bien (cambia muchos lotes a la vez), pero
#     su pulido es un descenso aleatorio corto y sus operadores dejan de
#     mejorar (pesos en el mínimo al final de las corridas).
# El híbrido usa cada uno en lo que mejor hace (esquema tipo ILS):
#   1. FASE TABÚ: búsqueda tabú de la v5 hasta que la mejor solución de la
#      fase no mejora en una fracción FRACCION_FASE del tiempo.
#   2. PATADA LNS: se destruyen q lotes y se reparan con los operadores de
#      la v4, partiendo de la mejor global o de la mejor de la fase
#      (50 % cada una). Se vacía la lista tabú y empieza otra fase.
#   3. APRENDIZAJE: cada pareja (destrucción, reparación) se premia según
#      cómo terminó la fase que abrió: 33 si encontró una nueva mejor
#      global, 9 si la fase terminó mejor que la solución destruida. Los
#      pesos de la ruleta se actualizan cada SEGMENTO_HIBRIDO patadas.

const FRACCION_FASE, SEGMENTO_HIBRIDO, P_DESDE_MEJOR = 0.03, 5, 0.5

mutable struct EstadoHibrido
    tabu::EstadoTabu
    destruir::Adaptativo
    reparar::Adaptativo
    op::Tuple{Int,Int}       # operadores de la última patada ((0, 0) = ninguna)
    mejor_antes::Float64     # mejor global al empezar la fase
    base_val::Float64        # valor de la solución que se destruyó
    fase::SolTabu            # mejor solución de la fase actual
    t_fase::Float64          # última mejora dentro de la fase
    patadas::Int
end

function EstadoHibrido(ins, seq, plan)
    st = EstadoTabu(ins, seq, plan)
    v = st.mejor[3]
    return EstadoHibrido(st, Adaptativo(length(DESTRUCCION)), Adaptativo(length(REPARACION)),
                         (0, 0), v, v, st.mejor, time(), 0)
end

# --- Fase tabú -------------------------------------------------------

function paso_hibrido!(h, ins, rng)
    iteracion_tabu!(h.tabu, ins, rng)
    h.tabu.actual[3] < h.fase[3] - 1e-9 && (h.fase = h.tabu.actual; h.t_fase = time())
    h.tabu.iter % LIMPIEZA_TABU == 0 && olvidar_vencidos!(h.tabu)
end

fase_estancada(h, segundos) = time() - h.t_fase > FRACCION_FASE * segundos

# --- Premio a los operadores de la patada anterior --------------------

function puntaje_fase(h)
    h.tabu.mejor[3] < h.mejor_antes - 1e-9 && return SIGMA_MEJOR
    h.fase[3] < h.base_val - 1e-9 && return SIGMA_MEJORA
    return 0.0
end

function premiar_fase!(h)
    h.op == (0, 0) && return
    p = puntaje_fase(h)
    premiar!(h.destruir, h.op[1], p)
    premiar!(h.reparar, h.op[2], p)
    h.patadas % SEGMENTO_HIBRIDO == 0 || return
    actualizar_pesos!(h.destruir)
    actualizar_pesos!(h.reparar)
end

# --- Patada LNS y nueva fase -------------------------------------------

# Hasta 10 intentos de destrucción/reparación factible; si ninguno lo es,
# se usa la perturbación aleatoria de la solución 3
function patada_lns(h, ins, rng)
    base = rand(rng) < P_DESDE_MEJOR ? h.tabu.mejor : h.fase
    for _ in 1:10
        d, r = ruleta(h.destruir, rng), ruleta(h.reparar, rng)
        cand = destruir_y_reparar(ins, base, d, r, tamano_destruccion(ins, rng), rng)
        isfinite(cand[3]) && return cand, base[3], (d, r)
    end
    return perturbar_plan(ins, base, rng), base[3], (0, 0)
end

function nueva_fase!(h, ins, rng)
    premiar_fase!(h)
    st = h.tabu
    cand, h.base_val, h.op = patada_lns(h, ins, rng)
    h.mejor_antes = st.mejor[3]
    st.actual, st.huella = cand, huellas(cand[1], cand[2], num_lotes(ins))
    empty!(st.lista)
    cand[3] < st.mejor[3] - 1e-9 && (st.mejor = cand; st.t_mejora = time())
    h.fase, h.t_fase, h.patadas = cand, time(), h.patadas + 1
end

function informar_avance(h, mostrar)
    (mostrar && h.patadas % 20 == 0) || return
    println("  patada $(h.patadas): mejor ", round(h.tabu.mejor[3], digits = 2),
            "  (iter tabú $(h.tabu.iter))")
end

function tabu_lns(ins, seq, plan, segundos; semilla = 1, mostrar = true)
    rng, fin = MersenneTwister(semilla), time() + segundos
    h = EstadoHibrido(ins, seq, plan)
    while time() < fin
        paso_hibrido!(h, ins, rng)
        fase_estancada(h, segundos) || continue
        nueva_fase!(h, ins, rng)
        informar_avance(h, mostrar)
    end
    return h
end
