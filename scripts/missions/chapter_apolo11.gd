extends Control
## CAPÍTULO "APOLLO 11: EAGLE" (julio de 1969). Vista 2D, pixel art placeholder, estilo sobrio (grises y dorados).
##
## El jugador es un controlador de vuelo de Houston (personaje imaginado). El recurso que une todo es el
## COMBUSTIBLE del motor (y el OXÍGENO en la superficie). Textos y valores en data/dialogos/apolo11.json.
## Se lanza desde el selector de destinos y emite chapter_finished al terminar.
##
## Fases:  0 Órbita lunar (cinemática pendiente) -> 1 Descenso (elegir zona + estabilizar el Eagle)
##         -> 2 Primer paso (cinemática pendiente + 4 acciones con el cursor) -> 3 Recolección de rocas
##         (vista aérea) -> 4 Despegue (medidor de potencia + corrección de ángulo) -> 5 Acoplamiento
##         (cinemática pendiente + epílogo).
## HUD: FECHA arriba a la izquierda, OBJETIVO arriba a la derecha; abajo, diálogo (con traducciones
##      pequeñas de las frases en inglés) y panel de telemetría con la barra de COMBUSTIBLE / OXÍGENO.
## Debug (solo en builds de depuración): F1-F6 saltan a cada fase.

signal chapter_finished

const DATA_PATH := "res://data/dialogos/apolo11.json"
const MISSION_ID := "apolo11"
const W := 640.0
const GAME_TOP := 22.0
const GAME_BOTTOM := 266.0
const GOLD := Color("#d8b050")
const GRAY := Color("#b8bcc8")
const GRAY_DIM := Color("#7a7e8c")
const RED := Color("#ff5a4a")
const REGOLITH := Color("#6a6a74")
const REGOLITH_DARK := Color("#4a4a56")
const REGOLITH_LIGHT := Color("#8e8e9a")
const FOIL := Color("#d8a838")
const MC := Vector2(320, 146)          # el Eagle visto desde arriba (centro del mapa de recolección)

## Si es true, al terminar marca la misión como completada y vuelve al selector.
@export var auto_return := true
@export var debug_mode := true

var data: Dictionary = {}
var world: Node2D
var ui_layer: Control
var dialog: TransmissionDialog
var mission_hud: MissionHUD

var _date_tag: Label
var _date_val: Label
var _obj_tag: Label
var _obj_val: Label
var _mm_title: Label
var _mm_info: Label
var _toast: Label
var _hud_draw: Control
var _pause_panel: PanelContainer
var _fade: ColorRect

var _fuel := 100.0
var _oxy := 100.0
var _tele: Array = []                  # líneas de telemetría: [[etiqueta, valor], ...]
var _tele_fn: Callable = Callable()    # si es válida, se llama cada frame para rellenar _tele
var _bar_name := ""
var _bar_val := 100.0
var _bar_show := false
var _bar_alert := false
var _clock_s := 0.0
var _countdown := 0.0
var _count_on := false
var _t := 0.0
var _shake := 0.0
var _flash := 0.0
var _mode := ""
var _retry := false

# Descenso
var _zones: Array = []
var _reticle := Vector2(320, 150)
var _picked: Dictionary = {}
var _pick_msg := ""
var _terrain: PackedVector2Array = PackedVector2Array()
var _lx := 320.0
var _lalt := 1000.0
var _lvx := 0.0
var _lvy := 0.0
var _lang := 0.0
var _lthrust := false
var _lrot := 0.0
var _ldust := 0.0
var _boom := -1.0
var _boom_pos := Vector2.ZERO
var _ship_hidden := false
var _fuel_warned := false
var _low_label := ""
var _pred_x := 0.0
# Primer paso
var _flag_t := 0.0
var _easep_t := 0.0
var _acts_done := 0
var _exp_done := 0
var _action_queue: Array = []
# Recolección
var _astro := MC + Vector2(0, 30)
var _astro_dir := Vector2.DOWN
var _rocks: Array = []
var _kg := 0.0
var _steps: Array = []
var _returning := false
var _rocks_cfg: Dictionary = {}
# Despegue
var _pm_val := 0.0
var _pm_t := 0.0
var _pm_zone := Vector2(0.66, 0.80)
var _pm_run := false
var _pm_stop := false
var _ang_err := 0.0
var _liftoff_t := -1.0
var _asc_alt := 0.0
var _asc_ang := 0.0
var _asc_target := 0.0
var _asc_band := 9.0
var _asc_progress := 0.0
var _asc_run := false
var _orbit_ok := false
var _asc_hint := ""


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
	var start := GameManager.consume_start_phase()   # 0 = normal; 1-6 = salta a esa fase
	var scenes: Array = data["scenes"]
	if start == 0:
		await mission_hud.show_briefing()
		await _disclaimer()
	else:
		mission_hud.minimize_now()
	var first := maxi(start - 1, 0)
	for i in range(first, scenes.size()):
		await _run_scene(scenes[i], i, start > 0 and i == first)
	mission_hud.mark_all_done()
	chapter_finished.emit()
	if auto_return:
		GameManager.mark_completed(MISSION_ID)
		GameManager.go_to_planet_select()


func _run_scene(sc: Dictionary, index: int, jumped: bool) -> void:
	_clear()
	var id := String(sc["id"])
	if jumped:
		_fuel = float(sc.get("fuel", _fuel))
	_retry = false
	_set_date(String(sc["date"]))
	_set_objective(String(sc["objective"]))
	await _banner(String(sc["title"]))
	mission_hud.set_phase(index, String(sc["title"]), String(sc["objective"]))
	match id:
		"orbita": await _scene_orbit(sc)
		"descenso": await _scene_descent(sc)
		"primer_paso": await _scene_first_step(sc)
		"rocas": await _scene_rocks(sc)
		"despegue": await _scene_ascent(sc)
		"acoplamiento": await _scene_docking(sc)


func say(lines: Array) -> void:
	await dialog.play(lines)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## Espera ENTER / clic o, si auto_seconds > 0, ese tiempo (lo que ocurra primero).
func wait_click_or_accept(auto_seconds: float = 0.0) -> void:
	_mode = "continue"
	var left := auto_seconds
	while _mode == "continue":
		await get_tree().process_frame
		if auto_seconds > 0.0 and not get_tree().paused:
			left -= get_process_delta_time()
			if left <= 0.0:
				_mode = ""


