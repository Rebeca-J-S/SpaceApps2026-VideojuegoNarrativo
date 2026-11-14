class_name MissionData
extends RefCounted
## Datos reales (NASA / NSSDCA) usados por todo el juego "What Was Left Behind by NASA".
## Centralizarlos aquí evita "números mágicos" en las escenas y facilita revisar su exactitud.

const GAME_TITLE := "WHAT WAS LEFT BEHIND BY NASA"
const GAME_SUBTITLE := "LO QUE LA NASA DEJÓ ATRÁS · LUNA Y MARTE"

# --- Apolo 11 (fase jugable actual) — NSSDCA 1969-059C ---
const LANDING_SITE := "0.67416° N, 23.47314° E"
const MOON_GRAVITY := 1.62          # m/s²
const LM_TOTAL_MASS_KG := 15103.0   # masa total del LM (ambas etapas + propelente)
const DESCENT_FUEL_KG := 8248.0     # propelente de la etapa de descenso
const DESCENT_THRUST_N := 45000.0   # empuje máximo del motor de descenso (regulable)
const DESCENT_BURN_S := 756.3       # duración de la ignición de descenso
const LEG_SPAN_M := 9.4             # distancia entre extremos de patas opuestas
const ORBIT_ALT_KM := 14.5          # punto más bajo de la órbita de descenso (Fase 0)
const EASEP_MASS_KG := 48.0
const EASEP_UPLINK_MHZ := 2119.0    # recibía órdenes
const EASEP_DOWNLINK_MHZ := 2276.5  # transmitía telemetría

# --- Destinos de la pantalla "SELECCIONA TU DESTINO" ---
const DESTINATIONS := [
	{
		"name": "LA LUNA",
		"mission": "MISIÓN APOLO 11 · 1969",
		"desc": "Pilota el descenso del Eagle: 756.3 s de ignición y 8,248 kg de combustible para posarte en el Mar de la Tranquilidad y despertar al EASEP.",
		"hardware": "Eagle LM-5 · EASEP · Retrorreflector LRRR",
		"scene": "res://scenes/levels/fase0_orbita.tscn",
	},
	{
		"name": "MARTE",
		"mission": "EXPEDICIÓN MARTE · 1976-2024",
		"desc": "Recorre los lugares donde descansan los exploradores robóticos y escucha sus historias. (Misión en desarrollo)",
		"hardware": "Viking 1 · Sojourner · Opportunity · InSight · Ingenuity",
		"scene": "res://scenes/levels/marte_fase0.tscn",
	},
]

# --- Sitios marcados sobre los planetas del menú (lat N+, lon E+) ---
# status: "focus" = misión jugable, "silent" = abandonado, "active" = sigue operando.
const MOON_SITES := [
	{"name": "APOLO 11", "lat": 0.67, "lon": 23.47, "status": "focus",
		"info": "Eagle LM-5, EASEP y retrorreflector LRRR · 1969"},
	{"name": "APOLO 12", "lat": -3.01, "lon": -23.42, "status": "silent",
		"info": "Etapa de descenso Intrepid y estación ALSEP · 1969"},
	{"name": "APOLO 14", "lat": -3.65, "lon": -17.47, "status": "silent",
		"info": "Las pelotas de golf de Alan Shepard · 1971"},
	{"name": "APOLO 15", "lat": 26.13, "lon": 3.63, "status": "silent",
		"info": "Primer rover lunar (LRV) · 1971"},
	{"name": "APOLO 16", "lat": -8.97, "lon": 15.50, "status": "silent",
		"info": "La foto familiar de Charlie Duke · 1972"},
	{"name": "APOLO 17", "lat": 20.19, "lon": 30.77, "status": "silent",
		"info": "Último rover lunar y último alunizaje tripulado · 1972"},
]

const MARS_SITES := [
	{"name": "VIKING 1", "lat": 22.27, "lon": -47.95, "status": "silent",
		"info": "Lander · operó de 1976 a 1982"},
	{"name": "VIKING 2", "lat": 47.67, "lon": 134.28, "status": "silent",
		"info": "Lander · operó de 1976 a 1980"},
	{"name": "SOJOURNER", "lat": 19.13, "lon": -33.22, "status": "silent",
		"info": "Primer rover en Marte · 1997"},
	{"name": "SPIRIT", "lat": -14.57, "lon": 175.47, "status": "silent",
		"info": "Rover · 2004 a 2010"},
	{"name": "OPPORTUNITY", "lat": -1.95, "lon": -5.53, "status": "silent",
		"info": "Rover · 2004 a 2018 (45 km recorridos)"},
	{"name": "INSIGHT", "lat": 4.50, "lon": 135.62, "status": "silent",
		"info": "Sismómetro marciano · 2018 a 2022"},
	{"name": "JEZERO", "lat": 18.44, "lon": 77.45, "status": "active",
		"info": "Ingenuity (silencioso desde 2024) y Perseverance (ACTIVO)"},
	{"name": "CURIOSITY", "lat": -4.59, "lon": 137.44, "status": "active",
		"info": "Rover ACTIVO desde 2012"},
]

