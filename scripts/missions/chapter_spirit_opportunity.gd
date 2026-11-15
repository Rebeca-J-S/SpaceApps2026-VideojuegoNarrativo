extends Control
## CAPÍTULO "SPIRIT Y OPPORTUNITY" (Marte, 2004-2018). Vista top-down, pixel art placeholder.
##
## Escena raíz modular: se lanza desde el selector de destinos y emite chapter_finished al terminar.
## Todos los textos y valores del HUD están en data/dialogos/spirit_opportunity.json.
##
## Orden: aviso inicial -> 1 Llegada de Spirit (2004) -> 2A Blueberries (2004) -> 2B Sílice (2007)
##        -> 3A Invierno de Spirit (2009-2010, opcional) -> 3B Rumbo a Endeavour (2010-2015)
##        -> 4 La tormenta (2018) -> pantalla de cierre.
##
## HUD: arriba izquierda AÑO, arriba derecha OBJETIVO; abajo retrato + diálogo (TransmissionDialog)
##      y panel de datos con DISTANCIA RECORRIDA, SEÑAL (%) y mini radar.
## Debug (solo en builds de depuración): F1-F6 saltan a cada escena, F7 a la pantalla de cierre.

signal chapter_finished

const DATA_PATH := "res://data/dialogos/spirit_opportunity.json"
const MISSION_ID := "gemelas"          # id de progreso (desbloquea las fichas en el Archivo)
const W := 640.0
const GAME_TOP := 22.0
const GAME_BOTTOM := 266.0
const SOIL := Color("#b5532a")
const SOIL_DARK := Color("#8c3a1e")
const SOIL_LIGHT := Color("#cf7440")
const ROCK := Color("#5a3a2a")

## Si es true, al terminar marca la misión como completada y vuelve al selector.
## Ponlo en false si otra escena escucha chapter_finished y decide qué hacer.
@export var auto_return := true
@export var debug_mode := true

var data: Dictionary = {}
var world: Node2D
var ui_layer: Control
var dialog: TransmissionDialog
var mission_hud: MissionHUD

var _year: Label
var _objective: Label
var _mm_title: Label
var _mm_info: Label
var _toast: Label
var _dist_label: Label
var _signal_label: Label
var _hud_draw: Control
var _pause_panel: PanelContainer
var _fade: ColorRect

var _distance := 0.0
var _rover_name := ""
var _signal := 90.0
var _signal_target := 90.0
var _fluct_t := 0.0
var _static := 0.0
var _t := 0.0
var _mode := ""                       # minijuego activo (para la entrada)

# Estado de los minijuegos
var _mast := 0.0
var _antenna := 0.0
var _rover_pos := Vector2.ZERO
var _rover_angle := -PI * 0.5
var _rocks: Array[Vector3] = []
var _berries: Array[Vector2] = []
var _berry_found: Array[bool] = []
var _cells: Array[bool] = []
var _wheel := Vector2.ZERO
var _cell_rect := Rect2(220, 110, 200, 70)
var _day := 0
var _scroll := 0.0
var _craters: Array[Vector3] = []
var _hit_cooldown := 0.0
var _shots_taken: Array[bool] = []
var _shot_target := -1
var _dust := 0.0
var _flash := 0.0
var _wrong_text := ""


func _ready() -> void:
	theme = RetroTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	data = GameManager.load_json(DATA_PATH)
	_build()
	await get_tree().process_frame
	_run_chapter()


# =========================================================================
# Flujo del capítulo
# =========================================================================
func _run_chapter() -> void:
	var start := GameManager.consume_start_phase()  # 0 = normal; 1-7 = escena; 8 = cierre
	var scenes: Array = data["scenes"]
	if start == 0:
		# Ficha de la misión a pantalla completa y luego minimizada.
		await mission_hud.show_briefing()
		await _disclaimer()
	else:
		mission_hud.minimize_now()
	var first := maxi(start - 1, 0)
	if start < 8:
		for i in range(first, scenes.size()):
			var sc: Dictionary = scenes[i]
			if not bool(sc.get("enabled", true)):
				continue
			await _run_scene(sc, i)
	mission_hud.mark_all_done()
	await _closing()
	chapter_finished.emit()
	if auto_return:
		GameManager.mark_completed(MISSION_ID)
		GameManager.go_to_planet_select()


func _run_scene(sc: Dictionary, index: int) -> void:
	_clear()
	_year.text = "%s %s" % [data["hud"]["year"], sc["year"]]
	_objective.text = "%s: %s" % [data["hud"]["objective"], sc["objective"]]
	_distance = float(sc.get("distance_km", 0.0))
	_rover_name = String(data["speakers"][String(sc.get("rover", "SPIRIT"))]["name"])
	_signal_target = float(sc.get("signal", 90))
	_signal = _signal_target
	await _banner(String(sc["title"]))
	# Teclas de la escena y pauta del científico (MissionHUD).
	mission_hud.set_phase(index, String(sc["title"]), String(sc["objective"]))
	match String(sc["id"]):
		"llegada_spirit": await _scene_arrival(sc)
		"blueberries": await _scene_blueberries(sc)
		"silice": await _scene_silica(sc)
		"invierno_spirit": await _scene_winter(sc)
		"endeavour": await _scene_endeavour(sc)
		"maraton": await say(sc["intro"])
		"tormenta": await _scene_storm(sc)


