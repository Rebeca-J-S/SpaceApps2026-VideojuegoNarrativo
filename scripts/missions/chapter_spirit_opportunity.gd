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
var _pause_menu: PauseMenu
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
var _pl_hover := -1
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
	_sfx_init()
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
		await _award_badge_piece(i)
	mission_hud.mark_all_done()
	chapter_finished.emit()
	if auto_return:
		GameManager.mark_completed(MISSION_ID)
		GameManager.go_to_planet_select()


## Cuaderno de insignias: cada fase terminada gana una pieza de la insignia de la misión.
func _award_badge_piece(index: int) -> void:
	var b := GameManager.find_badge(BADGE_ID)
	if b.is_empty() or not GameManager.unlock_badge_piece(BADGE_ID, index):
		return
	if GameManager.is_badge_complete(BADGE_ID):
		# Insignia completa: se desbloquea su ficha técnica (aviso grande, espera al jugador).
		await BadgeUnlockCard.present(self, b)
	else:
		_badge_toast.show_piece(b, GameManager.badge_pieces(BADGE_ID), index)


func _run_scene(sc: Dictionary, index: int) -> void:
	_clear()
	_set_date(String(sc["date"]))
	_set_objective(String(sc["objective"]))
	await _banner(String(sc["title"]))
	mission_hud.set_phase(index, String(sc["title"]), String(sc["objective"]))
	# Tarjeta "CÓMO SE JUEGA" antes de cada minijuego (las fases que son solo cinemática no tienen).
	await TutorialCard.present(self, GameManager.get_tutorial(BADGE_ID, String(sc["id"])), String(sc["title"]))
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
		if (tg as Dictionary).has("evidence"):
			out.append((tg as Dictionary)["evidence"])
	return out


func _add_evidence(ev: Dictionary) -> void:
	for e in _evidence:
		if String((e as Dictionary)["id"]) == String(ev["id"]):
			return
	_evidence.append(ev)
	sfx("ping2")
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
	mission_hud.buttons_pos = Vector2(W - 28, GAME_TOP + 3)
	mission_hud.show_info_buttons = false   # C / O / I van dentro del menú de tres puntos
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


## Menú de pausa común (botón de tres puntos o ESC): sonido, ayuda de los minijuegos y salir.
func _build_pause() -> void:
	_pause_menu = PauseMenu.new()
	_pause_menu.setup(BADGE_ID, data["scenes"])
	_pause_menu.hud = mission_hud
	_pause_menu.dots_pos = Vector2(W - 6, GAME_TOP + 3)
	add_child(_pause_menu)
	_pause_menu.apply_layout()


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
	sfx("whoosh", 1.0, -14.0)
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
# Efectos de sonido (sintetizados en código: no hacen falta archivos)
# =========================================================================
const SFX_RATE := 22050
## Cada sonido es una lista de tramos: [frecuencia inicial, final, segundos, forma, volumen].
const SFX := {
	"click": [[900.0, 700.0, 0.04, "sq", 0.45]],
	"select": [[500.0, 800.0, 0.06, "tri", 0.6]],
	"hover": [[1300.0, 1300.0, 0.025, "sine", 0.25]],
	"place": [[200.0, 90.0, 0.10, "sine", 1.0], [1000.0, 700.0, 0.03, "sq", 0.3]],
	"remove": [[600.0, 200.0, 0.12, "tri", 0.6]],
	"error": [[160.0, 150.0, 0.12, "sq", 0.5], [0.0, 0.0, 0.03, "gap", 0.0], [120.0, 110.0, 0.18, "sq", 0.5]],
	"ok": [[660.0, 660.0, 0.07, "sq", 0.4], [880.0, 880.0, 0.12, "sq", 0.4]],
	"win": [[523.0, 523.0, 0.10, "sq", 0.4], [659.0, 659.0, 0.10, "sq", 0.4], [784.0, 784.0, 0.10, "sq", 0.4], [1047.0, 1047.0, 0.28, "sq", 0.45]],
	"lose": [[400.0, 380.0, 0.14, "sq", 0.45], [300.0, 280.0, 0.14, "sq", 0.45], [200.0, 100.0, 0.35, "sq", 0.5]],
	"send": [[800.0, 1200.0, 0.06, "sq", 0.35], [1000.0, 1500.0, 0.06, "sq", 0.35], [1300.0, 2000.0, 0.10, "sq", 0.35]],
	"tick": [[1600.0, 1600.0, 0.012, "sq", 0.3]],
	"motor": [[55.0, 70.0, 0.22, "sq", 0.4]],
	"grind": [[0.0, 0.0, 0.25, "noise", 0.45]],
	"servo": [[300.0, 520.0, 0.14, "sq", 0.3], [520.0, 300.0, 0.14, "sq", 0.3]],
	"shutter": [[0.0, 0.0, 0.025, "noise", 0.9], [0.0, 0.0, 0.04, "gap", 0.0], [0.0, 0.0, 0.05, "noise", 0.7]],
	"chirp": [[1800.0, 1800.0, 0.03, "sq", 0.3], [1200.0, 1200.0, 0.03, "sq", 0.3], [2000.0, 2000.0, 0.03, "sq", 0.3], [1400.0, 1400.0, 0.03, "sq", 0.3], [1900.0, 1900.0, 0.04, "sq", 0.3]],
	"hum": [[110.0, 110.0, 0.35, "sine", 0.8]],
	"scan": [[400.0, 1600.0, 0.35, "sine", 0.6]],
	"ping": [[1320.0, 1320.0, 0.18, "sine", 0.7]],
	"ping2": [[880.0, 880.0, 0.08, "sine", 0.6], [1320.0, 1320.0, 0.20, "sine", 0.6]],
	"static": [[0.0, 0.0, 0.30, "noise", 0.35]],
	"warn": [[440.0, 440.0, 0.10, "sq", 0.4], [0.0, 0.0, 0.05, "gap", 0.0], [440.0, 440.0, 0.10, "sq", 0.4]],
	"whoosh": [[0.0, 0.0, 0.30, "noise", 0.3]],
}
var _sfx_cache: Dictionary = {}
var _sfx_pool: Array = []
var _sfx_next := 0


func _sfx_init() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)


func sfx(sound: String, pitch: float = 1.0, vol_db: float = -9.0) -> void:
	if _sfx_pool.is_empty() or not SFX.has(sound):
		return
	if not _sfx_cache.has(sound):
		_sfx_cache[sound] = _synth(SFX[sound])
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[sound]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