# --- Frases cortas de las máquinas (diálogo del menú) ---
const VOICE_LINES := [
	{"speaker": "ETAPA DE DESCENSO EAGLE",
		"text": "Bienvenido, explorador. Llevo en la Luna desde 1969 esperando a alguien que recuerde nuestro viaje."},
	{"speaker": "VIKING 1",
		"text": "Toqué Marte el 20 de julio de 1976: siete años exactos después del Eagle."},
	{"speaker": "EASEP",
		"text": "Escuché los pasos de los astronautas y el temblor de la Luna. Después, el silencio."},
	{"speaker": "OPPORTUNITY",
		"text": "Me diseñaron para 90 días marcianos. Rodé casi 15 años, hasta que una tormenta de polvo tapó el Sol."},
	{"speaker": "RETRORREFLECTOR LRRR",
		"text": "No tengo baterías. Solo devuelvo la luz que la Tierra me envía. Sigo despierto."},
	{"speaker": "INSIGHT",
		"text": "Como el EASEP en la Luna, yo escuché el interior de Marte: más de 1,300 martemotos."},
	{"speaker": "INGENUITY",
		"text": "Iba a volar 5 veces. Volé 72. Ahora descanso en el cráter Jezero."},
]

# --- ARCHIVO CIENTÍFICO ---
const ARCHIVE_SECTIONS := ["LUNA", "MARTE", "MISIÓN"]