func say(lines: Array) -> void:
	await dialog.play(lines)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func wait_click_or_accept(auto_seconds: float = 0.0) -> void:
	_mode = "continue"
	var left := auto_seconds
	while _mode == "continue":
		await get_tree().process_frame
		if auto_seconds > 0.0:
			left -= get_process_delta_time()
			if left <= 0.0:
				_mode = ""   # continúa solo; ENTER / clic solo adelantan


# =========================================================================
# Construcción del HUD
# =========================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2a120a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ui_layer = Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)

	# Barra superior: AÑO (izquierda) y OBJETIVO (derecha).
	var top := ColorRect.new()
	top.color = Color(0.02, 0.02, 0.04, 0.85)
	top.size = Vector2(W, GAME_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_year = _label(Vector2(8, 3), Vector2(200, 16), 13, RetroTheme.AMBER)
	_objective = _label(Vector2(200, 5), Vector2(432, 16), 10, RetroTheme.PHOSPHOR)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Título e instrucción de la minimisión (dentro del área de juego).
	_mm_title = _label(Vector2(8, GAME_TOP + 22), Vector2(400, 14), 11, RetroTheme.AMBER)
	_mm_info = _label(Vector2(8, GAME_TOP + 36), Vector2(560, 14), 10, RetroTheme.WHITE)
	_mm_title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	_mm_title.add_theme_constant_override("outline_size", 4)
	_mm_info.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	_mm_info.add_theme_constant_override("outline_size", 4)
	_toast = _label(Vector2(0, 120), Vector2(W, 40), 18, RetroTheme.AMBER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.hide()

	# Franja inferior: retrato + diálogo (centro) + panel de datos (derecha).
	var bottom := ColorRect.new()
	bottom.color = Color(0.02, 0.02, 0.04, 0.92)
	bottom.position = Vector2(0, GAME_BOTTOM)
	bottom.size = Vector2(W, 360 - GAME_BOTTOM)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	dialog = TransmissionDialog.new()
	dialog.position = Vector2(8, GAME_BOTTOM + 6)
	dialog.size = Vector2(458, 82)
	dialog.speakers = data["speakers"]
	dialog.transit_text = data["hud"]["in_transit"]
	# Menos ENTER: los mensajes avanzan solos (ENTER / clic solo adelantan) y la radio responde más rápido.
	dialog.auto_advance = true
	dialog.type_speed = 55.0
	dialog.transit_range = Vector2(0.35, 0.6)
	add_child(dialog)

	_hud_draw = Control.new()
	_hud_draw.position = Vector2(472, GAME_BOTTOM + 6)
	_hud_draw.size = Vector2(160, 82)
	_hud_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_draw.draw.connect(_draw_data_panel)
	add_child(_hud_draw)
	_dist_label = _label(Vector2(478, GAME_BOTTOM + 22), Vector2(100, 16), 13, RetroTheme.WHITE)
	_signal_label = _label(Vector2(478, GAME_BOTTOM + 52), Vector2(100, 14), 10, RetroTheme.PHOSPHOR)

	# Estática a pantalla completa y fundido.
	var static_layer := DrawNode.new(_draw_static)
	add_child(static_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)

	if debug_mode and OS.is_debug_build():
		var dbg := _label(Vector2(0, GAME_BOTTOM - 14), Vector2(W - 8, 12), 9, Color(1, 0.4, 0.4, 0.8))
		dbg.text = data["hud"]["debug"]
		dbg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# HUD común: ficha de misión, botones C/O/I, teclas y recordatorios del científico.
	mission_hud = MissionHUD.new()
	add_child(mission_hud)
	mission_hud.badge_pos = Vector2(8, GAME_TOP + 3)
	mission_hud.buttons_pos = Vector2(W - 6, GAME_TOP + 3)
	mission_hud.reminder_pos = Vector2(8, GAME_TOP + 54)
	mission_hud.briefing_auto_seconds = 7.0   # la ficha se minimiza sola; ENTER / clic la adelantan
	mission_hud.keys_pos = Vector2(8, GAME_BOTTOM - 17)
	mission_hud.busy_check = func() -> bool: return dialog.is_active() or _toast.visible
	# Las pistas del Científico salen en la caja de diálogo de abajo, no en un recuadro sobre el juego.
	mission_hud.reminder_callback = func(t: String) -> void: dialog.show_hint("CIENTIFICO", t)
	var titles: Array = []
	for sc in data["scenes"]:
		titles.append(String(sc["title"]))
	mission_hud.setup(data.get("mission_hud", {}), titles)
	mission_hud.apply_layout()

	_build_pause()
	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/crt_overlay.gdshader")
	mat.set_shader_parameter("scanline_strength", 0.1)
	mat.set_shader_parameter("vignette_strength", 0.35)
	crt.material = mat
	add_child(crt)


func _build_pause() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.position = Vector2(220, 100)
	_pause_panel.custom_minimum_size = Vector2(200, 0)
	add_child(_pause_panel)
	var box := VBoxContainer.new()
	_pause_panel.add_child(box)
	var t := Label.new()
	t.text = data["hud"]["pause_title"]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", RetroTheme.AMBER)
	box.add_child(t)
	var cont := Button.new()
	cont.text = data["hud"]["pause_continue"]
	cont.pressed.connect(_toggle_pause)
	box.add_child(cont)
	var exit := Button.new()
	exit.text = data["hud"]["pause_exit"]
	exit.pressed.connect(GameManager.go_to_planet_select)
	box.add_child(exit)
	_pause_panel.hide()


func _label(pos: Vector2, sz: Vector2, font_size: int, color: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else self).add_child(l)
	return l


func _clear() -> void:
	_mode = ""
	_mm_title.text = ""
	_mm_info.text = ""
	_static = 0.0
	for n in world.get_children():
		world.remove_child(n)
		n.queue_free()
	for n in ui_layer.get_children():
		ui_layer.remove_child(n)
		n.queue_free()


func _layer(fn: Callable) -> DrawNode:
	var d := DrawNode.new(fn)
	world.add_child(d)
	return d


func _banner(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 0.0
	_toast.show()
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	await tw.finished
	_toast.hide()


func toast(text: String, color: Color = RetroTheme.AMBER, seconds: float = 0.9) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.show()
	await wait(seconds)
	_toast.hide()
	_toast.add_theme_color_override("font_color", RetroTheme.AMBER)


# =========================================================================
# HUD dinámico: distancia, señal fluctuante y mini radar
# =========================================================================
func _process(delta: float) -> void:
	_t += delta
	_fluct_t -= delta
	if dialog.is_active() and dialog._robot_speaking:
		# La señal fluctúa mientras habla un rover.
		if _fluct_t <= 0.0:
			_fluct_t = 0.08
			_signal = clampf(_signal_target + randf_range(-28.0, 4.0), 0.0, 100.0)
	else:
		_signal = lerpf(_signal, _signal_target, minf(1.0, delta * 3.0))
	_dist_label.text = tr("%.2f km") % _distance
	_signal_label.text = "%s %d%%" % [data["hud"]["signal"], int(round(_signal))]
	_flash = maxf(0.0, _flash - delta * 3.0)
	_hud_draw.queue_redraw()


func _draw_data_panel() -> void:
	var c := _hud_draw
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.01, 0.04, 0.03, 0.92))
	c.draw_rect(r, RetroTheme.PHOSPHOR, false, 1.0)
	var font := ThemeDB.fallback_font
	c.draw_string(font, Vector2(6, 12), data["hud"]["distance"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.PHOSPHOR_DIM)
	c.draw_string(font, Vector2(6, 42), _rover_name, HORIZONTAL_ALIGNMENT_LEFT, 100, 9, RetroTheme.AMBER)
	# Barra de señal.
	var bar := Rect2(6, 62, 92, 7)
	var col := RetroTheme.PHOSPHOR if _signal > 35.0 else Color("#ff5a4a")
	c.draw_rect(bar, Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _signal / 100.0, bar.size.y)), col)
	c.draw_rect(bar, col, false, 1.0)
	# Mini radar con barrido y eco de la Tierra.
	var center := Vector2(130, 41)
	var rad := 24.0
	c.draw_circle(center, rad, Color(0, 0.1, 0.05, 0.9))
	c.draw_arc(center, rad, 0.0, TAU, 32, RetroTheme.PHOSPHOR, 1.0)
	c.draw_arc(center, rad * 0.5, 0.0, TAU, 24, RetroTheme.PHOSPHOR_DIM, 1.0)
	var sweep := fmod(_t * 2.2, TAU)
	c.draw_line(center, center + Vector2(cos(sweep), sin(sweep)) * rad, RetroTheme.PHOSPHOR, 1.0)
	var blip := center + Vector2(cos(-0.8), sin(-0.8)) * rad * 0.7
	var since := fposmod(sweep - (-0.8 + TAU), TAU)
	var a := clampf(1.0 - since / PI, 0.15, 1.0) * (_signal / 100.0)
	c.draw_rect(Rect2(blip - Vector2(2, 2), Vector2(4, 4)), Color(RetroTheme.PHOSPHOR, a))


