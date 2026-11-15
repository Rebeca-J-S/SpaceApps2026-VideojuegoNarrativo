extends Control
## CAPÍTULO "SPIRIT Y OPPORTUNITY: GEMELOS" (2004-2018). Vista 2D, pixel art placeholder (naranjas de Marte).
##
## El jugador es un planificador de operaciones del JPL (personaje imaginado). Los rovers no hablan:
## solo envían paquetes de datos. Textos y valores en data/dialogos/spirit_opportunity.json
## (el inglés está en data/i18n/en/spirit_opportunity.json).
##
## Fases (cada una = una pieza de la insignia):
##   0 Aterrizaje y primer sol (planificador de la jornada)  1 Detective del agua (instrumentos)
##   2 Atrapada en Purgatory (ensayo + escape)                3 La rueda arrastrada (conducción)
##   4 Invierno en Troy (reparto de energía)                  5 Rumbo a Endeavour (trazar ruta)
##   6 La tormenta (ventanas de luz) + último mensaje + epílogo
## Las cinemáticas todavía no existen: se muestra la pantalla "CINEMÁTICA PENDIENTE".
## Debug (solo en builds de depuración): F1-F7 saltan a cada fase.

signal chapter_finished

const DATA_PATH := "res://data/dialogos/spirit_opportunity.json"
const MISSION_ID := "spirit_opportunity"
const BADGE_ID := "spirit_opportunity"
const W := 640.0
const GAME_TOP := 22.0
const GAME_BOTTOM := 266.0
const GOLD := Color("#ffb347")
const GRAY := Color("#c8bcb0")
const GRAY_DIM := Color("#8a7c70")
const RED := Color("#ff5a4a")
const GREEN := Color("#7ad07a")
const CYAN := Color("#7ad0ff")
const YEL := Color("#ffd24a")
const MARS := Color("#b8643a")
const MARS_DARK := Color("#7a3e26")
const MARS_LIGHT := Color("#d98c58")
const SKY_TOP := Color("#8c5a48")
const SKY_LOW := Color("#d8a47c")
const PANEL := Color("#1a1210")
const SILVER := Color("#c0c4cc")

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
var _badge_toast: BadgeToast

var _tele: Array = []
var _tele_fn: Callable = Callable()
var _bar_name := ""
var _bar_val := 100.0
var _bar_show := false
var _bar_alert := false
var _bar_red_low := true
var _t := 0.0
var _mode := ""
var _input_cb: Callable = Callable()
var _evidence: Array = []
var _msg := ""
var _msg_t := 0.0
var _msg_col := GOLD

# Fase 0: planificador
const PL_X0 := 44.0
const PL_CW := 23.0
const PL_Y := 104.0
const PL_H := 32.0
var _pl_cfg: Dictionary = {}
var _pl_day: Dictionary = {}
var _pl_blocks: Array = []
var _pl_sel := 0
var _pl_cur := 0
var _pl_play := -1.0
var _pl_ok := false
var _pl_idx := 0
var _pl_n := 1
# Fase 1: agua
var _wd_cfg: Dictionary = {}
var _wd_energy := 0.0
var _wd_sel := 0
var _wd_used: Dictionary = {}
var _wd_solved: Dictionary = {}
var _wd_log := ""
var _wd_log_col := GRAY
var _wd_stage := "pick"
# Fase 2: Purgatory
var _sd_cfg: Dictionary = {}
var _sd_prog := 0.0
var _sd_sink := 0.0
var _sd_slip := 0.0
var _sd_queue: Array = []
var _sd_busy := false
var _sd_test := true
var _sd_sol := 0
var _sd_x := 0.0
var _sd_spin := 0.0
var _sd_free := false


func _ready() -> void:
	theme = RetroTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	data = GameManager.load_json(DATA_PATH)
	_build()
	_badge_toast = BadgeToast.new()
	add_child(_badge_toast)
	await get_tree().process_frame
	_run_chapter()


# =========================================================================
# Flujo del capítulo
# =========================================================================
func _run_chapter() -> void:
	var start := GameManager.consume_start_phase()   # 0 = normal; 1-7 = salta a esa fase
	var scenes: Array = data["scenes"]
	if start == 0:
		await mission_hud.show_briefing()
		await _disclaimer()
	else:
		mission_hud.minimize_now()
	var first := maxi(start - 1, 0)
	_preload_evidence(first)
	for i in range(first, scenes.size()):
		await _run_scene(scenes[i], i)
		_award_badge_piece(i)
	mission_hud.mark_all_done()
	chapter_finished.emit()
	if auto_return:
		GameManager.mark_completed(MISSION_ID)
		GameManager.go_to_planet_select()


## Cuaderno de insignias: cada fase terminada gana una pieza de la insignia de la misión.
func _award_badge_piece(index: int) -> void:
	var b := GameManager.find_badge(BADGE_ID)
	if not b.is_empty() and GameManager.unlock_badge_piece(BADGE_ID, index):
		_badge_toast.show_piece(b, GameManager.badge_pieces(BADGE_ID), index)


func _run_scene(sc: Dictionary, index: int) -> void:
	_clear()
	_set_date(String(sc["date"]))
	_set_objective(String(sc["objective"]))
	await _banner(String(sc["title"]))
	mission_hud.set_phase(index, String(sc["title"]), String(sc["objective"]))
	match String(sc["id"]):
		"aterrizaje": await _act_plan(sc)
		"agua": await _act_water(sc)
		"purgatory": await _act_sand(sc)
		"rueda": await _act_wheel(sc)
		"invierno": await _act_winter(sc)
		"endeavour": await _act_route(sc)
		"tormenta": await _act_storm(sc)


## Si se salta a una fase con F1-F7, la libreta recibe las pruebas de las fases anteriores.
func _preload_evidence(first: int) -> void:
	var scenes: Array = data["scenes"]
	for i in first:
		for ev in _scene_evidences(scenes[i]):
			_evidence.append(ev)


func _scene_evidences(sc: Dictionary) -> Array:
	var out: Array = []
	for ev in sc.get("evidence", []):
		out.append(ev)
	var mm: Dictionary = sc.get("minimission", {})
	for tg in mm.get("targets", []):
		out.append((tg as Dictionary)["evidence"])
	return out


func _add_evidence(ev: Dictionary) -> void:
	for e in _evidence:
		if String((e as Dictionary)["id"]) == String(ev["id"]):
			return
	_evidence.append(ev)
	toast(String(data["hud"]["new_evidence"]) % String(ev["title"]), CYAN, 1.3)


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


## Pantalla de cinemática que todavía no existe.
func _cinematic_pending(tag: String) -> void:
	var panel := ColorRect.new()
	panel.color = Color("#080505")
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var l1 := _label(Vector2(0, 86), Vector2(W, 26), 22, GOLD, ui_layer)
	l1.text = String(data["cinematic_pending"])
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := _label(Vector2(0, 122), Vector2(W, 16), 12, GRAY, ui_layer)
	l2.text = tag
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := _label(Vector2(0, 200), Vector2(W, 14), 10, GRAY_DIM, ui_layer)
	h.text = String(data["continue_hint"])
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween().set_loops()
	tw.tween_property(l1, "modulate:a", 0.45, 0.8)
	tw.tween_property(l1, "modulate:a", 1.0, 0.8)
	await wait(0.4)
	await wait_click_or_accept(5.0)
	tw.kill()
	panel.queue_free()
	l1.queue_free()
	l2.queue_free()
	h.queue_free()


# =========================================================================
# Construcción del HUD
# =========================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0a0606")
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

	var top := ColorRect.new()
	top.color = Color(0.07, 0.04, 0.04, 0.9)
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

	_mm_title = _label(Vector2(8, GAME_TOP + 22), Vector2(420, 14), 11, GOLD)
	_mm_info = _label(Vector2(8, GAME_TOP + 36), Vector2(620, 14), 10, GRAY)
	for l in [_mm_title, _mm_info]:
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
		l.add_theme_constant_override("outline_size", 4)
	_toast = _label(Vector2(0, 100), Vector2(W, 56), 17, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.hide()

	var bottom := ColorRect.new()
	bottom.color = Color(0.06, 0.04, 0.04, 0.95)
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

	mission_hud = MissionHUD.new()
	add_child(mission_hud)
	mission_hud.badge_pos = Vector2(8, GAME_TOP + 3)
	mission_hud.buttons_pos = Vector2(W - 6, GAME_TOP + 3)
	mission_hud.reminder_pos = Vector2(8, GAME_TOP + 54)
	mission_hud.briefing_auto_seconds = 7.0
	mission_hud.briefing_area = Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP)
	mission_hud.keys_pos = Vector2(8, GAME_BOTTOM - 17)
	mission_hud.busy_check = func() -> bool: return dialog.is_active() or _toast.visible
	mission_hud.reminder_callback = func(t: String) -> void: dialog.show_hint("JPL", t)
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
	_input_cb = Callable()
	_msg = ""
	_msg_t = 0.0
	_mm_title.text = ""
	_mm_info.text = ""
	_tele = []
	_tele_fn = Callable()
	_bar_show = false
	_bar_alert = false
	_bar_red_low = true
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


## Mensaje corto dentro de la zona de juego (sin bloquear).
func _say_msg(text: String, color: Color = GOLD, seconds: float = 2.2) -> void:
	_msg = text
	_msg_col = color
	_msg_t = seconds


func _axis_keys(neg_a: Key, neg_b: Key, pos_a: Key, pos_b: Key) -> float:
	var n := 1.0 if (Input.is_physical_key_pressed(neg_a) or Input.is_physical_key_pressed(neg_b)) else 0.0
	var p := 1.0 if (Input.is_physical_key_pressed(pos_a) or Input.is_physical_key_pressed(pos_b)) else 0.0
	return p - n


func _num(v: float, decimals: int = 1) -> String:
	var txt := "%.*f" % [decimals, v]
	return txt if GameManager.lang == "en" else txt.replace(".", ",")


# =========================================================================
# HUD dinámico: telemetría y barra
# =========================================================================
func _process(delta: float) -> void:
	_t += delta
	if _msg_t > 0.0:
		_msg_t -= delta
	if _tele_fn.is_valid():
		_tele = _tele_fn.call()
	_hud_draw.queue_redraw()


