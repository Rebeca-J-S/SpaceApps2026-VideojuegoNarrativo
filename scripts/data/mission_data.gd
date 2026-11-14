class_name MissionData
extends RefCounted
## Constantes físicas reales usadas por la jugabilidad.
## Los textos (sitios, archivo, diálogos) viven en res://data/*.json para editarlos sin código.

const GAME_TITLE := "WHAT WAS LEFT BEHIND"

# --- Apolo 11 — NSSDCA 1969-059C ---
const MOON_GRAVITY := 1.62          # m/s²
const LM_TOTAL_MASS_KG := 15103.0   # masa total del LM (ambas etapas + propelente)
const DESCENT_FUEL_KG := 8248.0     # propelente de la etapa de descenso
const DESCENT_THRUST_N := 45000.0   # empuje máximo del motor de descenso (regulable)
const ASCENT_THRUST_N := 15000.0    # motor de la etapa de ascenso
const DESCENT_BURN_S := 756.3       # duración de la ignición de descenso
const LEG_SPAN_M := 9.4             # distancia entre extremos de patas opuestas
const ORBIT_ALT_KM := 14.5          # punto más bajo de la órbita de descenso (Fase 0)

# --- Marte ---
const MARS_GRAVITY := 3.71          # m/s²

# --- Panel de CONTROLES del menú (BBCode) ---
const CONTROLS_BBCODE := """[color=#ffb347]GENERAL[/color]
» ENTER / CLIC : avanzar diálogos y confirmar
» ESC : pausa (continuar, reiniciar fase o volver al selector)
» 1, 2, 3, 4 o CLIC : activar los puntos brillantes de las fases de ciencia

[color=#ffb347]VUELO Y ATERRIZAJE[/color]
» W / FLECHA ARRIBA / ESPACIO : motor principal (empuje)
» A / D / FLECHAS IZQ-DER : propulsores laterales RCS (girar)
» S / FLECHA ABAJO : bajar (Pioneer en el cinturón de asteroides)

[color=#ffb347]ATERRIZAJE SEGURO DEL EAGLE[/color]
» Suelo plano, lejos de las rocas.
» Velocidad vertical menor a 2 m/s e inclinación menor a 6°.
» La gravedad lunar es 1.62 m/s² (1/6 de la terrestre): caes despacio, pero no frenas solo.

[color=#1f8a45](Los límites de aterrizaje son valores de juego, no especificaciones de la NASA.)[/color]"""