func _draw_static(c: DrawNode) -> void:
	if _static <= 0.0:
		return
	var n := int(5000 * _static)
	for i in n:
		var g := randf()
		c.draw_rect(Rect2(floorf(randf() * W), floorf(randf() * 360.0), 2, 1), Color(g, g, g, _static))


# =========================================================================
# Dibujo top-down compartido (PLACEHOLDERS: reemplazar por sprites)
# =========================================================================
func _draw_ground(c: CanvasItem, seed_value: int, scroll: float = 0.0) -> void:
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), SOIL)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 260:
		var x := rng.randf() * W
		var y := GAME_TOP + fposmod(rng.randf() * 244.0 + scroll, 244.0)
		c.draw_rect(Rect2(floorf(x), floorf(y), 2, 2), SOIL_DARK if i % 2 == 0 else SOIL_LIGHT)


## Rover MER visto desde arriba: plataforma de paneles solares, 6 ruedas y mástil.
func draw_rover_top(c: CanvasItem, pos: Vector2, angle: float, accent: Color, mast: float = 1.0, sunk: float = 0.0) -> void:
	c.draw_set_transform(pos, angle, Vector2(2, 2))
	for k in 3:
		var wx := -7.0 + k * 7.0
		c.draw_rect(Rect2(wx - 2, -11 + sunk, 4, 3), Color("#2a2a33"))
		c.draw_rect(Rect2(wx - 2, 8 - sunk, 4, 3), Color("#2a2a33"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-12, -8), Vector2(9, -8), Vector2(13, 0), Vector2(9, 8), Vector2(-12, 8)]), Color("#1e3f8f"))
	for k in 4:
		c.draw_rect(Rect2(-11 + k * 5, -7, 1, 14), Color("#3d6fd6"))
	c.draw_rect(Rect2(-4, -3, 9, 6), Color("#e3e6f0"))
	c.draw_rect(Rect2(-4, -3, 9, 1), accent)
	if mast > 0.0:
		c.draw_circle(Vector2(8, -4), 1.5 + mast * 1.5, Color("#c8ccd8"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _speaker_color(key: String) -> Color:
	return Color(String(data["speakers"][key]["color"]))


# =========================================================================
# Aviso inicial
# =========================================================================
func _disclaimer() -> void:
	_year.text = ""
	_objective.text = ""
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var l := _label(Vector2(40, 90), Vector2(560, 70), 15, RetroTheme.WHITE, ui_layer)
	l.text = data["disclaimer"]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := _label(Vector2(0, 200), Vector2(W, 14), 10, RetroTheme.PHOSPHOR, ui_layer)
	h.text = data["continue_hint"]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await wait(0.4)
	await wait_click_or_accept(4.0)


# =========================================================================
# ESCENA 1 — Llegada de Spirit: salida del módulo (3 pasos con clic)
# =========================================================================
func _scene_arrival(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var center := Vector2(320, 150)
	_mast = 0.0
	_antenna = 0.0
	_rover_pos = center
	_rover_angle = -PI * 0.5
	var earth_dir := Vector2(1, -0.6).normalized()
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2004)
		# Bolsas de aire desinfladas alrededor del módulo.
		for k in 6:
			var a := k * TAU / 6.0 + 0.3
			c.draw_circle(center + Vector2(cos(a), sin(a)) * 62.0, 12.0, Color("#d8ccb0"))
		# Módulo de aterrizaje: base triangular y 3 pétalos abiertos.
		var v := []
		for k in 3:
			var a := -PI * 0.5 + k * TAU / 3.0
			v.append(center + Vector2(cos(a), sin(a)) * 34.0)
		for k in 3:
			var p0: Vector2 = v[k]
			var p1: Vector2 = v[(k + 1) % 3]
			var out := ((p0 + p1) * 0.5 - center).normalized() * 50.0
			c.draw_colored_polygon(PackedVector2Array([p0, p1, (p0 + p1) * 0.5 + out]), Color("#c8ccd8"))
			c.draw_line(p0, (p0 + p1) * 0.5 + out, Color("#8a8ea6"), 1.0)
		c.draw_colored_polygon(PackedVector2Array(v), Color("#a7a9b4"))
		# Indicador de dirección de la Tierra.
		var ep := Vector2(600, 40)
		c.draw_circle(ep, 6.0, Color("#2e6bd1"))
		c.draw_string(ThemeDB.fallback_font, ep + Vector2(-40, 20), mm["earth_label"], HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("#80b4ff"))
		# Cono de visión de la cámara cuando el mástil está arriba.
		if _mast > 0.5:
			var fwd := Vector2(cos(_rover_angle), sin(_rover_angle))
			c.draw_colored_polygon(PackedVector2Array([_rover_pos, _rover_pos + fwd.rotated(-0.35) * 70.0, _rover_pos + fwd.rotated(0.35) * 70.0]), Color(1, 1, 0.8, 0.12 * _mast))
		draw_rover_top(c, _rover_pos, _rover_angle, _speaker_color("SPIRIT"), _mast)
		# Antena de alta ganancia apuntando a la Tierra.
		if _antenna > 0.0:
			var tip := _rover_pos + earth_dir * (12.0 + 20.0 * _antenna)
			c.draw_line(_rover_pos, tip, Color(0.5, 0.8, 1.0, 0.6 * _antenna), 1.0)
			c.draw_circle(tip, 2.0, Color("#80f2ff"))
	)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	var steps: Array = mm["steps"]
	# Paso 1: mástil.
	_mm_info.text = "1/3 · " + String(steps[0])
	var s1 := _spot(steps[0], 1, center + Vector2(26, -22))
	await s1.activated
	await _tween_prop("_mast", 1.0, 0.8)
	# Paso 2: antena.
	_mm_info.text = "2/3 · " + String(steps[1])
	var s2 := _spot(steps[1], 2, center + Vector2(30, 14))
	await s2.activated
	await _tween_prop("_antenna", 1.0, 0.8)
	_signal_target = 96.0
	# Paso 3: elegir ruta y bajar.
	_mm_info.text = "3/3 · " + String(steps[2])
	var routes: Array = mm["routes"]
	var exits: Array[Vector2] = []
	var spots: Array[Hotspot] = []
	for k in 3:
		var a := -PI * 0.5 + k * TAU / 3.0 + PI / 3.0
		exits.append(center + Vector2(cos(a), sin(a)) * 80.0)
		spots.append(_spot(routes[k], 3 + k, exits[k]))
	var chosen := -1
	while chosen < 0:
		await get_tree().process_frame
		for k in 3:
			if spots[k].used:
				chosen = k
	for s in spots:
		s.queue_free()
	_rover_angle = (exits[chosen] - center).angle()
	var tw := create_tween()
	tw.tween_property(self, "_rover_pos", exits[chosen] + (exits[chosen] - center).normalized() * 30.0, 1.6)
	await tw.finished
	_mm_title.text = ""
	_mm_info.text = ""
	await say(sc["outro"])


func _spot(text: String, num: int, pos: Vector2) -> Hotspot:
	var h := Hotspot.new(text, num, pos)
	world.add_child(h)
	return h


func _tween_prop(prop: String, value: Variant, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, prop, value, seconds)
	await tw.finished


# =========================================================================
# ESCENA 2A — Opportunity: cazador de blueberries
# =========================================================================
func _scene_blueberries(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var goal := int(mm["goal"])
	_wrong_text = String(mm["wrong"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2504
	_rocks.clear()
	_berries.clear()
	_berry_found.clear()
	for i in 26:
		_rocks.append(Vector3(rng.randf_range(30, 610), rng.randf_range(GAME_TOP + 40, GAME_BOTTOM - 16), rng.randf_range(6, 13)))
	while _berries.size() < 12:
		var p := Vector2(rng.randf_range(30, 610), rng.randf_range(GAME_TOP + 40, GAME_BOTTOM - 16))
		var ok := true
		for r: Vector3 in _rocks:
			if p.distance_to(Vector2(r.x, r.y)) < r.z + 8.0:
				ok = false
		if ok:
			_berries.append(p)
			_berry_found.append(false)
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2501)
		for r: Vector3 in _rocks:
			var pts := PackedVector2Array()
			for k in 6:
				var a := k * TAU / 6.0 + r.x
				pts.append(Vector2(r.x, r.y) + Vector2(cos(a), sin(a) * 0.8) * r.z * (0.8 + 0.25 * sin(r.y + k)))
			c.draw_colored_polygon(pts, ROCK)
			c.draw_rect(Rect2(r.x - r.z * 0.4, r.y - r.z * 0.5, 3, 2), Color("#7a5a44"))
		for i in _berries.size():
			var p := _berries[i]
			c.draw_circle(p, 3.0, Color("#5a6a8a"))
			c.draw_rect(Rect2(p - Vector2(1, 2), Vector2(1, 1)), Color("#a0b0d0"))
			if _berry_found[i]:
				c.draw_arc(p, 7.0, 0.0, TAU, 16, RetroTheme.PHOSPHOR, 1.0)
		draw_rover_top(c, Vector2(48, GAME_BOTTOM - 30), -PI * 0.25, _speaker_color("OPPORTUNITY"))
	)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	_mode = "berries"
	while _berry_found.count(true) < goal:
		_mm_info.text = "%s · %s: %d / %d" % [mm["instruction"], mm["counter"], _berry_found.count(true), goal]
		await get_tree().process_frame
	_mode = ""
	_mm_info.text = "%s: %d / %d" % [mm["counter"], goal, goal]
	await wait(0.5)
	await say(sc["outro"])


func _click_berries(pos: Vector2) -> void:
	for i in _berries.size():
		if not _berry_found[i] and pos.distance_to(_berries[i]) < 8.0:
			_berry_found[i] = true
			return
	for r: Vector3 in _rocks:
		if pos.distance_to(Vector2(r.x, r.y)) < r.z:
			toast(_wrong_text, Color("#ff9a7a"), 0.7)
			return


# =========================================================================
# ESCENA 2B — Spirit: rueda excavadora (arrastrar)
# =========================================================================
func _scene_silica(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var goal := float(mm["goal_ratio"])
	_cells.clear()
	var cols := int(_cell_rect.size.x / 10.0)
	var rows := int(_cell_rect.size.y / 10.0)
	for i in cols * rows:
		_cells.append(false)
	_wheel = Vector2(_cell_rect.position.x - 20, _cell_rect.get_center().y)
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2007)
		c.draw_rect(_cell_rect.grow(4), SOIL_DARK)
		for i in _cells.size():
			var cell := Rect2(_cell_rect.position + Vector2((i % cols) * 10, (i / cols) * 10), Vector2(10, 10))
			c.draw_rect(cell, Color("#f0f0e8") if _cells[i] else Color("#9a4426"))
		c.draw_rect(_cell_rect, Color(1, 1, 1, 0.25), false, 1.0)
		# Spirit detrás de su rueda trabada.
		draw_rover_top(c, _wheel + Vector2(-46, 0), 0.0, _speaker_color("SPIRIT"))
		# La rueda que se arrastra (vista desde arriba, con banda de rodadura).
		c.draw_rect(Rect2(_wheel - Vector2(9, 14), Vector2(18, 28)), Color("#2a2a33"))
		for k in 6:
			c.draw_rect(Rect2(_wheel + Vector2(-9, -13 + k * 5), Vector2(18, 2)), Color("#4a4a55"))
		c.draw_arc(_wheel, 20.0, 0.0, TAU, 24, Color(RetroTheme.AMBER, 0.5 + 0.3 * sin(c.t * 4.0)), 1.0)
	)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	_mode = "wheel"
	while true:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		var move := Vector2(Input.get_axis("rotate_left", "rotate_right"), Input.get_axis("thrust", "move_down"))
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not dialog.is_active():
			var target := get_local_mouse_position()
			if target.distance_to(_wheel) > 2.0:
				move = (target - _wheel).normalized()
		_wheel += move * 150.0 * dt
		_wheel.x = clampf(_wheel.x, 60.0, W - 20.0)
		_wheel.y = clampf(_wheel.y, GAME_TOP + 40.0, GAME_BOTTOM - 20.0)
		# Revela las celdas que toca la rueda.
		for i in _cells.size():
			if not _cells[i]:
				var cc := _cell_rect.position + Vector2((i % cols) * 10 + 5, (i / cols) * 10 + 5)
				if absf(cc.x - _wheel.x) < 12.0 and absf(cc.y - _wheel.y) < 16.0:
					_cells[i] = true
		var ratio := float(_cells.count(true)) / _cells.size()
		_mm_info.text = "%s · %s: %d%%" % [mm["instruction"], mm["counter"], int(ratio * 100.0)]
		if ratio >= goal:
			break
	_mode = ""
	await wait(0.4)
	await say(sc["outro"])


# =========================================================================
# ESCENA 3A — Invierno de Spirit (opcional): repartir energía
# =========================================================================
func _scene_winter(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var days := int(mm["days"])
	var energy := [100.0, 70.0, 45.0, 25.0]
	_day = 0
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2009)
		# Arena suave de "Troy" con Spirit atrapado.
		c.draw_set_transform(Vector2(320, 112), 0.0, Vector2(1.6, 1.0))
		c.draw_circle(Vector2.ZERO, 50.0, Color("#d89a6a"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rover_top(c, Vector2(320, 112), -0.2, _speaker_color("SPIRIT"), 1.0, 2.0)
		# El Sol cada vez más bajo y escarcha que aumenta.
		var k := float(_day) / maxf(1.0, days)
		c.draw_circle(Vector2(560, lerpf(60.0, 230.0, k)), 10.0, Color("#fff4c0"))
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(0.7, 0.8, 1.0, k * 0.25))
	)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	_mm_info.text = mm["instruction"]
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 160)   # sube para que el botón no quede tapado por la barra inferior
	panel.custom_minimum_size = Vector2(340, 0)
	ui_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 11)
	box.add_child(info)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.value = 50
	slider.custom_minimum_size = Vector2(320, 16)
	box.add_child(slider)
	var confirm := Button.new()
	confirm.text = mm["confirm"]
	box.add_child(confirm)
	slider.grab_focus()
	while _day < days:
		var e: float = energy[mini(_day, energy.size() - 1)]
		info.text = tr("%s %d/%d · ENERGÍA: %d%%\n%s: %d%%   ·   %s: %d%%") % [
			mm["day"], _day + 1, days, int(e), mm["heaters"], int(slider.value * e / 100.0),
			mm["instruments"], int((100.0 - slider.value) * e / 100.0)]
		await get_tree().process_frame
		# A/D mueven el slider (las flechas ya las maneja el propio slider mediante ui_left/ui_right).
		if not Input.is_action_just_pressed("ui_left") and not Input.is_action_just_pressed("ui_right"):
			if Input.is_action_just_pressed("rotate_left"):
				slider.value -= slider.step
			elif Input.is_action_just_pressed("rotate_right"):
				slider.value += slider.step
		var by_key := slider.has_focus() and Input.is_action_just_pressed("ui_accept")
		if _confirmed(confirm) or by_key:
			_day += 1
			_signal_target = maxf(10.0, _signal_target - 15.0)
			slider.grab_focus()   # el botón toma el foco al pulsarlo; lo devolvemos al slider
	panel.queue_free()
	# Aunque se haga bien, el invierno llega igual: la señal cae a 0 y queda la estática.
	var tw := create_tween()
	tw.tween_property(self, "_signal_target", 0.0, 2.5)
	await tw.finished
	_signal = 0.0
	var tw2 := create_tween()
	tw2.tween_property(self, "_static", 0.9, 1.0)
	await tw2.finished
	await toast(String(mm["final_text"]), RetroTheme.WHITE, 2.8)
	_static = 0.0


