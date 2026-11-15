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
» ESC o botón de tres puntos : menú de pausa (sonido, ayuda y salir)
» F11 / Alt+Enter : pantalla completa
» C · O · I : controles, objetivos e información de la misión
» L o botón EN | ES : cambiar el idioma (en los menús)

[color=#ffb347]LUNA · APOLLO 11[/color]
» Descenso: elige la zona con el visor y ENTER / CLIC
» Estabilización: CLIC / ESPACIO al ritmo (rápido = izquierda, lento = derecha)
» Superficie: CLIC o teclas 1-4 en los puntos · Rocas: WASD / FLECHAS
» Despegue: ENTER / ESPACIO / CLIC para detener la barra · A / D: ángulo

[color=#ffb347]MARTE · SPIRIT Y OPPORTUNITY[/color]
» CLIC o teclas 1-5 en los puntos · CLIC mantenido: arrastrar
» A / D: repartir la energía o conducir · ENTER: confirmar

[color=#ffb347]ESPACIO PROFUNDO · PIONEER 10[/color]
» WASD / FLECHAS: mover la nave o el visor · ENTER / CLIC: escanear
» A / D: apuntar la antena · CLIC / FLECHAS + ENTER: ubicar el Sol en la placa

[color=#1f8a45](Los límites, tiempos y medidores de los minijuegos son valores de juego, no especificaciones de la NASA.)[/color]"""
