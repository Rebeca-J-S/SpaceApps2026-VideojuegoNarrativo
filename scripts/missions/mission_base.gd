class_name MissionBase
extends Control
## Base común de las 4 misiones. Todas siguen la misma estructura de 6 fases:
##   0 Tutorial -> 1 Aproximación -> 2 Momento crítico -> 3 Ciencia -> 4 Abandono -> 5 Legado
##
## Cada misión hereda de aquí y solo implementa run_phase(i).
## La base aporta: capas (fondo, mundo, HUD), diálogo de radio, banner de fase, controles
## siempre visibles, puntos interactivos, pausa (ESC), reinicio de fase y pantalla final.

signal accept_pressed
signal hotspot_hit(hotspot: Hotspot)

const W := 640.0
const H := 360.0

# --- A rellenar por cada misión (en _init) ---
var mission_id := ""                 ## id para el progreso guardado
var mission_number := 1
var mission_name := ""
var dialog_path := ""
var phase_titles: Array = ["", "", "", "", "", ""]

var dialogs: Dictionary = {}
var phase := 0

var background: ColorRect
var world: Node2D
var hud: Control
var radio: RadioDialog
var _phase_label: Label
var _objective_label: Label
var mission_hud: MissionHUD
var _telemetry_panel: PanelContainer
var _telemetry_label: Label
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _pause_panel: PanelContainer
var _pause_first: Button


func _ready() -> void:
	theme = RetroTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogs = GameManager.load_json(dialog_path)
	_build_layers()
	await get_tree().process_frame
	run_mission()


# =========================================================================
# Flujo de la misión
# =========================================================================
func run_mission() -> void:
	var start := GameManager.consume_start_phase()
	# Ficha de la misión a pantalla completa y luego minimizada (solo al empezar desde cero).
	if start == 0:
		await mission_hud.show_briefing()
	else:
		mission_hud.minimize_now()
	for i in range(start, 6):
		phase = i
		await run_phase(i)
	await _complete()


## Implementado por cada misión.
func run_phase(_index: int) -> void:
	await wait(0.1)


## Muestra el banner de la fase y prepara el HUD. Limpia el mundo de la fase anterior.
func begin_phase(index: int, objective: String, controls: String) -> void:
	phase = index
	clear_world()
	_phase_label.text = "MISIÓN %d · FASE %d: %s" % [mission_number, index, phase_titles[index]]
	set_objective(objective)
	set_controls(controls)
	set_telemetry("")
	_banner_title.text = "FASE %d" % index
	_banner_sub.text = phase_titles[index]
	_banner.modulate.a = 0.0
	_banner.show()
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.3)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	await tw.finished
	_banner.hide()
	# Teclas de la fase y pauta del científico (se muestra en cuanto no haya diálogo).
	mission_hud.set_phase(index, phase_titles[index], objective, controls)


## El científico de Control de Misión recuerda algo durante la fase.
func remind(text: String = "") -> void:
	mission_hud.remind(text)


func say(key: String) -> void:
	if not dialogs.has(key):
		push_warning("Diálogo no encontrado: %s" % key)
		return
	await radio.play(dialogs[key])


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func wait_accept() -> void:
	await accept_pressed


func set_objective(text: String) -> void:
	_objective_label.text = "OBJETIVO: " + text if text != "" else ""
	if mission_hud:
		mission_hud.set_objective(text)


## Compatibilidad: los controles ahora se muestran como teclas en el MissionHUD
## (datos en el bloque "hud" del JSON). Este texto solo se usa si la fase no tiene teclas.
func set_controls(_text: String) -> void:
	pass


func set_telemetry(text: String) -> void:
	_telemetry_label.text = text
	_telemetry_panel.visible = text != ""


## Mensaje grande y breve en el centro (éxito / fallo).
func toast(text: String, color: Color = RetroTheme.AMBER, seconds: float = 1.6) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.show()
	await wait(seconds)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	await tw.finished
	_toast.hide()
	# Tras un fallo (mensaje en rojo), el científico recuerda la pauta de la fase.
	if color == Color("#ff5a4a"):
		mission_hud.remind()