func _draw_data_panel() -> void:
	var c := _hud_draw
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.05, 0.03, 0.03, 0.94))
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
		var col := RED if ((_bar_red_low and _bar_val <= 20.0) or alert) else GOLD
		c.draw_string(font, Vector2(6, 56), _bar_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GRAY)
		var bar := Rect2(6, 60, 148, 8)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_bar_val, 0.0, 100.0) / 100.0, bar.size.y)), col)
		c.draw_rect(bar, col, false, 1.0)
		c.draw_string(font, Vector2(6, 79), "%d%%" % int(round(_bar_val)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


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


# =========================================================================
# Dibujo compartido (PLACEHOLDERS: reemplazar por sprites)
# =========================================================================
func _txt(c: CanvasItem, pos: Vector2, text: String, size: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(ThemeDB.fallback_font, pos, text, align, width, size, col)


## Botón / tarjeta rectangular con texto centrado.
func _box(c: CanvasItem, r: Rect2, fill: Color, border: Color, text: String = "", size: int = 9, tcol: Color = GRAY) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r, border, false, 1.0)
	if text != "":
		_txt(c, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + size * 0.36), text, size, tcol, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_msg(c: CanvasItem, y: float) -> void:
	if _msg_t > 0.0 and _msg != "":
		var w := ThemeDB.fallback_font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16.0
		var r := Rect2(320.0 - w * 0.5, y, w, 16)
		c.draw_rect(r, Color(0.04, 0.02, 0.02, 0.92))
		c.draw_rect(r, _msg_col, false, 1.0)
		_txt(c, Vector2(r.position.x, y + 12), _msg, 10, _msg_col, w, HORIZONTAL_ALIGNMENT_CENTER)


func _mars_ground(c: CanvasItem, y_top: float, seed_v: int) -> void:
	c.draw_rect(Rect2(0, y_top, W, GAME_BOTTOM - y_top + 4), MARS)
	c.draw_rect(Rect2(0, y_top, W, 2), MARS_LIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 90:
		var x := rng.randf() * W
		var y := y_top + 4.0 + rng.randf() * (GAME_BOTTOM - y_top)
		c.draw_rect(Rect2(floorf(x), floorf(y), 2, 1), MARS_DARK if i % 2 == 0 else MARS_LIGHT)


func _mars_sky(c: CanvasItem, y_top: float, y_bot: float, dim: float = 0.0) -> void:
	var n := 8
	for i in n:
		var f := float(i) / float(n - 1)
		var col := SKY_TOP.lerp(SKY_LOW, f).darkened(dim)
		c.draw_rect(Rect2(0, y_top + (y_bot - y_top) * float(i) / float(n), W, (y_bot - y_top) / float(n) + 1.0), col)


## Rover visto de lado.
func _draw_rover_side(c: CanvasItem, pos: Vector2, s: float, sink: float = 0.0, spin: float = 0.0, tint: Color = SILVER) -> void:
	var p := pos + Vector2(0, sink * 6.0 * s)
	c.draw_set_transform(p, 0.0, Vector2(s, s))
	c.draw_rect(Rect2(-12, -10, 24, 5), tint)
	c.draw_rect(Rect2(-12, -10, 24, 1), tint.lightened(0.3))
	c.draw_rect(Rect2(-14, -12, 28, 2), Color("#3a4468"))
	c.draw_line(Vector2(5, -10), Vector2(5, -18), SILVER, 1.0)
	c.draw_rect(Rect2(3, -20, 5, 3), Color("#2a2c3a"))
	c.draw_line(Vector2(-9, -10), Vector2(-9, -14), SILVER, 1.0)
	c.draw_circle(Vector2(-9, -15), 2.0, tint)
	for wx in [-9.0, 0.0, 9.0]:
		c.draw_circle(Vector2(wx, -1), 4.0, Color("#2a2a30"))
		c.draw_circle(Vector2(wx, -1), 2.2, Color("#6a6a74"))
		var a := spin
		c.draw_line(Vector2(wx, -1), Vector2(wx, -1) + Vector2.from_angle(a) * 3.6, GRAY_DIM, 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rover visto desde arriba (mira hacia +x). La rueda delantera derecha puede estar "arrastrada".
func _draw_rover_top(c: CanvasItem, pos: Vector2, ang: float, s: float, drag: bool = false, tint: Color = SILVER) -> void:
	c.draw_set_transform(pos, ang, Vector2(s, s))
	for wx in [-7.0, 0.0, 7.0]:
		for wy in [-7.0, 7.0]:
			var col := Color("#2a2a30")
			if drag and wx > 0.0 and wy > 0.0:
				col = RED
			c.draw_rect(Rect2(wx - 2.5, wy - 1.5, 5, 3), col)
	c.draw_rect(Rect2(-9, -5, 18, 10), tint)
	c.draw_rect(Rect2(-9, -5, 18, 1), tint.lightened(0.3))
	c.draw_rect(Rect2(-6, -4, 8, 8), Color("#3a4468"))
	c.draw_rect(Rect2(5, -1, 4, 2), Color("#2a2c3a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =========================================================================
# FASE 0 · Aterrizaje y primer sol (planificador de la jornada)
# =========================================================================
func _act_plan(sc: Dictionary) -> void:
	await _cinematic_pending(String(sc["cinematic_tag"]))
	await say(sc["intro"])
	_pl_cfg = sc["minimission"]
	var days: Array = _pl_cfg["days"]
	_pl_n = days.size()
	_layer(_draw_plan)
	for di in days.size():
		await _plan_day(days[di], di)
	_input_cb = Callable()
	await say(sc["outro"])


func _plan_day(day: Dictionary, di: int) -> void:
	_pl_idx = di
	_pl_day = day
	_pl_blocks = []
	for b in day["blocks"]:
		var nb: Dictionary = (b as Dictionary).duplicate()
		nb["col"] = -1
		_pl_blocks.append(nb)
	_pl_sel = 0
	_pl_cur = 0
	_pl_play = -1.0
	_pl_ok = false
	_msg_t = 0.0
	_mm_title.text = String(day["title"])
	_mm_info.text = String(_pl_cfg["info"])
	_bar_name = tr("ENERGÍA")
	_bar_show = true
	_bar_red_low = false
	_tele_fn = func() -> Array:
		var tot := _pl_totals()
		var used: int = tot["e"]
		var sci: int = tot["s"]
		var budget: int = int(_pl_day["budget"])
		var target: int = int(_pl_day["sci_target"])
		_bar_val = clampf(float(budget - used) / float(budget) * 100.0, 0.0, 100.0)
		_bar_alert = used > budget
		return [
			[tr("PLAN"), "%d / %d" % [_pl_idx + 1, _pl_n]],
			[tr("ENERGÍA USADA"), "%d / %d" % [used, budget], RED if used > budget else GOLD],
			[tr("CIENCIA"), "%d / %d" % [sci, target], GREEN if sci >= target else GOLD],
		]
	_input_cb = _plan_input
	while not _pl_ok:
		await get_tree().process_frame
	_input_cb = Callable()
	_pl_play = 0.0
	while _pl_play < float(int(_pl_cfg["cols"])):
		await get_tree().process_frame
		if not get_tree().paused:
			_pl_play += get_process_delta_time() * 7.0
	_pl_play = -1.0
	await toast(String(_pl_cfg["msg_ok"]), GREEN, 1.4)


func _pl_totals() -> Dictionary:
	var e := 0
	var s := 0
	var miss: Array = []
	for b in _pl_blocks:
		if int(b["col"]) >= 0:
			e += int(b["energy"])
			s += int(b["sci"])
		elif bool(b["req"]):
			miss.append(String(b["label"]))
	return {"e": e, "s": s, "miss": miss}


## Devuelve "" si el bloque idx cabe en la columna col; si no, el motivo.
func _pl_valid(idx: int, col: int) -> String:
	var b: Dictionary = _pl_blocks[idx]
	var cols: int = int(_pl_cfg["cols"])
	var day_cols: int = int(_pl_cfg["day_cols"])
	var dur: int = int(b["dur"])
	if col < 0 or col + dur > cols:
		return String(_pl_cfg["msg_time"])
	match String(b["when"]):
		"day":
			if col + dur > day_cols:
				return String(_pl_cfg["msg_time"])
		"night":
			if col < day_cols:
				return String(_pl_cfg["msg_time"])
		"comm":
			var ok := false
			for w in _pl_cfg["comm"]:
				if col >= int(w[0]) and col + dur - 1 <= int(w[1]):
					ok = true
			if not ok:
				return String(_pl_cfg["msg_time"])
	for i in _pl_blocks.size():
		var o: Dictionary = _pl_blocks[i]
		if i != idx and int(o["col"]) >= 0 and col < int(o["col"]) + int(o["dur"]) and int(o["col"]) < col + dur:
			return String(_pl_cfg["msg_overlap"])
	return ""


func _pl_place(col: int) -> void:
	var b: Dictionary = _pl_blocks[_pl_sel]
	if int(b["col"]) >= 0:
		b["col"] = -1
		return
	var c := clampi(col, 0, int(_pl_cfg["cols"]) - int(b["dur"]))
	var why := _pl_valid(_pl_sel, c)
	if why != "":
		_say_msg(why, RED)
		return
	b["col"] = c


func _pl_send() -> void:
	var tot := _pl_totals()
	var miss: Array = tot["miss"]
	if not miss.is_empty():
		_say_msg(String(_pl_cfg["msg_missing"]) + " · " + tr("Falta: %s") % ", ".join(PackedStringArray(miss)), RED, 3.2)
		return
	if int(tot["e"]) > int(_pl_day["budget"]):
		_say_msg(String(_pl_cfg["msg_energy"]), RED)
		return
	if int(tot["s"]) < int(_pl_day["sci_target"]):
		_say_msg(String(_pl_cfg["msg_science"]), RED)
		return
	_pl_ok = true


func _pl_tray_rect(i: int) -> Rect2:
	return Rect2(16.0 + float(i % 3) * 204.0, 176.0 + float(i / 3) * 34.0, 198.0, 30.0)


func _pl_send_rect() -> Rect2:
	return Rect2(520, 148, 104, 20)


func _plan_input(event: InputEvent, click: bool) -> void:
	if _pl_play >= 0.0:
		return
	var lane := Rect2(PL_X0, PL_Y, PL_CW * 24.0, PL_H)
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		if lane.has_point(p):
			_pl_cur = clampi(int((p.x - PL_X0) / PL_CW), 0, 23)
	elif click:
		var p := get_local_mouse_position()
		for i in _pl_blocks.size():
			if _pl_tray_rect(i).has_point(p):
				_pl_sel = i
				if int((_pl_blocks[i] as Dictionary)["col"]) >= 0:
					(_pl_blocks[i] as Dictionary)["col"] = -1
				return
		if lane.has_point(p):
			_pl_cur = clampi(int((p.x - PL_X0) / PL_CW), 0, 23)
			_pl_place(_pl_cur)
		elif _pl_send_rect().has_point(p):
			_pl_send()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n := _pl_blocks.size()
		match int(event.physical_keycode):
			KEY_Q: _pl_sel = (_pl_sel + n - 1) % n
			KEY_E: _pl_sel = (_pl_sel + 1) % n
			KEY_A, KEY_LEFT: _pl_cur = maxi(0, _pl_cur - 1)
			KEY_D, KEY_RIGHT: _pl_cur = mini(23, _pl_cur + 1)
			KEY_P: _pl_send()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _pl_place(_pl_cur)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				var k: int = int(event.physical_keycode) - KEY_1
				if k < n:
					_pl_sel = k


func _draw_plan(c: DrawNode) -> void:
	var cfg := _pl_cfg
	if cfg.is_empty() or _pl_blocks.is_empty():
		return
	var cols: int = int(cfg["cols"])
	var day_cols: int = int(cfg["day_cols"])
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), PANEL)
	# Línea de tiempo: día (claro) y noche (oscuro).
	c.draw_rect(Rect2(PL_X0, PL_Y, PL_CW * float(day_cols), PL_H), Color("#4a3228"))
	c.draw_rect(Rect2(PL_X0 + PL_CW * float(day_cols), PL_Y, PL_CW * float(cols - day_cols), PL_H), Color("#161a2e"))
	_txt(c, Vector2(PL_X0, PL_Y - 14), tr("DÍA"), 10, YEL, PL_CW * float(day_cols), HORIZONTAL_ALIGNMENT_CENTER)
	_txt(c, Vector2(PL_X0 + PL_CW * float(day_cols), PL_Y - 14), tr("NOCHE"), 10, CYAN, PL_CW * float(cols - day_cols), HORIZONTAL_ALIGNMENT_CENTER)
	for w in cfg["comm"]:
		var wr := Rect2(PL_X0 + PL_CW * float(int(w[0])), PL_Y - 6, PL_CW * float(int(w[1]) - int(w[0]) + 1), PL_H + 12)
		c.draw_rect(wr, Color(CYAN, 0.22))
		c.draw_rect(wr, CYAN, false, 1.0)
		_txt(c, Vector2(wr.position.x - 8, PL_Y + PL_H + 16), tr("ENLACE"), 8, CYAN, wr.size.x + 16, HORIZONTAL_ALIGNMENT_CENTER)
	for i in cols + 1:
		c.draw_line(Vector2(PL_X0 + PL_CW * float(i), PL_Y), Vector2(PL_X0 + PL_CW * float(i), PL_Y + PL_H), Color(0, 0, 0, 0.45), 1.0)
	c.draw_rect(Rect2(PL_X0, PL_Y, PL_CW * float(cols), PL_H), GRAY_DIM, false, 1.0)
	# Vista previa del bloque elegido.
	var sb: Dictionary = _pl_blocks[_pl_sel]
	if int(sb["col"]) < 0 and _pl_play < 0.0:
		var pc := clampi(_pl_cur, 0, cols - int(sb["dur"]))
		var ok := _pl_valid(_pl_sel, pc) == ""
		var pr := Rect2(PL_X0 + PL_CW * float(pc), PL_Y + 2, PL_CW * float(int(sb["dur"])), PL_H - 4)
		c.draw_rect(pr, Color(GREEN if ok else RED, 0.35))
		c.draw_rect(pr, GREEN if ok else RED, false, 1.0)
	# Bloques colocados (llevan el número de su tarjeta).
	for i in _pl_blocks.size():
		var b: Dictionary = _pl_blocks[i]
		if int(b["col"]) < 0:
			continue
		var r := Rect2(PL_X0 + PL_CW * float(int(b["col"])) + 1, PL_Y + 2, PL_CW * float(int(b["dur"])) - 2, PL_H - 4)
		var fill := _pl_color(b)
		c.draw_rect(r, fill)
		c.draw_rect(r, Color.WHITE if i == _pl_sel else fill.lightened(0.4), false, 1.0)
		_txt(c, Vector2(r.position.x, r.position.y + 18), str(i + 1), 12, Color("#1a1210"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if _pl_play >= 0.0:
		var px := PL_X0 + PL_CW * _pl_play
		c.draw_rect(Rect2(PL_X0, PL_Y, PL_CW * _pl_play, PL_H), Color(1, 1, 1, 0.12))
		c.draw_line(Vector2(px, PL_Y - 6), Vector2(px, PL_Y + PL_H + 6), Color.WHITE, 2.0)
	# Tarjetas de tareas.
	_txt(c, Vector2(16, 172), tr("- ENERGÍA   + CIENCIA"), 8, GRAY_DIM)
	for i in _pl_blocks.size():
		var b: Dictionary = _pl_blocks[i]
		var r := _pl_tray_rect(i)
		var placed := int(b["col"]) >= 0
		var border := GOLD if i == _pl_sel else (GREEN if placed else GRAY_DIM)
		c.draw_rect(r, Color("#2a1c16") if not placed else Color("#16281a"))
		c.draw_rect(r, border, false, 2.0 if i == _pl_sel else 1.0)
		c.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 14, 24), _pl_color(b))
		_txt(c, Vector2(r.position.x + 3, r.position.y + 20), str(i + 1), 12, Color("#1a1210"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(c, Vector2(r.position.x + 22, r.position.y + 13), String(b["label"]), 10, Color.WHITE, r.size.x - 26)
		var info := "-%d" % int(b["energy"])
		if int(b["sci"]) > 0:
			info += "   +%d" % int(b["sci"])
		if bool(b["req"]):
			info = tr("OBLIGATORIA") + "   " + info
		_txt(c, Vector2(r.position.x + 22, r.position.y + 25), info, 9, GOLD if not bool(b["req"]) else YEL, r.size.x - 26)
	# Botón ENVIAR.
	var sr := _pl_send_rect()
	_box(c, sr, Color("#2a3a1c"), GREEN, tr("ENVIAR [P]"), 10, GREEN)
	_txt(c, Vector2(150, 172), String(cfg["tip_comm"]), 8, GRAY_DIM, 470)
	_draw_msg(c, 140)


func _pl_color(b: Dictionary) -> Color:
	if int(b["sci"]) > 0:
		return GREEN
	if bool(b["req"]):
		return YEL
	return MARS_LIGHT


# =========================================================================
# FASE 1 · Detective del agua
# =========================================================================
func _act_water(sc: Dictionary) -> void:
	await say(sc["intro"])
	_wd_cfg = sc["minimission"]
	_mm_title.text = String(_wd_cfg["title"])
	_mm_info.text = String(_wd_cfg["info"])
	_wd_energy = float(_wd_cfg["energy"])
	_wd_sel = 0
	_wd_used = {}
	_wd_solved = {}
	_wd_log = ""
	_wd_stage = "pick"
	_bar_name = tr("ENERGÍA")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _wd_energy / float(_wd_cfg["energy"]) * 100.0
		return [[tr("MEDICIONES"), "%d" % int(_wd_energy / float(_wd_cfg["cost"]))], [tr("EVIDENCIAS"), "%d / %d" % [_wd_solved.size(), (_wd_cfg["targets"] as Array).size()]]]
	_layer(_draw_water)
	_input_cb = _water_input
	while _wd_stage != "done":
		await get_tree().process_frame
	_input_cb = Callable()
	await say(sc["outro"])


func _wd_card_rect(i: int) -> Rect2:
	return Rect2(12, 84.0 + float(i) * 70.0, 300, 64)


func _wd_tool_rect(j: int) -> Rect2:
	return Rect2(326, 84.0 + float(j) * 32.0, 302, 29)


func _wd_opt_rect(j: int) -> Rect2:
	return Rect2(326, 100.0 + float(j) * 34.0, 302, 30)


func _water_input(event: InputEvent, click: bool) -> void:
	var targets: Array = _wd_cfg["targets"]
	if _wd_stage == "pick":
		if click:
			var p := get_local_mouse_position()
			for i in targets.size():
				if _wd_card_rect(i).has_point(p):
					_wd_sel = i
			for j in (_wd_cfg["tools"] as Array).size():
				if _wd_tool_rect(j).has_point(p):
					_water_use(j)
		elif event is InputEventKey and event.pressed and not event.echo:
			var k := int(event.physical_keycode)
			if k >= KEY_1 and k <= KEY_4:
				_water_use(k - KEY_1)
			elif k == KEY_UP or k == KEY_W:
				_wd_sel = (_wd_sel + targets.size() - 1) % targets.size()
			elif k == KEY_DOWN or k == KEY_S:
				_wd_sel = (_wd_sel + 1) % targets.size()
	elif _wd_stage == "quiz":
		if click:
			var p := get_local_mouse_position()
			for j in (_wd_cfg["options"] as Array).size():
				if _wd_opt_rect(j).has_point(p):
					_water_answer(j)
		elif event is InputEventKey and event.pressed and not event.echo:
			var k := int(event.physical_keycode)
			if k >= KEY_1 and k <= KEY_3:
				_water_answer(k - KEY_1)


func _water_use(j: int) -> void:
	var tools: Array = _wd_cfg["tools"]
	var targets: Array = _wd_cfg["targets"]
	var tg: Dictionary = targets[_wd_sel]
	var tid := String(tg["id"])
	if _wd_solved.has(tid):
		return
	var tool_id := String((tools[j] as Dictionary)["id"])
	var used: Array = _wd_used.get(tid, [])
	if used.has(tool_id):
		return
	if _wd_energy < float(_wd_cfg["cost"]):
		_wd_energy = float(_wd_cfg["energy"])
		_wd_used = {}
		_wd_log = ""
		_say_msg(String(_wd_cfg["no_energy"]), RED, 2.8)
		return
	_wd_energy -= float(_wd_cfg["cost"])
	var needs: Array = tg["needs"]
	var useful := needs.has(tool_id)
	var text := String((tg["results"] as Dictionary)[tool_id])
	if bool(tg["ordered"]) and tool_id == "apxs" and not used.has("rat"):
		text = String(tg["dusty"])
		useful = false
	_wd_log = text
	_wd_log_col = GREEN if useful else GRAY_DIM
	if useful:
		used.append(tool_id)
		_wd_used[tid] = used
		var done := true
		for n in needs:
			if not used.has(n):
				done = false
		if done:
			_wd_solved[tid] = true
			_add_evidence(tg["evidence"])
			_wd_log = String(_wd_cfg["done_target"]) + " · " + String((tg["evidence"] as Dictionary)["text"])
			_wd_log_col = YEL
			for i in targets.size():
				if not _wd_solved.has(String((targets[i] as Dictionary)["id"])):
					_wd_sel = i
			if _wd_solved.size() == targets.size():
				_wd_stage = "quiz"
				_wd_log = ""
	else:
		_wd_log = text


func _water_answer(j: int) -> void:
	if j == int(_wd_cfg["correct"]):
		_say_msg(String(_wd_cfg["right"]), GREEN, 2.5)
		_wd_stage = "done"
		await toast(String(_wd_cfg["right"]), GREEN, 1.6)
	else:
		_say_msg(String(_wd_cfg["wrong"]), RED, 2.8)


func _draw_water(c: DrawNode) -> void:
	if _wd_cfg.is_empty():
		return
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), PANEL)
	var targets: Array = _wd_cfg["targets"]
	var tools: Array = _wd_cfg["tools"]
	if _wd_stage == "quiz" or _wd_stage == "done":
		_txt(c, Vector2(326, 80), String(_wd_cfg["question"]), 10, YEL, 302)
		var opts: Array = _wd_cfg["options"]
		for j in opts.size():
			var r := _wd_opt_rect(j)
			_box(c, r, Color("#2a1c16"), GOLD, "", 9)
			_txt(c, Vector2(r.position.x + 6, r.position.y + 12), "%d" % (j + 1), 11, GOLD)
			c.draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 22, r.position.y + 12), String(opts[j]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 9, 2, Color.WHITE)
	else:
		for j in tools.size():
			var t: Dictionary = tools[j]
			var r := _wd_tool_rect(j)
			_box(c, r, Color("#2a1c16"), GRAY_DIM)
			_txt(c, Vector2(r.position.x + 6, r.position.y + 12), String(t["name"]), 10, GOLD, r.size.x - 8)
			_txt(c, Vector2(r.position.x + 6, r.position.y + 24), String(t["q"]), 8, GRAY, r.size.x - 8)
	for i in targets.size():
		var tg: Dictionary = targets[i]
		var r := _wd_card_rect(i)
		var tid := String(tg["id"])
		var solved := _wd_solved.has(tid)
		c.draw_rect(r, Color("#16281a") if solved else Color("#2a1c16"))
		c.draw_rect(r, GREEN if solved else (GOLD if i == _wd_sel else GRAY_DIM), false, 2.0 if i == _wd_sel else 1.0)
		# Muestra: esferas o capas.
		if tid == "esferas":
			for k in 7:
				c.draw_circle(Vector2(r.position.x + 22 + float(k % 4) * 8.0, r.position.y + 22 + float(k / 4) * 10.0), 3.0, Color("#7a8ac8") if not solved else CYAN)
		else:
			for k in 5:
				c.draw_rect(Rect2(r.position.x + 8, r.position.y + 10 + float(k) * 8.0, 34.0, 5), MARS_DARK.lerp(MARS_LIGHT, float(k) / 5.0))
		_txt(c, Vector2(r.position.x + 52, r.position.y + 15), String(tg["name"]), 10, Color.WHITE, r.size.x - 56)
		c.draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 52, r.position.y + 28), String(tg["desc"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 8, 2, GRAY)
		var used: Array = _wd_used.get(tid, [])
		var needs: Array = tg["needs"]
		var xx := r.position.x + 52
		for n in needs:
			var done := used.has(n)
			_box(c, Rect2(xx, r.position.y + 48, 44, 12), Color("#1a3a1c") if done else Color("#1a1210"), GREEN if done else GRAY_DIM, String(n).to_upper(), 8, GREEN if done else GRAY_DIM)
			xx += 48.0
	# Registro de lectura.
	var lr := Rect2(12, 226, 616, 36)
	c.draw_rect(lr, Color("#120c0a"))
	c.draw_rect(lr, GRAY_DIM, false, 1.0)
	_txt(c, Vector2(18, 237), tr("LECTURA"), 8, GRAY_DIM)
	var shown := _wd_log if _wd_log != "" else tr("SIN LECTURA TODAVÍA")
	c.draw_multiline_string(ThemeDB.fallback_font, Vector2(70, 237), shown, HORIZONTAL_ALIGNMENT_LEFT, 552, 10, 2, _wd_log_col if _wd_log != "" else GRAY_DIM)
	_draw_msg(c, 206)


# =========================================================================
# FASE 2 · Atrapada en Purgatory (ensayo en la Tierra + escape real)
# =========================================================================
func _act_sand(sc: Dictionary) -> void:
	await _cinematic_pending(String(sc["cinematic_tag"]))
	await say(sc["intro"])
	_sd_cfg = sc["minimission"]
	_mm_title.text = String(_sd_cfg["title"])
	_sd_test = true
	_sd_free = false
	_sd_reset()
	_sd_info()
	_bar_name = tr("HUNDIMIENTO")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _sd_sink * 100.0
		_bar_alert = _sd_sink > 0.7
		var sols := tr("ENSAYO") if _sd_test else "%d / %d" % [_sd_sol, int(_sd_cfg["sols_real"])]
		return [
			[tr("PROGRESO"), "%d%%" % int(_sd_prog * 100.0)],
			[tr("PATINAJE"), "%d%%" % int(_sd_slip * 100.0), RED if _sd_slip > 0.6 else GOLD],
			[tr("SOLES"), sols, CYAN if _sd_test else GOLD],
		]
	_layer(_draw_sand)
	_input_cb = _sand_input
	while not _sd_free:
		await get_tree().process_frame
	_input_cb = Callable()
	await say(sc["outro"])


func _sd_reset() -> void:
	_sd_prog = 0.0
	_sd_sink = float(_sd_cfg["start_sink"])
	_sd_slip = 0.0
	_sd_queue = []
	_sd_sol = 0
	_sd_x = 0.0
	_sd_busy = false


func _sd_info() -> void:
	_mm_info.text = String(_sd_cfg["info_test"]) if _sd_test else String(_sd_cfg["info_real"])


func _sd_slot_rect(i: int) -> Rect2:
	return Rect2(16.0 + float(i) * 54.0, 176, 50, 22)


func _sd_send_rect() -> Rect2:
	return Rect2(240, 176, 130, 22)


func _sd_cmd_rect(i: int) -> Rect2:
	return Rect2(10.0 + float(i) * 156.0, 208, 150, 26)


const SD_KEYS := ["fl", "fs", "bs", "bl"]


func _sand_input(event: InputEvent, click: bool) -> void:
	if _sd_busy:
		return
	if click:
		var p := get_local_mouse_position()
		for i in 4:
			if _sd_cmd_rect(i).has_point(p):
				_sd_add(i)
		if _sd_send_rect().has_point(p):
			_sd_send()
		for i in _sd_queue.size():
			if _sd_slot_rect(i).has_point(p):
				_sd_queue.remove_at(i)
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k >= KEY_1 and k <= KEY_4:
			_sd_add(k - KEY_1)
		elif k == KEY_BACKSPACE and not _sd_queue.is_empty():
			_sd_queue.pop_back()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_sd_send()


func _sd_add(i: int) -> void:
	if _sd_queue.size() < 4:
		_sd_queue.append(SD_KEYS[i])


func _sd_send() -> void:
	if _sd_queue.is_empty() or _sd_busy:
		return
	_sd_run()


func _sd_run() -> void:
	_sd_busy = true
	var k: float = float(_sd_cfg["k_test"]) if _sd_test else float(_sd_cfg["k_real"])
	var cmds: Dictionary = _sd_cfg["cmds"]
	var batch: Array = _sd_queue.duplicate()
	for cmd in batch:
		var cd: Dictionary = cmds[String(cmd)]
		var step: float = float(cd["step"])
		await wait(0.6)
		if step > 0.0:
			var slip := clampf(float(cd["slip0"]) * k + 0.9 * _sd_sink * k, 0.0, 1.0)
			_sd_slip = slip
			if slip > float(_sd_cfg["slip_limit"]):
				_say_msg(String(_sd_cfg["slip_stop"]), RED, 2.4)
				_sd_spin += 3.0
				continue
			_sd_prog += step * (1.0 - slip)
			_sd_sink = minf(1.0, _sd_sink + float(cd["sink"]) * slip * k)
		else:
			_sd_slip = 0.0
			_sd_prog += step * 0.5
			_sd_sink = maxf(0.0, _sd_sink - float(cd["relief"]))
		_sd_prog = maxf(0.0, _sd_prog)
		if _sd_prog >= 1.0:
			break
	_sd_queue = []
	_sd_sol += 1
	_sd_busy = false
	if _sd_prog >= 1.0:
		if _sd_test:
			await toast(String(_sd_cfg["test_ok"]), GREEN, 1.8)
			_sd_test = false
			_sd_reset()
			_sd_info()
		else:
			await toast(String(_sd_cfg["freed"]), GREEN, 1.8)
			_sd_free = true
	elif not _sd_test and _sd_sol >= int(_sd_cfg["sols_real"]):
		await toast(String(_sd_cfg["fail_real"]), RED, 1.8)
		_sd_reset()


func _draw_sand(c: DrawNode) -> void:
	if _sd_cfg.is_empty():
		return
	_mars_sky(c, GAME_TOP, 150.0)
	_mars_ground(c, 150.0, 21)
	# Duna: más oscura donde la arena es blanda.
	c.draw_rect(Rect2(0, 150, W, 56), Color(MARS_LIGHT, 0.35))
	for i in 12:
		c.draw_line(Vector2(float(i) * 60.0, 160), Vector2(float(i) * 60.0 + 40.0, 160 + sin(float(i)) * 5.0), Color(MARS_DARK, 0.6), 1.0)
	_txt(c, Vector2(0, 142), "PURGATORY", 9, GRAY_DIM, W, HORIZONTAL_ALIGNMENT_CENTER)
	# Rover.
	_sd_x = lerpf(_sd_x, _sd_prog, 0.1)
	if _sd_busy:
		_sd_spin += 0.35
	var rx := 70.0 + _sd_x * 470.0
	var ry := 148.0
	_draw_rover_side(c, Vector2(rx, ry), 2.2, _sd_sink * 1.6, _sd_spin, SILVER)
	if _sd_busy and _sd_slip > 0.3:
		for i in 8:
			c.draw_rect(Rect2(rx - 30.0 + randf() * 14.0, ry + 4.0 + randf() * 8.0, 2, 2), MARS_LIGHT)
	# Meta.
	c.draw_line(Vector2(70.0 + 470.0, 126), Vector2(70.0 + 470.0, 156), GREEN, 1.0)
	_txt(c, Vector2(480, 120), ">", 12, GREEN, 120, HORIZONTAL_ALIGNMENT_CENTER)
	# Cola de comandos.
	for i in 4:
		var r := _sd_slot_rect(i)
		var has := i < _sd_queue.size()
		_box(c, r, Color("#2a1c16") if has else Color("#120c0a"), GOLD if has else GRAY_DIM, _sd_short(String(_sd_queue[i])) if has else "", 9, Color.WHITE)
	_box(c, _sd_send_rect(), Color("#2a3a1c") if not _sd_busy else Color("#1a1210"), GREEN if not _sd_busy else GRAY_DIM, tr("ENVIAR [ENTER]"), 10, GREEN if not _sd_busy else GRAY_DIM)
	var names := [tr("1 AVANZAR LARGO"), tr("2 AVANZAR CORTO"), tr("3 RETROCEDER CORTO"), tr("4 RETROCEDER LARGO")]
	for i in 4:
		_box(c, _sd_cmd_rect(i), Color("#2a1c16"), GRAY_DIM, String(names[i]), 9, GOLD)
	_txt(c, Vector2(400, 192), tr("ENSAYO") if _sd_test else tr("MARTE"), 11, CYAN if _sd_test else GOLD, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_msg(c, 118)


func _sd_short(cmd: String) -> String:
	match cmd:
		"fl": return ">>"
		"fs": return ">"
		"bs": return "<"
		"bl": return "<<"
	return cmd


# =========================================================================
# FASE 3 · La rueda arrastrada (conducción vista desde arriba)
# =========================================================================
var _wh_cfg: Dictionary = {}
var _wh_pos := Vector2(40, 236)
var _wh_ang := -0.45
var _wh_energy := 100.0
var _wh_trail: Array = []
var _wh_patches: Array = []
var _wh_found := 0
var _wh_an := 0.0
var _wh_done := false
var _wh_moving := false
var _wh_hint_t := 0.0


func _act_wheel(sc: Dictionary) -> void:
	await say(sc["intro"])
	_wh_cfg = sc["minimission"]
	_mm_title.text = String(_wh_cfg["title"])
	_mm_info.text = String(_wh_cfg["info"])
	_wh_patches = []
	var zi := 0
	for z in _wh_cfg["zones"]:
		var zd: Dictionary = z
		var off := Vector2(float(zd["r"]) * 0.25, -float(zd["r"]) * 0.2) * (1.0 if zi % 2 == 0 else -1.0)
		_wh_patches.append({"pos": Vector2(float(zd["x"]), float(zd["y"])) + off, "kind": String(zd["kind"]), "found": false, "done": false})
		zi += 1
	_wh_found = 0
	_wh_done = false
	_wh_reset_run()
	_bar_name = tr("ENERGÍA")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _wh_energy
		return [[tr("MUESTRAS"), "%d / %d" % [_wh_found, int(_wh_cfg["need"])], GREEN if _wh_found >= int(_wh_cfg["need"]) else GOLD]]
	_layer(_draw_wheel)
	while not _wh_done:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		_wheel_step(get_process_delta_time())
	await toast(String(_wh_cfg["silica"]), GREEN, 1.6)
	await say(sc["outro"])
	for ev in sc["evidence"]:
		await _add_evidence(ev)


func _wh_reset_run() -> void:
	_wh_pos = Vector2(40, 236)
	_wh_ang = -0.45
	_wh_energy = 100.0
	_wh_trail = []
	_wh_an = 0.0
	for p in _wh_patches:
		if not bool(p["done"]):
			p["found"] = false


func _wheel_step(delta: float) -> void:
	var thr := Input.is_action_pressed("thrust")
	var steer := _axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)
	_wh_moving = thr and _wh_energy > 0.0
	if _wh_moving:
		# La rueda arrastrada tira del rover hacia la derecha: hay que corregir con A / D.
		_wh_ang += (steer * 1.9 + float(_wh_cfg["bias"])) * delta
		var np := _wh_pos + Vector2.from_angle(_wh_ang) * float(_wh_cfg["speed"]) * delta
		var blocked := false
		for r in _wh_cfg["rocks"]:
			if np.distance_to(Vector2(float(r[0]), float(r[1]))) < float(r[2]) + 6.0:
				blocked = true
		if blocked:
			_wh_energy -= 9.0 * delta
		else:
			_wh_pos = np.clamp(Vector2(10, 84), Vector2(630, 256))
		_wh_energy -= float(_wh_cfg["burn"]) * delta
		if _wh_trail.is_empty() or (_wh_trail[_wh_trail.size() - 1] as Vector2).distance_to(_wh_pos) > 5.0:
			_wh_trail.append(_wh_pos)
			if _wh_trail.size() > 700:
				_wh_trail.pop_front()
	# Descubrir suelo claro bajo el surco.
	for p in _wh_patches:
		if not bool(p["found"]) and not bool(p["done"]):
			for tp in _wh_trail:
				if (tp as Vector2).distance_to(p["pos"]) < 12.0:
					p["found"] = true
					_say_msg(String(_wh_cfg["found"]), YEL, 2.0)
					break
	# Analizar: quieto, cerca de un parche descubierto, manteniendo E o ENTER.
	var holding := (Input.is_action_pressed("interact") or Input.is_action_pressed("ui_accept")) and not thr
	var target := -1
	for i in _wh_patches.size():
		var p: Dictionary = _wh_patches[i]
		if bool(p["found"]) and not bool(p["done"]) and _wh_pos.distance_to(p["pos"]) < 22.0:
			target = i
	if holding and target >= 0:
		_wh_an += delta / float(_wh_cfg["analyze_s"])
		if _wh_an >= 1.0:
			_wh_an = 0.0
			var p: Dictionary = _wh_patches[target]
			p["done"] = true
			if String(p["kind"]) == "silice":
				_wh_found += 1
				_say_msg(String(_wh_cfg["silica"]), GREEN, 2.4)
			else:
				_say_msg(String(_wh_cfg["decoy"]), GRAY, 2.4)
			if _wh_found >= int(_wh_cfg["need"]):
				_wh_done = true
	else:
		_wh_an = maxf(0.0, _wh_an - delta * 2.0)
	if _wh_energy <= 0.0:
		_say_msg(String(_wh_cfg["no_energy"]), RED, 2.6)
		_wh_reset_run()


func _draw_wheel(c: DrawNode) -> void:
	if _wh_cfg.is_empty():
		return
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), MARS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 160:
		c.draw_rect(Rect2(floorf(rng.randf() * W), floorf(GAME_TOP + 60.0 + rng.randf() * 184.0), 2, 1), MARS_DARK if i % 2 == 0 else MARS_LIGHT)
	# Zonas sospechosas vistas desde la órbita (círculos punteados).
	for z in _wh_cfg["zones"]:
		var zc := Vector2(float(z["x"]), float(z["y"]))
		for k in 28:
			if k % 2 == 0:
				var a0 := float(k) / 28.0 * TAU
				c.draw_arc(zc, float(z["r"]), a0, a0 + TAU / 28.0, 4, Color(CYAN, 0.7), 1.0)
		_txt(c, zc + Vector2(-60, -float(z["r"]) - 3), String(_wh_cfg["zone_hint"]), 7, Color(CYAN, 0.8), 120, HORIZONTAL_ALIGNMENT_CENTER)
	for r in _wh_cfg["rocks"]:
		var rc := Vector2(float(r[0]), float(r[1]))
		c.draw_circle(rc + Vector2(1, 2), float(r[2]), Color(0, 0, 0, 0.3))
		c.draw_circle(rc, float(r[2]), Color("#5a3a30"))
		c.draw_circle(rc + Vector2(-2, -2), float(r[2]) * 0.6, Color("#7a5444"))
	# Surco de la rueda.
	for tp in _wh_trail:
		c.draw_rect(Rect2((tp as Vector2) - Vector2(1.5, 1.5), Vector2(3, 3)), MARS_DARK)
	# Suelo claro descubierto.
	for p in _wh_patches:
		if bool(p["found"]) or bool(p["done"]):
			var pp: Vector2 = p["pos"]
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			c.draw_circle(pp, 9.0 + pulse * 2.0, Color(1, 1, 0.9, 0.25))
			c.draw_circle(pp, 6.0, Color("#f4f0e8"))
			if bool(p["done"]):
				c.draw_arc(pp, 11.0, 0, TAU, 20, GREEN if String(p["kind"]) == "silice" else GRAY_DIM, 1.5)
	_draw_rover_top(c, _wh_pos, _wh_ang, 1.5, true)
	if _wh_an > 0.0:
		c.draw_arc(_wh_pos, 16.0, -PI * 0.5, -PI * 0.5 + TAU * _wh_an, 24, YEL, 2.0)
		_txt(c, _wh_pos + Vector2(-50, -22), tr("ANALIZANDO..."), 8, YEL, 100, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_msg(c, 232)


# =========================================================================
# FASE 4 · Invierno en Troy (reparto de energía por tramos)
# =========================================================================
var _wi_cfg: Dictionary = {}
var _wi_turn := 0
var _wi_temp := 70.0
var _wi_batt := 60.0
var _wi_sci := 0.0
var _wi_miss := 0
var _wi_alloc: Array = [20.0, 6.0, 10.0]
var _wi_row := 0
var _wi_busy := false
var _wi_won := false


func _act_winter(sc: Dictionary) -> void:
	await _cinematic_pending(String(sc["cinematic_tag"]))
	await say(sc["intro"])
	_wi_cfg = sc["minimission"]
	_mm_title.text = String(_wi_cfg["title"])
	_mm_info.text = String(_wi_cfg["info"])
	_wi_reset()
	_wi_won = false
	_bar_name = tr("TEMPERATURA")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _wi_temp
		return [
			[tr("TRAMO %d DE %d") % [mini(_wi_turn + 1, int(_wi_cfg["turns"])), int(_wi_cfg["turns"])], ""],
			[tr("BATERÍA"), "%d" % int(_wi_batt), RED if _wi_batt < 15.0 else GOLD],
			[tr("CIENCIA"), "%d / %d" % [int(_wi_sci), int(_wi_cfg["sci_goal"])], GREEN if _wi_sci >= float(_wi_cfg["sci_goal"]) else GOLD],
		]
	_layer(_draw_winter)
	_input_cb = _winter_input
	while not _wi_won:
		await get_tree().process_frame
	_input_cb = Callable()
	await _winter_final(sc)
	await say(sc["outro"])


func _wi_reset() -> void:
	_wi_turn = 0
	_wi_temp = float(_wi_cfg["temp_start"])
	_wi_batt = float(_wi_cfg["batt_start"])
	_wi_sci = 0.0
	_wi_miss = 0
	_wi_row = 0
	_wi_busy = false
	_wi_alloc = [_wi_need(), float(_wi_cfg["comm_need"]), 0.0]
	_wi_alloc[2] = maxf(0.0, _wi_avail() - _wi_alloc[0] - _wi_alloc[1])
	_wi_fit()


func _wi_income() -> float:
	var inc: Array = _wi_cfg["income"]
	return float(inc[mini(_wi_turn, inc.size() - 1)])


func _wi_need() -> float:
	return float(_wi_cfg["heat_base"]) + float(_wi_cfg["heat_growth"]) * float(_wi_turn)


func _wi_avail() -> float:
	return _wi_income() + minf(_wi_batt, float(_wi_cfg["batt_draw"]))


func _wi_total() -> float:
	return float(_wi_alloc[0]) + float(_wi_alloc[1]) + float(_wi_alloc[2])


## Ajusta el reparto a la energía disponible (primero recorta ciencia, luego comunicación, luego calor).
func _wi_fit() -> void:
	var av := _wi_avail()
	for idx in [2, 1, 0]:
		var over := _wi_total() - av
		if over <= 0.0:
			break
		_wi_alloc[idx] = maxf(0.0, float(_wi_alloc[idx]) - over)
	for i in 3:
		_wi_alloc[i] = roundf(float(_wi_alloc[i]))


func _wi_row_rect(i: int) -> Rect2:
	return Rect2(262, 84.0 + float(i) * 38.0, 366, 34)


func _wi_btn_rect(i: int, plus: bool) -> Rect2:
	return Rect2(576.0 + (24.0 if plus else 0.0), 100.0 + float(i) * 38.0, 20, 16)


func _wi_send_rect() -> Rect2:
	return Rect2(492, 232, 136, 24)


func _winter_input(event: InputEvent, click: bool) -> void:
	if _wi_busy:
		return
	if click:
		var p := get_local_mouse_position()
		for i in 3:
			if _wi_row_rect(i).has_point(p):
				_wi_row = i
			if _wi_btn_rect(i, false).has_point(p):
				_wi_change(i, -1.0)
			if _wi_btn_rect(i, true).has_point(p):
				_wi_change(i, 1.0)
		if _wi_send_rect().has_point(p):
			_winter_send()
	elif event is InputEventKey and event.pressed:
		match int(event.physical_keycode):
			KEY_UP, KEY_W: _wi_row = (_wi_row + 2) % 3
			KEY_DOWN, KEY_S: _wi_row = (_wi_row + 1) % 3
			KEY_LEFT, KEY_A: _wi_change(_wi_row, -1.0)
			KEY_RIGHT, KEY_D: _wi_change(_wi_row, 1.0)
			KEY_ENTER, KEY_KP_ENTER:
				if not event.echo:
					_winter_send()


func _wi_change(row: int, dir: float) -> void:
	var step := float(_wi_cfg["step"]) * dir
	var nv := maxf(0.0, float(_wi_alloc[row]) + step)
	if dir > 0.0 and _wi_total() + step > _wi_avail() + 0.01:
		_say_msg(String(_wi_cfg["over"]), RED, 1.4)
		return
	_wi_alloc[row] = nv


func _wi_predict() -> Dictionary:
	var h := float(_wi_alloc[0])
	var temp := clampf(_wi_temp + float(_wi_cfg["temp_gain"]) * (h - _wi_need()), 0.0, 100.0)
	var batt := clampf(_wi_batt + _wi_income() - _wi_total(), 0.0, 100.0)
	return {"temp": temp, "batt": batt}


func _winter_send() -> void:
	_wi_busy = true
	var pr := _wi_predict()
	var comm_ok := float(_wi_alloc[1]) >= float(_wi_cfg["comm_need"])
	_wi_temp = float(pr["temp"])
	_wi_batt = float(pr["batt"])
	_wi_sci += float(_wi_alloc[2]) / 5.0
	_wi_miss = 0 if comm_ok else _wi_miss + 1
	_wi_turn += 1
	_wi_busy = false
	var fail := ""
	if _wi_temp <= float(_wi_cfg["temp_min"]):
		fail = String(_wi_cfg["msg_cold"])
	elif _wi_miss >= 2:
		fail = String(_wi_cfg["msg_silent"])
	if fail != "":
		_wi_busy = true
		await toast(fail, RED, 2.0)
		await toast(String(_wi_cfg["msg_retry"]), GOLD, 1.0)
		_wi_reset()
		return
	if _wi_turn >= int(_wi_cfg["turns"]):
		if _wi_sci >= float(_wi_cfg["sci_goal"]):
			_wi_won = true
		else:
			_wi_busy = true
			await toast(String(_wi_cfg["msg_end"]) % int(_wi_sci), GOLD, 2.0)
			await toast(String(_wi_cfg["msg_low_sci"]), RED, 2.0)
			_wi_reset()
		return
	_wi_fit()


func _winter_final(sc: Dictionary) -> void:
	_clear_scene_only()
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.position = Vector2(0, GAME_TOP)
	panel.size = Vector2(W, GAME_BOTTOM - GAME_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)
	var l := _label(Vector2(0, 96), Vector2(W, 26), 20, GOLD, ui_layer)
	l.text = String(sc["final_title"])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := _label(Vector2(0, 130), Vector2(W, 18), 12, GRAY, ui_layer)
	l2.text = String(sc["final_sub"])
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.8)
	l.modulate.a = 0.0
	l2.modulate.a = 0.0
	create_tween().tween_property(l, "modulate:a", 1.0, 1.4)
	create_tween().tween_property(l2, "modulate:a", 1.0, 1.4)
	await wait(0.6)
	await wait_click_or_accept(5.0)
	panel.queue_free()
	l.queue_free()
	l2.queue_free()


## Borra el escenario dibujado pero conserva textos de la fase (para pantallas finales).
func _clear_scene_only() -> void:
	_bar_show = false
	_tele_fn = Callable()
	_tele = []
	for n in world.get_children():
		world.remove_child(n)
		n.queue_free()


func _draw_winter(c: DrawNode) -> void:
	if _wi_cfg.is_empty():
		return
	var turns: int = int(_wi_cfg["turns"])
	var f := float(mini(_wi_turn, turns - 1)) / float(turns - 1)
	# Escena (izquierda): cielo que se oscurece, Sol cada vez más bajo y Spirit casi enterrada.
	c.draw_rect(Rect2(0, GAME_TOP, 256, GAME_BOTTOM - GAME_TOP), PANEL)
	_mars_sky(c, 80.0, 170.0, 0.15 + f * 0.45)
	c.draw_rect(Rect2(8, 80, 244, 90), Color(0, 0, 0, 0))
	var sun := Vector2(200, lerpf(118.0, 162.0, f))
	c.draw_circle(sun, 9.0, Color("#ffe8b0"))
	c.draw_circle(sun, 14.0, Color(1, 0.9, 0.6, 0.18))
	c.draw_rect(Rect2(8, 170, 244, 70), MARS_DARK.lerp(MARS, 0.4))
	c.draw_rect(Rect2(8, 170, 244, 2), MARS_LIGHT)
	_draw_rover_side(c, Vector2(100, 188), 2.6, 0.6, 0.0, SILVER)
	_txt(c, Vector2(8, 236), "TROY", 9, GRAY_DIM, 244, HORIZONTAL_ALIGNMENT_CENTER)
	# Reparto de energía (derecha).
	var avail := _wi_avail()
	var rows := [tr("CALEFACTORES"), tr("COMUNICACIÓN"), tr("CIENCIA FIJA")]
	var cols := [Color("#ff8a50"), CYAN, GREEN]
	for i in 3:
		var r := _wi_row_rect(i)
		c.draw_rect(r, Color("#2a1c16") if i == _wi_row else Color("#1a1210"))
		c.draw_rect(r, GOLD if i == _wi_row else GRAY_DIM, false, 1.0)
		_txt(c, Vector2(r.position.x + 6, r.position.y + 12), String(rows[i]), 10, cols[i])
		var bx := r.position.x + 6.0
		var by := r.position.y + 18.0
		c.draw_rect(Rect2(bx, by, 270, 10), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bx, by, 270.0 * float(_wi_alloc[i]) / 100.0, 10), cols[i])
		c.draw_rect(Rect2(bx, by, 270, 10), GRAY_DIM, false, 1.0)
		var mark := _wi_need() if i == 0 else (float(_wi_cfg["comm_need"]) if i == 1 else -1.0)
		if mark >= 0.0:
			c.draw_line(Vector2(bx + 270.0 * mark / 100.0, by - 3), Vector2(bx + 270.0 * mark / 100.0, by + 13), Color.WHITE, 2.0)
		_txt(c, Vector2(r.position.x + 282, r.position.y + 27), "%d" % int(_wi_alloc[i]), 10, Color.WHITE, 40, HORIZONTAL_ALIGNMENT_LEFT)
		_box(c, _wi_btn_rect(i, false), Color("#3a2a20"), GRAY_DIM, "-", 11, Color.WHITE)
		_box(c, _wi_btn_rect(i, true), Color("#3a2a20"), GRAY_DIM, "+", 11, Color.WHITE)
	# Previsión.
	var pr := _wi_predict()
	var tcol := RED if float(pr["temp"]) <= float(_wi_cfg["temp_min"]) + 8.0 else GREEN
	_txt(c, Vector2(262, 208), tr("DISPONIBLE") + ": %d  ·  " % int(avail) + tr("USADA") + " %d" % int(_wi_total()), 10, GRAY)
	_txt(c, Vector2(262, 222), tr("PREVISIÓN") + ":  " + tr("TEMPERATURA") + " %d  ·  " % int(pr["temp"]) + tr("BATERÍA") + " %d" % int(pr["batt"]), 10, tcol, 366)
	var comm_ok := float(_wi_alloc[1]) >= float(_wi_cfg["comm_need"])
	var cl := tr("ENLACE") + (" OK" if comm_ok else " " + tr("ENLACE PERDIDO"))
	_txt(c, Vector2(262, 240), cl + ("   [" + str(_wi_miss) + "]" if _wi_miss > 0 else ""), 10, GREEN if comm_ok else RED, 220)
	_box(c, _wi_send_rect(), Color("#2a3a1c"), GREEN, tr("ENVIAR TRAMO [ENTER]"), 9, GREEN)
	_draw_msg(c, 64)


# =========================================================================
# FASE 5 · Rumbo a Endeavour (trazar la ruta)
# =========================================================================
var _rt_cfg: Dictionary = {}
var _rt_wps: Array = []
var _rt_cursor := Vector2(320, 160)
var _rt_run := false
var _rt_prog := 0.0
var _rt_done := false
var _rt_seen: Dictionary = {}


func _act_route(sc: Dictionary) -> void:
	await say(sc["intro"])
	_rt_cfg = sc["minimission"]
	_mm_title.text = String(_rt_cfg["title"])
	_mm_info.text = String(_rt_cfg["info"])
	_rt_wps = []
	_rt_run = false
	_rt_done = false
	_rt_prog = 0.0
	_rt_seen = {}
	_bar_name = tr("SOLES")
	_bar_show = true
	_bar_red_low = false
	_tele_fn = func() -> Array:
		var est := _rt_cost(_rt_wps)
		var budget := float(_rt_cfg["budget"])
		_bar_val = clampf((budget - est) / budget * 100.0, 0.0, 100.0)
		_bar_alert = est > budget
		return [
			[tr("PUNTOS"), "%d / %d" % [_rt_wps.size(), int(_rt_cfg["max_wps"])]],
			[tr("ESTIMADO"), "%s / %d" % [_num(est), int(budget)], RED if est > budget else GREEN],
		]
	_layer(_draw_route)
	_input_cb = _route_input
	while not _rt_done:
		await get_tree().process_frame
		if _rt_run and not get_tree().paused:
			_route_drive(get_process_delta_time())
	_input_cb = Callable()
	await toast(String(_rt_cfg["msg_arrive"]), GREEN, 1.6)
	dialog.show_hint("INGENIERIA", String(_rt_cfg["reverse_note"]), 6.0)
	await toast(String(_rt_cfg["milestone_a"]), YEL, 2.2)
	await toast(String(_rt_cfg["milestone_b"]), YEL, 2.2)
	await say(sc["outro"])
	for ev in sc["evidence"]:
		await _add_evidence(ev)


func _rt_points(wps: Array) -> Array:
	var pts: Array = [Vector2(float((_rt_cfg["start"] as Array)[0]), float((_rt_cfg["start"] as Array)[1]))]
	for w in wps:
		pts.append(w)
	pts.append(Vector2(float((_rt_cfg["end"] as Array)[0]), float((_rt_cfg["end"] as Array)[1])))
	return pts


func _rt_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 == 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _rt_in_dune(p: Vector2, d: Array) -> bool:
	var dx := (p.x - float(d[0])) / (float(d[2]) * 0.5)
	var dy := (p.y - float(d[1])) / (float(d[3]) * 0.5)
	return dx * dx + dy * dy <= 1.0


## Soles estimados de una ruta: distancia + desvíos por cráteres + patinaje en dunas.
func _rt_cost(wps: Array) -> float:
	var pts := _rt_points(wps)
	var cost := 0.0
	var pps := float(_rt_cfg["px_per_sol"])
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		cost += a.distance_to(b) / pps
		for cr in _rt_cfg["craters"]:
			if _rt_seg_dist(Vector2(float(cr[0]), float(cr[1])), a, b) < float(cr[2]):
				cost += 2.0 * float(cr[2]) * float(_rt_cfg["crater_detour"]) / pps
		for d in _rt_cfg["dunes"]:
			for k in 41:
				if _rt_in_dune(a.lerp(b, float(k) / 40.0), d):
					cost += float(_rt_cfg["dune_cost"])
					break
	return cost


func _route_input(event: InputEvent, click: bool) -> void:
	if _rt_run:
		return
	var area := Rect2(8, 76, 624, 182)
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		if area.has_point(p):
			_rt_cursor = p
	elif click:
		var p := get_local_mouse_position()
		if area.has_point(p):
			_rt_cursor = p
			_route_add()
	elif event is InputEventKey and event.pressed:
		var step := 8.0
		match int(event.physical_keycode):
			KEY_LEFT, KEY_A: _rt_cursor.x = maxf(14, _rt_cursor.x - step)
			KEY_RIGHT, KEY_D: _rt_cursor.x = minf(626, _rt_cursor.x + step)
			KEY_UP, KEY_W: _rt_cursor.y = maxf(84, _rt_cursor.y - step)
			KEY_DOWN, KEY_S: _rt_cursor.y = minf(252, _rt_cursor.y + step)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo:
					_route_add()
			KEY_BACKSPACE:
				if not _rt_wps.is_empty():
					_rt_wps.pop_back()
			KEY_G:
				if not event.echo:
					_route_go()


func _route_add() -> void:
	if _rt_wps.size() < int(_rt_cfg["max_wps"]):
		_rt_wps.append(_rt_cursor)


func _route_go() -> void:
	if _rt_cost(_rt_wps) > float(_rt_cfg["budget"]):
		_say_msg(String(_rt_cfg["msg_over"]), RED, 2.6)
		return
	_rt_run = true
	_rt_prog = 0.0
	_rt_seen = {}


func _rt_path_len(pts: Array) -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += (pts[i] as Vector2).distance_to(pts[i + 1])
	return l


func _rt_at(pts: Array, dist: float) -> Vector2:
	var d := dist
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var sl := a.distance_to(b)
		if d <= sl:
			return a.lerp(b, d / maxf(sl, 0.001))
		d -= sl
	return pts[pts.size() - 1]


func _route_drive(delta: float) -> void:
	var pts := _rt_points(_rt_wps)
	var total := _rt_path_len(pts)
	_rt_prog += delta * 120.0
	var p := _rt_at(pts, _rt_prog)
	for i in (_rt_cfg["dunes"] as Array).size():
		if not _rt_seen.has("d%d" % i) and _rt_in_dune(p, (_rt_cfg["dunes"] as Array)[i]):
			_rt_seen["d%d" % i] = true
			_say_msg(String(_rt_cfg["msg_dune"]), RED, 2.0)
	for i in (_rt_cfg["craters"] as Array).size():
		var cr: Array = (_rt_cfg["craters"] as Array)[i]
		if not _rt_seen.has("c%d" % i) and p.distance_to(Vector2(float(cr[0]), float(cr[1]))) < float(cr[2]) + 8.0:
			_rt_seen["c%d" % i] = true
			_say_msg(String(_rt_cfg["msg_crater"]), CYAN, 2.0)
	if _rt_prog >= total:
		_rt_run = false
		_rt_done = true


func _draw_route(c: DrawNode) -> void:
	if _rt_cfg.is_empty():
		return
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), PANEL)
	var area := Rect2(8, 76, 624, 182)
	c.draw_rect(area, MARS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	for i in 200:
		c.draw_rect(Rect2(area.position.x + floorf(rng.randf() * area.size.x), area.position.y + floorf(rng.randf() * area.size.y), 2, 1), MARS_DARK if i % 2 == 0 else MARS_LIGHT)
	# Dunas (claras) y cráteres (anillos oscuros).
	for d in _rt_cfg["dunes"]:
		_ellipse(c, Vector2(float(d[0]), float(d[1])), float(d[2]) * 0.5, float(d[3]) * 0.5, Color(0.95, 0.75, 0.5, 0.55))
	for cr in _rt_cfg["craters"]:
		var cc := Vector2(float(cr[0]), float(cr[1]))
		c.draw_circle(cc, float(cr[2]), Color("#5a3020"))
		c.draw_circle(cc + Vector2(2, 2), float(cr[2]) - 4.0, Color("#3a1e14"))
		c.draw_arc(cc, float(cr[2]), 0, TAU, 28, MARS_LIGHT, 1.0)
	_txt(c, Vector2(560, 90), "ENDEAVOUR", 9, GOLD, 60, HORIZONTAL_ALIGNMENT_CENTER)
	var pts := _rt_points(_rt_wps)
	var over := _rt_cost(_rt_wps) > float(_rt_cfg["budget"])
	var lcol := RED if over else GREEN
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], lcol, 2.0)
	if not _rt_run and _rt_wps.size() < int(_rt_cfg["max_wps"]):
		c.draw_line(pts[pts.size() - 2], _rt_cursor, Color(1, 1, 1, 0.35), 1.0)
		c.draw_circle(_rt_cursor, 4.0, Color(1, 1, 1, 0.5))
	for i in _rt_wps.size():
		c.draw_circle(_rt_wps[i], 6.0, Color("#1a1210"))
		c.draw_arc(_rt_wps[i], 6.0, 0, TAU, 14, YEL, 1.5)
		_txt(c, (_rt_wps[i] as Vector2) + Vector2(-6, 4), str(i + 1), 9, YEL, 12, HORIZONTAL_ALIGNMENT_CENTER)
	var s: Vector2 = pts[0]
	c.draw_circle(s, 5.0, GREEN)
	var e: Vector2 = pts[pts.size() - 1]
	c.draw_circle(e, 6.0, GOLD)
	if _rt_run:
		var p := _rt_at(pts, _rt_prog)
		var ahead := _rt_at(pts, _rt_prog + 4.0)
		_draw_rover_top(c, p, (ahead - p).angle() + PI, 1.3, false)
	_draw_msg(c, 232)


