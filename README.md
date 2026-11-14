# Guardianes de la Tranquilidad (The Silent Sentinels)

Videojuego educativo en Pixel Art 2D (Godot 4, GDScript) para el **NASA Space Apps Challenge 2026**,
desafío *"Abandoned but not Forgotten"*. La historia del Apolo 11 contada por el hardware que se
quedó en la Luna: la Etapa de Descenso del Eagle (LM-5), el EASEP y el retrorreflector LRRR.

## Cómo abrirlo
1. Godot 4.3 o superior → *Import* → selecciona `project.godot`.
2. F5 para ejecutar (arranca en `scenes/ui/intro_screen.tscn`).

## Estructura
```
assets/      sprites/  fonts/  audio/  shaders/   (arte final; hoy solo el shader CRT)
scenes/      ui/ (intro, menú)   levels/ (fases de juego)
scripts/     autoload/ (SceneTransition)   data/ (MissionData: datos reales NASA)
             fx/ (Starfield, MoonSurface)  ui/ (RetroTheme, escenas UI)   levels/
```

## Configuración Pixel Art (ya aplicada en project.godot)
- Viewport 640x360, ventana 1280x720, stretch `viewport` + aspect `keep` + scale mode `integer`.
- Filtro de texturas por defecto `Nearest`, snap 2D a píxel, fuentes sin antialiasing.
- Renderer `Compatibility` (necesario para exportar a Web/HTML5).