# =========================================================================
# Mundo de juego
# =========================================================================
func clear_world() -> void:
	for c in world.get_children():
		world.remove_child(c)
		c.queue_free()


func add_world(node: Node) -> Node:
	world.add_child(node)
	return node


## Capa de dibujo placeholder dentro del mundo.
func draw_layer(fn: Callable, animated: bool = true) -> DrawNode:
	var n := DrawNode.new(fn, animated)
	world.add_child(n)
	return n


func add_starfield(count: int = 140, drift: Vector2 = Vector2.ZERO) -> Starfield:
	var s := Starfield.new()
	s.star_count = count
	s.drift = drift
	world.add_child(s)
	return s


## Crea puntos interactivos: defs = [["TEXTO", Vector2(x, y)], ...] numerados 1, 2, 3...
func spawn_hotspots(defs: Array) -> Array[Hotspot]:
	var list: Array[Hotspot] = []
	for i in defs.size():
		var h := Hotspot.new(defs[i][0], i + 1, defs[i][1])
		h.activated.connect(func(hs: Hotspot) -> void: hotspot_hit.emit(hs))
		world.add_child(h)
		list.append(h)
	return list


## Espera a que el jugador active cualquiera de los puntos. Devuelve el activado.
func wait_hotspot() -> Hotspot:
	var h: Hotspot = await hotspot_hit
	return h


## Espera hasta que se active el punto concreto.
func wait_specific(spot: Hotspot) -> void:
	while true:
		var h := await wait_hotspot()
		if h == spot:
			return


## Cámara de aterrizaje: la nave se queda arriba (top_y) hasta que el suelo entra en cuadro;
## después el suelo queda fijo en ground_screen_y y la nave baja hacia él.
## Devuelve la coordenada Y del suelo en pantalla.
func landing_camera(l: Lander, ppm: float, ground_screen_y: float = 318.0, top_y: float = 80.0) -> float:
	var ground_y := maxf(ground_screen_y, top_y + l.alt * ppm)
	l.position = Vector2(l.x * ppm, ground_y - l.alt * ppm - l.feet_offset())
	return ground_y


# =========================================================================
# Utilidades de dibujo compartidas
# =========================================================================
## Suelo lunar sencillo con borde iluminado y cráteres.
static func draw_moon_ground(c: CanvasItem, ground_y: float, tint: Color = Color("#5d5c69")) -> void:
	c.draw_rect(Rect2(0, ground_y, W, H - ground_y + 40), tint)
	c.draw_rect(Rect2(0, ground_y, W, 2), tint.lightened(0.25))
	for i in 9:
		var cx := fmod(i * 97.0 + 30.0, W)
		var cy := ground_y + 14.0 + fmod(i * 23.0, 30.0)
		var r := 6.0 + fmod(i * 7.0, 12.0)
		c.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.0, 0.35))
		c.draw_circle(Vector2(0, -2), r + 1, tint.lightened(0.15))
		c.draw_circle(Vector2.ZERO, r, tint.darkened(0.25))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## La Tierra pequeña en el cielo.
static func draw_earth(c: CanvasItem, pos: Vector2, r: float) -> void:
	c.draw_circle(pos, r + 1.0, Color(0.5, 0.9, 1.0, 0.3))
	c.draw_circle(pos, r, Color("#2e6bd1"))
	c.draw_circle(pos + Vector2(-r * 0.3, -r * 0.2), r * 0.4, Color("#3f9a52"))
	c.draw_rect(Rect2(pos.x - r * 0.6, pos.y + r * 0.2, r * 0.6, 1), Color("#e8f0ff"))


## Barra horizontal simple con etiqueta (energía, señal, progreso...).
static func draw_bar(c: CanvasItem, rect: Rect2, value: float, color: Color, label: String = "") -> void:
	c.draw_rect(rect, Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), color)
	c.draw_rect(rect, color.lightened(0.3), false, 1.0)
	if label != "":
		c.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


# =========================================================================
# Entrada: pausa y "pulsa para continuar"
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_toggle_pause()
		return
	if get_tree().paused or radio.is_active():
		return
	if event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		accept_pressed.emit()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		_pause_first.grab_focus()


func _restart_phase() -> void:
	GameManager.set_start_phase(phase)
	get_tree().paused = false
	SceneTransition.change_scene(scene_file_path, 0.3)


