class_name MissionData
extends RefCounted
## Datos reales de la misión Apolo 11 (NASA / NSSDCA) usados por todo el juego.
## Centralizarlos aquí evita "números mágicos" en las escenas de gameplay.

# --- Parámetros físicos y de misión ---
const LANDING_SITE := "0.67416° N, 23.47314° E"
const MOON_GRAVITY := 1.62          # m/s²
const LM_TOTAL_MASS_KG := 15103.0   # masa inicial del LM-5
const DESCENT_FUEL_KG := 8248.0     # propelente de descenso
const DESCENT_THRUST_N := 45000.0   # empuje máximo del motor de descenso
const DESCENT_BURN_S := 756.3       # duración total de la ignición de descenso
const LEG_SPAN_M := 9.4             # envergadura entre patas
const ORBIT_ALT_KM := 14.5          # altitud inicial (Fase 0)
const EASEP_MASS_KG := 48.0
const EASEP_FREQ_MHZ := 2119.0

# --- Frases cortas de las máquinas (diálogo del menú) ---
const VOICE_LINES := [
	{
		"speaker": "ETAPA DE DESCENSO EAGLE",
		"text": "Bienvenido, controlador. Llevo aquí desde 1969 esperando a alguien que recuerde nuestro viaje.",
	},
	{
		"speaker": "EASEP",
		"text": "Escuché los pasos de los astronautas y el temblor de la Luna. Después, el silencio.",
	},
	{
		"speaker": "RETRORREFLECTOR LRRR",
		"text": "No tengo baterías. Solo devuelvo la luz que la Tierra me envía. Sigo despierto.",
	},
	{
		"speaker": "ETAPA DE DESCENSO EAGLE",
		"text": "Fui su plataforma de lanzamiento. Ellos se fueron; yo me quedé a cuidar la Tranquilidad.",
	},
]

# --- Fichas del ARCHIVO CIENTÍFICO ---
const ARCHIVE := [
	{
		"tab": "EAGLE LM-5",
		"name": "ETAPA DE DESCENSO DEL MÓDULO LUNAR EAGLE",
		"id": "LM-5 · COSPAR 1969-059C · ESTADO: EN LA SUPERFICIE",
		"facts": [
			["Masa total inicial del LM", "15,103 kg"],
			["Propelente de descenso", "8,248 kg"],
			["Empuje máximo del motor", "45,000 N (regulable)"],
			["Ignición de descenso", "756.3 s"],
			["Envergadura de las 4 patas", "9.4 m"],
			["Alunizaje", "20 de julio de 1969"],
			["Ubicación", "Mare Tranquillitatis, 0.67416° N, 23.47314° E"],
		],
		"voice": "Mi mitad superior despegó llevando a Armstrong y Aldrin de vuelta a órbita. Yo fui su plataforma de lanzamiento. En mi pata delantera guardo una placa: 'Aquí hombres del planeta Tierra pusieron pie por primera vez sobre la Luna, julio de 1969 d.C. Vinimos en paz en nombre de toda la humanidad.'",
	},
	{
		"tab": "EASEP",
		"name": "PAQUETE DE EXPERIMENTOS CIENTÍFICOS (EASEP)",
		"id": "Early Apollo Scientific Experiments Package · ESTADO: INACTIVO",
		"facts": [
			["Masa", "48 kg"],
			["Posición", "17 m al sur del Eagle"],
			["Energía", "2 paneles solares (este / oeste)"],
			["Instrumentos", "Sismómetro pasivo + detector de polvo"],
			["Enlace con la Tierra", "2119 MHz (banda S)"],
			["Fin de operaciones", "27 de agosto de 1969"],
		],
		"voice": "Trabajé en temperaturas 30 °C por encima de mi límite de diseño. Sentí cada paso de los astronautas y las sacudidas de la propia Luna. Mi voz se apagó en agosto de 1969, pero lo que escuché enseñó a la humanidad que la Luna también tiembla.",
	},
	{
		"tab": "LRRR",
		"name": "RETRORREFLECTOR LÁSER (LRRR)",
		"id": "Laser Ranging Retro-Reflector · ESTADO: ACTIVO (2026)",
		"facts": [
			["Posición", "5 m al nor-noroeste del EASEP"],
			["Reflectores", "100 prismas de sílice fundida"],
			["Tamaño del panel", "~46 cm de lado"],
			["Energía", "Ninguna (instrumento pasivo)"],
			["Descubrimiento", "La Luna se aleja ~3.8 cm por año"],
		],
		"voice": "No necesito baterías ni órdenes. Cuando un observatorio de la Tierra me dispara un pulso láser, se lo devuelvo por el mismo camino. Gracias a mí medís la distancia Tierra-Luna con precisión de milímetros. Más de medio siglo después, sigo trabajando.",
	},
	{
		"tab": "MISIÓN",
		"name": "APOLO 11 · FASES DEL JUEGO",
		"id": "Gravedad lunar: 1.62 m/s² (1/6 de la terrestre)",
		"facts": [
			["Fase 0", "Estabilización en órbita a 14.5 km"],
			["Fase 1", "Aproximación: 756.3 s de ignición"],
			["Fase 2", "Aterrizaje de precisión entre rocas"],
			["Fase 3", "Despliegue del EASEP (2119 MHz)"],
			["Fase 4", "Abandono: despegue de la etapa de ascenso"],
			["Fase 5", "Legado: lunamotos y láser Tierra-Luna"],
		],
		"voice": "Cada número de este juego es real. Pilotarás con el mismo combustible, el mismo empuje y la misma gravedad que nosotros enfrentamos en 1969.",
	},
]

# --- Panel de CONTROLES / TELEMETRÍA (BBCode) ---
const CONTROLS_BBCODE := """[color=#ffb347]PROPULSIÓN[/color]
» W / FLECHA ARRIBA / ESPACIO : motor de descenso (empuje)
» A / D / FLECHAS IZQ-DER : propulsores RCS (rotar el módulo)
» ESC : pausa

[color=#ffb347]TELEMETRÍA EN PANTALLA[/color]
» ALT : altitud sobre la superficie
» V/V y V/H : velocidad vertical y horizontal
» COMB : propelente restante (de 8,248 kg)
» INCL : inclinación del módulo

[color=#ffb347]OBJETIVO: ALUNIZAJE SEGURO[/color]
» Toca suelo plano con las 4 patas, lejos de las rocas.
» Velocidad vertical menor a 2 m/s.
» Inclinación menor a 6° para poder desplegar el EASEP.
» La gravedad lunar es 1.62 m/s²: ¡el módulo cae despacio, pero no frena solo!

[color=#1f8a45](Controles del prototipo: pueden ajustarse durante el desarrollo.)[/color]"""
