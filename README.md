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
| `scenes/missions/chapter_apolo11.tscn` | Capítulo Apollo 11: Eagle (selector → Luna → Apolo 11): viaje Tierra-Luna (cinemática con reloj de vuelo: 75 h 50 min) y órbita lunar, descenso (elegir zona y estabilizar el Eagle con el ritmo de los clics), primer paso (cinemática de la escalera y la frase + acciones con el cursor), recolección de rocas, despegue (medidor de potencia + ángulo) y acoplamiento (cinemática). Textos en `data/dialogos/apolo11.json`. Debug: F1-F6 saltan a cada fase. |
| `scenes/missions/mision_surveyor3.tscn` | Misión 2 · Huellas en el polvo (guion aprobado). |
| `scenes/missions/mision_apolo11.tscn` | Misión 1 · Guardianes de la Tranquilidad (Apolo 11): cinemática del viaje Tierra-Luna, descenso, minijuego de estabilización del aterrizaje, cinemática de Neil y Buzz, minijuego de recolección de pruebas (21.55 kg, 2 tubos de núcleo, EASEP y LRRR) y cinemática de ascenso. Datos: NSSDCA 1969-059C. |
| `scenes/missions/mision_pioneer.tscn` | Misión 3 · La última señal (propuesta). |
| `scenes/missions/chapter_spirit_opportunity.tscn` | Misión 4 · Capítulo Spirit y Opportunity «Gemelos» (7 fases: planificar el sol, detective del agua, escape de Purgatory, rueda arrastrada, invierno en Troy, ruta a Endeavour, tormenta + epílogo). Las cinemáticas son pantallas «CINEMÁTICA PENDIENTE». Textos en `data/dialogos/spirit_opportunity.json` (inglés en `data/i18n/en/`). Emite `chapter_finished`. Debug: F1-F7 saltan a cada fase. |
| `scenes/missions/chapter_pioneer10.tscn` | Capítulo Pioneer 10 (selector → Espacio profundo → Pioneer 10): lanzamiento, cinturón (esquive), Júpiter (encuadre y disparo), cinemática de la tormenta solar y la magnetosfera (con un momento de control: apuntar la antena a la Tierra con A/D), silencio, la placa (púlsares) y epílogo. Pioneer 11 ya no aparece en el selector. Textos en `data/dialogos/pioneer10.json`. Debug: F1-F7 saltan a cada fase. |

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

## Idiomas (inglés / español)
- El juego arranca en **inglés**; el botón **EN | ES** (arriba a la derecha en la intro, el menú y el
  selector, o la tecla **L**) cambia a español y viceversa. La elección se guarda en `user://progreso.cfg`.
- Los textos fuente están en **español** (JSON de `data/` y código). `data/i18n/en/*.json` guarda las
  parejas `"texto en español": "English text"`: los JSON se traducen al cargarse y el código usa `tr()`.
- Si cambias o añades un texto en español, añade su traducción en `data/i18n/en/`. Mientras falte, el
  juego lo muestra en español y, al ejecutarlo desde el editor, avisa por consola (`i18n: falta...`).
- Un valor vacío (`""`) oculta el texto en inglés (p. ej. la traducción `sub` de una frase que ya está
  en inglés). Los números se muestran con el formato de cada idioma (21.5 / 21,5).

## Sitios bloqueados
`data/sites.json` lista todos los equipos del desafío (Luna: Apolo 11, LRV, ALSEP, Surveyor · Marte:
Sojourner, Spirit y Opportunity, Viking, Phoenix e InSight, Ingenuity · Espacio profundo: Pioneer 10, Dawn,
NEAR Shoemaker, Kepler). Los que tienen `"locked": true` (o no tienen `scene`) se ven como punto gris y su
ficha dice "BLOQUEADO". Hoy solo se juegan **Apolo 11** y **Pioneer 10**. Para habilitar uno, quita
`"locked": true` y pon su `"scene"` (el capítulo de Spirit y Opportunity ya existe: basta con quitar `locked`).

## Cuaderno de insignias
- Cada equipo del desafío tiene una insignia (`data/badges.json`: nombre, descripción, enlace de referencia
  NASA, icono y número de piezas). Cada **fase terminada** de una misión gana una pieza; al terminar todas,
  la insignia se completa. En la misión aparece un aviso breve con la pieza nueva (`BadgeToast`).
- El cuaderno se abre desde **Archivo científico → CUADERNO DE INSIGNIAS**: una libreta con las 13
  insignias (completas, a medias o bloqueadas). Clic o ENTER en una abre su ficha con la insignia grande,
  su estado, la descripción y el botón **ABRIR ENLACE** a la página de la NASA.
- Las piezas ganadas se guardan en `user://progreso.cfg` (sección `insignias`). El dibujo de cada insignia
  está en `scripts/components/badge_art.gd` (PLACEHOLDER: se puede sustituir por sprites).
- **Ficha técnica**: al completar una insignia se desbloquea la ficha histórica y técnica del artefacto
  (campo `sheet` de `data/badges.json`: datos, historia y dónde está hoy). La misión muestra un aviso
  grande (`BadgeUnlockCard`) con el botón **VER FICHA**, y en el cuaderno aparece el botón
  **FICHA TÉCNICA** (`BadgeSheet`).

## Menú de pausa, tutoriales y sonido
- En cada misión, el botón de tres puntos (esquina superior derecha) o **ESC** abre el menú de pausa
  (`scripts/components/pause_menu.gd`): **SONIDO** (volumen de música y efectos), **AYUDA** (cómo se
  juega cada minijuego de la misión y preguntas frecuentes) y **SALIR DE LA MISIÓN** (elegir otra
  misión, menú principal o cerrar el juego).
- Antes de cada minijuego aparece una tarjeta **CÓMO SE JUEGA** (`TutorialCard`) con el objetivo, las
  teclas y las reglas; pausa el juego hasta pulsar ENTER o clic. Los textos están en `data/guia.json`
  (`juegos` → misión → id de escena; las fases que son solo cinemática no tienen tarjeta) y la misma
  guía se ve en **AYUDA**.
- Sonido: `GameManager` crea los buses **Music** y **SFX**; todo `AudioStreamPlayer` nuevo pasa al bus SFX.
  La música ambiental es un bucle generado por código (PLACEHOLDER: se puede cambiar por una pista real
  en `GameManager._start_music`). El volumen se guarda en `user://progreso.cfg` (sección `ajustes`).

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