func _ellipse(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)


# =========================================================================
# FASE 6 · La tormenta (ventanas de luz) + último mensaje + epílogo
# =========================================================================
var _st_cfg: Dictionary = {}
var _st_t := 0.0
var _st_batt := 0.0
var _st_frames := 0
var _st_cool := 0.0
var _st_done := false
var _st_tex: ImageTexture
var _st_reveal := 0.0
var _st_cut := false
var _cl_screen := 0
var _cl_t0 := 0.0
var _cl_cfg: Dictionary = {}
var _cl_quiz_ok := false


func _act_storm(sc: Dictionary) -> void:
	await _cinematic_pending(String(sc["cinematic_tag"]))
	await say(sc["intro"])
	_st_cfg = sc["minimission"]
	_mm_title.text = String(_st_cfg["title"])
	_mm_info.text = String(_st_cfg["info"])
	_st_restart()
	_st_done = false
	_bar_name = tr("BATERÍA")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _st_batt
		return [
			[tr("LUZ"), "%d%%" % int(_st_light(_st_t) * 100.0), GREEN if _st_light(_st_t) >= float(_st_cfg["threshold"]) else GRAY_DIM],
			[tr("FOTOS"), "%d / %d" % [_st_frames, int(_st_cfg["frames_goal"])]],
		]
	_layer(_draw_storm)
	_input_cb = _storm_input
	while not _st_done:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		_storm_step(get_process_delta_time())
	_input_cb = Callable()
	await toast(String(_st_cfg["done"]), GREEN, 1.8)
	await _last_message(sc)
	await say(sc["outro"])
	await _closing(sc)