func _synth(segs: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	for seg in segs:
		var f0: float = seg[0]
		var f1: float = seg[1]
		var shape: String = seg[3]
		var vol: float = seg[4]
		var n := int(float(SFX_RATE) * float(seg[2]))
		for i in n:
			var f := float(i) / float(n)
			phase += lerpf(f0, f1, f) / float(SFX_RATE)
			var env := minf(1.0, float(i) / (float(SFX_RATE) * 0.004)) * (1.0 - f)
			var v := 0.0
			match shape:
				"sq": v = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
				"sine": v = sin(phase * TAU)
				"tri": v = absf(fposmod(phase, 1.0) * 4.0 - 2.0) - 1.0
				"noise": v = rng.randf_range(-1.0, 1.0)
			var s := int(clampf(v * env * vol, -1.0, 1.0) * 12000.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SFX_RATE
	wav.stereo = false
	wav.data = data
	return wav


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
	var last_col := -1
	while _pl_play < float(int(_pl_cfg["cols"])):
		await get_tree().process_frame
		if not get_tree().paused:
			_pl_play += get_process_delta_time() * 7.0
		var col_now := int(_pl_play)
		if col_now != last_col:
			last_col = col_now
			sfx("tick", 1.0, -16.0)
			for b in _pl_blocks:
				if int(b["col"]) == col_now:
					sfx(String({"conducir": "motor", "mi": "ping", "brazo": "servo", "pano": "shutter", "calent": "hum", "enviar": "chirp", "mastil": "servo", "antena": "servo"}.get(String(b["id"]), "click")))
	_pl_play = -1.0
	sfx("win")
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
		sfx("remove")
		return
	var c := clampi(col, 0, int(_pl_cfg["cols"]) - int(b["dur"]))
	var why := _pl_valid(_pl_sel, c)
	if why != "":
		_say_msg(why, RED)
		sfx("error")
		return
	b["col"] = c
	sfx("place")


func _pl_send() -> void:
	var tot := _pl_totals()
	var miss: Array = tot["miss"]
	if not miss.is_empty():
		_say_msg(String(_pl_cfg["msg_missing"]) + " · " + tr("Falta: %s") % ", ".join(PackedStringArray(miss)), RED, 3.2)
		sfx("error")
		return
	if int(tot["e"]) > int(_pl_day["budget"]):
		_say_msg(String(_pl_cfg["msg_energy"]), RED)
		sfx("warn")
		return
	if int(tot["s"]) < int(_pl_day["sci_target"]):
		_say_msg(String(_pl_cfg["msg_science"]), RED)
		sfx("error")
		return
	sfx("send")
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
		var h := -1
		for i in _pl_blocks.size():
			if _pl_tray_rect(i).has_point(p):
				h = i
		if h != _pl_hover and h >= 0:
			sfx("hover")
		_pl_hover = h
		if lane.has_point(p):
			var nc := clampi(int((p.x - PL_X0) / PL_CW), 0, 23)
			if nc != _pl_cur:
				_pl_cur = nc
				sfx("tick", 1.0, -18.0)
	elif click:
		var p := get_local_mouse_position()
		for i in _pl_blocks.size():
			if _pl_tray_rect(i).has_point(p):
				_pl_sel = i
				if int((_pl_blocks[i] as Dictionary)["col"]) >= 0:
					(_pl_blocks[i] as Dictionary)["col"] = -1
					sfx("remove")
				else:
					sfx("select")
				return
		if lane.has_point(p):
			_pl_cur = clampi(int((p.x - PL_X0) / PL_CW), 0, 23)
			_pl_place(_pl_cur)
		elif _pl_send_rect().has_point(p):
			_pl_send()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n := _pl_blocks.size()
		match int(event.physical_keycode):
			KEY_Q:
				_pl_sel = (_pl_sel + n - 1) % n
				sfx("select")
			KEY_E:
				_pl_sel = (_pl_sel + 1) % n
				sfx("select")
			KEY_A, KEY_LEFT:
				_pl_cur = maxi(0, _pl_cur - 1)
				sfx("tick", 1.0, -14.0)
			KEY_D, KEY_RIGHT:
				_pl_cur = mini(23, _pl_cur + 1)
				sfx("tick", 1.0, -14.0)
			KEY_P: _pl_send()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _pl_place(_pl_cur)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				var k: int = int(event.physical_keycode) - KEY_1
				if k < n:
					_pl_sel = k
					sfx("select")


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
		var border := GOLD if i == _pl_sel else (Color.WHITE if i == _pl_hover else (GREEN if placed else GRAY_DIM))
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
# FASE 1 · Detective del agua (explorar el afloramiento + tablero de hipótesis)
# =========================================================================
var _wd_hover := -1
var _wd_hover_poi := -1
var _wd_x := 20.0
var _wd_goto := -1.0
var _wd_revealed: Dictionary = {}
var _wd_alive: Dictionary = {}
var _wd_scan_t := 0.0
var _wd_snd := 0.0
const WD_VIEW := Rect2(12, 108, 616, 68)
const WD_POI_Y := 152.0
const WD_ROVER_Y := 172.0


func _act_water(sc: Dictionary) -> void:
	await say(sc["intro"])
	_wd_cfg = sc["minimission"]
	_mm_title.text = String(_wd_cfg["title"])
	_mm_info.text = String(_wd_cfg["info"])
	_wd_reset_all()
	_bar_name = tr("ENERGÍA")
	_bar_show = true
	_tele_fn = func() -> Array:
		_bar_val = _wd_energy / float(_wd_cfg["energy"]) * 100.0
		var alive := 0
		for k in _wd_alive:
			if bool(_wd_alive[k]):
				alive += 1
		return [[tr("MEDICIONES"), "%d" % int(_wd_energy / 8.0)], [tr("HIPÓTESIS"), "%d / %d" % [alive, _wd_alive.size()]]]
	_layer(_draw_water)
	_input_cb = _water_input
	while _wd_stage != "done":
		await get_tree().process_frame
		if get_tree().paused:
			continue
		_water_step(get_process_delta_time())
	_input_cb = Callable()
	await say(sc["outro"])


func _wd_reset_all() -> void:
	_wd_energy = float(_wd_cfg["energy"])
	_wd_x = 20.0
	_wd_goto = -1.0
	_wd_used = {}
	_wd_solved = {}
	_wd_revealed = {}
	_wd_log = ""
	_wd_stage = "pick"
	_wd_hover = -1
	_wd_hover_poi = -1
	_wd_alive = {}
	for h in _wd_cfg["hypotheses"]:
		_wd_alive[String((h as Dictionary)["id"])] = true


func _wd_tool_rect(j: int) -> Rect2:
	return Rect2(12.0 + float(j) * 124.0, 210, 120, 34)


func _wd_poi_rect(tg: Dictionary) -> Rect2:
	return Rect2(float(tg["x"]) - 18.0, WD_POI_Y - 24.0, 36, 34)


func _wd_poi_at(p: Vector2) -> int:
	var targets: Array = _wd_cfg["targets"]
	for i in targets.size():
		if _wd_poi_rect(targets[i]).has_point(p):
			return i
	return -1


## Muestra a menos de `range` píxeles del rover (la más cercana) o -1.
func _wd_nearest() -> int:
	var best := -1
	var bd := float(_wd_cfg["range"])
	var targets: Array = _wd_cfg["targets"]
	for i in targets.size():
		var d := absf(float((targets[i] as Dictionary)["x"]) - _wd_x)
		if d <= bd:
			bd = d
			best = i
	return best


func _water_step(delta: float) -> void:
	_wd_scan_t = maxf(0.0, _wd_scan_t - delta)
	if _wd_mg != "":
		_wd_mg_update(delta)
		return
	if _wd_stage != "pick":
		return
	var dir := _axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)
	if dir != 0.0:
		_wd_goto = -1.0
	elif _wd_goto >= 0.0:
		if absf(_wd_goto - _wd_x) < 3.0:
			_wd_goto = -1.0
		else:
			dir = signf(_wd_goto - _wd_x)
	if dir == 0.0:
		return
	var mv := dir * float(_wd_cfg["speed"]) * delta
	var nx := clampf(_wd_x + mv, 20.0, 620.0)
	_wd_energy -= absf(nx - _wd_x) / 80.0 * float(_wd_cfg["drive_cost"])
	_wd_x = nx
	_wd_snd -= delta
	if _wd_snd <= 0.0:
		_wd_snd = 0.3
		sfx("motor", 1.0, -17.0)
	if _wd_energy <= 0.0:
		_wd_no_energy()


func _wd_no_energy() -> void:
	_wd_energy = float(_wd_cfg["energy"])
	_wd_used = {}
	_wd_x = 20.0
	_wd_goto = -1.0
	_wd_log = ""
	_say_msg(String(_wd_cfg["no_energy"]), RED, 2.8)
	sfx("lose")


func _water_input(event: InputEvent, click: bool) -> void:
	if _wd_mg != "":
		_wd_mg_input(event, click)
		return
	if _wd_stage != "pick":
		return
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		var h := -1
		for j in (_wd_cfg["tools"] as Array).size():
			if _wd_tool_rect(j).has_point(p):
				h = j
		var hp := _wd_poi_at(p)
		if (h != _wd_hover and h >= 0) or (hp != _wd_hover_poi and hp >= 0):
			sfx("hover")
		_wd_hover = h
		_wd_hover_poi = hp
	elif click:
		var p := get_local_mouse_position()
		for j in (_wd_cfg["tools"] as Array).size():
			if _wd_tool_rect(j).has_point(p):
				_water_use(j)
				return
		if WD_VIEW.has_point(p) or _wd_poi_at(p) >= 0:
			var hp := _wd_poi_at(p)
			_wd_goto = float((_wd_cfg["targets"] as Array)[hp]["x"]) if hp >= 0 else clampf(p.x, 20.0, 620.0)
			sfx("click")
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k >= KEY_1 and k <= KEY_5:
			_water_use(k - KEY_1)


func _water_use(j: int) -> void:
	if _wd_stage != "pick" or _wd_mg != "":
		return
	var tools: Array = _wd_cfg["tools"]
	var tl: Dictionary = tools[j]
	var tool_id := String(tl["id"])
	var cost := float(tl["cost"])
	# Pancam: revela las muestras cercanas (se puede usar en cualquier sitio).
	if tool_id == "pancam":
		if _wd_energy < cost:
			_wd_no_energy()
			return
		_wd_energy -= cost
		sfx("scan")
		var ok_p := await _wd_minigame("pancam", {})
		if not ok_p:
			_wd_log = String(_wd_cfg["mg_fail"])
			_wd_log_col = RED
			return
		_wd_scan_t = 0.7
		var n := 0
		for tg in _wd_cfg["targets"]:
			if absf(float((tg as Dictionary)["x"]) - _wd_x) <= float(_wd_cfg["scan_range"]) and not _wd_revealed.has(String(tg["id"])):
				_wd_revealed[String(tg["id"])] = true
				n += 1
		_wd_log = String(_wd_cfg["msg_scanned"]) % n if n > 0 else String(_wd_cfg["msg_nothing"])
		_wd_log_col = CYAN if n > 0 else GRAY_DIM
		return
	var ti := _wd_nearest()
	if ti < 0:
		_wd_log = String(_wd_cfg["msg_far"])
		_wd_log_col = GRAY_DIM
		sfx("error")
		return
	var tg: Dictionary = (_wd_cfg["targets"] as Array)[ti]
	var tid := String(tg["id"])
	if not _wd_revealed.has(tid):
		_wd_log = String(_wd_cfg["msg_scan"])
		_wd_log_col = GRAY_DIM
		sfx("error")
		return
	if _wd_solved.has(tid):
		_wd_log = String(_wd_cfg["msg_done"])
		_wd_log_col = GRAY_DIM
		sfx("error")
		return
	var used: Array = _wd_used.get(tid, [])
	if used.has(tool_id):
		_wd_log = String(_wd_cfg["msg_used"])
		_wd_log_col = GRAY_DIM
		sfx("error")
		return
	if _wd_energy < cost:
		_wd_no_energy()
		return
	_wd_energy -= cost
	var needs: Array = tg["needs"]
	var useful := needs.has(tool_id)
	var text := String((tg["results"] as Dictionary)[tool_id])
	if bool(tg["ordered"]) and tool_id == "apxs" and not used.has("rat"):
		# Con polvo encima no hay micro-reto que valga: la lectura sale inútil.
		text = String(tg["dusty"])
		useful = false
	else:
		var ok := await _wd_minigame(tool_id, tg)
		if not ok:
			_wd_log = String(_wd_cfg["mg_fail"])
			_wd_log_col = RED
			return
	_wd_log = text
	_wd_log_col = GREEN if useful else GRAY_DIM
	if not useful:
		await wait(0.2)
		sfx("error")
		return
	used.append(tool_id)
	_wd_used[tid] = used
	var done := true
	for n in needs:
		if not used.has(n):
			done = false
	if not done:
		return
	_wd_solved[tid] = true
	if tg.has("evidence"):
		_add_evidence(tg["evidence"])
	var outs: Array = tg["rules_out"]
	var ruled := false
	for h in outs:
		if bool(_wd_alive.get(String(h), false)):
			_wd_alive[String(h)] = false
			ruled = true
	sfx("win" if ruled else "tick")
	_wd_log = String(_wd_cfg["done_target"]) + " · " + String(tg["why"])
	_wd_log_col = YEL if ruled else GRAY
	var alive := 0
	for k in _wd_alive:
		if bool(_wd_alive[k]):
			alive += 1
	if alive == 1:
		_wd_stage = "concl"
		await wait(1.2)
		sfx("win")
		await toast(String(_wd_cfg["conclusion"]), GREEN, 3.2)
		_wd_stage = "done"


# ---- Micro-retos de los instrumentos (cada uno imita cómo funciona el instrumento)
var _wd_mg := ""
var _wd_mg_t := 0.0
var _wd_mg_ok := false
var _wd_mg_prog := 0.0
var _wd_mg_d := 1.0
var _wd_mg_limit := 12.0
var _wd_mg_a: Dictionary = {}
const MG := Rect2(12, 108, 616, 100)


func _wd_minigame(id: String, tg: Dictionary) -> bool:
	_wd_mg_d = 1.0 + 0.25 * float(_wd_solved.size())
	_wd_mg_t = 0.0
	_wd_mg_prog = 0.0
	_wd_mg_ok = false
	_wd_mg_a = {"tg": String(tg.get("id", ""))}
	match id:
		"pancam":
			_wd_mg_limit = 16.0
			var marks: Array = []
			for f in 3:
				for k in 2:
					marks.append({"x": randf_range(40.0, 600.0), "y": randf_range(136.0, 160.0), "f": f, "found": false})
			_wd_mg_a.merge({"filter": 0, "marks": marks, "found": 0})
		"mi":
			_wd_mg_limit = 14.0
			_wd_mg_a.merge({"f": randf(), "target": 0.5, "phase": randf() * TAU})
		"moss":
			_wd_mg_limit = 16.0
			_wd_mg_a.merge({"c": Vector2(320, 150), "shake": Vector2.ZERO, "gust": 0.0, "gust_t": 1.5, "tpos": Vector2(320, 150), "cross": Vector2(320, 150)})
		"apxs":
			_wd_mg_limit = 30.0
			var kinds: Array = []
			for i in 6:
				kinds.append(true)
			for i in 5:
				kinds.append(false)
			kinds.shuffle()
			var peaks: Array = []
			for i in kinds.size():
				peaks.append({"x": 660.0 + float(i) * 62.0, "target": kinds[i], "used": false, "h": randf_range(26.0, 44.0)})
			_wd_mg_a.merge({"peaks": peaks, "hits": 0, "miss": 0})
		"rat":
			_wd_mg_limit = 14.0
			_wd_mg_a.merge({"p": 0.0, "zone": 0.5, "heat": 0.0, "phase": randf() * TAU})
	_wd_mg = id
	while _wd_mg != "":
		await get_tree().process_frame
	return _wd_mg_ok


func _wd_mg_end(ok: bool) -> void:
	_wd_mg_ok = ok
	_wd_mg = ""
	sfx("ok" if ok else "lose")


func _wd_mg_input(event: InputEvent, click: bool) -> void:
	match _wd_mg:
		"pancam":
			if click:
				_mg_pancam_click(get_local_mouse_position())
			elif event is InputEventKey and event.pressed and not event.echo:
				var k := int(event.physical_keycode)
				if k == KEY_Q or k == KEY_LEFT:
					_mg_pancam_filter(-1)
				elif k == KEY_E or k == KEY_RIGHT:
					_mg_pancam_filter(1)
		"mi":
			if event is InputEventMouseMotion:
				_wd_mg_a["f"] = clampf((get_local_mouse_position().x - 24.0) / 592.0, 0.0, 1.0)
		"moss":
			if event is InputEventMouseMotion:
				_wd_mg_a["c"] = get_local_mouse_position().clamp(Vector2(40, 132), Vector2(600, 176))
		"apxs":
			if click or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_KP_ENTER)):
				_mg_apxs_press()