const ARCHIVE := {
	"LUNA": [
		{
			"tab": "EAGLE LM-5",
			"name": "ETAPA DE DESCENSO DEL MÓDULO LUNAR EAGLE",
			"id": "LM-5 · COSPAR 1969-059C · EN LA SUPERFICIE",
			"facts": [
				["Masa total del LM", "15,103 kg"],
				["Propelente de descenso", "8,248 kg"],
				["Empuje máximo del motor", "45,000 N (regulable)"],
				["Ignición de descenso", "756.3 s"],
				["Distancia entre patas", "9.4 m"],
				["Alunizaje", "20 jul 1969, 20:17:40 UT"],
				["Ubicación", "Mare Tranquillitatis, 0.67416° N, 23.47314° E"],
			],
			"voice": "Mi mitad superior despegó llevando a Armstrong y Aldrin de vuelta a órbita. Yo fui su plataforma de lanzamiento. En una de mis patas guardo una placa: 'Aquí hombres del planeta Tierra pusieron pie por primera vez sobre la Luna, julio de 1969 d.C. Vinimos en paz en nombre de toda la humanidad.'",
		},
		{
			"tab": "EASEP",
			"name": "PAQUETE DE EXPERIMENTOS CIENTÍFICOS (EASEP)",
			"id": "Early Apollo Scientific Experiments Package · INACTIVO",
			"facts": [
				["Masa", "48 kg"],
				["Posición", "~17 m al sur del Eagle"],
				["Energía", "2 paneles solares (este / oeste)"],
				["Instrumentos", "Sismómetro pasivo + detector de polvo"],
				["Enlace", "Recibía a 2119 MHz, transmitía a 2276.5 MHz"],
				["Fin de operaciones", "27 de agosto de 1969"],
			],
			"voice": "Trabajé a temperaturas 30 °C por encima de lo previsto. Sentí cada paso de los astronautas y las sacudidas de la propia Luna. Dejé de responder en agosto de 1969, pero lo que escuché abrió el camino a las estaciones sísmicas de las siguientes misiones Apolo.",
		},
		{
			"tab": "LRRR",
			"name": "RETRORREFLECTOR LÁSER (LRRR)",
			"id": "Laser Ranging Retro-Reflector · ACTIVO (2026)",
			"facts": [
				["Posición", "~5 m al nor-noroeste del EASEP"],
				["Reflectores", "100 prismas de sílice fundida"],
				["Tamaño del panel", "~46 cm de lado"],
				["Energía", "Ninguna (instrumento pasivo)"],
				["Descubrimiento", "La Luna se aleja ~3.8 cm por año"],
			],
			"voice": "No necesito baterías ni órdenes. Cuando un observatorio de la Tierra me dispara un pulso láser, se lo devuelvo por el mismo camino. Gracias a mí medís la distancia Tierra-Luna con precisión de milímetros. Más de medio siglo después, sigo trabajando.",
		},
		{
			"tab": "ROVER LRV",
			"name": "VEHÍCULO DE EXPLORACIÓN LUNAR (LRV)",
			"id": "Lunar Roving Vehicle · 3 unidades en la Luna",
			"facts": [
				["Misiones", "Apolo 15, 16 y 17 (1971-1972)"],
				["Masa", "~210 kg"],
				["Energía", "Baterías de plata-zinc (no recargables)"],
				["Mayor recorrido total", "~36 km (Apolo 17)"],
			],
			"voice": "Llevé a los astronautas más lejos que nunca de su módulo. Mis hermanos y yo seguimos aparcados donde nos dejaron, con la cámara de televisión apuntando al cielo.",
		},
		{
			"tab": "OBJETOS",
			"name": "LO QUE DEJARON LOS ASTRONAUTAS",
			"id": "Para despegar, cada kilo contaba",
			"facts": [
				["Cubrebotas y mochilas PLSS", "Abandonados para ahorrar peso"],
				["Cámaras Hasselblad", "Solo volvieron los cartuchos de película"],
				["Pelotas de golf", "Alan Shepard, Apolo 14 (1971)"],
				["Foto familiar", "Charlie Duke, Apolo 16 (1972)"],
				["Placas y banderas", "En todos los sitios de alunizaje"],
			],
			"voice": "No somos máquinas famosas, pero también somos historia. Cada objeto que quedó en la Luna permitió que los astronautas volvieran a casa con rocas y muestras para la ciencia.",
		},
	],
	"MARTE": [
		{
			"tab": "VIKING 1",
			"name": "VIKING 1 LANDER",
			"id": "Primer aterrizaje exitoso de EE. UU. en Marte · INACTIVO",
			"facts": [
				["Aterrizaje", "20 jul 1976, Chryse Planitia"],
				["Misión", "Fotos de la superficie y búsqueda de vida"],
				["Fin de operaciones", "Noviembre de 1982"],
			],
			"voice": "Llegué siete años exactos después del Eagle. Envié las primeras fotos desde la superficie marciana y busqué señales de vida en su suelo. Trabajé más de seis años.",
		},
		{
			"tab": "SOJOURNER",
			"name": "ROVER SOJOURNER (MARS PATHFINDER)",
			"id": "Primer rover sobre otro planeta · INACTIVO",
			"facts": [
				["Aterrizaje", "4 jul 1997, Ares Vallis"],
				["Masa", "10.6 kg"],
				["Misión prevista", "7 días"],
				["Última comunicación", "27 de septiembre de 1997"],
			],
			"voice": "Era tan pequeño como un horno de microondas. Demostré que una máquina con ruedas podía explorar Marte, y todos los rovers que vinieron después siguieron mis huellas.",
		},
		{
			"tab": "OPPORTUNITY",
			"name": "ROVER OPPORTUNITY (MER-B)",
			"id": "Mars Exploration Rover · INACTIVO",
			"facts": [
				["Aterrizaje", "25 ene 2004, Meridiani Planum"],
				["Misión prevista", "90 días marcianos"],
				["Distancia recorrida", "45.16 km"],
				["Descubrimiento", "Pruebas de agua líquida en el pasado"],
				["Última comunicación", "10 de junio de 2018"],
			],
			"voice": "Rodé casi quince años y recorrí más que una maratón. En 2018 una tormenta de polvo cubrió todo el planeta y mis paneles solares se quedaron sin luz. Mi gemelo Spirit descansa al otro lado de Marte.",
		},
		{
			"tab": "INSIGHT",
			"name": "LANDER INSIGHT",
			"id": "Sismómetro marciano · INACTIVO",
			"facts": [
				["Aterrizaje", "26 nov 2018, Elysium Planitia"],
				["Instrumento estrella", "Sismómetro SEIS"],
				["Martemotos detectados", "Más de 1,300"],
				["Fin de la misión", "Diciembre de 2022"],
			],
			"voice": "Medio siglo después del EASEP, hice en Marte lo mismo que él en la Luna: escuchar. Gracias a mis temblores sabemos cómo es Marte por dentro. El polvo fue cubriendo mis paneles hasta que me quedé dormido.",
		},
		{
			"tab": "INGENUITY",
			"name": "HELICÓPTERO INGENUITY",
			"id": "Primer vuelo propulsado en otro planeta · INACTIVO",
			"facts": [
				["Masa", "1.8 kg"],
				["Primer vuelo", "19 de abril de 2021"],
				["Vuelos previstos / realizados", "5 / 72"],
				["Último vuelo", "18 de enero de 2024"],
				["Ubicación", "Cráter Jezero"],
			],
			"voice": "Viajé pegado a la panza de Perseverance. Iba a ser solo una demostración, pero volé durante casi tres años. Una de mis hélices se dañó y ya no puedo volar, pero sigo en Jezero.",
		},
	],
	"MISIÓN": [
		{
			"tab": "APOLO 11",
			"name": "MISIÓN JUGABLE: APOLO 11",
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
	],
}

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