func _st_restart() -> void:
	_st_t = 0.0
	_st_batt = float(_st_cfg["battery_start"])
	_st_frames = 0
	_st_cool = 0.0


## Luz que llega a los paneles en el instante t: pulsos cada ~6 s dentro de una tormenta que se espesa.
func _st_light(t: float) -> float:
	var env := lerpf(1.0, 0.45, clampf(t / float(_st_cfg["seconds"]), 0.0, 1.0))
	return env * (0.5 + 0.5 * sin(TAU * t / 6.0 + 0.6))


func _storm_input(event: InputEvent, click: bool) -> void:
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("thrust"):
		_storm_photo()


func _storm_photo() -> void:
	if _st_cool > 0.0:
		return
	_st_cool = float(_st_cfg.get("cooldown", 3.0))
	_st_batt = maxf(0.0, _st_batt - float(_st_cfg["photo_cost"]))
	if _st_light(_st_t) >= float(_st_cfg["threshold"]):
		_st_frames += 1
		_say_msg(String(_st_cfg["good"]), GREEN, 1.4)
	else:
		_say_msg(String(_st_cfg["dark"]), RED, 1.6)


func _storm_step(delta: float) -> void:
	_st_t += delta
	_st_cool = maxf(0.0, _st_cool - delta)
	_st_batt = clampf(_st_batt + (float(_st_cfg["gain"]) * _st_light(_st_t) - float(_st_cfg["drain"])) * delta, 0.0, 100.0)
	if _st_frames >= int(_st_cfg["frames_goal"]):
		_st_done = true
	elif _st_batt <= 0.0:
		_say_msg(String(_st_cfg["no_energy"]), RED, 2.6)
		_st_restart()
	elif _st_t >= float(_st_cfg["seconds"]):
		_say_msg(String(_st_cfg["retry"]), RED, 2.6)
		_st_restart()