func _mg_pancam_filter(dir: int) -> void:
	_wd_mg_a["filter"] = (int(_wd_mg_a["filter"]) + dir + 3) % 3
	sfx("select")


func _mg_pancam_click(p: Vector2) -> void:
	for i in 3:
		if Rect2(24.0 + float(i) * 110.0, 168, 104, 16).has_point(p):
			_wd_mg_a["filter"] = i
			sfx("select")
			return
	for m in _wd_mg_a["marks"]:
		var md: Dictionary = m
		if not bool(md["found"]) and int(md["f"]) == int(_wd_mg_a["filter"]) and Vector2(float(md["x"]), float(md["y"])).distance_to(p) < 14.0:
			md["found"] = true
			_wd_mg_a["found"] = int(_wd_mg_a["found"]) + 1
			_wd_mg_prog = float(_wd_mg_a["found"]) / 6.0
			sfx("ping")
			var left := 0
			for m2 in _wd_mg_a["marks"]:
				if int((m2 as Dictionary)["f"]) == int(_wd_mg_a["filter"]) and not bool((m2 as Dictionary)["found"]):
					left += 1
			if left == 0 and int(_wd_mg_a["found"]) < 6:
				_wd_mg_a["switch_t"] = 0.5
			return
	_wd_mg_t += 0.6
	sfx("tick")


func _mg_apxs_press() -> void:
	var best := -1
	var bd := 16.0
	var peaks: Array = _wd_mg_a["peaks"]
	for i in peaks.size():
		var pk: Dictionary = peaks[i]
		var d := absf(float(pk["x"]) - 160.0)
		if not bool(pk["used"]) and d < bd:
			bd = d
			best = i
	if best >= 0 and bool((peaks[best] as Dictionary)["target"]):
		(peaks[best] as Dictionary)["used"] = true
		_wd_mg_a["hits"] = int(_wd_mg_a["hits"]) + 1
		_wd_mg_prog = float(_wd_mg_a["hits"]) / 4.0
		sfx("ping")
	else:
		if best >= 0:
			(peaks[best] as Dictionary)["used"] = true
		_wd_mg_a["miss"] = int(_wd_mg_a["miss"]) + 1
		sfx("error")


func _wd_mg_update(delta: float) -> void:
	_wd_mg_t += delta
	var a := _wd_mg_a
	var d := _wd_mg_d
	match _wd_mg:
		"pancam":
			if int(a["found"]) >= 6:
				_wd_mg_end(true)
				return
			if float(a.get("switch_t", 0.0)) > 0.0:
				a["switch_t"] = float(a["switch_t"]) - delta
				if float(a["switch_t"]) <= 0.0:
					# Salta al siguiente filtro que aún tenga destellos por encontrar.
					for k in range(1, 4):
						var nf := (int(a["filter"]) + k) % 3
						var pending := false
						for m3 in a["marks"]:
							if int((m3 as Dictionary)["f"]) == nf and not bool((m3 as Dictionary)["found"]):
								pending = true
						if pending:
							a["filter"] = nf
							sfx("select")
							break
		"mi":
			var f: float = a["f"]
			f = clampf(f + _axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT) * 0.6 * delta, 0.0, 1.0)
			a["f"] = f
			# Los primeros 2 s el punto de enfoque está quieto; después deriva despacio.
			var drift := maxf(0.0, _wd_mg_t - 2.0)
			var target := 0.5 + 0.22 * sin(drift * 0.3 * (1.0 + (d - 1.0) * 0.5) + float(a["phase"]))
			a["target"] = target
			var sharp := clampf(1.0 - absf(f - target) / 0.24, 0.0, 1.0)
			a["sharp"] = sharp
			if sharp >= 0.8:
				_wd_mg_prog += delta / 1.1
			else:
				_wd_mg_prog = maxf(0.0, _wd_mg_prog - delta * 0.5)
			if _wd_mg_prog >= 1.0:
				_wd_mg_end(true)
				return
		"moss":
			var c: Vector2 = a["c"]
			var kv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
			c = (c + kv * 120.0 * delta).clamp(Vector2(40, 132), Vector2(600, 176))
			a["c"] = c
			var gust: float = maxf(0.0, float(a["gust"]) - delta * 0.7)
			var gt: float = float(a["gust_t"]) - delta
			if gt <= 0.0:
				gust = 1.0
				gt = randf_range(2.0, 3.5)
				sfx("whoosh", 1.0, -16.0)
			a["gust"] = gust
			a["gust_t"] = gt
			var amp := 4.0 + gust * 14.0
			var sh := Vector2(sin(_wd_mg_t * 17.0), cos(_wd_mg_t * 13.0)) * amp
			a["shake"] = sh
			var cross := c + sh
			a["cross"] = cross
			var tpos := Vector2(320.0 + 70.0 * sin(_wd_mg_t * 0.5 * d), 154.0 + 14.0 * sin(_wd_mg_t * 0.9 * d))
			a["tpos"] = tpos
			if cross.distance_to(tpos) < 22.0:
				_wd_mg_prog += delta / (3.2 * sqrt(d))
			else:
				_wd_mg_prog = maxf(0.0, _wd_mg_prog - delta * 0.4)
			if _wd_mg_prog >= 1.0:
				_wd_mg_end(true)
				return
		"apxs":
			var speed := 85.0 * (1.0 + (d - 1.0) * 0.5)
			var peaks: Array = a["peaks"]
			var alive := 0
			for pk in peaks:
				var p: Dictionary = pk
				p["x"] = float(p["x"]) - speed * delta
				if float(p["x"]) > 10.0:
					alive += 1
			if int(a["miss"]) >= 3:
				_wd_mg_end(false)
				return
			if int(a["hits"]) >= 4:
				_wd_mg_end(true)
				return
			if alive == 0:
				_wd_mg_end(false)
				return
		"rat":
			var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
			var p: float = a["p"]
			p = clampf(p + (1.1 if held else -0.9) * delta, 0.0, 1.0)
			a["p"] = p
			var zone := 0.5 + 0.2 * sin(_wd_mg_t * 0.9 * d + float(a["phase"]))
			a["zone"] = zone
			var heat: float = a["heat"]
			heat = clampf(heat + (0.8 if p > 0.88 else -0.5) * delta, 0.0, 1.0)
			a["heat"] = heat
			if absf(p - zone) < 0.12 / sqrt(d):
				_wd_mg_prog += delta / 3.5
				if int(_wd_mg_t * 8.0) % 3 == 0:
					sfx("tick", 0.6, -18.0)
			else:
				_wd_mg_prog = maxf(0.0, _wd_mg_prog - delta * 0.2)
			if heat >= 1.0:
				_say_msg(String(_wd_cfg["mg_hot"]), RED, 2.0)
				_wd_mg_end(false)
				return
			if _wd_mg_prog >= 1.0:
				_wd_mg_end(true)
				return
	if _wd_mg_t >= _wd_mg_limit:
		var ok := false
		if _wd_mg == "pancam":
			ok = int(a["found"]) >= 5
		_wd_mg_end(ok)