# =========================================================================
# Construcción del HUD
# =========================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#050508")
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

	# Barra superior: FECHA (izquierda) y OBJETIVO (derecha). Etiquetas en gris, datos en dorado.
	var top := ColorRect.new()
	top.color = Color(0.05, 0.05, 0.07, 0.88)
	top.size = Vector2(W, GAME_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_date_tag = _label(Vector2(8, 5), Vector2(40, 14), 10, GRAY)
	_date_tag.text = String(data["hud"]["date"])
	_date_val = _label(Vector2(48, 3), Vector2(200, 16), 13, GOLD)
	_obj_tag = _label(Vector2(300, 5), Vector2(80, 14), 10, GRAY)
	_obj_tag.text = String(data["hud"]["objective"])
	_obj_val = _label(Vector2(200, 4), Vector2(432, 16), 11, GOLD)
	_obj_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_date_tag.hide()
	_obj_tag.hide()

	# Título e instrucción de la fase.
	_mm_title = _label(Vector2(8, GAME_TOP + 22), Vector2(420, 14), 11, GOLD)
	_mm_info = _label(Vector2(8, GAME_TOP + 36), Vector2(620, 14), 10, GRAY)
	for l in [_mm_title, _mm_info]:
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
		l.add_theme_constant_override("outline_size", 4)
	_toast = _label(Vector2(0, 100), Vector2(W, 56), 17, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.hide()

	# Franja inferior: diálogo (izquierda) + telemetría (derecha).
	var bottom := ColorRect.new()
	bottom.color = Color(0.04, 0.04, 0.06, 0.94)
	bottom.position = Vector2(0, GAME_BOTTOM)
	bottom.size = Vector2(W, 360 - GAME_BOTTOM)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	dialog = TransmissionDialog.new()
	dialog.position = Vector2(8, GAME_BOTTOM + 6)
	dialog.size = Vector2(458, 82)
	dialog.speakers = data["speakers"]
	dialog.transit_text = data["hud"]["in_transit"]
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

	# HUD común: ficha de misión, botones C/O/I, teclas y pistas de Control.
	mission_hud = MissionHUD.new()
	add_child(mission_hud)
	mission_hud.badge_pos = Vector2(8, GAME_TOP + 3)
	mission_hud.buttons_pos = Vector2(W - 6, GAME_TOP + 3)
	mission_hud.reminder_pos = Vector2(8, GAME_TOP + 54)
	mission_hud.briefing_auto_seconds = 7.0
	mission_hud.briefing_area = Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP)
	mission_hud.keys_pos = Vector2(8, GAME_BOTTOM - 17)
	mission_hud.busy_check = func() -> bool: return dialog.is_active() or _toast.visible
	mission_hud.reminder_callback = func(t: String) -> void: dialog.show_hint("CONTROL", t)
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
	t.add_theme_color_override("font_color", GOLD)
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


func _set_date(text: String) -> void:
	_date_tag.visible = text != ""
	_date_val.text = text


func _set_objective(text: String) -> void:
	_obj_val.text = text
	_obj_tag.visible = text != ""
	if text != "":
		var f := ThemeDB.fallback_font
		var wv := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var wt := f.get_string_size(_obj_tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_obj_tag.position.x = 632.0 - wv - wt - 8.0


func _clear() -> void:
	_mode = ""
	_mm_title.text = ""
	_mm_info.text = ""
	_tele = []
	_tele_fn = Callable()
	_bar_show = false
	_bar_alert = false
	_count_on = false
	_shake = 0.0
	world.position = Vector2.ZERO
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


func _stars(count: int = 130) -> Starfield:
	var s := Starfield.new()
	s.star_count = count
	world.add_child(s)
	return s


func _banner(text: String) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", GOLD)
	_toast.modulate.a = 0.0
	_toast.show()
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	await tw.finished
	_toast.hide()


func toast(text: String, color: Color = GOLD, seconds: float = 0.9) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.show()
	await wait(seconds)
	_toast.hide()
	_toast.add_theme_color_override("font_color", GOLD)


func _axis_keys(neg_a: Key, neg_b: Key, pos_a: Key, pos_b: Key) -> float:
	var n := 1.0 if (Input.is_physical_key_pressed(neg_a) or Input.is_physical_key_pressed(neg_b)) else 0.0
	var p := 1.0 if (Input.is_physical_key_pressed(pos_a) or Input.is_physical_key_pressed(pos_b)) else 0.0
	return p - n


func _fmt_clock(secs: float) -> String:
	var s := maxi(0, int(secs))
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _num(v: float, decimals: int = 1) -> String:
	return ("%.*f" % [decimals, v]).replace(".", ",")


# =========================================================================
# HUD dinámico: telemetría y barra de combustible / oxígeno
# =========================================================================
func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO
	if _count_on:
		_countdown = maxf(0.0, _countdown - delta * 16.0)
	if _tele_fn.is_valid():
		_tele = _tele_fn.call()
	_hud_draw.queue_redraw()


func _draw_data_panel() -> void:
	var c := _hud_draw
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.03, 0.03, 0.05, 0.94))
	c.draw_rect(r, GRAY_DIM, false, 1.0)
	var font := ThemeDB.fallback_font
	var y := 13.0
	for row in _tele:
		var lab := String(row[0])
		var val := String(row[1])
		var vcol: Color = row[2] if row.size() > 2 else GOLD
		c.draw_string(font, Vector2(6, y), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GRAY_DIM)
		var lw := font.get_string_size(lab + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		c.draw_string(font, Vector2(6 + lw, y), val, HORIZONTAL_ALIGNMENT_LEFT, 148.0 - lw, 9, vcol)
		y += 13.0
	if _bar_show:
		var alert := _bar_alert and int(_t * 5.0) % 2 == 0
		var col := RED if (_bar_val <= 20.0 or alert) else GOLD
		c.draw_string(font, Vector2(6, 56), _bar_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GRAY)
		var bar := Rect2(6, 60, 148, 8)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_bar_val, 0.0, 100.0) / 100.0, bar.size.y)), col)
		c.draw_rect(bar, col, false, 1.0)
		c.draw_string(font, Vector2(6, 79), "%d%%" % int(round(_bar_val)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


# =========================================================================
# Aviso inicial y pantalla de cinemática pendiente
# =========================================================================
func _disclaimer() -> void:
	_set_date("")
	_set_objective("")
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var l := _label(Vector2(40, 90), Vector2(560, 70), 15, GRAY, ui_layer)
	l.text = data["disclaimer"]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := _label(Vector2(0, 200), Vector2(W, 14), 10, GOLD, ui_layer)
	h.text = data["continue_hint"]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await wait(0.4)
	await wait_click_or_accept(4.0)
	panel.queue_free()
	h.queue_free()
	l.queue_free()


## Marcador de posición para las cinemáticas que todavía no existen: solo un mensaje en pantalla.
func _cinematic_pending(_tag: String) -> void:
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var l := _label(Vector2(0, 100), Vector2(W, 30), 22, GOLD, ui_layer)
	l.text = String(data["cinematic_pending"])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await wait(0.3)
	await wait_click_or_accept(3.0)
	panel.queue_free()
	l.queue_free()


# =========================================================================
# Dibujo compartido (PLACEHOLDERS: reemplazar por sprites)
# =========================================================================
## Módulo lunar Eagle: etapa de descenso dorada, etapa de ascenso gris, patas y ventanas.
func _draw_eagle(c: CanvasItem, pos: Vector2, ang: float, s: float, flame: float = 0.0, legs: bool = true, ascent_only: bool = false) -> void:
	c.draw_set_transform(pos, ang, Vector2(s, s))
	if not ascent_only:
		if legs:
			c.draw_line(Vector2(-6, 2), Vector2(-12, 11), GRAY, 1.0)
			c.draw_line(Vector2(6, 2), Vector2(12, 11), GRAY, 1.0)
			c.draw_rect(Rect2(-14, 11, 5, 1), GRAY)
			c.draw_rect(Rect2(9, 11, 5, 1), GRAY)
		c.draw_rect(Rect2(-8, -1, 16, 8), FOIL)                          # etapa de descenso
		c.draw_rect(Rect2(-8, -1, 16, 1), FOIL.lightened(0.3))
		c.draw_rect(Rect2(-8, 5, 16, 2), FOIL.darkened(0.3))
		if flame > 0.0:
			c.draw_colored_polygon(PackedVector2Array([Vector2(-3, 7), Vector2(3, 7), Vector2(0, 7.0 + 8.0 * flame + 2.0 * sin(_t * 40.0))]), Color("#ffb347"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-1.5, 7), Vector2(1.5, 7), Vector2(0, 7.0 + 4.0 * flame)]), Color("#fff4c0"))
	c.draw_rect(Rect2(-6, -9, 12, 8), Color("#b0b4c0"))                  # etapa de ascenso
	c.draw_rect(Rect2(-6, -9, 12, 1), Color("#d8dce8"))
	c.draw_rect(Rect2(-3, -7, 3, 3), Color("#2a3048"))                   # ventana
	c.draw_line(Vector2(0, -9), Vector2(0, -13), GRAY, 1.0)              # antena
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Astronauta de pie (vista lateral).
func _draw_astro_side(c: CanvasItem, pos: Vector2, s: float, arm_up: float = 0.0) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(s, s))
	c.draw_rect(Rect2(-3, -6, 2, 6), Color("#e8e8f0"))
	c.draw_rect(Rect2(1, -6, 2, 6), Color("#e8e8f0"))
	c.draw_rect(Rect2(-4, -14, 8, 9), Color("#f0f0f8"))
	c.draw_rect(Rect2(-6, -13, 2, 7), Color("#c8ccd8"))                  # mochila
	c.draw_circle(Vector2(0, -17), 4.0, Color("#f0f0f8"))
	c.draw_rect(Rect2(-2, -19, 5, 4), GOLD)                              # visor dorado
	c.draw_line(Vector2(3, -12), Vector2(6, -12 + arm_up * -6.0), Color("#f0f0f8"), 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _fill_surface(c: CanvasItem, y_top: float, seed_v: int) -> void:
	c.draw_rect(Rect2(0, y_top, W, GAME_BOTTOM - y_top + 4), REGOLITH)
	c.draw_rect(Rect2(0, y_top, W, 2), REGOLITH_LIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 70:
		var x := rng.randf() * W
		var y := y_top + 4.0 + rng.randf() * (GAME_BOTTOM - y_top)
		c.draw_rect(Rect2(floorf(x), floorf(y), 2, 1), REGOLITH_DARK if i % 2 == 0 else REGOLITH_LIGHT)


# =========================================================================
# FASE 0 · Órbita lunar (cinemática pendiente + diálogos)
# =========================================================================
func _scene_orbit(sc: Dictionary) -> void:
	_fuel = float(sc["fuel"])
	_bar_name = String(data["hud"]["fuel"])
	_bar_show = true
	_bar_val = _fuel
	_countdown = float(sc["countdown_start"])
	_count_on = true
	_tele_fn = func() -> Array:
		return [["ALTITUD", "%s KM" % _num(14.5)], ["T. HASTA DESCENSO", _fmt_clock(_countdown)]]
	_stars()
	_layer(func(c: DrawNode) -> void:
		# La Luna abajo y la Columbia orbitando.
		c.draw_circle(Vector2(320, 520), 332.0, Color(0.5, 0.5, 0.56, 0.18))
		c.draw_circle(Vector2(320, 520), 328.0, Color("#5a5a66"))
		for k in 9:
			var cp := Vector2(320.0 + (k - 4) * 62.0, 205.0 + fmod(k * 37.0, 40.0))
			c.draw_circle(cp, 6.0 + fmod(k * 7.0, 9.0), REGOLITH_DARK)
		c.draw_circle(Vector2(560, 70), 9.0, Color("#2e6bd1"))                    # la Tierra
		c.draw_circle(Vector2(557, 67), 3.0, Color("#3f9a52"))
		var cx := 320.0 + sin(c.t * 0.35) * 190.0
		var cy := 128.0 + cos(c.t * 0.35) * 8.0
		c.draw_rect(Rect2(cx - 14, cy - 5, 22, 10), Color("#c8ccd8"))             # módulo de servicio
		c.draw_rect(Rect2(cx - 14, cy - 5, 22, 2), Color("#e8ecf8"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 8, cy - 5), Vector2(cx + 8, cy + 5), Vector2(cx + 20, cy)]), FOIL)   # módulo de comando
		c.draw_rect(Rect2(cx - 18, cy - 2, 4, 4), GRAY_DIM)
	)
	await _cinematic_pending(String(sc.get("cinematic_tag", "")))
	await say(sc["dialog"])
	_count_on = false