func _draw_storm(c: DrawNode) -> void:
	if _st_cfg.is_empty():
		return
	var prog := clampf(_st_t / float(_st_cfg["seconds"]), 0.0, 1.0)
	_mars_sky(c, GAME_TOP, 170.0, prog * 0.55)
	# Polvo en el aire.
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 80:
		var x := fmod(rng.randf() * W + _t * (20.0 + rng.randf() * 30.0), W)
		c.draw_rect(Rect2(x, GAME_TOP + rng.randf() * 150.0, 2, 1), Color(0.9, 0.6, 0.4, 0.25 + prog * 0.3))
	c.draw_rect(Rect2(0, 170, W, GAME_BOTTOM - 170), MARS_DARK.lerp(MARS, 0.5).darkened(prog * 0.4))
	c.draw_rect(Rect2(0, 170, W, 2), MARS_LIGHT.darkened(prog * 0.4))
	_draw_rover_side(c, Vector2(320, 188), 2.6, 0.0, 0.0, SILVER)
	# Fotos del panorama.
	var goal := int(_st_cfg["frames_goal"])
	for i in goal:
		var r := Rect2(20.0 + float(i) * 26.0, 78, 22, 14)
		c.draw_rect(r, GREEN.darkened(0.4) if i < _st_frames else Color("#1a1210"))
		c.draw_rect(r, GREEN if i < _st_frames else GRAY_DIM, false, 1.0)
	# Gráfico de luz: pasado reciente y previsión de los próximos segundos.
	var g := Rect2(20, 208, 600, 50)
	c.draw_rect(g, Color("#120c0a"))
	var thr := float(_st_cfg["threshold"])
	for i in 200:
		var tt := _st_t - 2.0 + float(i) / 20.0
		if tt < 0.0:
			continue
		var v := _st_light(tt)
		var h := v * 46.0
		var col := GREEN if v >= thr else Color("#4a3a30")
		if i < 40:
			col = col.darkened(0.35)
		c.draw_rect(Rect2(g.position.x + float(i) * 3.0, g.position.y + 48.0 - h, 3, h), col)
	c.draw_line(Vector2(g.position.x, g.position.y + 48.0 - thr * 46.0), Vector2(g.end.x, g.position.y + 48.0 - thr * 46.0), YEL, 1.0)
	c.draw_line(Vector2(g.position.x + 120.0, g.position.y), Vector2(g.position.x + 120.0, g.end.y), Color.WHITE, 2.0)
	c.draw_rect(g, GRAY_DIM, false, 1.0)
	_txt(c, Vector2(g.position.x + 126, g.position.y + 10), tr("LUZ"), 8, GRAY)
	_draw_msg(c, 186)