func _draw_mg(c: CanvasItem) -> void:
	var a := _wd_mg_a
	c.draw_rect(MG, Color("#0e0a08"))
	c.draw_rect(MG, GOLD, false, 2.0)
	var tools: Array = _wd_cfg["tools"]
	var tname := ""
	for tl in tools:
		if String((tl as Dictionary)["id"]) == _wd_mg:
			tname = String((tl as Dictionary)["name"])
	_txt(c, Vector2(MG.position.x + 8, MG.position.y + 12), tname, 10, GOLD, 200)
	_txt(c, Vector2(MG.position.x + 112, MG.position.y + 12), String((_wd_cfg["mg"] as Dictionary)[_wd_mg]), 8, GRAY, 296)
	var tl_left := clampf(1.0 - _wd_mg_t / _wd_mg_limit, 0.0, 1.0)
	c.draw_rect(Rect2(420, 112, 200, 5), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(420, 112, 200.0 * tl_left, 5), RED if tl_left < 0.25 else CYAN)
	c.draw_rect(Rect2(24, 196, 592, 6), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(24, 196, 592.0 * clampf(_wd_mg_prog, 0.0, 1.0), 6), GREEN)
	c.draw_rect(Rect2(24, 196, 592, 6), GRAY_DIM, false, 1.0)
	var area := Rect2(24, 128, 592, 62)
	match _wd_mg:
		"pancam":
			var flt := int(a["filter"])
			var tints := [Color(0, 0, 0, 0), Color(1, 0.2, 0.1, 0.18), Color(0.5, 0.1, 0.8, 0.28)]
			c.draw_rect(area, MARS.darkened(0.2))
			c.draw_rect(area, tints[flt])
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in 60:
				c.draw_rect(Rect2(area.position.x + floorf(rng.randf() * area.size.x), area.position.y + floorf(rng.randf() * 36.0), 2, 1), MARS_DARK)
			for m in a["marks"]:
				var md: Dictionary = m
				if int(md["f"]) != flt:
					continue
				var mp := Vector2(float(md["x"]), float(md["y"]))
				if bool(md["found"]):
					c.draw_arc(mp, 9.0, 0, TAU, 14, GREEN, 2.0)
				else:
					var pl := 0.5 + 0.5 * sin(_t * 8.0 + mp.x)
					c.draw_line(mp - Vector2(5, 0), mp + Vector2(5, 0), Color(1, 1, 0.8, 0.5 + pl * 0.5), 1.0)
					c.draw_line(mp - Vector2(0, 5), mp + Vector2(0, 5), Color(1, 1, 0.8, 0.5 + pl * 0.5), 1.0)
			var names := [tr("VISIBLE"), tr("ROJO"), tr("INFRARROJO")]
			for i in 3:
				var r := Rect2(24.0 + float(i) * 110.0, 168, 104, 16)
				_box(c, r, Color("#4a3020") if i == flt else Color("#2a1c16"), YEL if i == flt else GRAY_DIM, "%d  %s" % [i + 1, String(names[i])], 8, Color.WHITE)
			_txt(c, Vector2(380, 180), tr("DESTELLOS") + " %d / 6" % int(a["found"]), 9, YEL, 230, HORIZONTAL_ALIGNMENT_RIGHT)
		"mi":
			var sharp: float = float(a.get("sharp", 0.0))
			c.draw_rect(Rect2(24, 128, 200, 62), Color("#16120e"))
			var blur := (1.0 - sharp) * 7.0
			var offs := [Vector2.ZERO] if blur < 0.6 else [Vector2(-blur, 0), Vector2(blur, 0), Vector2(0, -blur * 0.5), Vector2(0, blur * 0.5)]
			for o in offs:
				c.draw_set_transform(Vector2(124, 164) + (o as Vector2), 0.0, Vector2(2.6, 2.6))
				_draw_poi(c, String(a["tg"]), Vector2.ZERO, true)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			c.draw_rect(Rect2(24, 128, 200, 62), Color(0.1, 0.07, 0.05, (1.0 - sharp) * 0.35))
			c.draw_rect(Rect2(24, 128, 200, 62), GRAY_DIM, false, 1.0)
			# Rueda de enfoque.
			_txt(c, Vector2(250, 142), tr("ENFOQUE"), 9, GRAY)
			c.draw_rect(Rect2(250, 150, 360, 8), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(250, 150, 360, 8), GRAY_DIM, false, 1.0)
			c.draw_rect(Rect2(250.0 + 360.0 * float(a["f"]) - 3.0, 145, 6, 18), Color.WHITE)
			_txt(c, Vector2(250, 178), tr("NITIDEZ"), 9, GRAY)
			c.draw_rect(Rect2(300, 170, 310, 8), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(300, 170, 310.0 * sharp, 8), GREEN if sharp >= 0.8 else YEL)
			c.draw_line(Vector2(300.0 + 310.0 * 0.8, 167), Vector2(300.0 + 310.0 * 0.8, 181), Color.WHITE, 2.0)
			if sharp < 0.6:
				var dirx := float(a["target"]) - float(a["f"])
				_txt(c, Vector2(250.0 + 360.0 * float(a["f"]) - 20.0, 144), "<<" if dirx < 0.0 else ">>", 10, YEL, 40, HORIZONTAL_ALIGNMENT_CENTER)
		"moss":
			c.draw_rect(area, Color("#2a1c16"))
			for i in 10:
				c.draw_line(Vector2(area.position.x + float(i) * 60.0, area.position.y), Vector2(area.position.x + float(i) * 60.0, area.end.y), Color(1, 1, 1, 0.05), 1.0)
			var tpos: Vector2 = a.get("tpos", Vector2(320, 150))
			var cross: Vector2 = a.get("cross", Vector2(320, 150))
			var inside := cross.distance_to(tpos) < 22.0
			c.draw_arc(tpos, 22.0, 0, TAU, 28, GREEN if inside else YEL, 2.0)
			c.draw_line(cross - Vector2(10, 0), cross + Vector2(10, 0), Color.WHITE, 1.0)
			c.draw_line(cross - Vector2(0, 10), cross + Vector2(0, 10), Color.WHITE, 1.0)
			if float(a.get("gust", 0.0)) > 0.3:
				_txt(c, Vector2(24, 140), tr("RÁFAGA"), 9, RED)
		"apxs":
			c.draw_rect(area, Color("#10140e"))
			c.draw_line(Vector2(24, 186), Vector2(616, 186), GRAY_DIM, 1.0)
			c.draw_line(Vector2(160, 128), Vector2(160, 190), YEL, 2.0)
			for pk in a["peaks"]:
				var p: Dictionary = pk
				var px := float(p["x"])
				if px < 24.0 or px > 616.0:
					continue
				var h := float(p["h"])
				var col := (GREEN if bool(p["target"]) else GRAY_DIM)
				if bool(p["used"]):
					col = Color(col, 0.3)
				c.draw_colored_polygon(PackedVector2Array([Vector2(px - 9, 186), Vector2(px, 186.0 - h), Vector2(px + 9, 186)]), col)
			_txt(c, Vector2(30, 140), tr("ACIERTOS") + " %d/4   " % int(a["hits"]) + tr("ERRORES") + " %d/3" % int(a["miss"]), 9, YEL, 300)
		"rat":
			var p: float = float(a.get("p", 0.0))
			var zone: float = float(a.get("zone", 0.5))
			var gx := 24.0
			var gw := 360.0
			_txt(c, Vector2(gx, 140), tr("PRESIÓN"), 9, GRAY)
			c.draw_rect(Rect2(gx, 146, gw, 14), Color(0, 0, 0, 0.6))
			var zw := 0.12 / sqrt(_wd_mg_d)
			c.draw_rect(Rect2(gx + gw * (zone - zw), 146, gw * zw * 2.0, 14), Color(GREEN, 0.45))
			c.draw_rect(Rect2(gx + gw * 0.88, 146, gw * 0.12, 14), Color(RED, 0.35))
			c.draw_rect(Rect2(gx, 146, gw, 14), GRAY_DIM, false, 1.0)
			c.draw_rect(Rect2(gx + gw * p - 3.0, 142, 6, 22), Color.WHITE)
			_txt(c, Vector2(gx, 178), tr("CALOR"), 9, GRAY)
			c.draw_rect(Rect2(gx + 40, 170, 200, 8), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(gx + 40, 170, 200.0 * float(a.get("heat", 0.0)), 8), RED)
			# Roca con polvo que se va limpiando.
			var rr := Rect2(440, 134, 160, 50)
			c.draw_rect(rr, Color("#6a4a3a"))
			c.draw_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, rr.size.y), Color(0.85, 0.6, 0.4, 1.0 - clampf(_wd_mg_prog, 0.0, 1.0)))
			c.draw_rect(rr, GRAY_DIM, false, 1.0)
			if absf(p - zone) < zw and p > 0.05:
				for i in 5:
					c.draw_rect(Rect2(rr.position.x + 40.0 + randf() * 80.0, rr.position.y + 10.0 + randf() * 30.0, 2, 2), YEL)


func _draw_water(c: DrawNode) -> void:
	if _wd_cfg.is_empty():
		return
	c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), PANEL)
	# Tablero de hipótesis: cada una se tacha cuando una prueba la descarta.
	_txt(c, Vector2(12, 80), String(_wd_cfg["hyp_title"]), 8, GOLD)
	var hyps: Array = _wd_cfg["hypotheses"]
	var only_agua := _wd_stage == "concl" or _wd_stage == "done"
	for i in hyps.size():
		var h: Dictionary = hyps[i]
		var r := Rect2(12.0 + float(i) * 206.0, 84, 200, 22)
		var alive := bool(_wd_alive.get(String(h["id"]), true))
		var win := only_agua and alive
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		c.draw_rect(r, Color("#16281a") if win else (Color("#2a1c16") if alive else Color("#140c0a")))
		c.draw_rect(r, YEL.lerp(Color.WHITE, pulse) if win else (GOLD if alive else Color("#5a3030")), false, 2.0 if win else 1.0)
		_txt(c, Vector2(r.position.x, r.position.y + 15), String(h["name"]), 10, GREEN if win else (Color.WHITE if alive else GRAY_DIM), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if not alive:
			c.draw_line(r.position + Vector2(6, 11), r.position + Vector2(r.size.x - 6, 11), RED, 2.0)
	# Afloramiento: cielo, borde del cráter lejano y suelo.
	c.draw_rect(WD_VIEW, SKY_LOW)
	c.draw_rect(Rect2(WD_VIEW.position, Vector2(WD_VIEW.size.x, 22)), SKY_TOP)
	var rim := PackedVector2Array([Vector2(12, 134), Vector2(90, 124), Vector2(180, 130), Vector2(290, 120), Vector2(420, 128), Vector2(520, 122), Vector2(628, 130), Vector2(628, 140), Vector2(12, 140)])
	c.draw_colored_polygon(rim, MARS_DARK)
	c.draw_rect(Rect2(12, 140, 616, 36), MARS)
	c.draw_rect(Rect2(12, 140, 616, 2), MARS_LIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 70:
		c.draw_rect(Rect2(12.0 + floorf(rng.randf() * 612.0), 144.0 + floorf(rng.randf() * 30.0), 2, 1), MARS_DARK if i % 2 == 0 else MARS_LIGHT)
	var near := _wd_nearest()
	var targets: Array = _wd_cfg["targets"]
	for i in targets.size():
		var tg: Dictionary = targets[i]
		var px := float(tg["x"])
		var rev := _wd_revealed.has(String(tg["id"]))
		var solved := _wd_solved.has(String(tg["id"]))
		_draw_poi(c, String(tg["id"]), Vector2(px, WD_POI_Y), rev)
		if solved:
			c.draw_arc(Vector2(px, WD_POI_Y - 6), 15.0, 0, TAU, 20, GREEN, 2.0)
		if rev:
			_txt(c, Vector2(px - 50, WD_POI_Y - 28), String(tg["name"]), 7, GRAY, 100, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_txt(c, Vector2(px - 10, WD_POI_Y - 20), "?", 12, YEL, 20, HORIZONTAL_ALIGNMENT_CENTER)
		if i == _wd_hover_poi:
			c.draw_rect(_wd_poi_rect(tg), Color.WHITE, false, 1.0)
		if i == near and _wd_stage == "pick":
			c.draw_line(Vector2(px - 14, WD_POI_Y + 12), Vector2(px + 14, WD_POI_Y + 12), YEL, 2.0)
			_txt(c, Vector2(px - 40, WD_POI_Y + 22), tr("EN RANGO"), 7, YEL, 80, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_rover_side(c, Vector2(_wd_x, WD_ROVER_Y), 1.2, 0.0, _wd_x * 0.2, SILVER)
	if _wd_scan_t > 0.0:
		var f := 1.0 - _wd_scan_t / 0.7
		c.draw_arc(Vector2(_wd_x, WD_ROVER_Y - 14), float(_wd_cfg["scan_range"]) * f, PI, TAU, 40, Color(CYAN, 1.0 - f), 2.0)
	# Resultado de la lectura.
	var lr := Rect2(12, 180, 616, 26)
	c.draw_rect(lr, Color("#120c0a"))
	c.draw_rect(lr, GRAY_DIM, false, 1.0)
	_txt(c, Vector2(18, 196), tr("LECTURA"), 8, GRAY_DIM, 60)
	var shown := _wd_log if _wd_log != "" else tr("SIN LECTURA TODAVÍA")
	c.draw_multiline_string(ThemeDB.fallback_font, Vector2(70, 191), shown, HORIZONTAL_ALIGNMENT_LEFT, 552, 9, 2, _wd_log_col if _wd_log != "" else GRAY_DIM)
	# Instrumentos.
	var tools: Array = _wd_cfg["tools"]
	for j in tools.size():
		var t: Dictionary = tools[j]
		var r := _wd_tool_rect(j)
		var hov := _wd_hover == j
		var tid := ""
		if near >= 0:
			tid = String((targets[near] as Dictionary)["id"])
		var was_used := tid != "" and (_wd_used.get(tid, []) as Array).has(String(t["id"]))
		c.draw_rect(r, Color("#4a3020") if hov else (Color("#1a1210") if was_used else Color("#2a1c16")))
		c.draw_rect(r, Color.WHITE if hov else (GRAY_DIM if was_used else GOLD), false, 2.0 if hov else 1.0)
		_txt(c, Vector2(r.position.x + 5, r.position.y + 13), String(t["name"]), 9, GRAY_DIM if was_used else GOLD, r.size.x - 8)
		_txt(c, Vector2(r.position.x + 5, r.position.y + 26), String(t["q"]), 8, GRAY, r.size.x - 8)
		_txt(c, Vector2(r.position.x, r.position.y + 13), "-%d" % int(t["cost"]), 8, GRAY_DIM, r.size.x - 5, HORIZONTAL_ALIGNMENT_RIGHT)
	if _wd_mg != "":
		_draw_mg(c)
	_draw_msg(c, 112)


## Dibujo de cada muestra (sin escanear se ve como una roca gris).
func _draw_poi(c: CanvasItem, id: String, p: Vector2, rev: bool) -> void:
	if not rev:
		c.draw_circle(p + Vector2(0, -4), 7.0, Color("#6a5a50"))
		return
	match id:
		"esferas":
			for k in 8:
				c.draw_circle(p + Vector2(-9.0 + float(k % 4) * 6.0, -8.0 + float(k / 4) * 6.0), 2.5, Color("#7a8ac8"))
		"capas":
			for k in 4:
				c.draw_rect(Rect2(p.x - 13, p.y - 14 + float(k) * 5.0, 26, 4), MARS_DARK.lerp(MARS_LIGHT, float(k) / 4.0))
		"basalto":
			c.draw_circle(p + Vector2(0, -6), 10.0, Color("#2a2428"))
			c.draw_circle(p + Vector2(-3, -9), 4.0, Color("#4a4048"))
		"arena":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 4), p + Vector2(-5, -8), p + Vector2(5, -8), p + Vector2(14, 4)]), Color("#d8a878"))