func _complete() -> void:
	clear_world()
	mission_hud.mark_all_done()
	GameManager.mark_completed(mission_id)
	set_objective("")
	set_telemetry("")
	add_starfield(160)
	_banner_title.text = "MISIÓN COMPLETADA"
	_banner_sub.text = "%s\nNuevas transmisiones desbloqueadas en el ARCHIVO CIENTÍFICO\n\nENTER / CLIC: volver al selector de destinos" % mission_name
	_banner.modulate.a = 1.0
	_banner.show()
	await wait(0.6)
	await wait_accept()
	GameManager.go_to_planet_select()


# =========================================================================
# Construcción de capas e interfaz
# =========================================================================
func _build_layers() -> void:
	background = ColorRect.new()
	background.color = RetroTheme.SPACE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	# Barra superior: fase, objetivo y controles (siempre visibles).
	var bar := ColorRect.new()
	bar.color = Color(0.01, 0.03, 0.04, 0.75)
	bar.position = Vector2.ZERO
	bar.size = Vector2(W, 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar)
	_phase_label = _label(Vector2(8, 2), 12, RetroTheme.AMBER)
	_objective_label = _label(Vector2(8, 18), 10, RetroTheme.PHOSPHOR)

	_telemetry_panel = PanelContainer.new()
	_telemetry_panel.position = Vector2(W - 170, 40)
	_telemetry_panel.custom_minimum_size = Vector2(162, 0)
	_telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_telemetry_panel)
	_telemetry_label = Label.new()
	_telemetry_label.add_theme_font_size_override("font_size", 10)
	_telemetry_panel.add_child(_telemetry_label)
	_telemetry_panel.hide()

	# Banner central de fase.
	_banner = ColorRect.new()
	(_banner as ColorRect).color = Color(0, 0, 0, 0.65)
	_banner.position = Vector2(0, 120)
	_banner.size = Vector2(W, 110)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_banner)
	_banner_title = _label(Vector2(0, 10), 26, RetroTheme.AMBER, _banner)
	_banner_title.size = Vector2(W, 34)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.1))
	_banner_title.add_theme_constant_override("outline_size", 6)
	_banner_sub = _label(Vector2(0, 46), 12, RetroTheme.WHITE, _banner)
	_banner_sub.size = Vector2(W, 60)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.hide()

	_toast = _label(Vector2(0, 150), 20, RetroTheme.AMBER)
	_toast.size = Vector2(W, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.1))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.hide()

	radio = RadioDialog.new()
	add_child(radio)

	# HUD común: ficha de misión, botones C/O/I, teclas de la fase y recordatorios del científico.
	mission_hud = MissionHUD.new()
	add_child(mission_hud)
	mission_hud.badge_pos = Vector2(W - 8 - 180, 19)
	mission_hud.buttons_pos = Vector2(W - 6, 3)
	mission_hud.reminder_pos = Vector2(8, 40)
	mission_hud.keys_pos = Vector2(8, H - 18)
	mission_hud.busy_check = func() -> bool: return radio.is_active() or _banner.visible
	mission_hud.setup(dialogs.get("hud", {}), phase_titles.duplicate())
	mission_hud.apply_layout()

	_build_pause_panel()

	# Overlay CRT por encima de todo.
	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/crt_overlay.gdshader")
	mat.set_shader_parameter("scanline_strength", 0.1)
	mat.set_shader_parameter("vignette_strength", 0.35)
	crt.material = mat
	add_child(crt)


func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.position = Vector2(W * 0.5 - 110, 100)
	_pause_panel.custom_minimum_size = Vector2(220, 0)
	add_child(_pause_panel)
	var box := VBoxContainer.new()
	_pause_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", RetroTheme.AMBER)
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	_pause_first = _pause_button(box, "CONTINUAR", _toggle_pause)
	_pause_button(box, "REINICIAR FASE", _restart_phase)
	_pause_button(box, "VOLVER AL SELECTOR", GameManager.go_to_planet_select)
	_pause_panel.hide()


func _pause_button(box: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 22)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _label(pos: Vector2, font_size: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else hud).add_child(l)
	return l