## Imagen oscura y con ruido que se forma línea a línea y se corta antes de terminar.
func _last_message(sc: Dictionary) -> void:
	_clear_scene_only()
	var lm: Dictionary = sc["last_message"]
	_mm_title.text = String(lm["title"])
	_mm_info.text = String(lm["caption"])
	var img := Image.create(130, 78, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5111
	for y in 78:
		for x in 130:
			var ridge := 40.0 + sin(float(x) * 0.13) * 3.0 + sin(float(x) * 0.31) * 1.5
			var base := Color(0.30, 0.19, 0.16) if float(y) < ridge else Color(0.10, 0.05, 0.04)
			var n := rng.randf() * 0.16
			var px := Color(base.r + n, base.g + n * 0.7, base.b + n * 0.6)
			if rng.randf() < 0.012:
				px = Color(0.8, 0.7, 0.6)
			img.set_pixel(x, y, px)
	_st_tex = ImageTexture.create_from_image(img)
	_st_reveal = 0.0
	_st_cut = false
	var cut_row := 48.0
	var lm_layer := _layer(func(c: DrawNode) -> void:
		var dst := Rect2(190, 80, 260, 156)
		c.draw_rect(dst.grow(3), Color("#120c0a"))
		c.draw_rect(Rect2(dst.position, Vector2(dst.size.x, 156)), Color.BLACK)
		var rows := int(_st_reveal)
		if rows > 0:
			c.draw_texture_rect_region(_st_tex, Rect2(dst.position, Vector2(260, float(rows) * 2.0)), Rect2(0, 0, 130, rows))
		if rows < 78 and not _st_cut:
			c.draw_line(dst.position + Vector2(0, float(rows) * 2.0), dst.position + Vector2(260, float(rows) * 2.0), Color(0.9, 0.9, 0.9, 0.6), 1.0)
		c.draw_rect(dst.grow(3), GRAY_DIM, false, 1.0)
		if _st_cut:
			_txt(c, Vector2(0, 254), String(lm["cut"]), 10, RED, W, HORIZONTAL_ALIGNMENT_CENTER))
	lm_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	await wait(0.8)
	while _st_reveal < cut_row:
		await get_tree().process_frame
		if not get_tree().paused:
			_st_reveal += get_process_delta_time() * 9.0
	_st_cut = true
	await wait_click_or_accept(7.0)


# ---- Epílogo: estadísticas y recorrido, libreta de evidencias, Perseverance
func _closing(sc: Dictionary) -> void:
	_clear_scene_only()
	_cl_cfg = sc["closing"]
	_mm_title.text = String(_cl_cfg["title"])
	_mm_info.text = ""
	_cl_screen = 0
	_cl_t0 = _t
	_cl_quiz_ok = false
	_layer(_draw_closing)
	await wait(0.5)
	await wait_click_or_accept(0.0)
	_cl_screen = 1
	_cl_t0 = _t
	_mm_info.text = String(_cl_cfg["quiz_title"])
	_input_cb = _closing_input
	while not _cl_quiz_ok:
		await get_tree().process_frame
	_input_cb = Callable()
	await wait(0.5)
	await wait_click_or_accept(0.0)
	_cl_screen = 2
	_cl_t0 = _t
	_mm_info.text = ""
	await wait(0.6)
	await wait_click_or_accept(0.0)


func _cl_opt_rect(j: int) -> Rect2:
	return Rect2(326, 106.0 + float(j) * 36.0, 302, 32)


func _closing_input(event: InputEvent, click: bool) -> void:
	if _cl_quiz_ok:
		return
	var pick := -1
	if click:
		var p := get_local_mouse_position()
		for j in 3:
			if _cl_opt_rect(j).has_point(p):
				pick = j
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k >= KEY_1 and k <= KEY_3:
			pick = k - KEY_1
	if pick < 0:
		return
	if pick == int(_cl_cfg["quiz_correct"]):
		_cl_quiz_ok = true
		_say_msg(String(_cl_cfg["quiz_right"]), GREEN, 999.0)
	else:
		_say_msg(String(_cl_cfg["quiz_wrong"]), RED, 3.0)


func _draw_closing(c: DrawNode) -> void:
	if _cl_cfg.is_empty():
		return
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), PANEL)
	match _cl_screen:
		0:
			var stats: Array = _cl_cfg["stats"]
			var cols := [CYAN, YEL]
			for i in stats.size():
				_txt(c, Vector2(20, 90.0 + float(i) * 14.0), String((stats[i] as Array)[0]) + "  " + String((stats[i] as Array)[1]), 10, cols[i], 600)
			var prog := clampf((_t - _cl_t0) / 5.0, 0.0, 1.0)
			var maps := [
				{"r": Rect2(24, 128, 290, 96), "pts": [Vector2(0.1, 0.75), Vector2(0.4, 0.3), Vector2(0.62, 0.6), Vector2(0.88, 0.4)], "names": _cl_cfg["pts_spirit"], "cap": _cl_cfg["map_spirit"], "col": CYAN},
				{"r": Rect2(326, 128, 290, 96), "pts": [Vector2(0.08, 0.8), Vector2(0.25, 0.5), Vector2(0.48, 0.72), Vector2(0.7, 0.3), Vector2(0.92, 0.2)], "names": _cl_cfg["pts_opp"], "cap": _cl_cfg["map_opp"], "col": YEL},
			]
			for m in maps:
				var r: Rect2 = m["r"]
				c.draw_rect(r, MARS_DARK)
				c.draw_rect(r, GRAY_DIM, false, 1.0)
				var pts: Array = m["pts"]
				var names: Array = m["names"]
				var pp: float = prog * float(pts.size() - 1)
				for i in pts.size() - 1:
					var a: Vector2 = r.position + Vector2((pts[i] as Vector2).x * r.size.x, (pts[i] as Vector2).y * r.size.y)
					var b: Vector2 = r.position + Vector2((pts[i + 1] as Vector2).x * r.size.x, (pts[i + 1] as Vector2).y * r.size.y)
					var f := clampf(pp - float(i), 0.0, 1.0)
					if f > 0.0:
						c.draw_line(a, a.lerp(b, f), m["col"], 2.0)
				for i in pts.size():
					if pp >= float(i):
						var q: Vector2 = r.position + Vector2((pts[i] as Vector2).x * r.size.x, (pts[i] as Vector2).y * r.size.y)
						c.draw_circle(q, 3.0, Color.WHITE)
						_txt(c, q + Vector2(-34, 12 if i % 2 == 0 else -6), String(names[i]), 7, GRAY, 68, HORIZONTAL_ALIGNMENT_CENTER)
				_txt(c, Vector2(r.position.x, r.end.y + 12), String(m["cap"]), 8, m["col"], r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_txt(c, Vector2(0, 256), String(_cl_cfg["badge_hint"]), 9, GRAY_DIM, W, HORIZONTAL_ALIGNMENT_CENTER)
		1:
			# Libreta de evidencias.
			var nb := Rect2(14, 78, 300, 168)
			c.draw_rect(nb, Color("#2a1c16"))
			c.draw_rect(nb, GOLD, false, 1.0)
			_txt(c, Vector2(nb.position.x + 8, nb.position.y + 12), tr("LIBRETA DE EVIDENCIAS"), 10, GOLD)
			var y := nb.position.y + 28.0
			for ev in _evidence:
				var e: Dictionary = ev
				_txt(c, Vector2(nb.position.x + 8, y), "- " + String(e["title"]), 9, CYAN, 284)
				c.draw_multiline_string(ThemeDB.fallback_font, Vector2(nb.position.x + 16, y + 10), String(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, 280, 8, 1, GRAY)
				y += 22.0
			_txt(c, Vector2(326, 100), String(_cl_cfg["quiz_q"]), 10, YEL, 302)
			var opts: Array = _cl_cfg["quiz_options"]
			for j in opts.size():
				var r := _cl_opt_rect(j)
				_box(c, r, Color("#2a1c16"), GOLD)
				_txt(c, Vector2(r.position.x + 6, r.position.y + 13), "%d" % (j + 1), 11, GOLD)
				c.draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 22, r.position.y + 13), String(opts[j]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 9, 2, Color.WHITE)
			if _msg_t > 0.0:
				c.draw_multiline_string(ThemeDB.fallback_font, Vector2(326, 226), _msg, HORIZONTAL_ALIGNMENT_LEFT, 302, 9, 3, _msg_col)
			if _cl_quiz_ok:
				_txt(c, Vector2(326, 246), String(_cl_cfg["badge_hint"]), 8, GRAY_DIM, 302)
		2:
			var fade := clampf((_t - _cl_t0) / 1.2, 0.0, 1.0)
			c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(0, 0, 0, 1))
			var l1 := String(_cl_cfg["perseverance"])
			c.draw_multiline_string(ThemeDB.fallback_font, Vector2(40, 96), l1, HORIZONTAL_ALIGNMENT_CENTER, 560, 11, 3, Color(CYAN, fade))
			c.draw_multiline_string(ThemeDB.fallback_font, Vector2(40, 150), String(_cl_cfg["final"]), HORIZONTAL_ALIGNMENT_CENTER, 560, 14, 4, Color(GOLD, clampf((_t - _cl_t0 - 0.8) / 1.2, 0.0, 1.0)))
			_txt(c, Vector2(0, 250), String(data["hud"]["button_back"]), 10, Color(GRAY, clampf((_t - _cl_t0 - 2.0) / 1.0, 0.0, 1.0)), W, HORIZONTAL_ALIGNMENT_CENTER)



# =========================================================================
# Entrada: pausa, debug y despacho a cada fase
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
		if k >= KEY_F1 and k <= KEY_F7:
			GameManager.set_start_phase(k - KEY_F1 + 1)
			SceneTransition.change_scene(scene_file_path, 0.2)
			return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not MissionHUD.hover_ui
	if _mode == "continue":
		if click or event.is_action_pressed("ui_accept"):
			_mode = ""
		return
	if _input_cb.is_valid():
		_input_cb.call(event, click)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		(_pause_panel.get_child(0).get_child(1) as Button).grab_focus()
