# What Was Left Behind

Videojuego educativo en Pixel Art 2D (Godot 4.5, GDScript) para el **NASA Space Apps Challenge 2026**,
desafío *"Abandoned but not Forgotten"*. La historia del equipo que la NASA dejó en la Luna, en Marte y en
el espacio profundo, contada en primera persona por las propias máquinas, que te hablan por radio.

## Cómo abrirlo
1. Godot 4.5 → *Import* → selecciona `project.godot`.
2. F5 para ejecutar (arranca en `scenes/ui/intro_screen.tscn`).

## Flujo de escenas
`intro_screen` → `main_menu` → `planet_select` → misión → regreso al selector.

| Escena | Qué hay |
|---|---|
| `scenes/ui/intro_screen.tscn` | Pasillo de nave abandonada, alarma roja, objetos en gravedad cero (con ficha al pasar el ratón), transmisión de radio y zoom hacia la Luna de la ventana. |
| `scenes/ui/main_menu.tscn` | Luna y Marte girando con sus sitios. Iniciar misión, Archivo científico (lee `data/archive.json`; la "transmisión" de cada máquina se desbloquea al completar su misión), Controles, Salir. |
| `scenes/ui/planet_select.tscn` | Tres destinos de `data/sites.json` (Luna, Marte, Espacio profundo) con puntos verdes en las coordenadas reales. Clic en un punto o ENTER → ficha → INICIAR MISIÓN → zoom con ondas de radar. |
| `scenes/missions/mision_apolo11.tscn` | Misión 1 · Guardianes de la Tranquilidad (guion aprobado). |
| `scenes/missions/mision_surveyor3.tscn` | Misión 2 · Huellas en el polvo (guion aprobado). |
| `scenes/missions/mision_pioneer.tscn` | Misión 3 · La última señal (propuesta). |
| `scenes/missions/chapter_spirit_opportunity.tscn` | Misión 4 · Capítulo Spirit y Opportunity (vista top-down, HUD propio, transmisiones TX/RX). Textos en `data/dialogos/spirit_opportunity.json`. Emite `chapter_finished`. Debug: F1-F7 saltan a cada escena, F8 al cierre. |
| `scenes/missions/chapter_pioneer10.tscn` | Capítulo Pioneer 10 (selector → Espacio profundo → Pioneer 10): lanzamiento, cinturón (esquive), Júpiter (encuadre y disparo), cinemática de la tormenta solar y la magnetosfera (con un momento de control: apuntar la antena a la Tierra con A/D), silencio, la placa (púlsares) y epílogo. La cinemática de Io aún muestra "CINEMÁTICA PENDIENTE". Pioneer 11 ya no aparece en el selector. Textos en `data/dialogos/pioneer10.json`. Debug: F1-F7 saltan a cada fase. |

Las misiones 1-3 siguen las mismas 6 fases (0 tutorial → 5 legado) sobre `scripts/missions/mission_base.gd`.
La misión 4 (Marte) es un capítulo independiente: `scripts/missions/chapter_spirit_opportunity.gd`.
ESC abre la pausa (continuar, reiniciar fase, volver al selector).

## HUD común de las misiones (`scripts/components/mission_hud.gd`)
- **Ficha de misión**: al empezar cada misión se muestra a pantalla completa y luego se minimiza en una insignia (clic en ella = ver la ficha).
- **Tres botones de información**: `[C] CONTROLES`, `[O] OBJETIVOS`, `[I] MISIÓN` (también con las teclas C, O, I). Pausan el juego.
- **Indicadores de controles**: las teclas de la fase actual, abajo a la izquierda; se iluminan al pulsarlas.
- **Recordatorios del científico**: al empezar cada fase, tras un fallo o si el jugador pasa ~18 s sin actuar.
- Los textos están en el bloque `"hud"` de cada `data/dialogos/mision_X.json` (y `"mission_hud"` en `spirit_opportunity.json`).

## Estructura
```
data/                 sites.json · archive.json · dialogos/intro.json, mision_1..3.json, spirit_opportunity.json
scenes/ui/            intro, menú, selector          scenes/missions/   las 4 misiones
scenes/components/    radio_dialog.tscn
scripts/autoload/     SceneTransition (fundido) · GameManager (datos, progreso, Input Map)
scripts/components/   RadioDialog · TransmissionDialog (TX/RX) · Lander · Hotspot · DrawNode
scripts/missions/     MissionBase + una por misión
scripts/fx/           ShipCorridor · PixelPlanet · DeepSpaceView · Starfield · PixelSprites
assets/shaders/       crt_overlay · pixel_planet       assets/sprites, fonts, audio (arte final)
```

## Datos y precisión
- Todos los textos están en `data/`. Las entradas con `"verificar"` son datos por confirmar con las
  fuentes oficiales; las de `"propuesta": true` son añadidos que no están en el guion aprobado.
- Las constantes físicas reales están en `scripts/data/mission_data.gd`. Los límites de aterrizaje y la
  aceleración del tiempo son valores de juego.

## Input Map
Se registra por código en `GameManager` (no hace falta crearlo a mano):
`thrust` W/↑/Espacio · `move_down` S/↓ · `rotate_left` A/← · `rotate_right` D/→ · más `ui_accept` y `ui_cancel`.

## Progreso
`user://progreso.cfg` (ConfigFile) guarda las misiones completadas.

## Exportar
Renderer `Compatibility`. Al exportar, añade `*.json` en *Resources → Filters to export non-resource files*
para que se incluya la carpeta `data/`.