var _confirm_flag := false


func _confirmed(btn: Button) -> bool:
	if not btn.pressed.is_connected(_on_confirm_pressed):
		btn.pressed.connect(_on_confirm_pressed)
	if _confirm_flag:
		_confirm_flag = false
		return true
	return false


func _on_confirm_pressed() -> void:
	_confirm_flag = true


# =========================================================================
# ESCENA 3B — Opportunity sigue: rumbo a Endeavour + emparejar hallazgos
# =========================================================================
func _scene_endeavour(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var end_km := float(mm["end_km"])
	_rover_pos = Vector2(320, GAME_BOTTOM - 40)
	_craters.clear()
	_scroll = 0.0
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2010, _scroll)
		for cr: Vector3 in _craters:
			c.draw_circle(Vector2(cr.x, cr.y), cr.z, SOIL_DARK)
			c.draw_arc(Vector2(cr.x, cr.y), cr.z, 0.0, TAU, 20, SOIL_LIGHT, 2.0)
		# El borde del cráter Endeavour aparece al final del trayecto.
		var k := clampf((_distance - (end_km - 1.5)) / 1.5, 0.0, 1.0)
		if k > 0.0:
			c.draw_arc(Vector2(320, GAME_TOP - 400 + k * 330), 420.0, 0.0, PI, 64, Color("#e09a62"), 6.0)
		draw_rover_top(c, _rover_pos, -PI * 0.5, _speaker_color("OPPORTUNITY"))
	)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	_mm_info.text = mm["instruction"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn := 0.0
	var rate := (end_km - _distance) / 36.0   # km por segundo de juego (tiempo muy acelerado)
	while _distance < end_km:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		_hit_cooldown = maxf(0.0, _hit_cooldown - dt)
		var dir := Input.get_axis("rotate_left", "rotate_right")
		_rover_pos.x = clampf(_rover_pos.x + dir * 150.0 * dt, 40.0, W - 40.0)
		var speed := 0.0 if _hit_cooldown > 0.0 else 1.0
		_scroll += 70.0 * dt * speed
		_distance = minf(end_km, _distance + rate * dt * speed)
		spawn -= dt * speed
		if spawn <= 0.0:
			spawn = rng.randf_range(0.6, 1.2)
			_craters.append(Vector3(rng.randf_range(40, W - 40), GAME_TOP - 20, rng.randf_range(12, 26)))
		var keep: Array[Vector3] = []
		for cr: Vector3 in _craters:
			var v := cr
			v.y += 70.0 * dt * speed
			if _hit_cooldown <= 0.0 and Vector2(v.x, v.y).distance_to(_rover_pos) < v.z + 14.0:
				_hit_cooldown = 1.0
				toast(String(mm["crater_hit"]), Color("#ff9a7a"), 0.8)
				continue
			if v.y < GAME_BOTTOM + 30:
				keep.append(v)
		_craters = keep
	_craters.clear()
	await _matching(mm)
	_mm_title.text = ""
	_mm_info.text = ""


func _matching(mm: Dictionary) -> void:
	_mm_title.text = mm["match_title"]
	_mm_info.text = ""
	var panel := PanelContainer.new()
	panel.position = Vector2(30, GAME_TOP + 40)
	panel.custom_minimum_size = Vector2(580, 0)
	ui_layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var left_col := VBoxContainer.new()
	var right_col := VBoxContainer.new()
	row.add_child(left_col)
	row.add_child(right_col)
	var lefts: Array = mm["match_left"]
	var rights: Array = mm["match_right"]
	# Los de la derecha van en otro orden (barajado, nunca el mismo orden que la izquierda).
	var order: Array = range(lefts.size())
	while lefts.size() > 1 and order == range(lefts.size()):
		order.shuffle()
	var left_btns: Array[Button] = []
	var right_btns: Array[Button] = []
	for i in lefts.size():
		var b := Button.new()
		b.text = lefts[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(200, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left_col.add_child(b)
		left_btns.append(b)
	for j in order.size():
		var b := Button.new()
		b.text = rights[order[j]]
		b.custom_minimum_size = Vector2(350, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_meta("pair", order[j])
		right_col.add_child(b)
		right_btns.append(b)
	left_btns[0].grab_focus()
	var matched := 0
	_mode = "match"
	_match_left = left_btns
	_match_picked = -1
	_match_answers.clear()
	for i in left_btns.size():
		left_btns[i].toggled.connect(_on_match_left.bind(i))
	for b in right_btns:
		b.pressed.connect(_on_match_right.bind(int(b.get_meta("pair"))))
	while matched < lefts.size():
		await get_tree().process_frame
		if _match_answers.is_empty():
			continue
		var pair: int = _match_answers.pop_front()
		if _match_picked < 0:
			await toast(String(mm["match_pick"]), RetroTheme.WHITE, 0.7)
			continue
		if pair == _match_picked:
			var lb := left_btns[_match_picked]
			lb.disabled = true
			lb.set_pressed_no_signal(false)
			for b in right_btns:
				if int(b.get_meta("pair")) == pair:
					b.disabled = true
			matched += 1
			_match_picked = -1
			await toast(String(mm["match_ok"]), RetroTheme.PHOSPHOR, 0.7)
		else:
			await toast(String(mm["match_bad"]), Color("#ff9a7a"), 0.8)
			mission_hud.remind()
	_mode = ""
	await wait(0.5)
	panel.queue_free()


var _match_left: Array[Button] = []
var _match_picked := -1
var _match_answers: Array[int] = []


func _on_match_left(on: bool, i: int) -> void:
	if not on:
		return
	_match_picked = i
	for k in _match_left.size():
		if k != i:
			_match_left[k].set_pressed_no_signal(false)


func _on_match_right(pair: int) -> void:
	_match_answers.append(pair)


# =========================================================================
# ESCENA 4 — La tormenta: completar el panorama antes del polvo
# =========================================================================
func _scene_storm(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	var shots := int(mm["shots"])
	var base_dust_time := float(mm["dust_seconds"])
	var dust_time := base_dust_time
	var fails := 0
	_layer(func(c: DrawNode) -> void:
		_draw_ground(c, 2018)
		draw_rover_top(c, Vector2(320, 200), -PI * 0.5, _speaker_color("OPPORTUNITY"), 1.0)
		# Tira del panorama: cada toma muestra un trozo del horizonte.
		for i in _shots_taken.size():
			var r := _shot_rect(i, shots)
			c.draw_rect(r, Color(0, 0, 0, 0.6))
			if _shots_taken[i]:
				c.draw_rect(r, Color("#c98a5e"))
				var base := r.position.y + r.size.y * 0.65
				for x in int(r.size.x):
					var gx := r.position.x + x
					var h := 6.0 + 5.0 * sin(gx * 0.05) + 3.0 * sin(gx * 0.17)
					c.draw_rect(Rect2(gx, base - h, 1, h + r.size.y * 0.35), Color("#8c3a1e"))
			var target := i == _shot_target and fmod(c.t, 0.5) < 0.35
			c.draw_rect(r, RetroTheme.AMBER if target else Color(1, 1, 1, 0.4), false, 2.0 if target else 1.0)
		if _flash > 0.0:
			c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 1, 1, _flash * 0.4))
		# La tormenta oscurece el cielo y tapa la luz.
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(0.35, 0.18, 0.08, _dust * 0.65))
		for k in int(_dust * 160):
			c.draw_rect(Rect2(fmod(k * 53.0 + c.t * 90.0, W), GAME_TOP + fmod(k * 29.0, 244.0), 3, 1), Color(0.8, 0.55, 0.35, _dust * 0.8))
		MissionBase.draw_bar(c, Rect2(440, GAME_TOP + 62, 180, 8), _dust, Color("#d08a4a"), String(mm["dust_label"]))
		c.draw_string(ThemeDB.fallback_font, Vector2(8, GAME_TOP + 134), String(mm["note"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.75))
	)
	_shots_taken.clear()
	for i in shots:
		_shots_taken.append(false)
	await say(sc["intro"])
	_mm_title.text = mm["title"]
	while true:
		_dust = 0.0
		for i in shots:
			_shots_taken[i] = false
		_pick_shot_target()
		_mode = "storm"
		while _shots_taken.count(false) > 0 and _dust < 1.0:
			_mm_info.text = "%s · %s: %d / %d" % [mm["instruction"], mm["shots_label"], _shots_taken.count(true), shots]
			await get_tree().process_frame
			_dust = minf(1.0, _dust + get_process_delta_time() / dust_time)
		_mode = ""
		if _shots_taken.count(false) == 0:
			break
		await toast(String(mm["fail"]), Color("#ff9a7a"), 1.6)
		mission_hud.remind()
		# Ayuda progresiva: cada fallo da 25 % más de tiempo (máximo el doble).
		fails += 1
		dust_time = base_dust_time * minf(2.0, 1.0 + 0.25 * fails)
		if fails == 2:
			await toast(String(mm["assist"]), RetroTheme.PHOSPHOR, 1.8)
	_shot_target = -1
	_mm_info.text = "%s: %d / %d" % [mm["shots_label"], shots, shots]
	await say(sc["outro"])
	# La señal cae a 0, estática y fundido a negro.
	var tw := create_tween()
	tw.tween_property(self, "_signal_target", 0.0, 2.5)
	tw.parallel().tween_property(self, "_dust", 1.0, 2.5)
	await tw.finished
	_signal = 0.0
	var tw2 := create_tween()
	tw2.tween_property(self, "_static", 1.0, 1.0)
	tw2.tween_interval(1.0)
	tw2.tween_property(_fade, "modulate:a", 1.0, 1.2)
	await tw2.finished
	_static = 0.0


func _shot_rect(i: int, total: int) -> Rect2:
	var w := 64.0
	var gap := (W - 40.0 - w * total) / maxf(1.0, total - 1)
	return Rect2(20 + i * (w + gap), GAME_TOP + 70, w, 48)


func _pick_shot_target() -> void:
	var free: Array[int] = []
	for i in _shots_taken.size():
		if not _shots_taken[i]:
			free.append(i)
	_shot_target = free[randi() % free.size()] if not free.is_empty() else -1


func _take_shot(index: int) -> void:
	if index != _shot_target or index < 0:
		return
	_shots_taken[index] = true
	_flash = 1.0
	_pick_shot_target()


# =========================================================================
# Pantalla de cierre
# =========================================================================
func _closing() -> void:
	_clear()
	var cl: Dictionary = data["closing"]
	_year.text = ""
	_objective.text = ""
	_fade.modulate.a = 0.0
	_signal_target = 0.0
	_signal = 0.0
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var title := _label(Vector2(20, 50), Vector2(600, 24), 16, RetroTheme.AMBER, ui_layer)
	title.text = cl["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 100.0
	for st in cl["stats"]:
		var l := _label(Vector2(40, y), Vector2(560, 18), 12, RetroTheme.WHITE, ui_layer)
		l.text = "%s · %s" % [st[0], st[1]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		y += 26.0
	if bool(cl.get("epilogue_enabled", false)):
		var ep := _label(Vector2(40, y + 14), Vector2(560, 18), 11, RetroTheme.PHOSPHOR, ui_layer)
		ep.text = cl["epilogue"]
		ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := _label(Vector2(0, 222), Vector2(W, 14), 10, Color("#80f2ff"), ui_layer)
	h.text = cl["button"]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await wait(0.6)
	await wait_click_or_accept()


# =========================================================================
# Entrada: minijuegos, pausa y debug
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_toggle_pause()
		return
	if get_tree().paused:
		return
	if debug_mode and OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_F1 and k <= KEY_F8:
			GameManager.set_start_phase(k - KEY_F1 + 1)
			SceneTransition.change_scene(scene_file_path, 0.2)
			return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	match _mode:
		"continue":
			if click or event.is_action_pressed("ui_accept"):
				_mode = ""
		"berries":
			if click:
				_click_berries(get_local_mouse_position())
		"storm":
			if click:
				for i in _shots_taken.size():
					if _shot_rect(i, _shots_taken.size()).has_point(get_local_mouse_position()):
						_take_shot(i)
			elif event.is_action_pressed("ui_accept"):
				_take_shot(_shot_target)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		(_pause_panel.get_child(0).get_child(1) as Button).grab_focus()
