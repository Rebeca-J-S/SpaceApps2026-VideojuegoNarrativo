# What Was Left Behind by NASA

Videojuego educativo en Pixel Art 2D (Godot 4.5, GDScript) para el **NASA Space Apps Challenge 2026**,
desafío *"Abandoned but not Forgotten: Storytelling about NASA's Discarded Equipment on the Moon and Mars"*.
La historia del hardware que la NASA dejó en la Luna y Marte, contada por las propias máquinas.
Misión jugable actual: el alunizaje del Apolo 11 (Eagle LM-5, EASEP y LRRR).

## Cómo abrirlo
1. Godot 4.5 → *Import* → selecciona `project.godot`.
2. F5 para ejecutar (arranca en `scenes/ui/intro_screen.tscn`).

## Flujo
- **Intro** (`scenes/ui/intro_screen.tscn`): pasillo de la nave en pixel art, alarma roja y objetos
  flotando en gravedad cero (cosas reales que los astronautas dejaron en la Luna; pasa el ratón
  por encima para ver su ficha). Registro de a bordo con efecto máquina de escribir → INICIAR,
  que hace zoom por el pasillo hacia la Luna de la ventana y llega al menú.
- **Menú** (`scenes/ui/main_menu.tscn`): la Luna y Marte rotando, con los sitios de hardware
  marcados (Apolo 11-17, Viking, Sojourner, Spirit, Opportunity, InSight, Ingenuity, Curiosity…).
  Archivo científico por secciones LUNA / MARTE / MISIÓN.
- **Selección de destino** (`scenes/ui/mission_select.tscn`): INICIAR MISIÓN lleva aquí. Elige la
  Luna (Apolo 11 → `fase0_orbita`) o Marte (`marte_fase0`, en desarrollo); al confirmar, zoom al planeta.

## Estructura
```
assets/   shaders/ (crt_overlay, pixel_planet)  sprites/ fonts/ audio/ (arte final)
scenes/   ui/ (intro, menú)   levels/ (fases de juego)
scripts/  autoload/ SceneTransition       data/ MissionData (datos reales NASA)
          fx/ ShipCorridor, PixelPlanet, PixelSprites, Starfield, MoonSurface (para la fase de alunizaje)
          ui/ RetroTheme + escenas UI     levels/
```

## Configuración Pixel Art (en project.godot)
- Viewport 640x360, ventana 1280x720, stretch `viewport` + aspect `keep` + scale mode `integer`.
- Filtro de texturas `Nearest`, snap 2D a píxel, fuentes sin antialiasing.
- Renderer `Compatibility` (necesario para exportar a Web/HTML5).