## Opción de respuesta resaltada si el ratón o las flechas están sobre ella.
func _draw_option(c: CanvasItem, r: Rect2, number: int, text: String, focused: bool, size: int = 9) -> void:
	c.draw_rect(r, Color("#4a3020") if focused else Color("#2a1c16"))
	c.draw_rect(r, Color.WHITE if focused else GOLD, false, 2.0 if focused else 1.0)
	if focused:
		c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 7, r.position.y + r.size.y * 0.5 - 4), Vector2(r.position.x - 2, r.position.y + r.size.y * 0.5), Vector2(r.position.x - 7, r.position.y + r.size.y * 0.5 + 4)]), GOLD)
	_txt(c, Vector2(r.position.x + 6, r.position.y + r.size.y * 0.5 + 4), "%d" % number, 11, GOLD)
	c.draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 22, r.position.y + 12), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, size, 2, Color.WHITE)



# =========================================================================
# FASE 2 · Atrapada en Purgatory (ensayo en la Tierra + escape real)
# =========================================================================
var _sd_cnt := 0
var _sd_hover := -1
var _sd_coach := ""
const SD_KEYS := ["fl", "fs", "bs", "bl"]


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
		_bar_red_low = false
		var sols := tr("ENSAYO") if _sd_test else "%d / %d" % [_sd_cnt / 4, int(_sd_cfg["sols_real"])]
		return [
			[tr("PROGRESO"), "%d%%" % int(_sd_prog * 100.0)],
			[tr("PATINAJE"), "%d%%" % int(_sd_slip * 100.0), RED if _sd_slip > 0.6 else GOLD],
			[tr("SOLES"), "%s · %d/4" % [sols, _sd_cnt % 4], CYAN if _sd_test else GOLD],
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
	_sd_cnt = 0
	_sd_x = 0.0
	_sd_busy = false
	_sd_coach = String(_sd_cfg["coach_start"])


func _sd_info() -> void:
	_mm_info.text = String(_sd_cfg["info_test"]) if _sd_test else String(_sd_cfg["info_real"])


func _sd_cmd_rect(i: int) -> Rect2:
	return Rect2(10.0 + float(i) * 156.0, 202, 150, 40)


func _sand_input(event: InputEvent, click: bool) -> void:
	if event is InputEventMouseMotion:
		var h := -1
		for i in 4:
			if _sd_cmd_rect(i).has_point(get_local_mouse_position()):
				h = i
		if h != _sd_hover and h >= 0:
			sfx("hover")
		_sd_hover = h
		return
	if _sd_busy:
		return
	if click:
		for i in 4:
			if _sd_cmd_rect(i).has_point(get_local_mouse_position()):
				_sd_exec(i)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k >= KEY_1 and k <= KEY_4:
			_sd_exec(k - KEY_1)


func _sd_exec(i: int) -> void:
	if _sd_busy:
		return
	_sd_busy = true
	var cd: Dictionary = (_sd_cfg["cmds"] as Dictionary)[SD_KEYS[i]]
	var k: float = float(_sd_cfg["k_test"]) if _sd_test else float(_sd_cfg["k_real"])
	var step: float = float(cd["step"])
	sfx("motor" if step > 0.0 else "servo")
	await wait(0.6)
	var stopped := false
	if step > 0.0:
		var slip := clampf(float(cd["slip0"]) * k + 0.9 * _sd_sink * k, 0.0, 1.0)
		_sd_slip = slip
		if slip > float(_sd_cfg["slip_limit"]):
			stopped = true
			_say_msg(String(_sd_cfg["slip_stop"]), RED, 2.4)
			sfx("warn")
			_sd_spin += 3.0
		else:
			_sd_prog += step * (1.0 - slip)
			_sd_sink = minf(1.0, _sd_sink + float(cd["sink"]) * slip * k)
			if slip > 0.5:
				sfx("grind")
	else:
		_sd_slip = 0.0
		_sd_prog += step * 0.5
		_sd_sink = maxf(0.0, _sd_sink - float(cd["relief"]))
		sfx("ok")
	_sd_prog = maxf(0.0, _sd_prog)
	_sd_cnt += 1
	if stopped:
		_sd_coach = String(_sd_cfg["coach_stop"])
	elif _sd_sink > 0.6:
		_sd_coach = String(_sd_cfg["coach_sink"])
	elif _sd_slip > 0.5:
		_sd_coach = String(_sd_cfg["coach_slip"])
	else:
		_sd_coach = String(_sd_cfg["coach_ok"])
	if _sd_cnt % 4 == 0:
		sfx("tick")
	if _sd_prog >= 1.0:
		if _sd_test:
			sfx("win")
			await toast(String(_sd_cfg["test_ok"]), GREEN, 1.8)
			_sd_test = false
			_sd_reset()
			_sd_info()
		else:
			sfx("win")
			await toast(String(_sd_cfg["freed"]), GREEN, 1.8)
			_sd_free = true
		return
	if not _sd_test and _sd_cnt >= int(_sd_cfg["sols_real"]) * 4:
		sfx("lose")
		await toast(String(_sd_cfg["fail_real"]), RED, 1.8)
		_sd_reset()
		return
	_sd_busy = false


func _draw_sand(c: DrawNode) -> void:
	if _sd_cfg.is_empty():
		return
	_mars_sky(c, GAME_TOP, 150.0)
	_mars_ground(c, 150.0, 21)
	c.draw_rect(Rect2(0, 150, W, 40), Color(MARS_LIGHT, 0.35))
	for i in 12:
		c.draw_line(Vector2(float(i) * 60.0, 160), Vector2(float(i) * 60.0 + 40.0, 160 + sin(float(i)) * 5.0), Color(MARS_DARK, 0.6), 1.0)
	_txt(c, Vector2(0, 142), "PURGATORY", 9, GRAY_DIM, W, HORIZONTAL_ALIGNMENT_CENTER)
	_sd_x = lerpf(_sd_x, _sd_prog, 0.1)
	if _sd_busy:
		_sd_spin += 0.35
	var rx := 70.0 + _sd_x * 470.0
	var ry := 148.0
	_draw_rover_side(c, Vector2(rx, ry), 2.2, _sd_sink * 1.6, _sd_spin, SILVER)
	if _sd_busy and _sd_slip > 0.3:
		for i in 8:
			c.draw_rect(Rect2(rx - 30.0 + randf() * 14.0, ry + 4.0 + randf() * 8.0, 2, 2), MARS_LIGHT)
	c.draw_line(Vector2(540, 126), Vector2(540, 156), GREEN, 1.0)
	_txt(c, Vector2(480, 120), ">", 12, GREEN, 120, HORIZONTAL_ALIGNMENT_CENTER)
	# Barra de patinaje con su límite (slip check).
	var lim := float(_sd_cfg["slip_limit"])
	var bar := Rect2(170, 172, 300, 6)
	c.draw_rect(bar, Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _sd_slip, 6)), RED if _sd_slip > lim else (YEL if _sd_slip > 0.5 else GREEN))
	c.draw_rect(bar, GRAY_DIM, false, 1.0)
	c.draw_line(Vector2(bar.position.x + bar.size.x * lim, 169), Vector2(bar.position.x + bar.size.x * lim, 181), Color.WHITE, 2.0)
	_txt(c, Vector2(20, 178), tr("PATINAJE"), 8, GRAY, 146, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(c, Vector2(0, 194), _sd_coach, 9, YEL, W, HORIZONTAL_ALIGNMENT_CENTER)
	# Órdenes.
	for i in 4:
		var r := _sd_cmd_rect(i)
		var cd: Dictionary = (_sd_cfg["cmds"] as Dictionary)[SD_KEYS[i]]
		var hov := _sd_hover == i and not _sd_busy
		c.draw_rect(r, Color("#4a3020") if hov else (Color("#1a1210") if _sd_busy else Color("#2a1c16")))
		c.draw_rect(r, Color.WHITE if hov else (GRAY_DIM if _sd_busy else GOLD), false, 2.0 if hov else 1.0)
		_txt(c, Vector2(r.position.x + 5, r.position.y + 13), "%d  %s" % [i + 1, String(cd["name"])], 9, GRAY_DIM if _sd_busy else GOLD, r.size.x - 8)
		c.draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 5, r.position.y + 25), String(cd["desc"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 8, 2, GRAY)
	_txt(c, Vector2(400, 84), tr("ENSAYO") if _sd_test else tr("MARTE"), 11, CYAN if _sd_test else GOLD, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_msg(c, 112)


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
var _wh_snd := 0.0
var _wh_beep := 0.0


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
		_wh_snd -= delta
		if _wh_snd <= 0.0:
			_wh_snd = 0.3
			sfx("motor", 1.0, -17.0)
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
					sfx("ping")
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
		_wh_beep -= delta
		if _wh_beep <= 0.0:
			_wh_beep = 0.22
			sfx("tick", 0.8 + _wh_an, -10.0)
		if _wh_an >= 1.0:
			_wh_an = 0.0
			var p: Dictionary = _wh_patches[target]
			p["done"] = true
			if String(p["kind"]) == "silice":
				_wh_found += 1
				_say_msg(String(_wh_cfg["silica"]), GREEN, 2.4)
				sfx("win")
			else:
				_say_msg(String(_wh_cfg["decoy"]), GRAY, 2.4)
				sfx("error")
			if _wh_found >= int(_wh_cfg["need"]):
				_wh_done = true
	else:
		_wh_an = maxf(0.0, _wh_an - delta * 2.0)
	if _wh_energy <= 0.0:
		_say_msg(String(_wh_cfg["no_energy"]), RED, 2.6)
		sfx("lose")
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


var _wi_drag := -1
var _wi_hover := -1


func _wi_bar_rect(i: int) -> Rect2:
	var r := _wi_row_rect(i)
	return Rect2(r.position.x + 6.0, r.position.y + 14.0, 270, 18)


func _winter_input(event: InputEvent, click: bool) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_wi_drag = -1
		return
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		var h := -1
		for i in 3:
			if _wi_row_rect(i).has_point(p):
				h = i
		if h != _wi_hover and h >= 0 and _wi_drag < 0:
			sfx("hover")
		_wi_hover = h
		if _wi_drag >= 0:
			_wi_set_x(_wi_drag, p.x)
		return
	if _wi_busy:
		return
	if click:
		var p := get_local_mouse_position()
		for i in 3:
			if _wi_btn_rect(i, false).has_point(p):
				_wi_row = i
				_wi_change(i, -1.0)
			elif _wi_btn_rect(i, true).has_point(p):
				_wi_row = i
				_wi_change(i, 1.0)
			elif _wi_bar_rect(i).has_point(p):
				_wi_row = i
				_wi_drag = i
				_wi_set_x(i, p.x)
			elif _wi_row_rect(i).has_point(p):
				_wi_row = i
				sfx("select")
		if _wi_send_rect().has_point(p):
			_winter_send()
	elif event is InputEventKey and event.pressed:
		match int(event.physical_keycode):
			KEY_UP, KEY_W:
				_wi_row = (_wi_row + 2) % 3
				sfx("select")
			KEY_DOWN, KEY_S:
				_wi_row = (_wi_row + 1) % 3
				sfx("select")
			KEY_LEFT, KEY_A: _wi_change(_wi_row, -1.0)
			KEY_RIGHT, KEY_D: _wi_change(_wi_row, 1.0)
			KEY_ENTER, KEY_KP_ENTER:
				if not event.echo:
					_winter_send()


## Arrastrar la barra con el ratón: el valor sigue al puntero sin pasarse de la energía disponible.
func _wi_set_x(row: int, x: float) -> void:
	var bx := _wi_bar_rect(row).position.x
	var stepv := float(_wi_cfg["step"])
	var v := roundf(clampf((x - bx) / 270.0 * 100.0, 0.0, 100.0) / stepv) * stepv
	var cap := float(_wi_alloc[row]) + (_wi_avail() - _wi_total())
	if v > cap:
		v = floorf(cap / stepv) * stepv
	if v != float(_wi_alloc[row]):
		_wi_alloc[row] = v
		sfx("tick", 0.7 + v / 100.0 * 1.3, -13.0)


func _wi_change(row: int, dir: float) -> void:
	var step := float(_wi_cfg["step"]) * dir
	var nv := maxf(0.0, float(_wi_alloc[row]) + step)
	if dir > 0.0 and _wi_total() + step > _wi_avail() + 0.01:
		_say_msg(String(_wi_cfg["over"]), RED, 1.4)
		sfx("error")
		return
	if nv != float(_wi_alloc[row]):
		_wi_alloc[row] = nv
		sfx("tick", 0.7 + nv / 100.0 * 1.3, -13.0)


func _wi_predict() -> Dictionary:
	var h := float(_wi_alloc[0])
	var temp := clampf(_wi_temp + float(_wi_cfg["temp_gain"]) * (h - _wi_need()), 0.0, 100.0)
	var batt := clampf(_wi_batt + _wi_income() - _wi_total(), 0.0, 100.0)
	return {"temp": temp, "batt": batt}


func _winter_send() -> void:
	_wi_busy = true
	sfx("send")
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
		sfx("lose")
		await toast(fail, RED, 2.0)
		await toast(String(_wi_cfg["msg_retry"]), GOLD, 1.0)
		_wi_reset()
		return
	if _wi_turn >= int(_wi_cfg["turns"]):
		if _wi_sci >= float(_wi_cfg["sci_goal"]):
			sfx("win")
			_wi_won = true
		else:
			_wi_busy = true
			sfx("lose")
			await toast(String(_wi_cfg["msg_end"]) % int(_wi_sci), GOLD, 2.0)
			await toast(String(_wi_cfg["msg_low_sci"]), RED, 2.0)
			_wi_reset()
		return
	sfx("ok" if comm_ok else "warn")
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
		c.draw_rect(r, Color("#3a2820") if (i == _wi_drag or i == _wi_hover) else (Color("#2a1c16") if i == _wi_row else Color("#1a1210")))
		c.draw_rect(r, GOLD if i == _wi_row else (Color.WHITE if i == _wi_hover else GRAY_DIM), false, 2.0 if i == _wi_row else 1.0)
		_txt(c, Vector2(r.position.x + 6, r.position.y + 12), String(rows[i]), 10, cols[i])
		var bx := r.position.x + 6.0
		var by := r.position.y + 18.0
		c.draw_rect(Rect2(bx, by, 270, 10), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bx, by, 270.0 * float(_wi_alloc[i]) / 100.0, 10), cols[i])
		c.draw_rect(Rect2(bx, by, 270, 10), GRAY_DIM, false, 1.0)
		var kx := bx + 270.0 * float(_wi_alloc[i]) / 100.0
		c.draw_rect(Rect2(kx - 2, by - 4, 4, 18), Color.WHITE if (i == _wi_drag or i == _wi_hover) else GRAY)
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
	_txt(c, Vector2(262, 252), tr("ARRASTRA PARA REPARTIR"), 8, GRAY_DIM, 220)
	_txt(c, Vector2(262, 240), cl + ("   [" + str(_wi_miss) + "]" if _wi_miss > 0 else ""), 10, GREEN if comm_ok else RED, 220)
	_box(c, _wi_send_rect(), Color("#2a3a1c"), GREEN, tr("ENVIAR TRAMO [ENTER]"), 9, GREEN)
	_draw_msg(c, 64)


# =========================================================================
# FASE 5 · Rumbo a Endeavour (el rover avanza en vivo hacia tus puntos y deja rastro)
# =========================================================================
var _rt_cfg: Dictionary = {}
var _rt_wps: Array = []
var _rt_cursor := Vector2(320, 160)
var _rt_rover := Vector2.ZERO
var _rt_ang := 0.0
var _rt_used := 0.0
var _rt_trail: Array = []
var _rt_ghosts: Array = []
var _rt_seen: Dictionary = {}
var _rt_started := false
var _rt_done := false
var _rt_in_dune := false
var _rt_step_t := 0.0


func _act_route(sc: Dictionary) -> void:
	await say(sc["intro"])
	_rt_cfg = sc["minimission"]
	_mm_title.text = String(_rt_cfg["title"])
	_mm_info.text = String(_rt_cfg["info"])
	_rt_ghosts = []
	_rt_done = false
	_rt_attempt_reset(false)
	_bar_name = tr("SOLES")
	_bar_show = true
	_tele_fn = func() -> Array:
		var budget := float(_rt_cfg["budget"])
		_bar_val = clampf((budget - _rt_used) / budget * 100.0, 0.0, 100.0)
		return [
			[tr("USADOS"), "%s / %d" % [_num(_rt_used), int(budget)], RED if _rt_used > budget * 0.85 else GREEN],
			[tr("PUNTOS PENDIENTES"), "%d / %d" % [_rt_wps.size(), int(_rt_cfg["max_wps"])]],
		]
	_layer(_draw_route)
	_input_cb = _route_input
	while not _rt_done:
		await get_tree().process_frame
		if not get_tree().paused:
			_route_drive(get_process_delta_time())
	_input_cb = Callable()
	sfx("win")
	await toast(String(_rt_cfg["msg_arrive"]), GREEN, 1.6)
	dialog.show_hint("INGENIERIA", String(_rt_cfg["reverse_note"]), 6.0)
	await toast(String(_rt_cfg["milestone_a"]), YEL, 2.2)
	await toast(String(_rt_cfg["milestone_b"]), YEL, 2.2)
	await say(sc["outro"])
	for ev in sc["evidence"]:
		await _add_evidence(ev)


func _rt_start() -> Vector2:
	var a: Array = _rt_cfg["start"]
	return Vector2(float(a[0]), float(a[1]))


func _rt_end() -> Vector2:
	var a: Array = _rt_cfg["end"]
	return Vector2(float(a[0]), float(a[1]))


## Nuevo intento: el rover vuelve al inicio. El rastro anterior queda como guía (fantasma).
func _rt_attempt_reset(keep_ghost: bool) -> void:
	if keep_ghost and _rt_trail.size() > 2:
		_rt_ghosts.append(_rt_trail.duplicate())
		if _rt_ghosts.size() > 3:
			_rt_ghosts.pop_front()
	_rt_trail = []
	_rt_wps = []
	_rt_used = 0.0
	_rt_seen = {}
	_rt_started = false
	_rt_rover = _rt_start()
	_rt_ang = (_rt_end() - _rt_start()).angle()
	_rt_in_dune = false


func _rt_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 == 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _rt_dune_at(p: Vector2, d: Array) -> bool:
	var dx := (p.x - float(d[0])) / (float(d[2]) * 0.5)
	var dy := (p.y - float(d[1])) / (float(d[3]) * 0.5)
	return dx * dx + dy * dy <= 1.0


func _route_input(event: InputEvent, click: bool) -> void:
	var area := Rect2(8, 76, 624, 182)
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		if area.has_point(p):
			_rt_cursor = p
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if area.has_point(get_local_mouse_position()):
			_route_remove(get_local_mouse_position())
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
				if not event.echo and not _rt_wps.is_empty():
					_rt_wps.pop_back()
					sfx("remove")


func _route_add() -> void:
	if _rt_wps.size() >= int(_rt_cfg["max_wps"]):
		_say_msg(String(_rt_cfg["msg_full"]), RED, 1.6)
		sfx("error")
		return
	var p := _rt_cursor
	if p.distance_to(_rt_end()) < 18.0:
		p = _rt_end()
	_rt_wps.append(p)
	sfx("place")
	if not _rt_started:
		_rt_started = true
		sfx("motor")


## Clic derecho: borra el punto más cercano al puntero (o, si no hay ninguno cerca, el último).
func _route_remove(at: Vector2) -> void:
	if _rt_wps.is_empty():
		return
	var best := -1
	var bd := 18.0
	for i in _rt_wps.size():
		var d := (_rt_wps[i] as Vector2).distance_to(at)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		best = _rt_wps.size() - 1
	_rt_wps.remove_at(best)
	sfx("remove")


func _route_drive(delta: float) -> void:
	if not _rt_started:
		return
	var budget := float(_rt_cfg["budget"])
	var pps := float(_rt_cfg["px_per_sol"])
	if _rt_wps.is_empty():
		if _rt_rover.distance_to(_rt_end()) < 14.0:
			_rt_done = true
		elif _msg_t <= 0.0:
			_say_msg(String(_rt_cfg["msg_wait"]), CYAN, 1.8)
		return
	var target: Vector2 = _rt_wps[0]
	var to := target - _rt_rover
	var dist := to.length()
	var in_dune := false
	for d in _rt_cfg["dunes"]:
		if _rt_dune_at(_rt_rover, d):
			in_dune = true
	var spd := float(_rt_cfg["speed"]) * (0.5 if in_dune else 1.0)
	var mv := minf(spd * delta, dist)
	if dist > 0.01:
		_rt_ang = lerp_angle(_rt_ang, to.angle(), 0.2)
		_rt_rover += to / dist * mv
	_rt_used += mv / pps
	_rt_step_t -= delta
	if _rt_step_t <= 0.0:
		_rt_step_t = 0.35 if not in_dune else 0.6
		sfx("motor", 1.0, -16.0)
	if _rt_trail.is_empty() or (_rt_trail[_rt_trail.size() - 1] as Vector2).distance_to(_rt_rover) > 3.0:
		_rt_trail.append(_rt_rover)
	for i in (_rt_cfg["dunes"] as Array).size():
		if not _rt_seen.has("d%d" % i) and _rt_dune_at(_rt_rover, (_rt_cfg["dunes"] as Array)[i]):
			_rt_seen["d%d" % i] = true
			_rt_used += float(_rt_cfg["dune_cost"])
			_say_msg(String(_rt_cfg["msg_dune"]), RED, 2.0)
			sfx("grind")
	for i in (_rt_cfg["craters"] as Array).size():
		var cr: Array = (_rt_cfg["craters"] as Array)[i]
		if not _rt_seen.has("c%d" % i) and _rt_rover.distance_to(Vector2(float(cr[0]), float(cr[1]))) < float(cr[2]):
			_rt_seen["c%d" % i] = true
			_rt_used += 2.0 * float(cr[2]) * float(_rt_cfg["crater_detour"]) / pps
			_say_msg(String(_rt_cfg["msg_crater"]), CYAN, 2.0)
			sfx("warn")
	if dist <= 3.0:
		_rt_wps.pop_front()
		sfx("tick")
		if _rt_rover.distance_to(_rt_end()) < 14.0:
			_rt_done = true
			return
	if _rt_used > budget:
		sfx("lose")
		_say_msg(String(_rt_cfg["msg_over"]), RED, 3.2)
		_rt_attempt_reset(true)


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
	for d in _rt_cfg["dunes"]:
		_ellipse(c, Vector2(float(d[0]), float(d[1])), float(d[2]) * 0.5, float(d[3]) * 0.5, Color(0.95, 0.75, 0.5, 0.55))
	for cr in _rt_cfg["craters"]:
		var cc := Vector2(float(cr[0]), float(cr[1]))
		c.draw_circle(cc, float(cr[2]), Color("#5a3020"))
		c.draw_circle(cc + Vector2(2, 2), float(cr[2]) - 4.0, Color("#3a1e14"))
		c.draw_arc(cc, float(cr[2]), 0, TAU, 28, MARS_LIGHT, 1.0)
	_txt(c, Vector2(560, 90), "ENDEAVOUR", 9, GOLD, 60, HORIZONTAL_ALIGNMENT_CENTER)
	# Rastros de intentos anteriores (guía) y del intento actual.
	for g in _rt_ghosts:
		var gt: Array = g
		for i in range(0, gt.size(), 2):
			c.draw_rect(Rect2((gt[i] as Vector2) - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.4))
	for tp in _rt_trail:
		c.draw_rect(Rect2((tp as Vector2) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(GREEN, 0.9))
	# Ruta pendiente.
	var prev := _rt_rover
	for i in _rt_wps.size():
		c.draw_line(prev, _rt_wps[i], Color(YEL, 0.6), 1.0)
		prev = _rt_wps[i]
	var area_has := area.has_point(_rt_cursor)
	if area_has and _rt_wps.size() < int(_rt_cfg["max_wps"]):
		c.draw_line(prev, _rt_cursor, Color(1, 1, 1, 0.3), 1.0)
		c.draw_circle(_rt_cursor, 4.0, Color(1, 1, 1, 0.5))
	for i in _rt_wps.size():
		c.draw_circle(_rt_wps[i], 6.0, Color("#1a1210"))
		c.draw_arc(_rt_wps[i], 6.0, 0, TAU, 14, YEL, 1.5)
		_txt(c, (_rt_wps[i] as Vector2) + Vector2(-6, 4), str(i + 1), 9, YEL, 12, HORIZONTAL_ALIGNMENT_CENTER)
	c.draw_circle(_rt_start(), 4.0, GREEN)
	c.draw_circle(_rt_end(), 6.0, GOLD)
	_draw_rover_top(c, _rt_rover, _rt_ang, 1.3, false)
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
var _st_was_on := false
var _cl_focus := 0
var _cl_screen := 0
var _cl_t0 := 0.0
var _cl_cfg: Dictionary = {}
var _cl_quiz_ok := false


var _st_sol := 0
var _st_sol_t := 0.0
var _st_temp := 0.0
var _st_score := 0.0
var _st_combo := 0
var _st_faults := 0
var _st_off := false
var _st_sleep := false
var _st_tp := 5.0
var _st_gust := -9.0
var _st_dust := -9.0
var _st_gust_on := false
var _st_dust_on := false
var _st_heating := false
var _st_heat_mouse := false
var _st_rating := ""
var _st_rating_col := GOLD
var _st_rating_t := 0.0
var _st_stars := 0
var _st_hover := -1
var _st_hist: Array = []
var _st_hist_t := 0.0
var _st_hum_t := 0.0


func _act_storm(sc: Dictionary) -> void:
	await _cinematic_pending(String(sc["cinematic_tag"]))
	await say(sc["intro"])
	_st_cfg = sc["minimission"]
	_mm_title.text = String(_st_cfg["title"])
	_mm_info.text = String(_st_cfg["info"])
	_bar_name = tr("BATERÍA")
	_bar_show = true
	_bar_red_low = true
	_tele_fn = func() -> Array:
		_bar_val = _st_batt
		return [
			[tr("SOL %d DE %d") % [mini(_st_sol + 1, int(_st_cfg["sols"])), int(_st_cfg["sols"])], tr("FALLOS") + " %d/%d" % [_st_faults, int(_st_cfg["fault_limit"])], RED if _st_faults > 0 else GRAY_DIM],
			[tr("LUZ"), "%d%%" % int(_st_light_now() * 100.0), GREEN if _st_light_now() >= float(_st_cfg["thr_good"]) else GRAY_DIM],
			[tr("PANORAMA"), "%d" % int(_st_score), GOLD],
		]
	_layer(_draw_storm)
	_input_cb = _storm_input
	while true:
		_st_restart()
		_st_done = false
		while not _st_done:
			await get_tree().process_frame
			if get_tree().paused:
				continue
			_storm_step(get_process_delta_time())
		var stars: Array = _st_cfg["stars"]
		_st_stars = 0
		for th in stars:
			if _st_score >= float(th):
				_st_stars += 1
		if _st_stars >= 1:
			break
		sfx("lose")
		await toast(String(_st_cfg["msg_low"]), RED, 2.6)
	_input_cb = Callable()
	_st_heat_mouse = false
	mission_hud.clear_guidance()
	sfx("win")
	await toast(String(_st_cfg["done"]) + "  " + tr("ESTRELLAS: %d / 3") % _st_stars, GREEN, 2.4)
	await _last_message(sc)
	await say(sc["outro"])
	await _closing(sc)


func _st_restart() -> void:
	_st_sol = 0
	_st_batt = float(_st_cfg["battery_start"])
	_st_temp = float(_st_cfg["temp_start"])
	_st_score = 0.0
	_st_combo = 0
	_st_faults = 0
	_st_frames = 0
	_st_cool = 0.0
	_st_off = false
	_st_sleep = false
	_st_hist = []
	_st_new_sol()


func _st_new_sol() -> void:
	_st_sol_t = 0.0
	_st_tp = randf_range(3.5, 6.5)
	_st_gust = randf_range(1.0, 8.0) if randf() < float(_st_cfg["gust_chance"]) else -9.0
	_st_dust = randf_range(1.0, 8.0) if randf() < float(_st_cfg["dust_chance"]) else -9.0
	_st_gust_on = false
	_st_dust_on = false


func _st_env(sol: int) -> float:
	return lerpf(float(_st_cfg["env0"]), float(_st_cfg["env1"]), float(sol) / float(int(_st_cfg["sols"]) - 1))


## Luz sin imprevistos (lo único que se puede prever, y solo unos segundos).
func _st_base_at(t: float) -> float:
	return _st_env(_st_sol) * (0.15 + 0.85 * exp(-pow((t - _st_tp) / 1.5, 2.0)))


func _st_light_now() -> float:
	if _st_cfg.is_empty():
		return 0.0
	var l := _st_base_at(_st_sol_t)
	if _st_sol_t >= _st_gust and _st_sol_t < _st_gust + 2.0:
		l += 0.3
	if _st_sol_t >= _st_dust and _st_sol_t < _st_dust + 2.5:
		l *= 0.5
	return clampf(l, 0.0, 1.0)


func _st_btn_rect(i: int) -> Rect2:
	return [Rect2(20, 222, 200, 22), Rect2(230, 222, 170, 22), Rect2(410, 222, 130, 22)][i]


func _storm_input(event: InputEvent, click: bool) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_st_heat_mouse = false
		return
	if event is InputEventMouseMotion:
		var h := -1
		for i in 3:
			if _st_btn_rect(i).has_point(get_local_mouse_position()):
				h = i
		if h != _st_hover and h >= 0:
			sfx("hover")
		_st_hover = h
		return
	if click:
		var p := get_local_mouse_position()
		if _st_btn_rect(1).has_point(p):
			_st_heat_mouse = true
		elif _st_btn_rect(2).has_point(p):
			_st_toggle_sleep()
		else:
			_storm_photo()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_storm_photo()
		elif k == KEY_S or k == KEY_DOWN:
			_st_toggle_sleep()


func _st_toggle_sleep() -> void:
	if _st_off:
		return
	_st_sleep = not _st_sleep
	sfx("click")
	if not _st_sleep:
		_st_cool = maxf(_st_cool, 1.0)


func _storm_photo() -> void:
	if _st_off or _st_sleep:
		_say_msg(String(_st_cfg["msg_cant"]), RED, 1.6)
		sfx("error")
		return
	if _st_cool > 0.0:
		return
	_st_cool = float(_st_cfg["cooldown"])
	_st_batt = maxf(0.0, _st_batt - float(_st_cfg["photo_cost"]))
	sfx("shutter")
	var l := _st_light_now()
	var mult: float = [1.0, 1.25, 1.5][mini(_st_combo, 2)]
	if l < float(_st_cfg["thr_poor"]):
		_st_combo = 0
		_st_rating = String(_st_cfg["r_dark"])
		_st_rating_col = RED
		_st_rating_t = 1.3
		sfx("error")
		return
	var gain := minf(34.0, 30.0 * l * l * mult)
	_st_score += gain
	_st_frames += 1
	if l >= float(_st_cfg["thr_perfect"]):
		_st_rating = String(_st_cfg["r_perfect"])
		_st_rating_col = YEL
		sfx("win")
	elif l >= float(_st_cfg["thr_good"]):
		_st_rating = String(_st_cfg["r_good"])
		_st_rating_col = GREEN
		sfx("ok")
	else:
		_st_rating = String(_st_cfg["r_poor"])
		_st_rating_col = GRAY
		sfx("tick")
	_st_rating += "  +%d" % int(gain)
	_st_rating_t = 1.3
	_st_combo = _st_combo + 1 if l >= float(_st_cfg["thr_good"]) else 0


func _st_fault(msg: String) -> void:
	_st_off = true
	_st_sleep = false
	_st_faults += 1
	_st_combo = 0
	_st_score = maxf(0.0, _st_score - float(_st_cfg["fault_penalty"]))
	sfx("lose")
	_say_msg(msg, RED, 3.0)
	if _st_faults >= int(_st_cfg["fault_limit"]):
		_say_msg(String(_st_cfg["msg_retry3"]), RED, 3.2)
		_st_restart()


func _storm_step(delta: float) -> void:
	_st_sol_t += delta
	_st_cool = maxf(0.0, _st_cool - delta)
	_st_rating_t = maxf(0.0, _st_rating_t - delta)
	# Imprevistos: ráfaga que limpia paneles y pico de polvo.
	var in_gust := _st_sol_t >= _st_gust and _st_sol_t < _st_gust + 2.0
	var in_dust := _st_sol_t >= _st_dust and _st_sol_t < _st_dust + 2.5
	if in_gust and not _st_gust_on:
		sfx("whoosh", 1.0, -8.0)
		sfx("ping2")
		_say_msg(String(_st_cfg["msg_gust"]), GREEN, 2.0)
	if in_dust and not _st_dust_on:
		sfx("warn")
		_say_msg(String(_st_cfg["msg_dust"]), RED, 2.0)
	_st_gust_on = in_gust
	_st_dust_on = in_dust
	var l := _st_light_now()
	_st_hist_t += delta
	if _st_hist_t >= 0.05:
		_st_hist_t = 0.0
		_st_hist.append(l)
		if _st_hist.size() > 80:
			_st_hist.pop_front()
	_st_heating = (Input.is_physical_key_pressed(KEY_H) or _st_heat_mouse) and not _st_off
	var cold := lerpf(float(_st_cfg["cold0"]), float(_st_cfg["cold1"]), float(_st_sol) / float(int(_st_cfg["sols"]) - 1))
	var drain := float(_st_cfg["drain"])
	if _st_sleep or _st_off:
		drain *= float(_st_cfg["sleep_factor"])
		cold *= 0.5
	_st_temp = clampf(_st_temp + (-cold + (float(_st_cfg["heat"]) if _st_heating else 0.0)) * delta, 0.0, 100.0)
	_st_batt = clampf(_st_batt + (float(_st_cfg["gain"]) * l - drain - (float(_st_cfg["heat_cost"]) if _st_heating else 0.0)) * delta, 0.0, 100.0)
	if _st_heating:
		_st_hum_t -= delta
		if _st_hum_t <= 0.0:
			_st_hum_t = 0.4
			sfx("hum", 1.0, -16.0)
	if not _st_off:
		if _st_batt <= 0.0:
			_st_fault(String(_st_cfg["msg_fault_batt"]))
			return
		if _st_temp <= 0.0:
			_st_fault(String(_st_cfg["msg_fault_cold"]))
			return
	if _st_sol_t >= float(_st_cfg["sol_s"]):
		_st_sol += 1
		if _st_sol >= int(_st_cfg["sols"]):
			_st_done = true
			return
		sfx("tick")
		if _st_off:
			_st_off = false
			_st_batt = maxf(_st_batt, 15.0)
			_st_temp = maxf(_st_temp, 25.0)
		_st_new_sol()


func _star(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)


func _draw_storm(c: DrawNode) -> void:
	if _st_cfg.is_empty():
		return
	var env := _st_env(_st_sol)
	var dim := (1.0 - env) * 0.9 + (0.25 if _st_dust_on else 0.0)
	_mars_sky(c, GAME_TOP, 150.0, dim)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 80:
		var x := fmod(rng.randf() * W + _t * (20.0 + rng.randf() * 30.0 + (160.0 if _st_gust_on else 0.0)), W)
		c.draw_rect(Rect2(x, GAME_TOP + rng.randf() * 130.0, 3 if _st_gust_on else 2, 1), Color(0.9, 0.6, 0.4, 0.25 + (1.0 - env) * 0.4))
	c.draw_rect(Rect2(0, 150, W, GAME_BOTTOM - 150), MARS_DARK.lerp(MARS, 0.5).darkened((1.0 - env) * 0.5))
	c.draw_rect(Rect2(0, 150, W, 2), MARS_LIGHT.darkened((1.0 - env) * 0.5))
	if _st_heating:
		c.draw_circle(Vector2(320, 150), 26.0 + sin(_t * 12.0) * 2.0, Color(1.0, 0.5, 0.2, 0.25))
	_draw_rover_side(c, Vector2(320, 172), 2.0, 0.0, 0.0, SILVER)
	if _st_off or _st_sleep:
		c.draw_rect(Rect2(0, GAME_TOP, W, 150 - GAME_TOP), Color(0, 0, 0, 0.45))
		_txt(c, Vector2(0, 126), tr("SIN ENERGÍA") if _st_off else tr("DURMIENDO"), 12, RED if _st_off else CYAN, W, HORIZONTAL_ALIGNMENT_CENTER)
	# Panorama: barra con las tres estrellas.
	var bar := Rect2(20, 84, 600, 10)
	c.draw_rect(Rect2(bar.position - Vector2(2, 2), bar.size + Vector2(4, 4)), Color(0.04, 0.02, 0.02, 0.85))
	var maxs := float(_st_cfg["max_score"])
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_st_score / maxs, 0.0, 1.0), bar.size.y)), GREEN)
	c.draw_rect(bar, GRAY_DIM, false, 1.0)
	_txt(c, Vector2(24, 82), tr("PANORAMA"), 8, GRAY)
	for th in _st_cfg["stars"]:
		var sx := bar.position.x + bar.size.x * float(th) / maxs
		_star(c, Vector2(sx, 89), 7.0, YEL if _st_score >= float(th) else Color(0.3, 0.25, 0.2))
	if _st_rating_t > 0.0:
		_txt(c, Vector2(0, 128), _st_rating, 14, _st_rating_col, W, HORIZONTAL_ALIGNMENT_CENTER)
	if _st_combo >= 1:
		_txt(c, Vector2(24, 128), tr("COMBO") + " x%s" % _num([1.0, 1.25, 1.5][mini(_st_combo, 2)], 2), 11, YEL)
	# Gráfico de luz: pasado (real) y futuro (borroso: solo se ve lo base, sin imprevistos).
	var g := Rect2(20, 176, 440, 40)
	c.draw_rect(g, Color("#120c0a"))
	var now_x := g.position.x + g.size.x * 4.0 / 7.0
	for lvl in [[float(_st_cfg["thr_poor"]), GRAY_DIM], [float(_st_cfg["thr_good"]), GREEN], [float(_st_cfg["thr_perfect"]), YEL]]:
		var ly := g.end.y - 2.0 - float(lvl[0]) * (g.size.y - 4.0)
		c.draw_line(Vector2(g.position.x, ly), Vector2(g.end.x, ly), Color(lvl[1], 0.5), 1.0)
	var hn := _st_hist.size()
	for i in hn:
		var x := now_x - float(hn - i) * (now_x - g.position.x) / 80.0
		var v: float = _st_hist[i]
		var col := YEL if v >= float(_st_cfg["thr_perfect"]) else (GREEN if v >= float(_st_cfg["thr_good"]) else (GRAY if v >= float(_st_cfg["thr_poor"]) else Color("#4a3a30")))
		var h := v * (g.size.y - 4.0)
		c.draw_rect(Rect2(x, g.end.y - 2.0 - h, 3, h), col)
	var frng := RandomNumberGenerator.new()
	for i in 56:
		var ft := float(i) / 56.0 * 3.0
		var x := now_x + float(i) * (g.end.x - now_x) / 56.0
		var fog := ft / 3.0
		frng.seed = i * 31 + int(_st_sol_t * 4.0)
		var v := clampf(_st_base_at(_st_sol_t + ft) + frng.randf_range(-0.12, 0.12) * fog, 0.0, 1.0)
		var h := v * (g.size.y - 4.0)
		c.draw_rect(Rect2(x, g.end.y - 2.0 - h, 3, h), Color(1, 1, 1, 0.35 * (1.0 - fog * 0.7)))
	c.draw_line(Vector2(now_x, g.position.y), Vector2(now_x, g.end.y), Color.WHITE, 2.0)
	c.draw_rect(g, GRAY_DIM, false, 1.0)
	_txt(c, Vector2(g.position.x + 4, g.position.y + 10), tr("LUZ"), 8, GRAY)
	# Temperatura, tiempo del sol y enfriamiento de la cámara.
	var tx := 472.0
	_txt(c, Vector2(tx, 184), tr("TEMPERATURA"), 8, GRAY)
	c.draw_rect(Rect2(tx, 188, 148, 8), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(tx, 188, 148.0 * _st_temp / 100.0, 8), RED if _st_temp < 25.0 else Color("#ff8a50"))
	c.draw_rect(Rect2(tx, 188, 148, 8), GRAY_DIM, false, 1.0)
	_txt(c, Vector2(tx, 210), "SOL", 8, GRAY)
	c.draw_rect(Rect2(tx + 24, 203, 124, 5), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(tx + 24, 203, 124.0 * _st_sol_t / float(_st_cfg["sol_s"]), 5), CYAN)
	# Botones.
	var labels := [tr("FOTO [ENTER]"), tr("CALENTAR [H]"), tr("DORMIR [S]")]
	var lit := [_st_cool <= 0.0 and not _st_off and not _st_sleep, _st_heating, _st_sleep]
	for i in 3:
		var r := _st_btn_rect(i)
		var hov := _st_hover == i
		c.draw_rect(r, Color("#4a3020") if (hov or bool(lit[i]) and i > 0) else Color("#2a1c16"))
		c.draw_rect(r, Color.WHITE if hov else (GREEN if bool(lit[i]) else GRAY_DIM), false, 2.0 if hov else 1.0)
		_txt(c, Vector2(r.position.x, r.position.y + 15), String(labels[i]), 10, GREEN if bool(lit[i]) else GRAY, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if _st_cool > 0.0:
		var cr := _st_btn_rect(0)
		c.draw_rect(Rect2(cr.position.x, cr.end.y - 3, cr.size.x * (1.0 - _st_cool / float(_st_cfg["cooldown"])), 3), YEL)
	_draw_msg(c, 98)


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
	var last_row := -1
	while _st_reveal < cut_row:
		await get_tree().process_frame
		if not get_tree().paused:
			_st_reveal += get_process_delta_time() * 9.0
		if int(_st_reveal) != last_row:
			last_row = int(_st_reveal)
			if last_row % 2 == 0:
				sfx("tick", 0.6 + randf() * 0.8, -15.0)
	_st_cut = true
	sfx("static")
	sfx("lose")
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
	_cl_focus = 0
	sfx("scan")
	_layer(_draw_closing)
	await wait(0.5)
	await wait_click_or_accept(0.0)
	_cl_screen = 1
	_cl_t0 = _t
	sfx("select")
	_mm_info.text = String(_cl_cfg["quiz_title"])
	_input_cb = _closing_input
	while not _cl_quiz_ok:
		await get_tree().process_frame
	_input_cb = Callable()
	await wait(0.5)
	await wait_click_or_accept(0.0)
	_cl_screen = 2
	_cl_t0 = _t
	sfx("ping2")
	_mm_info.text = ""
	await wait(0.6)
	await wait_click_or_accept(0.0)


func _cl_opt_rect(j: int) -> Rect2:
	return Rect2(326, 106.0 + float(j) * 36.0, 302, 32)


func _closing_input(event: InputEvent, click: bool) -> void:
	if _cl_quiz_ok:
		return
	if event is InputEventMouseMotion:
		for j in 3:
			if _cl_opt_rect(j).has_point(get_local_mouse_position()) and j != _cl_focus:
				_cl_focus = j
				sfx("hover")
		return
	var pick := -1
	if click:
		for j in 3:
			if _cl_opt_rect(j).has_point(get_local_mouse_position()):
				pick = j
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := int(event.physical_keycode)
		if k >= KEY_1 and k <= KEY_3:
			pick = k - KEY_1
		elif k == KEY_UP or k == KEY_W:
			_cl_focus = (_cl_focus + 2) % 3
			sfx("hover")
		elif k == KEY_DOWN or k == KEY_S:
			_cl_focus = (_cl_focus + 1) % 3
			sfx("hover")
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			pick = _cl_focus
	if pick < 0:
		return
	_cl_focus = pick
	if pick == int(_cl_cfg["quiz_correct"]):
		_cl_quiz_ok = true
		sfx("win")
		_say_msg(String(_cl_cfg["quiz_right"]), GREEN, 999.0)
	else:
		sfx("error")
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
				_draw_option(c, _cl_opt_rect(j), j + 1, String(opts[j]), (not _cl_quiz_ok) and j == _cl_focus)
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
	_pause_menu.toggle()