# =========================================================================
# FASE 1 · Descenso y aterrizaje
# =========================================================================
func _scene_descent(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	_zones = sc["zones"]
	_build_terrain()
	if not _retry:
		await say(sc["intro"])
	_mm_title.text = String(mm["title"])
	_bar_name = String(data["hud"]["fuel"])
	_bar_show = true
	while true:
		_fuel = 100.0
		_bar_val = _fuel
		_bar_alert = false
		var zone := await _pick_zone(mm)
		var ok := await _fly_descent(mm, zone)
		if ok:
			break
		_retry = true
		await toast(String(mm["retry"]), GRAY, 1.8)
	_tele_fn = Callable()
	await toast(String(mm["landed"]), GOLD, 1.8)
	await say(sc["outro"])


func _zone_at(x: float) -> Dictionary:
	for z in _zones:
		if absf(x - float(z["x"])) <= float(z["w"]) * 0.5 - 4.0:
			return z
	return {}


func _zone_safe_at(x: float) -> bool:
	var z := _zone_at(x)
	return not z.is_empty() and bool(z["safe"])


func _terrain_y(x: float) -> float:
	var y := 236.0 + sin(x * 0.021) * 3.0 + sin(x * 0.057 + 1.0) * 2.0
	for z in _zones:
		var d := absf(x - float(z["x"])) - float(z["w"]) * 0.5
		if bool(z["safe"]):
			if d < 6.0:
				y = lerpf(236.0, y, clampf((d + 6.0) / 12.0, 0.0, 1.0))
		elif d < 0.0:
			y += (sin(x * 0.9) + sin(x * 1.7 + 2.0)) * 3.5 - 2.0
	return y


func _build_terrain() -> void:
	_terrain = PackedVector2Array()
	var x := 0.0
	while x <= W + 8.0:
		_terrain.append(Vector2(x, _terrain_y(x)))
		x += 8.0
	_terrain.append(Vector2(W + 8.0, 300.0))
	_terrain.append(Vector2(0.0, 300.0))


## Visor: vista desde arriba de las zonas candidatas; se mueve el visor y se elige.
func _pick_zone(mm: Dictionary) -> Dictionary:
	_reticle = Vector2(320, 150)
	_picked = {}
	_pick_msg = ""
	_mm_info.text = String(mm["pick_info"])
	_tele_fn = func() -> Array:
		var z := _zone_at(_reticle.x)
		var txt := "-"
		var col := GRAY
		if not z.is_empty():
			txt = "%s · %s" % [z["name"], mm["zone_ok"] if bool(z["safe"]) else mm["zone_bad"]]
			col = Color("#7aff9a") if bool(z["safe"]) else RED
		return [["ALTITUD", "1 000 M"], ["VEL. VERT.", "-16 M/S"], ["ZONA", txt, col]]
	var layer := _layer(_draw_pick)
	var title := _label(Vector2(0, GAME_TOP + 52), Vector2(W, 16), 12, GOLD, ui_layer)
	title.text = String(mm["pick_title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode = "zone"
	while _picked.is_empty():
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		var mv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
		_reticle = (_reticle + mv * 170.0 * dt).clamp(Vector2(20, 90), Vector2(620, 224))
	_mode = ""
	title.queue_free()
	layer.queue_free()
	var zp := _picked
	var msg := String(mm["picked"]) if bool(zp["safe"]) else String(mm["picked_bad"])
	toast(msg % String(zp["name"]), GOLD if bool(zp["safe"]) else RED, 2.0)
	return zp


func _confirm_zone() -> void:
	var z := _zone_at(_reticle.x)
	if z.is_empty():
		return
	_picked = z


func _draw_pick(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	var area := Rect2(12, 82, 616, 150)
	c.draw_rect(area, Color("#585862"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for i in 200:
		c.draw_rect(Rect2(area.position.x + rng.randf() * area.size.x, area.position.y + rng.randf() * area.size.y, 2, 1), Color(1, 1, 1, 0.10))
	for z in _zones:
		var zr := Rect2(float(z["x"]) - float(z["w"]) * 0.5, 96, float(z["w"]), 122)
		if not bool(z["safe"]):
			# Cráteres y rocas dentro de la zona peligrosa.
			for k in 4:
				var cp := Vector2(zr.position.x + 14.0 + rng.randf() * (zr.size.x - 28.0), zr.position.y + 16.0 + rng.randf() * (zr.size.y - 32.0))
				var cr := 8.0 + rng.randf() * 9.0
				c.draw_circle(cp, cr, Color("#34343e"))
				c.draw_arc(cp, cr, 0.0, TAU, 18, Color("#8e8e9a"), 1.5)
			for k in 5:
				var rp := Vector2(zr.position.x + 8.0 + rng.randf() * (zr.size.x - 16.0), zr.position.y + 8.0 + rng.randf() * (zr.size.y - 16.0))
				c.draw_circle(rp, 3.0, Color("#2a2a32"))
				c.draw_circle(rp + Vector2(-1, -1), 1.5, Color("#7a7a86"))
		c.draw_rect(zr, Color(GOLD, 0.7), false, 1.0)
		c.draw_string(font, zr.position + Vector2(zr.size.x * 0.5 - 4.0, 12.0), String(z["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	# Visor.
	var z_under := _zone_at(_reticle.x)
	var vcol := GRAY
	if not z_under.is_empty():
		vcol = Color("#7aff9a") if bool(z_under["safe"]) else RED
	var h := 44.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := _reticle + Vector2(sx * h, sy * h)
			c.draw_line(corner, corner - Vector2(sx * 12.0, 0.0), vcol, 2.0)
			c.draw_line(corner, corner - Vector2(0.0, sy * 12.0), vcol, 2.0)
	c.draw_line(_reticle + Vector2(-7, 0), _reticle + Vector2(7, 0), vcol, 1.0)
	c.draw_line(_reticle + Vector2(0, -7), _reticle + Vector2(0, 7), vcol, 1.0)


func _fly_descent(mm: Dictionary, zone: Dictionary) -> bool:
	var g := float(mm["gravity"])
	var thrust_a := float(mm["thrust"])
	var burn := float(mm["burn"])
	var rcs_burn := float(mm["rcs_burn"])
	var rot_rate := float(mm["rot_rate"])
	var dist_amp := float(mm["disturbance"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_lx = float(zone["x"]) + rng.randf_range(-14.0, 14.0)
	_lalt = float(mm["start_alt"])
	_lvx = 0.0
	_lvy = float(mm["start_vy"])
	_lang = 0.0
	_lthrust = false
	_lrot = 0.0
	_ldust = 0.0
	_boom = -1.0
	_ship_hidden = false
	_fuel_warned = false
	_low_label = ""
	_mm_info.text = String(mm["info"])
	_tele_fn = func() -> Array:
		var zs := _zone_safe_at(_lx)
		return [
			["ALTITUD", "%d M" % int(maxf(0.0, _lalt))],
			["VEL. VERT.", "%d M/S" % int(round(_lvy)), RED if _lvy < -float(mm["v_ok"]) - 1.0 and _lalt < 80.0 else GOLD],
			["ZONA", String(mm["zone_ok"]) if zs else String(mm["zone_bad"]), Color("#7aff9a") if zs else RED],
		]
	var stars := _stars(110)
	var layer := _layer(_draw_descent)
	var disturbance := 0.0
	var result := false
	while true:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		var rot := Input.get_axis("rotate_left", "rotate_right")
		_lthrust = Input.is_action_pressed("thrust") and _fuel > 0.0
		_lrot = rot if _fuel > 0.0 else 0.0
		# Perturbaciones: el módulo tiende a girar solo y hay que corregirlo.
		disturbance = clampf(disturbance + rng.randf_range(-1.0, 1.0) * dist_amp * dt * 4.0, -dist_amp, dist_amp)
		_lang += (_lrot * rot_rate + disturbance) * dt
		if _lthrust:
			_fuel = maxf(0.0, _fuel - burn * dt)
		_fuel = maxf(0.0, _fuel - absf(_lrot) * rcs_burn * dt)
		var ay := -g
		var ax := 0.0
		if _lthrust:
			ay += thrust_a * cos(_lang)
			ax += thrust_a * sin(_lang)
		_lvy += ay * dt
		_lvx += ax * dt
		_lalt += _lvy * dt
		_lx = clampf(_lx + _lvx * dt, 8.0, W - 8.0)
		_bar_val = _fuel
		_bar_alert = _fuel <= float(mm["low_fuel"])
		_ldust = _ldust + dt if (_lthrust and _lalt < 60.0) else 0.0
		# Aviso de Houston y contador que late con poco combustible.
		if _fuel <= float(mm["warn_fuel"]) and not _fuel_warned:
			_fuel_warned = true
			dialog.show_hint("CONTROL", String(mm["warn_text"]), 4.0)
		if _fuel <= float(mm["low_fuel"]):
			_low_label = "%s: %d S" % [mm["low_label"], int(_fuel / maxf(0.1, burn * g / thrust_a))]
		else:
			_low_label = ""
		# Punto donde caería si no se corrige (visor de predicción).
		var tf := (_lvy + sqrt(maxf(0.0, _lvy * _lvy + 2.0 * g * maxf(_lalt, 0.0)))) / g
		_pred_x = _lx + _lvx * maxf(tf, 0.0)
		if _lalt <= 0.0:
			_lalt = 0.0
			var reason := ""
			if _lvy < -float(mm["v_ok"]):
				reason = String(mm["crash_speed"])
			elif absf(_lang) > float(mm["ang_ok"]):
				reason = String(mm["crash_tilt"])
			elif not _zone_safe_at(_lx):
				reason = String(mm["crash_zone"])
			elif absf(_lvx) > float(mm["vx_ok"]):
				reason = String(mm["crash_drift"])
			if reason == "":
				result = true
				_lvy = 0.0
				_lvx = 0.0
				_lthrust = false
				_flash = 0.4
				await wait(0.6)
			else:
				_ship_hidden = true
				_boom = 0.0
				_boom_pos = Vector2(_lx, 232.0)
				_shake = 7.0
				_flash = 1.0
				toast(reason, RED, 2.2)
				await wait(2.4)
			break
	_tele_fn = Callable()
	layer.queue_free()
	stars.queue_free()
	_low_label = ""
	return result


func _alt_to_px(alt: float) -> float:
	return 190.0 * sqrt(maxf(alt, 0.0) / 1000.0)


func _draw_descent(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	# Suelo.
	c.draw_colored_polygon(_terrain, REGOLITH)
	c.draw_polyline(_terrain.slice(0, _terrain.size() - 2), REGOLITH_LIGHT, 1.0)
	for z in _zones:
		var x0 := float(z["x"]) - float(z["w"]) * 0.5
		if bool(z["safe"]):
			c.draw_rect(Rect2(x0, 236, float(z["w"]), 2), Color("#7aff9a", 0.7))
			c.draw_circle(Vector2(x0, 233), 1.5, Color("#7aff9a"))
			c.draw_circle(Vector2(x0 + float(z["w"]), 233), 1.5, Color("#7aff9a"))
		else:
			for k in 6:
				var bx := x0 + 8.0 + fmod(k * 29.0 + float(z["x"]), float(z["w"]) - 12.0)
				var by := _terrain_y(bx)
				c.draw_circle(Vector2(bx, by - 2.0), 3.0 + (k % 3), Color("#2a2a32"))
		c.draw_string(font, Vector2(float(z["x"]) - 4.0, 258), String(z["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD if bool(z["safe"]) else RED)
	# Marcador de predicción.
	var px := clampf(_pred_x, 4.0, W - 4.0)
	var pcol := Color("#7aff9a") if _zone_safe_at(px) else RED
	c.draw_line(Vector2(px - 6, 240), Vector2(px + 6, 240), pcol, 2.0)
	c.draw_line(Vector2(px, 237), Vector2(px, 243), pcol, 1.0)
	# El Eagle.
	var sy := 236.0 - _alt_to_px(_lalt) - 13.0
	if not _ship_hidden:
		var flame := 1.0 if _lthrust else 0.0
		_draw_eagle(c, Vector2(_lx, sy), _lang, 1.6, flame)
		if absf(_lrot) > 0.1:
			var side := -signf(_lrot)
			c.draw_circle(Vector2(_lx + side * 12.0, sy - 8.0), 2.0, Color(1, 1, 1, 0.7))
	if _ldust > 0.0 and _lalt < 60.0:
		for k in 14:
			var dx := (k - 7) * 6.0 * (1.0 + _ldust * 0.4)
			c.draw_rect(Rect2(_lx + dx, 232.0 - fmod(k * 3.0 + _t * 20.0, 6.0), 3, 2), Color(0.8, 0.8, 0.85, 0.5))
	# Explosión.
	if _boom >= 0.0:
		_boom += get_process_delta_time()
		for k in 8:
			var a := k * TAU / 8.0
			var d := _boom * 60.0
			c.draw_circle(_boom_pos + Vector2(cos(a), sin(a) * 0.6) * d, maxf(0.5, 5.0 - _boom * 3.0), Color("#ffb347", maxf(0.0, 1.0 - _boom)))
	# Combustible crítico: contador que late.
	if _low_label != "":
		var beat := 0.55 + 0.45 * sin(_t * 9.0)
		c.draw_string(font, Vector2(0, GAME_TOP + 62), _low_label, HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color(RED, beat))
	if _flash > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 0.9, 0.7, _flash * 0.3))


# =========================================================================
# FASE 2 · Primer paso (cinemática pendiente + acciones con el cursor)
# =========================================================================
func _scene_first_step(sc: Dictionary) -> void:
	var ac: Dictionary = sc["actions"]
	_flag_t = 0.0
	_easep_t = 0.0
	_acts_done = 0
	_exp_done = 0
	_action_queue.clear()
	_clock_s = 0.0
	_tele_fn = func() -> Array:
		return [["T. EN SUPERFICIE", _fmt_clock(_clock_s)], ["MUESTRAS", "0 KG"], ["EXPERIMENTOS", "%d/1" % _exp_done]]
	_stars(60)
	_layer(_draw_surface_scene)
	await _cinematic_pending(String(sc.get("cinematic_tag", "")))
	await say(sc["intro"])
	_mm_title.text = String(ac["title"])
	_mm_info.text = String(ac["info"])
	var items: Array = ac["items"]
	for i in items.size():
		var it: Dictionary = items[i]
		var hs := Hotspot.new(String(it["label"]), i + 1, Vector2(float(it["x"]), float(it["y"])))
		hs.activated.connect(func(_h: Hotspot) -> void: _action_queue.append(String(it["id"])))
		world.add_child(hs)
	while _acts_done < items.size():
		await get_tree().process_frame
		if get_tree().paused:
			continue
		_clock_s += get_process_delta_time() * 40.0
		if not _action_queue.is_empty() and not dialog.is_active():
			var id: String = _action_queue.pop_front()
			await _do_action(id, ac)
	_mm_info.text = ""
	await toast(String(ac["done"]), GOLD, 1.6)
	_clock_s = 19.0 * 60.0
	await say(sc["outro"])


func _do_action(id: String, ac: Dictionary) -> void:
	match id:
		"bandera":
			var tw := create_tween()
			tw.tween_property(self, "_flag_t", 1.0, 1.4)
			await tw.finished
			await toast(String(ac["flag_text"]), GOLD, 1.2)
		"placa":
			var panel := ColorRect.new()
			panel.color = Color(0.04, 0.04, 0.06, 0.96)
			panel.position = Vector2(80, 70)
			panel.size = Vector2(480, 170)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui_layer.add_child(panel)
			var title := _label(Vector2(0, 8), Vector2(480, 16), 12, GOLD, panel)
			title.text = String(ac["plaque_title"])
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var es := _label(Vector2(20, 34), Vector2(440, 60), 13, Color("#e8e4d0"), panel)
			es.text = String(ac["plaque_es"])
			es.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var en := _label(Vector2(20, 104), Vector2(440, 50), 10, GRAY_DIM, panel)
			en.text = String(ac["plaque_en"])
			en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			await wait(0.4)
			await wait_click_or_accept(8.0)
			panel.queue_free()
		"easep":
			var tw2 := create_tween()
			tw2.tween_property(self, "_easep_t", 1.0, 1.6)
			await tw2.finished
			_exp_done = 1
			await toast(String(ac["easep_text"]), GOLD, 1.6)
		"nixon":
			await say(ac["nixon_lines"])
	_acts_done += 1


func _draw_surface_scene(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	_fill_surface(c, 196.0, 1969)
	c.draw_circle(Vector2(560, 60), 10.0, Color("#2e6bd1"))                       # la Tierra en el cielo
	c.draw_circle(Vector2(557, 57), 3.5, Color("#3f9a52"))
	_draw_eagle(c, Vector2(150, 190), 0.0, 2.2)
	c.draw_line(Vector2(176, 184), Vector2(176, 198), GRAY, 2.0)                  # escalera
	c.draw_rect(Rect2(112, 163, 24, 6), Color("#1a1c28"))                         # la placa en la pata
	c.draw_rect(Rect2(112, 163, 24, 6), GOLD, false, 1.0)
	_draw_astro_side(c, Vector2(250, 214), 1.6, 0.4 + 0.4 * sin(c.t * 1.4))
	# Bandera.
	var fp := Vector2(470, 200)
	c.draw_line(fp, fp + Vector2(0, -52.0 * maxf(_flag_t, 0.05)), Color("#c8ccd8"), 2.0)
	if _flag_t > 0.05:
		var fy := fp.y - 52.0 * _flag_t
		for k in 7:
			c.draw_rect(Rect2(fp.x + 1, fy + k * 2.0, 28, 2), Color("#d8342a") if k % 2 == 0 else Color("#ffffff"))
		c.draw_rect(Rect2(fp.x + 1, fy, 12, 8), Color("#2a3f9a"))
	# EASEP.
	if _easep_t > 0.0:
		var ex := 490.0
		c.draw_rect(Rect2(ex - 12, 224 - 10.0 * _easep_t, 14, 10.0 * _easep_t), FOIL)         # sismómetro
		c.draw_rect(Rect2(ex + 6, 224 - 6.0 * _easep_t, 8, 6.0 * _easep_t), Color("#b0b4c0"))   # detector de polvo
		c.draw_line(Vector2(ex - 4, 214), Vector2(ex - 4, 214 - 12.0 * _easep_t), GRAY, 1.0)
	# Nixon: el teléfono de la Casa Blanca (icono).
	c.draw_circle(Vector2(330, 106), 3.0, Color(GOLD, 0.0))
	c.draw_string(font, Vector2(8, GAME_BOTTOM - 8), "", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GRAY)


# =========================================================================
# FASE 3 · Recolección de rocas (vista aérea)
# =========================================================================
func _scene_rocks(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	_rocks_cfg = mm
	_mm_title.text = String(mm["title"])
	_bar_name = String(data["hud"]["oxygen"])
	_bar_show = true
	var goal := float(mm["goal_kg"])
	var limit_px := 110.0
	var speed := float(mm["speed"])
	var arrow_chars := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	while true:
		_oxy = 100.0
		_bar_val = _oxy
		_bar_alert = false
		_kg = 0.0
		_returning = false
		_steps.clear()
		_astro = MC + Vector2(0, 26)
		_astro_dir = Vector2.DOWN
		_place_rocks(mm)
		_mm_info.text = String(mm["info"])
		_tele_fn = func() -> Array:
			var d := _astro.distance_to(MC) / limit_px * float(mm["limit_m"])
			var tgt := _next_target()
			var arrow := "·"
			if tgt != Vector2.ZERO:
				var ang := (tgt - _astro).angle()
				arrow = arrow_chars[int(round(ang / (TAU / 8.0))) & 7]
			return [["MUESTRAS", "%s / %s KG" % [_num(_kg), _num(goal)]], ["DIST. MÓDULO", "%d M" % int(round(d))], ["FLECHA", arrow]]
		var layer := _layer(_draw_rocks)
		var hint1 := false
		var hint2 := false
		var failed := false
		var done := false
		while not done and not failed:
			await get_tree().process_frame
			if get_tree().paused:
				continue
			var dt := get_process_delta_time()
			var mv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
			if mv.length() > 1.0:
				mv = mv.normalized()
			if mv != Vector2.ZERO:
				_astro_dir = mv
				if int(_t * 12.0) % 3 == 0 and (_steps.is_empty() or _astro.distance_to(_steps[_steps.size() - 1]["p"]) > 9.0):
					_steps.append({"p": _astro, "t": _t})
			var np := _astro + mv * speed * dt
			var off := np - MC
			if off.length() > limit_px:
				np = MC + off.normalized() * limit_px
				if not _toast.visible:
					toast(String(mm["limit_text"]), RED, 0.8)
			_astro = np
			# Recoger rocas al pasar por encima.
			for r in _rocks:
				if not bool(r["got"]) and _astro.distance_to(r["p"]) < float(r["r"]) + 6.0:
					r["got"] = true
					_kg += float(r["m"])
					_flash = 0.15
			# Oxígeno: baja con el tiempo y con la distancia al módulo.
			var dist_f := _astro.distance_to(MC) / limit_px
			_oxy = maxf(0.0, _oxy - (float(mm["o2_base"]) + float(mm["o2_distance"]) * dist_f) * dt)
			_bar_val = _oxy
			_bar_alert = _oxy <= float(mm["o2_warn"])
			if not hint1:
				hint1 = true
				dialog.show_hint("ARMSTRONG", String(mm["hint_start"]), 3.5)
			if _oxy <= float(mm["o2_warn"]) and not hint2:
				hint2 = true
				dialog.show_hint("ALDRIN", String(mm["hint_o2"]), 4.0)
			if _kg >= goal and not _returning:
				_returning = true
				toast(String(mm["return_text"]), GOLD, 1.6)
			if _returning and _astro.distance_to(MC) < 20.0:
				done = true
			if _oxy <= 0.0:
				failed = true
		layer.queue_free()
		_tele_fn = Callable()
		if done:
			break
		await toast(String(mm["fail"]), RED, 2.6)
		await toast(String(mm["retry"]), GRAY, 1.4)
		_retry = true
	await toast(String(mm["success"]), GOLD, 1.6)
	await say(sc["outro"])


func _place_rocks(mm: Dictionary) -> void:
	_rocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969 + (1 if _retry else 0)
	var counts := [int(mm["rocks_big"]), int(mm["rocks_mid"]), int(mm["rocks_small"])]
	var mass_rng := [Vector2(2.2, 3.0), Vector2(0.9, 1.4), Vector2(0.25, 0.5)]
	var radii := [7.0, 5.0, 3.0]
	for kind in 3:
		for k in counts[kind]:
			for tries in 40:
				var ang := rng.randf() * TAU
				var rad := sqrt(rng.randf()) * 100.0
				var p := MC + Vector2(cos(ang), sin(ang)) * rad
				if p.distance_to(MC) < 30.0:
					continue
				var okp := true
				for r in _rocks:
					if p.distance_to(r["p"]) < 16.0:
						okp = false
				if okp:
					_rocks.append({"p": p, "m": rng.randf_range(mass_rng[kind].x, mass_rng[kind].y), "r": radii[kind], "got": false, "kind": kind})
					break


## Siguiente punto de muestreo: la roca grande más cercana, luego las medianas, luego el Eagle.
func _next_target() -> Vector2:
	if _returning:
		return MC
	var best := Vector2.ZERO
	var bd := 1e9
	for kind in [0, 1, 2]:
		for r in _rocks:
			if not bool(r["got"]) and int(r["kind"]) == kind:
				var d := _astro.distance_to(r["p"])
				if d < bd:
					bd = d
					best = r["p"]
		if best != Vector2.ZERO:
			return best
	return best


func _draw_rocks(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color("#52525c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		c.draw_rect(Rect2(rng.randf() * W, GAME_TOP + rng.randf() * 244.0, 2, 1), Color(1, 1, 1, 0.07))
	for i in 9:
		var cp := Vector2(rng.randf() * W, GAME_TOP + 20.0 + rng.randf() * 210.0)
		c.draw_circle(cp, 7.0 + rng.randf() * 10.0, Color("#44444e"))
	# Límite de 100 m.
	c.draw_arc(MC, 110.0, 0.0, TAU, 72, Color(RED, 0.5), 1.0)
	c.draw_string(font, MC + Vector2(-34, -114), "100 M", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(RED, 0.7))
	# El Eagle visto desde arriba.
	c.draw_circle(MC, 15.0, FOIL)
	c.draw_circle(MC, 9.0, Color("#b0b4c0"))
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		c.draw_line(MC + Vector2(cos(a), sin(a)) * 14.0, MC + Vector2(cos(a), sin(a)) * 21.0, GRAY, 2.0)
	# Pisadas.
	for st in _steps:
		var age := _t - float(st["t"])
		if age < 12.0:
			c.draw_rect(Rect2(st["p"] - Vector2(1, 1), Vector2(2, 2)), Color(0.3, 0.3, 0.36, 0.8 - age / 15.0))
	# Rocas.
	var tgt := _next_target()
	for r in _rocks:
		if bool(r["got"]):
			continue
		var p: Vector2 = r["p"]
		var rr := float(r["r"])
		c.draw_circle(p + Vector2(2, 2), rr, Color(0, 0, 0, 0.3))
		c.draw_circle(p, rr + 1.0, Color("#9a9aa6"))   # borde claro: las rocas se leen sobre el suelo oscuro
		c.draw_circle(p, rr, Color("#5a5a66") if int(r["kind"]) != 0 else Color("#6a5a60"))
		c.draw_circle(p + Vector2(-rr * 0.3, -rr * 0.3), maxf(1.0, rr * 0.35), Color("#c0c0cc"))
		if p == tgt and not _returning:
			c.draw_arc(p, rr + 4.0 + sin(_t * 6.0), 0.0, TAU, 16, Color(GOLD, 0.9), 1.0)
	# Astronauta (vista aérea: casco con visor dorado y mochila).
	var hop := absf(sin(_t * 7.0)) * 2.0 if _astro_dir != Vector2.ZERO else 0.0
	var ap := _astro + Vector2(0, -hop)
	c.draw_circle(_astro + Vector2(0, 3), 6.0, Color(0, 0, 0, 0.3))
	c.draw_circle(ap - _astro_dir * 3.0, 5.0, Color("#c8ccd8"))
	c.draw_circle(ap, 6.0, Color("#f0f0f8"))
	c.draw_circle(ap + _astro_dir * 3.0, 3.0, GOLD)
	# Flecha hacia el siguiente punto.
	if tgt != Vector2.ZERO:
		var d := (tgt - _astro).normalized()
		var tip := _astro + d * 22.0
		c.draw_line(_astro + d * 12.0, tip, Color(GOLD, 0.8), 2.0)
		c.draw_line(tip, tip - d.rotated(0.5) * 6.0, Color(GOLD, 0.8), 2.0)
		c.draw_line(tip, tip - d.rotated(-0.5) * 6.0, Color(GOLD, 0.8), 2.0)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 1, 1, _flash * 0.2))


# =========================================================================
# FASE 4 · Despegue (medidor de potencia + corrección de ángulo)
# =========================================================================
func _scene_ascent(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	_mm_title.text = String(mm["title"])
	_bar_name = String(data["hud"]["fuel"])
	_bar_show = true
	_orbit_ok = false
	_liftoff_t = -1.0
	_asc_alt = 0.0
	_asc_ang = 0.0
	_tele_fn = func() -> Array:
		var pw := int(round(_pm_val * 100.0)) if _pm_run else 0
		return [["PROPULSIÓN", "%d%%" % pw], ["ÁNGULO", "%d°" % int(round(_asc_ang))], ["ÓRBITA", String(mm["orbit_ok"]) if _orbit_ok else "—"]]
	_stars(100)
	_layer(_draw_ascent)
	if not _retry:
		await say(sc["intro"])
	var spd_mul := 1.0
	var attempts := 0
	while true:
		_fuel = float(mm["fuel_start"])
		_bar_val = _fuel
		_bar_alert = false
		_orbit_ok = false
		_liftoff_t = -1.0
		_asc_alt = 0.0
		_asc_ang = 0.0
		_ang_err = 0.0
		_asc_progress = 0.0
		var got_off := false
		while not got_off:
			if _fuel < float(mm["fail_low_cost"]) - 0.01:
				break
			var res := await _power_meter(mm, spd_mul)
			attempts += 1
			if res == 0:
				got_off = true
			elif res < 0:
				_fuel = maxf(0.0, _fuel - float(mm["fail_low_cost"]))
				_bar_val = _fuel
				await toast(String(mm["low_text"]), RED, 1.6)
				spd_mul *= 1.12
			else:
				_fuel = maxf(0.0, _fuel - float(mm["fail_high_cost"]))
				_bar_val = _fuel
				_ang_err = signf(randf() - 0.5) * 0.35
				await toast(String(mm["high_text"]), RED, 1.6)
				spd_mul *= 1.12
		if got_off:
			await say(sc["liftoff"])
			var reached := await _ascent_orbit(mm)
			if reached:
				break
		await toast(String(mm["no_fuel"]), RED, 2.0)
		await toast(String(mm["retry"]), GRAY, 1.4)
		_retry = true
		spd_mul = 1.0
	_tele_fn = Callable()
	await toast(String(mm["orbit_ok"]), GOLD, 1.8)
	await say(sc["outro"])


## Devuelve 0 si se detuvo en la zona verde, -1 si quedó por debajo y 1 si se pasó.
func _power_meter(mm: Dictionary, spd_mul: float) -> int:
	_pm_zone = Vector2(float((mm["zone"] as Array)[0]), float((mm["zone"] as Array)[1]))
	var shift := randf_range(-0.04, 0.04)
	_pm_zone += Vector2(shift, shift)
	_pm_t = 0.0
	_pm_val = 0.0
	_pm_stop = false
	_pm_run = true
	_mm_info.text = String(mm["meter_info"])
	_mode = "power"
	while not _pm_stop:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		_pm_t += get_process_delta_time() * float(mm["pm_speed"]) * spd_mul
		_pm_val = absf(fmod(_pm_t, 2.0) - 1.0)
	_mode = ""
	_pm_run = false
	var v := _pm_val
	await wait(0.35)
	if v < _pm_zone.x:
		return -1
	if v > _pm_zone.y:
		return 1
	return 0


func _ascent_orbit(mm: Dictionary) -> bool:
	_flash = 0.8
	_shake = 5.0
	_liftoff_t = 0.0
	await toast(String(mm["liftoff_text"]), GOLD, 0.9)
	_mm_info.text = String(mm["orbit_info"])
	_asc_run = true
	_asc_progress = 0.0
	_asc_band = float(mm["band"])
	_asc_ang = rad_to_deg(_ang_err)
	var elapsed := 0.0
	var dist := 0.0
	var secs_needed := float(mm["orbit_seconds"])
	var limit := float(mm["orbit_limit"])
	var ok := false
	while true:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		elapsed += dt
		_liftoff_t += dt
		# Perfil de cabeceo: la nave debe inclinarse poco a poco (la banda dorada sube).
		_asc_target = clampf(elapsed * 4.0, 0.0, 40.0) - 8.0
		var rot := Input.get_axis("rotate_left", "rotate_right")
		dist = clampf(dist + randf_range(-1.0, 1.0) * 28.0 * dt, -14.0, 14.0)
		_asc_ang += (rot * 38.0 + dist) * dt
		var inside := absf(_asc_ang - _asc_target) <= _asc_band
		_fuel = maxf(0.0, _fuel - (float(mm["orbit_burn_in"]) if inside else float(mm["orbit_burn_out"])) * dt)
		_bar_val = _fuel
		_bar_alert = _fuel <= 4.0
		if inside:
			_asc_progress = minf(1.0, _asc_progress + dt / secs_needed)
		_asc_alt = elapsed * 40.0
		if _asc_progress >= 1.0:
			ok = true
			break
		if _fuel <= 0.0 or elapsed > limit:
			break
	_asc_run = false
	if ok:
		_orbit_ok = true
		_flash = 0.5
		await wait(0.6)
	return ok


func _draw_ascent(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	var lifted := _liftoff_t >= 0.0
	var gy := 236.0 + (_asc_alt * 0.0 if not lifted else minf(_asc_alt * 1.6, 160.0))
	if gy < 300.0:
		_fill_surface(c, gy, 1969)
		# Etapa de descenso, bandera y huellas que se quedan atrás.
		_draw_eagle(c, Vector2(320, gy - 13.0), 0.0, 1.6, 0.0, true, false)
		c.draw_line(Vector2(210, gy), Vector2(210, gy - 34), Color("#c8ccd8"), 2.0)
		for k in 7:
			c.draw_rect(Rect2(211, gy - 34 + k * 2.0, 18, 2), Color("#d8342a") if k % 2 == 0 else Color("#ffffff"))
	if lifted:
		# La etapa de ascenso sube y se inclina.
		var rise := minf(_asc_alt * 1.2, 110.0)
		var pos := Vector2(320.0 + sin(deg_to_rad(_asc_ang)) * 20.0, 222.0 - rise)
		_draw_eagle(c, pos + Vector2(0, 8), deg_to_rad(_asc_ang), 1.4, 1.0, false, true)
		c.draw_colored_polygon(PackedVector2Array([pos + Vector2(-4, 14), pos + Vector2(4, 14), pos + Vector2(0, 26.0 + 6.0 * sin(_t * 40.0))]), Color("#ffb347"))
	# Medidor de potencia.
	if _pm_run:
		var bar := Rect2(150, 110, 340, 26)
		c.draw_rect(bar.grow(6), Color(0.03, 0.03, 0.05, 0.9))
		c.draw_rect(bar, Color("#1a1c28"))
		c.draw_rect(Rect2(bar.position.x + bar.size.x * _pm_zone.x, bar.position.y, bar.size.x * (_pm_zone.y - _pm_zone.x), bar.size.y), Color("#3f9a52"))
		c.draw_rect(bar, GRAY, false, 1.0)
		var mx := bar.position.x + bar.size.x * _pm_val
		c.draw_rect(Rect2(mx - 2, bar.position.y - 6, 4, bar.size.y + 12), GOLD)
		c.draw_string(font, Vector2(bar.position.x, bar.position.y - 12), "PROPULSIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GRAY)
		c.draw_string(font, Vector2(bar.end.x - 36, bar.position.y - 12), "%d%%" % int(round(_pm_val * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	# Control de ángulo.
	if _asc_run:
		var ab := Rect2(120, 232, 400, 14)
		c.draw_rect(ab, Color(0.03, 0.03, 0.05, 0.85))
		c.draw_rect(ab, GRAY_DIM, false, 1.0)
		var sc_x := func(deg: float) -> float: return ab.position.x + ab.size.x * 0.5 + deg * 6.0
		var tx: float = sc_x.call(_asc_target)
		c.draw_rect(Rect2(tx - _asc_band * 6.0, ab.position.y, _asc_band * 12.0, ab.size.y), Color(GOLD, 0.35))
		var ax2: float = clampf(sc_x.call(_asc_ang), ab.position.x + 2.0, ab.end.x - 2.0)
		c.draw_rect(Rect2(ax2 - 2, ab.position.y - 3, 4, ab.size.y + 6), Color("#7aff9a") if absf(_asc_ang - _asc_target) <= _asc_band else RED)
		var pb := Rect2(120, 218, 400, 5)
		c.draw_rect(pb, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(pb.position, Vector2(pb.size.x * _asc_progress, pb.size.y)), GOLD)
		c.draw_string(font, Vector2(120, 214), "ÓRBITA", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GRAY)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 0.9, 0.7, _flash * 0.35))


# =========================================================================
# FASE 5 · Acoplamiento y regreso (cinemática pendiente + epílogo)
# =========================================================================
func _scene_docking(sc: Dictionary) -> void:
	_bar_show = false
	_clock_s = 21.0 * 3600.0 + 36.0 * 60.0
	_tele_fn = func() -> Array:
		return [["ACOPLAMIENTO", "CONFIRMADO"], ["T. EN SUPERFICIE", _fmt_clock(_clock_s).substr(0, 5)], ["MUESTRAS", "%s KG" % _num(21.5)]]
	_stars(120)
	_layer(func(c: DrawNode) -> void:
		c.draw_circle(Vector2(320, 520), 332.0, Color(0.5, 0.5, 0.56, 0.18))
		c.draw_circle(Vector2(320, 520), 328.0, Color("#5a5a66"))
		# La Columbia y el Eagle acoplándose.
		c.draw_rect(Rect2(250, 120, 70, 24), Color("#c8ccd8"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(320, 120), Vector2(320, 144), Vector2(344, 132)]), FOIL)
		_draw_eagle(c, Vector2(400 - 40.0 * clampf(c.t * 0.2, 0.0, 1.0), 138), -PI / 2.0, 1.4, 0.0, false, true)
	)
	await _cinematic_pending(String(sc.get("cinematic_tag", "")))
	await say(sc["dialog"])
	# Epílogo en texto sobre negro.
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 1.0)
	await tw.finished
	_clear()
	_set_date("")
	_set_objective("")
	var y := 70.0
	for line in sc["epilogue"]:
		var l := _label(Vector2(40, y), Vector2(560, 36), 12, GRAY, ui_layer)
		l.text = String(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		var tl := create_tween()
		tl.tween_property(l, "modulate:a", 1.0, 0.9)
		y += 40.0
		await wait(1.6)
	var f := _label(Vector2(40, y + 14), Vector2(560, 60), 15, GOLD, ui_layer)
	f.text = String(sc["final_text"])
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.modulate.a = 0.0
	_fade.modulate.a = 0.0
	var tf := create_tween()
	tf.tween_property(f, "modulate:a", 1.0, 1.2)
	await wait(1.8)
	var h := _label(Vector2(0, 240), Vector2(W, 14), 10, GRAY, ui_layer)
	h.text = String(data["hud"]["button_back"])
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await wait_click_or_accept()


# =========================================================================
# Entrada: elegir zona, detener la barra, pausa y debug
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
		if k >= KEY_F1 and k <= KEY_F6:
			GameManager.set_start_phase(k - KEY_F1 + 1)
			SceneTransition.change_scene(scene_file_path, 0.2)
			return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not MissionHUD.hover_ui
	match _mode:
		"continue":
			if click or event.is_action_pressed("ui_accept"):
				_mode = ""
		"zone":
			if event is InputEventMouseMotion:
				_reticle = get_local_mouse_position().clamp(Vector2(20, 90), Vector2(620, 224))
			elif click or event.is_action_pressed("ui_accept"):
				_confirm_zone()
		"power":
			if click or event.is_action_pressed("ui_accept"):
				_pm_stop = true


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		(_pause_panel.get_child(0).get_child(1) as Button).grab_focus()
