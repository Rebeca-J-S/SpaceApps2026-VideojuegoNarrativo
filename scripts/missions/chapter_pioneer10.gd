extends Control
## CAPÍTULO "PIONEER 10" (1972-2003). Vista 2D, pixel art placeholder.
##
## El jugador es una controladora de vuelo (personaje imaginado) en Goldstone, California; la
## protagonista es la nave. El recurso que une todo es la ENERGÍA del RTG, que baja con cada fase.
## Textos y valores en data/dialogos/pioneer10.json. Se lanza desde el selector de destinos y emite
## chapter_finished al terminar (igual que el capítulo de Spirit y Opportunity).
##
## Fases:  0 Lanzamiento (tutorial) -> 1 Cinturón (esquive arcade) -> 2 Júpiter (encuadre y disparo,
##         Io = cinemática pendiente) -> 3 Tormenta (cinemática pendiente) -> 4 Silencio (línea de
##         tiempo) -> 5 La placa (púlsares y error) -> Epílogo.
## HUD: AÑO arriba a la izquierda, OBJETIVO arriba a la derecha, ENERGÍA RTG siempre visible abajo a la
##      derecha (con barra de PROGRESO cuando aplica); diálogo (TransmissionDialog) abajo a la izquierda.
## Debug (solo en builds de depuración): F1-F7 saltan a cada fase.

signal chapter_finished

const PioneerArt := preload("res://scripts/missions/mision_pioneer.gd")
const DATA_PATH := "res://data/dialogos/pioneer10.json"
const MISSION_ID := "pioneer"          # id de progreso (desbloquea las fichas de Pioneer en el Archivo)
const W := 640.0
const GAME_TOP := 22.0
const GAME_BOTTOM := 266.0
const YELLOW := Color("#ffd24a")
const RED := Color("#ff5a4a")

## Si es true, al terminar marca la misión como completada y vuelve al selector.
@export var auto_return := true
@export var debug_mode := true

var data: Dictionary = {}
var world: Node2D
var ui_layer: Control
var dialog: TransmissionDialog
var mission_hud: MissionHUD

var _year_tag: Label
var _year_val: Label
var _obj_tag: Label
var _obj_val: Label
var _mm_title: Label
var _mm_info: Label
var _toast: Label
var _fade_text: Label
var _hud_draw: Control
var _pause_panel: PanelContainer
var _fade: ColorRect

var _energy := 100.0
var _progress := 0.0
var _show_progress := false
var _minimal := false
var _depleted := false
var _retry := false
var _static := 0.0
var _static_decay := 0.0
var _t := 0.0
var _shake := 0.0
var _glitch := 0.0           # interferencia al recibir daño (0-1)
var _flash := 0.0
var _mode := ""
var _hl_rect := Rect2()

# Lanzamiento
var _alt := 0.0              # altura ganada por el cohete (unidades del mundo del lanzamiento)
var _cheer := 0.0            # 0 = el público espera, 1 = salta de alegría
var _rumble := 0.0           # segundos de temblor tras el encendido
var _launch_stars: Starfield
var _rk_state := 0           # 0 en la plataforma, 1 ascendiendo, 2 separada
var _stage_y := 0.0
var _probe_show := 0.0
var _cruise := 0.0           # segundos de crucero tras la separación: la sonda nunca se detiene
var _recede := 0.0           # el planeta se va alejando hacia abajo
# Cinturón
var _ship := Vector2(110, 144)
var _asteroids: Array = []        # cada asteroide es un Dictionary (posición, radio, velocidad, color...)
var _shield := 5
var _shield_max := 5
var _invuln := 0.0
var _belt_coast := false     # tras cruzar el cinturón la nave sigue su viaje y los asteroides siguen pasando
var _coast_speed := 0.0
# Júpiter
var _moons: Array = []
var _moon_i := 0
var _photos: Array[bool] = []
var _visor := Vector2(320, 150)
var _rad := 0.0
var _photo_acc: Array = []           # precisión (%) de cada foto aceptada
var _visor_target := Vector2(320, 150)   # hacia donde apunta la mano; el visor lo sigue con retraso
var _spike_t := 0.0                  # >0 mientras dura un pico de radiación
var _spike_cd := 7.0                 # tiempo hasta el próximo pico
var _spike_static := 0.0
var _mouse_aim := false              # true si el punto de mira lo mueve el mouse (más retraso que con teclas)
var _scanning := false               # escaneo por líneas en curso
var _scan_t := 0.0
var _scan_dur := 2.0
var _scan_n := 30
var _scan_lines: Array = []          # true = línea nítida, false = línea dañada
var _scan_quality := 0.0
var _freeze := 0.0                   # pausa breve al disparar ("hit stop")
var _pol_active := false
var _pol_skip := false
var _pol_y := 340.0
var _pol: Dictionary = {}
var _tone: AudioStreamPlayer
var _shutter: AudioStreamPlayer
# Silencio
# Fase 3 · Cinemática de la tormenta y la magnetosfera
var _st_shot := 0          # 0 Sol y tormenta · 1 antena · 2 magnetosfera de Júpiter
var _st_flare := 0.0
var _st_wave := -1.0       # avance del frente de partículas (0-1)
var _st_ant := 0.0         # desvío de la antena respecto a la Tierra (radianes)
var _st_drift := 0.0
var _st_signal := 1.0
var _st_jup := 0.0
var _st_temp := 1.0        # temperatura del plasma relativa a la de fuera (x1 a x100)
var _st_cross := 0.0
var _st_bars := 0.0        # franjas negras de cine

var _sil_year := 1976.0
var _sil_log: Array = []
var _sil_frac := 0.0
# Placa
const MAP := Rect2(10, 74, 380, 170)
var _pulsars: Array = []
var _sun := Vector2.ZERO
var _cursor := Vector2(200, 159)
var _proposal := Vector2.ZERO
var _has_prop := false
var _signs: Array = []
var _best_pct := 100.0
var _last_pct := 100.0
var _frags := 0
var _attempts := 0
var _plate_won := false
var _plate_mm: Dictionary = {}


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
	var start := GameManager.consume_start_phase()   # 0 = normal; 1-7 = salta a esa fase
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
		_energy = float(sc.get("energy", _energy))
	_minimal = id == "epilogo"
	_set_year(String(sc["year"]))
	_set_objective(String(sc["objective"]))
	_show_progress = bool(sc.get("show_progress", false))
	_progress = 0.0
	_retry = false
	await _banner(String(sc["title"]))
	mission_hud.set_phase(index, String(sc["title"]), String(sc["objective"]))
	while true:
		_depleted = false
		var e0 := _energy
		match id:
			"lanzamiento": await _scene_launch(sc)
			"cinturon": await _scene_belt(sc)
			"jupiter": await _scene_jupiter(sc)
			"tormenta": await _scene_storm(sc)
			"silencio": await _scene_silence(sc)
			"placa": await _scene_plate(sc)
			"epilogo": await _scene_epilogue(sc)
		if not _depleted:
			break
		# Sin energía: la fase termina y se reintenta con una reserva mínima.
		_mode = ""
		await toast(String(data["hud"]["energy_out"]), RED, 2.4)
		_energy = maxf(e0, 20.0)
		_retry = true
		_clear()


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


func _drain(amount: float) -> void:
	_energy = clampf(_energy - amount, 0.0, 100.0)
	if _energy <= 0.0:
		_depleted = true


# =========================================================================
# Construcción del HUD
# =========================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = RetroTheme.SPACE
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

	# Barra superior: AÑO (izquierda) y OBJETIVO (derecha). Etiquetas en blanco, datos en amarillo.
	var top := ColorRect.new()
	top.color = Color(0.02, 0.02, 0.04, 0.85)
	top.size = Vector2(W, GAME_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_year_tag = _label(Vector2(8, 5), Vector2(34, 14), 10, RetroTheme.WHITE)
	_year_tag.text = String(data["hud"]["year"])
	_year_val = _label(Vector2(44, 3), Vector2(200, 16), 13, YELLOW)
	_obj_tag = _label(Vector2(300, 5), Vector2(80, 14), 10, RetroTheme.WHITE)
	_obj_tag.text = String(data["hud"]["objective"])
	_obj_val = _label(Vector2(200, 4), Vector2(432, 16), 11, YELLOW)
	_obj_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Sin datos todavía (ficha inicial): no se muestran las etiquetas vacías.
	_year_tag.hide()
	_obj_tag.hide()

	# Título e instrucción de la fase (dentro del área de juego).
	_mm_title = _label(Vector2(8, GAME_TOP + 22), Vector2(420, 14), 11, YELLOW)
	_mm_info = _label(Vector2(8, GAME_TOP + 36), Vector2(620, 14), 10, RetroTheme.WHITE)
	for l in [_mm_title, _mm_info]:
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
		l.add_theme_constant_override("outline_size", 4)
	_toast = _label(Vector2(0, 110), Vector2(W, 50), 18, YELLOW)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.hide()

	# Franja inferior: diálogo (izquierda) + panel de energía (derecha).
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

	# Resalte del tutorial, estática a pantalla completa, fundido y texto sobre el fundido.
	add_child(DrawNode.new(_draw_highlight))
	add_child(DrawNode.new(_draw_static))
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_fade_text = _label(Vector2(40, 140), Vector2(560, 60), 15, RetroTheme.WHITE)
	_fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fade_text.hide()

	if debug_mode and OS.is_debug_build():
		var dbg := _label(Vector2(0, GAME_BOTTOM - 14), Vector2(W - 8, 12), 9, Color(1, 0.4, 0.4, 0.8))
		dbg.text = data["hud"]["debug"]
		dbg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# HUD común: ficha de misión, botones C/O/I, teclas y pistas del científico.
	mission_hud = MissionHUD.new()
	add_child(mission_hud)
	mission_hud.badge_pos = Vector2(8, GAME_TOP + 3)
	mission_hud.buttons_pos = Vector2(W - 6, GAME_TOP + 3)
	mission_hud.reminder_pos = Vector2(8, GAME_TOP + 54)
	mission_hud.briefing_auto_seconds = 7.0
	mission_hud.briefing_area = Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP)   # ficha centrada en el área de juego
	mission_hud.keys_pos = Vector2(8, GAME_BOTTOM - 17)
	mission_hud.busy_check = func() -> bool: return dialog.is_active() or _toast.visible
	mission_hud.reminder_callback = func(t: String) -> void: dialog.show_hint("CONTROLADORA", t)
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


func _set_year(text: String) -> void:
	_year_tag.visible = text != ""
	_year_val.text = text


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
	_static = 0.0
	_static_decay = 0.0
	_hl_rect = Rect2()
	_shake = 0.0
	_fade_text.hide()
	_belt_coast = false
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


func _stars(drift: Vector2 = Vector2.ZERO, count: int = 130) -> Starfield:
	var s := Starfield.new()
	s.star_count = count
	s.drift = drift
	world.add_child(s)
	return s


func _banner(text: String) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", YELLOW)
	_toast.modulate.a = 0.0
	_toast.show()
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	await tw.finished
	_toast.hide()


func toast(text: String, color: Color = YELLOW, seconds: float = 0.9) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.show()
	await wait(seconds)
	_toast.hide()
	_toast.add_theme_color_override("font_color", YELLOW)


# =========================================================================
# HUD dinámico
# =========================================================================
func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_glitch = maxf(0.0, _glitch - delta * 3.5)
	if _rk_state == 2:
		_cruise += delta
		_recede = _cruise * 4.0
	if _rumble > 0.0:
		_rumble -= delta
		_shake = maxf(_shake, 2.2 + _rumble)
	if _static_decay > 0.0:
		_static = maxf(0.0, _static - _static_decay * delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO
	if _belt_coast:
		_coast_step(delta)
	_hud_draw.queue_redraw()


## Después del cinturón: la nave acelera hacia la derecha y los asteroides restantes siguen pasando (sin dañar).
func _coast_step(dt: float) -> void:
	_coast_speed = minf(150.0, _coast_speed + 22.0 * dt)
	_ship.x += _coast_speed * dt
	_ship.y = lerpf(_ship.y, 144.0, minf(1.0, dt * 1.2))
	_move_asteroids(dt, false, {})


func _draw_data_panel() -> void:
	var c := _hud_draw
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.01, 0.04, 0.03, 0.92))
	c.draw_rect(r, RetroTheme.PHOSPHOR, false, 1.0)
	var font := ThemeDB.fallback_font
	if _minimal:
		c.draw_string(font, Vector2(6, 12), String(data["hud"]["energy"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.PHOSPHOR_DIM)
		c.draw_string(font, Vector2(6, 40), "·  ·  ·", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RetroTheme.PHOSPHOR_DIM)
		return
	c.draw_string(font, Vector2(6, 12), String(data["hud"]["energy"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
	var col := YELLOW if _energy > 25.0 else RED
	var bar := Rect2(6, 17, 148, 9)
	c.draw_rect(bar, Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _energy / 100.0, bar.size.y)), col)
	c.draw_rect(bar, col, false, 1.0)
	c.draw_string(font, Vector2(6, 42), "%d%%" % int(round(_energy)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	if _show_progress:
		c.draw_string(font, Vector2(6, 58), String(data["hud"]["progress"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
		var pb := Rect2(6, 63, 148, 8)
		c.draw_rect(pb, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(pb.position, Vector2(pb.size.x * clampf(_progress, 0.0, 1.0), pb.size.y)), RetroTheme.PHOSPHOR)
		c.draw_rect(pb, RetroTheme.PHOSPHOR, false, 1.0)


func _draw_static(c: DrawNode) -> void:
	if _glitch > 0.0:
		# Bandas de interferencia desplazadas, con borde cian: se ven en toda la pantalla.
		for i in 8:
			var yy := floorf(randf() * 350.0)
			var hh := randf_range(2.0, 12.0)
			var off := randf_range(-22.0, 22.0) * _glitch
			c.draw_rect(Rect2(off, yy, W, hh), Color(1, 1, 1, 0.12 * _glitch))
			c.draw_rect(Rect2(off + 5.0, yy, W, 2.0), Color(0.4, 1.0, 1.0, 0.3 * _glitch))
	if _static <= 0.0:
		return
	var n := int(5000 * _static)
	for i in n:
		var g := randf()
		c.draw_rect(Rect2(floorf(randf() * W), floorf(randf() * 360.0), 2, 1), Color(g, g, g, _static))


func _draw_highlight(c: DrawNode) -> void:
	if _hl_rect.size == Vector2.ZERO:
		return
	var a := 0.5 + 0.5 * sin(c.t * 7.0)
	c.draw_rect(_hl_rect, Color(YELLOW, 0.15 + 0.15 * a))
	c.draw_rect(_hl_rect, Color(YELLOW, 0.6 + 0.4 * a), false, 2.0)


func _speaker_color(key: String) -> Color:
	return Color(String(data["speakers"][key]["color"]))


# =========================================================================
# Aviso inicial
# =========================================================================
func _disclaimer() -> void:
	_set_year("")
	_set_objective("")
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
	panel.queue_free()
	h.queue_free()
	l.queue_free()


# =========================================================================
# FASE 0 · Lanzamiento (tutorial)
# =========================================================================
func _scene_launch(sc: Dictionary) -> void:
	_alt = 0.0
	_cheer = 0.0
	_rumble = 0.0
	_cruise = 0.0
	_recede = 0.0
	_rk_state = 0
	_stage_y = 0.0
	_probe_show = 0.0
	_launch_stars = _stars()
	_layer(_draw_launch)
	if not _retry:
		await say(sc["intro"])
	var countdown: Array = sc["countdown"]
	for i in countdown.size():
		_flash = 0.4
		if i == 2:
			create_tween().tween_property(self, "_cheer", 0.4, 1.0)   # el público se emociona
		await toast(String(countdown[i]), YELLOW, 0.85)
	# Despegue: el cohete sube, el mundo se aleja y el planeta se curva.
	_rk_state = 1
	_rumble = 2.4
	_flash = 0.8
	create_tween().tween_property(self, "_cheer", 1.0, 0.5)
	_mm_info.text = String(sc["cheer"])
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_alt", 760.0, 7.0)
	create_tween().tween_property(_launch_stars, "drift:y", 38.0, 6.0)   # las estrellas bajan: la nave sube
	await tw.finished
	_mm_info.text = ""
	# Separación en el espacio, con la Tierra abajo.
	_rk_state = 2
	_stage_y = 175.0
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(self, "_stage_y", 330.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(self, "_probe_show", 1.0, 2.2)
	create_tween().tween_property(_launch_stars, "drift", Vector2(-18.0, 3.0), 2.5)
	await tw2.finished
	await say(sc["separation"])
	# Tutorial del HUD: se resalta cada elemento mientras se explica.
	for step in sc["tutorial"]:
		match String(step["target"]):
			"year": _hl_rect = Rect2(4, 1, 100, 20)
			"objective": _hl_rect = Rect2(_obj_tag.position.x - 4.0, 1, 636.0 - _obj_tag.position.x, 20)
			"energy": _hl_rect = Rect2(470, GAME_BOTTOM + 4, 164, 46)
		await say([step])
	_hl_rect = Rect2()
	await toast(String(sc["closing_text"]), RetroTheme.WHITE, 3.4)


## Zoom de la cámara: se aleja del suelo a medida que el cohete gana altura.
func _zoom_s() -> float:
	return 1.0 if _alt <= 43.0 else 91.0 / (48.0 + _alt)


func _rocket_base_y() -> float:
	return 218.0 - _alt if _alt <= 43.0 else 175.0


## Arco superior de un planeta de radio r con su "techo" en y_top (la curva que se ve).
func _planet_arc(y_top: float, r: float, step: float = 10.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cy := y_top + r
	var x := -40.0
	while x <= 680.0:
		pts.append(Vector2(x, cy - sqrt(maxf(0.0, r * r - (x - 320.0) * (x - 320.0)))))
		x += step
	return pts


## Relleno del planeta en columnas (evita polígonos enormes que Godot no logra triangular).
func _fill_planet(c: CanvasItem, y_top: float, r: float, col: Color) -> void:
	var cy := y_top + r
	var x := -40.0
	while x < 680.0:
		var y := cy - sqrt(maxf(0.0, r * r - (x + 2.0 - 320.0) * (x + 2.0 - 320.0)))
		c.draw_rect(Rect2(x, y, 4.0, 400.0 - y), col)
		x += 4.0


func _draw_launch(c: DrawNode) -> void:
	var s := _zoom_s()
	var piv := Vector2(320, 266)
	var y_h := piv.y - (piv.y - 236.0) * s + _recede
	var r_scr := lerpf(520.0, 12000.0, pow(s, 3.0))
	# Halo de la atmósfera sobre el borde del planeta (más visible cuanto más lejos).
	var halo := lerpf(1.0, 0.25, s)
	for k in 4:
		c.draw_polyline(_planet_arc(y_h - (k + 1) * 2.5, r_scr + (k + 1) * 2.5), Color(0.3, 0.55, 1.0, halo * 0.12), 3.0)
	# El suelo del lanzamiento se convierte en el planeta visto desde arriba.
	_fill_planet(c, y_h, r_scr, Color("#0d1712").lerp(Color("#0a1830"), 1.0 - s))
	c.draw_polyline(_planet_arc(y_h, r_scr), Color(0.45, 0.7, 1.0, halo * 0.75), 2.0)
	# --- Mundo del lanzamiento (se escala hacia el pie de la pantalla) ---
	c.draw_set_transform(piv - piv * s + Vector2(0.0, _recede), 0.0, Vector2(s, s))
	if _rk_state == 1 and _alt < 220.0:
		# Resplandor del motor sobre la plataforma.
		var g := 1.0 - _alt / 220.0
		for k in 4:
			c.draw_circle(Vector2(320, 236), 40.0 + k * 34.0, Color(1.0, 0.6, 0.2, 0.05 * g))
	# Plataforma, torre y reflectores.
	c.draw_rect(Rect2(296, 232, 48, 6), Color("#3a3c4c"))
	c.draw_rect(Rect2(312, 218, 16, 14), Color("#2a2c3a"))
	c.draw_rect(Rect2(350, 150, 6, 88), Color("#4a4c60"))
	for k in 5:
		c.draw_rect(Rect2(345, 160 + k * 16, 16, 2), Color("#4a4c60"))
	for lx in [250.0, 430.0]:
		c.draw_rect(Rect2(lx, 206, 2, 32), Color("#3a3c4c"))
		c.draw_circle(Vector2(lx + 1, 205), 3.0, Color("#ffe9a0"))
		c.draw_circle(Vector2(lx + 1, 205), 9.0, Color(1, 0.9, 0.6, 0.12))
	# Estela de humo: una columna de nubes desde la plataforma hasta el cohete.
	if _rk_state >= 1:
		var n := int(_alt / 8.0)
		for k in n:
			var age := _alt - k * 8.0
			var wy := 218.0 - k * 8.0
			var wx := 320.0 + sin(k * 1.3) * (2.0 + age * 0.03)
			var rad := 4.0 + age * 0.045
			var warm := clampf(1.0 - age / 160.0, 0.0, 1.0)
			c.draw_circle(Vector2(wx, wy), rad, Color(0.62 + 0.3 * warm, 0.6 + 0.12 * warm, 0.62, 0.30 - 0.18 * (age / maxf(_alt, 1.0))))
	# Público festejando.
	for i in 18:
		var left := i < 10
		var px := (70.0 + i * 17.0) if left else (440.0 + (i - 10) * 21.0)
		_draw_person(c, px, 241.0 + (i % 3) * 3.0, i)
	# Confeti.
	if _cheer > 0.7:
		for k in 46:
			var cx := 60.0 + fmod(k * 53.0, 520.0)
			var cy2 := 150.0 + fmod(c.t * (24.0 + k % 5 * 6.0) + k * 17.0, 90.0)
			var confetti: Array = [Color("#ff5a4a"), Color("#ffd24a"), Color("#80f2ff"), Color("#7aff9a"), Color("#ffffff")]
			var col: Color = confetti[k % 5]
			c.draw_rect(Rect2(cx + sin(c.t * 3.0 + k) * 6.0, cy2, 2, 2), Color(col, 0.9))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# --- Cohete (en pantalla, sin escalar) ---
	var x := 320.0
	var by := _rocket_base_y()
	if _rk_state < 2:
		c.draw_rect(Rect2(x - 8, by - 58, 16, 58), Color("#d8d8e0"))
		c.draw_rect(Rect2(x - 8, by - 38, 16, 4), Color("#c0532a"))
		c.draw_rect(Rect2(x - 6, by - 88, 12, 30), Color("#e8e8f0"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, by - 88), Vector2(x + 6, by - 88), Vector2(x, by - 102)]), Color("#c0532a"))
		if _rk_state == 1:
			var fl := 16.0 + 8.0 * sin(c.t * 40.0) + minf(_alt, 300.0) * 0.06
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, by), Vector2(x + 8, by), Vector2(x, by + fl + 16)]), Color("#ffb347"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, by), Vector2(x + 4, by), Vector2(x, by + fl)]), Color("#fff4c0"))
			c.draw_circle(Vector2(x, by + 6), 14.0, Color(1.0, 0.7, 0.3, 0.12))
	else:
		# Separación: la etapa inferior cae y la sonda sigue sola.
		c.draw_rect(Rect2(x - 8, _stage_y, 16, 58), Color("#8a8ea6"))
		var pp := Vector2(x + 90.0 * _probe_show + _cruise * 9.0, 150.0 - 45.0 * _probe_show - _cruise * 1.5)
		PioneerArt.draw_pioneer(c, pp, -0.5 + sin(c.t * 0.8) * 0.04, 1.6)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 0.9, 0.7, _flash * 0.3))


## Una persona del público: salta y levanta los brazos según `_cheer`; algunas llevan bandera.
func _draw_person(c: CanvasItem, x: float, y: float, i: int) -> void:
	var cheer := _cheer
	var ph := i * 1.7
	var hop := absf(sin(_t * 7.0 + ph)) * 7.0 * cheer
	var sway := sin(_t * 1.6 + ph) * 0.6 * (1.0 - cheer)
	var by := y - hop
	var shirt: Color = [Color("#e8e8f0"), Color("#ff9a7a"), Color("#80b4ff"), Color("#ffd24a"), Color("#7aff9a"), Color("#d0a0ff")][i % 6]
	var skin: Color = [Color("#f0c8a0"), Color("#c89870"), Color("#8a5a3a")][i % 3]
	var pants := Color("#2a2c44")
	c.draw_rect(Rect2(x - 2 + sway, by - 5, 1.6, 5), pants)
	c.draw_rect(Rect2(x + 0.6 + sway, by - 5, 1.6, 5), pants)
	c.draw_rect(Rect2(x - 2.6 + sway, by - 11, 5.2, 6), shirt)
	c.draw_circle(Vector2(x + sway, by - 13.6), 2.3, skin)
	# Brazos: abajo mientras esperan, arriba (y ondeando) cuando festejan.
	var up := lerpf(2.0, -7.5, cheer)
	var wave := sin(_t * 9.0 + ph) * 1.8 * cheer
	c.draw_line(Vector2(x - 2.6 + sway, by - 10), Vector2(x - 5.0 + sway - wave, by - 10 + up), shirt, 1.4)
	c.draw_line(Vector2(x + 2.6 + sway, by - 10), Vector2(x + 5.0 + sway + wave, by - 10 + up), shirt, 1.4)
	if i % 5 == 0:
		# Bandera.
		var fx := x + 5.0 + sway + wave
		var ft := by - 10 + up
		c.draw_line(Vector2(fx, ft), Vector2(fx, ft - 10), Color("#c8ccd8"), 1.0)
		# Bandera de Estados Unidos: franjas rojas y blancas y cantón azul con estrellas.
		for k in 7:
			c.draw_rect(Rect2(fx + 0.5, ft - 10 + k, 8, 1), Color("#d8342a") if k % 2 == 0 else Color("#ffffff"))
		c.draw_rect(Rect2(fx + 0.5, ft - 10, 3.5, 4), Color("#2a3f9a"))
		c.draw_rect(Rect2(fx + 1.0, ft - 9.5, 1, 1), Color("#ffffff"))
		c.draw_rect(Rect2(fx + 2.5, ft - 8.0, 1, 1), Color("#ffffff"))
		c.draw_rect(Rect2(fx + 1.0, ft - 7.0, 1, 1), Color("#ffffff"))


# =========================================================================
# FASE 1 · Cinturón de asteroides (esquive arcade)
# =========================================================================
func _scene_belt(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	_shield_max = int(mm["shield_max"])
	_shield = _shield_max
	_invuln = 0.0
	_ship = Vector2(110, 144)
	_asteroids.clear()
	_stars(Vector2(-60, 0), 150)
	_layer(func(c: DrawNode) -> void:
		# Luz zodiacal: resplandor tenue que crece con el avance.
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1.0, 0.85, 0.5, 0.025 + 0.05 * _progress))
		for a in _asteroids:
			if bool(a["bg"]):
				_draw_asteroid(c, a)
		for a in _asteroids:
			if not bool(a["bg"]):
				_draw_asteroid(c, a)
		var blink := _invuln > 0.0 and int(c.t * 14.0) % 2 == 0
		if not blink:
			PioneerArt.draw_pioneer(c, _ship, PI, 1.5)
		# Escudo: segmentos.
		var font := ThemeDB.fallback_font
		c.draw_string(font, Vector2(8, GAME_BOTTOM - 22), String(data["hud"]["shield"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
		for k in _shield_max:
			var seg := Rect2(52 + k * 12, GAME_BOTTOM - 31, 10, 9)
			c.draw_rect(seg, YELLOW if k < _shield else Color(0.25, 0.1, 0.1, 0.8))
			c.draw_rect(seg, Color(1, 1, 1, 0.4), false, 1.0)
		if _flash > 0.0:
			c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 0.3, 0.2, _flash * 0.25))
	)
	if not _retry:
		await say(sc["intro"])
	_mm_title.text = String(mm["title"])
	_mode = "belt"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1972
	var secs := float(mm["seconds"])
	var speed := float(mm["ship_speed"])
	var spawn := 0.8
	var bg_spawn := 0.2
	var last_y := 144.0
	_belt_coast = false
	_coast_speed = 30.0
	while _progress < 1.0 and not _depleted:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		_invuln = maxf(0.0, _invuln - dt)
		# Movimiento en 8 direcciones (WASD o flechas); en diagonal no va más rápido.
		var mv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
		if mv.length() > 1.0:
			mv = mv.normalized()
		_ship = (_ship + mv * speed * dt).clamp(Vector2(50, GAME_TOP + 20), Vector2(400, GAME_BOTTOM - 20))
		_progress = minf(1.0, _progress + dt / secs)
		_drain(float(mm["energy_per_second"]) * dt)
		spawn -= dt
		if spawn <= 0.0 and _progress < 0.88:
			var iv: Array = mm["spawn_interval"]
			spawn = rng.randf_range(float(iv[0]), float(iv[1]))
			last_y = _spawn_asteroids(rng, mm, last_y)
		# Asteroides de fondo: muy tenues y lejanos, no chocan (dan profundidad).
		bg_spawn -= dt
		if bg_spawn <= 0.0 and _progress < 0.9:
			var bi: Array = mm["bg_interval"]
			bg_spawn = rng.randf_range(float(bi[0]), float(bi[1]))
			_spawn_background(rng, mm)
		_move_asteroids(dt, true, mm)
		_mm_info.text = "%s · %s: %d" % [mm["instruction"], mm["counter"], int(_progress * 12.0)]
	_mode = ""
	if _depleted:
		return
	# La nave no se detiene: sigue su viaje fuera del cinturón mientras se cuenta el logro.
	_belt_coast = true
	_mm_info.text = ""
	await toast(String(sc["reward"]), YELLOW, 2.6)
	await say(sc["outro"])
	var guard := 0.0
	while _ship.x < W + 40.0 and guard < 4.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	_belt_coast = false


## Mueve los asteroides; los sólidos (no de fondo) dañan a la nave si `collide` es true.
func _move_asteroids(dt: float, collide: bool, mm: Dictionary) -> void:
	var keep: Array = []
	for a in _asteroids:
		a["x"] = float(a["x"]) + float(a["vx"]) * dt
		a["y"] = float(a["y"]) + float(a["vy"]) * dt
		a["rot"] = float(a["rot"]) + float(a["spin"]) * dt
		var ap := Vector2(float(a["x"]), float(a["y"]))
		if collide and not bool(a["bg"]) and _invuln <= 0.0 and ap.distance_to(_ship) < float(a["r"]) * 0.88 + 7.0:
			_on_belt_hit(mm)
		if ap.x > -50.0 and ap.y > GAME_TOP - 50.0 and ap.y < GAME_BOTTOM + 50.0:
			keep.append(a)
	_asteroids = keep


## Un asteroide lejano: pequeño, lento, casi transparente y sin colisión.
func _spawn_background(rng: RandomNumberGenerator, mm: Dictionary) -> void:
	var rr: Array = mm["bg_radius"]
	var sp: Array = mm["bg_speed"]
	var al: Array = mm["bg_alpha"]
	var r := rng.randf_range(float(rr[0]), float(rr[1]))
	var col := Color(String(mm["bg_color"]))
	col.a = rng.randf_range(float(al[0]), float(al[1]))
	_asteroids.append({
		"x": W + 30.0 + r, "y": rng.randf_range(GAME_TOP + 6.0, GAME_BOTTOM - 6.0), "r": r,
		"vx": -rng.randf_range(float(sp[0]), float(sp[1])), "vy": 0.0,
		"rot": rng.randf() * TAU, "spin": rng.randf_range(-0.6, 0.6),
		"seed": rng.randf() * 10.0, "col": col, "fast": false, "bg": true,
	})


## Crea uno o dos asteroides dispersos: tamaños, velocidades y colores variados. Devuelve la última Y.
func _spawn_asteroids(rng: RandomNumberGenerator, mm: Dictionary, last_y: float) -> float:
	var n := 2 if rng.randf() < float(mm["pair_chance"]) else 1
	var palette: Array = mm["asteroid_colors"]
	var rr: Array = mm["radius_range"]
	var y := last_y
	var first_y := -1000.0
	for k in n:
		# Lejos del asteroide anterior, para que queden esparcidos y haya por dónde pasar.
		for tries in 8:
			y = rng.randf_range(GAME_TOP + 14.0, GAME_BOTTOM - 14.0)
			if absf(y - last_y) > 48.0 and absf(y - first_y) > 80.0:
				break
		first_y = y
		var r := lerpf(float(rr[0]), float(rr[1]), pow(rng.randf(), 1.7))   # pocos grandes, más pequeños
		var fast := rng.randf() < float(mm["fast_chance"])
		var sp: Array = mm["speed_fast"] if fast else mm["speed_slow"]
		var base := Color(String(palette[rng.randi() % palette.size()]))
		if fast:
			base = base.lightened(0.18)
		base.a = rng.randf_range(0.82, 1.0)   # los que dañan se ven siempre sólidos
		_asteroids.append({
			"x": W + 30.0 + r, "y": y, "r": r,
			"vx": -rng.randf_range(float(sp[0]), float(sp[1])),
			"vy": rng.randf_range(-24.0, 24.0) if rng.randf() < 0.45 else 0.0,
			"rot": rng.randf() * TAU, "spin": rng.randf_range(-1.5, 1.5),
			"seed": rng.randf() * 10.0, "col": base, "fast": fast, "bg": false,
		})
		last_y = y
	return last_y


func _draw_asteroid(c: CanvasItem, a: Dictionary) -> void:
	var p := Vector2(float(a["x"]), float(a["y"]))
	var r := float(a["r"])
	var col: Color = a["col"]
	if bool(a["fast"]):
		# Estela: se nota a simple vista cuáles vienen más rápido.
		c.draw_line(p + Vector2(r * 0.6, 0), p + Vector2(r * 0.6 + 26.0 + r, 0), Color(col, 0.28), maxf(2.0, r * 0.6))
	var pts := PackedVector2Array()
	for k in 9:
		var ang := float(a["rot"]) + k * TAU / 9.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * r * (0.76 + 0.24 * sin(k * 2.3 + float(a["seed"]))))
	c.draw_colored_polygon(pts, col)
	if bool(a["bg"]):
		return
	# Borde claro: los asteroides sólidos (los que dañan) se leen bien.
	var rim := pts.duplicate()
	rim.append(pts[0])
	c.draw_polyline(rim, Color(1, 1, 1, 0.22), 1.0)
	c.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), maxf(1.5, r * 0.18), Color(1, 1, 1, 0.16 * col.a))
	c.draw_circle(p + Vector2(r * 0.25, r * 0.3), maxf(1.2, r * 0.13), Color(0, 0, 0, 0.22))


func _on_belt_hit(mm: Dictionary) -> void:
	_shield -= 1
	_invuln = 1.3
	_shake = 6.0
	_flash = 1.0
	# Interferencia breve en toda la pantalla.
	_glitch = 1.0
	_static = 0.6
	_static_decay = 2.6
	if _shield <= 0:
		# Sin escudo: se pierde tiempo de vuelo y energía, pero no hay "muerte".
		_progress = maxf(0.0, _progress - 0.15)
		_drain(6.0)
		_shield = 3
		toast(String(mm["shield_out"]), RED, 1.8)
	else:
		toast(String(mm["hit"]), RED, 0.6)


# =========================================================================
# FASE 2 · Júpiter y sus lunas (encuadre y disparo)
# =========================================================================
func _scene_jupiter(sc: Dictionary) -> void:
	var mm: Dictionary = sc["minimission"]
	_moons = mm["moons"]
	_moon_i = 0
	_photos.clear()
	_photo_acc.clear()
	for m in _moons:
		_photos.append(false)
		_photo_acc.append(0)
	_visor = Vector2(320, 150)
	_visor_target = _visor
	var spike_iv: Array = mm["spike_interval"]
	_spike_cd = randf_range(float(spike_iv[0]), float(spike_iv[1]))
	_spike_t = 0.0
	_spike_static = 0.0
	_rad = 0.0
	_flash = 0.0
	_scanning = false
	_scan_lines = []
	_scan_t = 0.0
	_scan_n = int(mm["scan_lines"])
	_freeze = 0.0
	_pol_active = false
	_pol_skip = false
	_stars()
	_setup_jupiter_audio()
	_layer(_draw_jupiter)
	if not _retry:
		await say(sc["intro"])
	_mm_title.text = String(mm["title"])
	_mode = "jupiter"
	while _moon_i < _moons.size() and _rad < 100.0 and not _depleted:
		await get_tree().process_frame
		if get_tree().paused:
			_stop_tone()
			continue
		var dt := get_process_delta_time()
		if _freeze > 0.0:
			_freeze -= dt   # pausa breve al disparar
			continue
		var m: Dictionary = _moons[_moon_i]
		var mv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
		# La mano mueve el punto de mira y el visor lo sigue con un leve retraso (inercia de la cámara).
		_visor_target = (_visor_target + mv * 135.0 * dt).clamp(Vector2(70, GAME_TOP + 70), Vector2(W - 70, GAME_BOTTOM - 62))
		if mv != Vector2.ZERO:
			_mouse_aim = false
		var lag := float(mm["camera_lag_mouse"]) if _mouse_aim else float(mm["camera_lag"])
		_visor = _visor.lerp(_visor_target, 1.0 - exp(-lag * dt))
		_rad = minf(100.0, _rad + float(mm["radiation_rate"]) * dt)
		# Picos de radiación: de vez en cuando una ráfaga llena la pantalla de estática.
		_spike_cd -= dt
		if _spike_t > 0.0:
			_spike_t -= dt
			_spike_static = randf_range(0.5, 0.8)   # estática sostenida mientras dura el pico
			_visor += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * float(mm["spike_jitter"])   # el foco tiembla
			_glitch = maxf(_glitch, 0.7)
			_shake = maxf(_shake, 2.5)
		else:
			if _spike_cd <= 0.0:
				_trigger_spike(mm)
			_spike_static = move_toward(_spike_static, 0.0, dt * 1.8)
		_drain(float(mm["energy_per_second"]) * dt)
		_progress = float(_photos.count(true)) / float(maxi(1, _photos.size()))
		# La radiación se siente: la pantalla tiembla y se llena de ruido.
		if _rad > 60.0:
			_shake = maxf(_shake, (_rad - 60.0) / 40.0 * 2.2)
		_static = maxf(clampf((_rad - 75.0) / 25.0, 0.0, 1.0) * 0.22, _spike_static)
		_update_tone(_visor.distance_to(_moon_pos(m)), float(m["tol"]))
		if _scanning:
			var res := _scan_step(dt, m, mm)
			if res == 1:
				await _photo_ok(m)
			elif res == -1:
				_photo_fail(m, mm)
		if _moon_i < _moons.size():
			var cur: Dictionary = _moons[_moon_i]
			if _scanning:
				_mm_info.text = "%s %s · %s %d%%" % [mm["scanning"], cur["name"], mm["stars_label"], int(_live_quality() * 100.0)]
			else:
				_mm_info.text = "%s · %d/%d  %s" % [mm["instruction"], _photos.count(true), _photos.size(), cur["name"]]
	_stop_tone()
	_mode = ""
	_scanning = false
	_static = 0.0
	_spike_static = 0.0
	if _depleted:
		return
	_progress = float(_photos.count(true)) / float(maxi(1, _photos.size()))
	if _moon_i >= _moons.size():
		await toast(String(sc["reward"]), YELLOW, 2.4)
		var total := 0
		for acc in _photo_acc:
			total += int(acc)
		await toast(String(mm["album_summary"]) % int(round(float(total) / float(maxi(1, _moons.size())))), RetroTheme.WHITE, 1.8)
		await say(sc["outro_full"])
	else:
		await toast(String(mm["damaged"]), RED, 2.0)
		_drain(float(mm["damaged_energy_cost"]))
		await say(sc["outro_partial"])


## Pico de radiación: estática en toda la pantalla durante medio segundo y aviso en grande.
func _trigger_spike(mm: Dictionary) -> void:
	var iv: Array = mm["spike_interval"]
	_spike_cd = randf_range(float(iv[0]), float(iv[1]))
	_spike_t = float(mm["spike_seconds"])
	_spike_static = 0.8
	_glitch = 1.0
	_shake = 6.0
	_rad = minf(100.0, _rad + float(mm["spike_radiation"]))
	# La interferencia desplaza el foco: un empujón al azar que luego hay que recuperar.
	_visor = (_visor + Vector2.from_angle(randf() * TAU) * float(mm["spike_kick"])).clamp(Vector2(70, GAME_TOP + 70), Vector2(W - 70, GAME_BOTTOM - 62))
	toast(String(mm["spike_text"]), RED, _spike_t + 0.4)


func _live_quality() -> float:
	if _scan_lines.is_empty():
		return 0.0
	return float(_scan_lines.count(true)) / float(_scan_lines.size())


## Empieza el escaneo: la imagen se forma línea a línea y hay que mantener la luna dentro del círculo.
func _start_scan() -> void:
	if _mode != "jupiter" or _scanning or _pol_active or _spike_t > 0.0 or _moon_i >= _moons.size():
		return
	var m: Dictionary = _moons[_moon_i]
	_scanning = true
	_scan_t = 0.0
	_scan_lines = []
	_scan_dur = float(m["scan"])
	_flash = 0.5
	_freeze = 0.06
	_play_shutter()


## Avanza el escaneo. Devuelve 0 mientras sigue, 1 si la foto salió bien y -1 si salió arruinada.
func _scan_step(dt: float, m: Dictionary, mm: Dictionary) -> int:
	_scan_t += dt
	var target := mini(_scan_n, int(_scan_t / _scan_dur * float(_scan_n)))
	var tol := float(m["tol"])
	var mp := _moon_pos(m)
	while _scan_lines.size() < target:
		_scan_lines.append(_visor.distance_to(mp) <= tol and _spike_t <= 0.0)
	if _scan_t < _scan_dur:
		return 0
	_scanning = false
	_scan_quality = _live_quality()
	return 1 if _scan_quality >= float(mm["min_quality"]) else -1


func _photo_fail(m: Dictionary, mm: Dictionary) -> void:
	_rad = minf(100.0, _rad + float(m["miss"]))
	_shake = 5.0
	toast(String(mm["scan_bad"]), RED, 1.2)


## Foto aceptada: obturador, polaroid con un dato real de la luna y estrellas por calidad.
func _photo_ok(m: Dictionary) -> void:
	var q := _scan_quality
	var acc := int(round(q * 100.0))
	_photos[_moon_i] = true
	_photo_acc[_moon_i] = acc
	_flash = 1.0
	_freeze = 0.1
	_play_shutter()
	_pol = {"i": _moon_i, "acc": acc, "lines": _scan_lines.duplicate()}
	_pol_active = true
	_pol_skip = false
	_pol_y = 340.0
	_mode = "polaroid"
	_mm_info.text = String(m["name"])
	_stop_tone()
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_pol_y", 62.0, 0.45)
	await tw.finished
	var held := 0.0
	while held < 3.8 and not _pol_skip:
		await get_tree().process_frame
		if not get_tree().paused:
			held += get_process_delta_time()
	var tw2 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(self, "_pol_y", 350.0, 0.3)
	await tw2.finished
	_pol_active = false
	_mode = "jupiter"
	_moon_i += 1
	_scan_lines = []
	_scan_t = 0.0


func _moon_pos(m: Dictionary) -> Vector2:
	var d := float(m["drift"])
	var sp := float(m.get("speed", 1.0))
	var a: Array = m["anchor"]
	var tt := _t * sp
	return Vector2(float(a[0]) + sin(tt * 0.9) * d + sin(tt * 2.3) * d * 0.22, float(a[1]) + cos(tt * 0.7) * d * 0.6 + cos(tt * 1.9) * d * 0.15)


func _axis_keys(neg_a: Key, neg_b: Key, pos_a: Key, pos_b: Key) -> float:
	var n := 1.0 if (Input.is_physical_key_pressed(neg_a) or Input.is_physical_key_pressed(neg_b)) else 0.0
	var p := 1.0 if (Input.is_physical_key_pressed(pos_a) or Input.is_physical_key_pressed(pos_b)) else 0.0
	return p - n


func _align_color(off: float, tol: float) -> Color:
	if off <= tol:
		return RetroTheme.PHOSPHOR
	if off <= tol * 1.8:
		return YELLOW
	return Color("#ff7a5a")


# --- sonido generado por código (sin archivos): tono de enfoque y obturador ---
func _setup_jupiter_audio() -> void:
	_tone = AudioStreamPlayer.new()
	_tone.stream = _make_tone()
	_tone.volume_db = -30.0
	world.add_child(_tone)
	_shutter = AudioStreamPlayer.new()
	_shutter.stream = _make_noise(0.14)
	_shutter.volume_db = -10.0
	world.add_child(_shutter)


## Más agudo cuanto más cerca está la luna del centro del visor.
func _update_tone(off: float, tol: float) -> void:
	if not is_instance_valid(_tone):
		return
	var near := 1.0 if off <= tol else clampf(1.0 - (off - tol) / (tol * 3.0), 0.0, 1.0)
	if near <= 0.03:
		_stop_tone()
		return
	_tone.pitch_scale = lerpf(0.7, 1.9, near)
	_tone.volume_db = lerpf(-36.0, -24.0, near)
	if not _tone.playing:
		_tone.play()


func _stop_tone() -> void:
	if is_instance_valid(_tone) and _tone.playing:
		_tone.stop()


func _play_shutter() -> void:
	if is_instance_valid(_shutter):
		_shutter.pitch_scale = randf_range(0.9, 1.1)
		_shutter.play()


func _make_tone() -> AudioStreamWAV:
	var count := 2000   # 40 ciclos exactos de 50 muestras: el bucle no tiene saltos
	var bytes := PackedByteArray()
	bytes.resize(count)
	for i in count:
		bytes[i] = int(sin(TAU * float(i) / 50.0) * 26.0) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav


func _make_noise(seconds: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1973
	for i in count:
		var env := pow(1.0 - float(i) / count, 2.0)
		bytes[i] = int(rng.randf_range(-1.0, 1.0) * 70.0 * env) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


# --- dibujo ---
func _draw_jupiter(c: DrawNode) -> void:
	var mm: Dictionary = data["scenes"][2]["minimission"]
	var font := ThemeDB.fallback_font
	# Júpiter, enorme, a la izquierda (bandas).
	var jc := Vector2(-40, 150)
	var rr := 200.0
	c.draw_circle(jc, rr, Color("#b98a5e"))
	for k in range(-8, 9):
		var dy := k * 22.0
		var wch := 2.0 * sqrt(maxf(0.0, rr * rr - dy * dy))
		var col := Color("#d8b48a") if k % 2 == 0 else Color("#9a6a44")
		c.draw_rect(Rect2(jc.x - wch * 0.5 + sin(c.t * 0.35 + k * 0.9) * 7.0, jc.y + dy - 6.0, wch, 11.0), Color(col, 0.55))
	c.draw_circle(Vector2(110 + sin(c.t * 0.18) * 9.0, 195 + sin(c.t * 0.11) * 3.0), 14.0, Color("#b0452a"))
	var mi := mini(_moon_i, _moons.size() - 1)
	var m: Dictionary = _moons[mi]
	var tol := float(m["tol"])
	var mp := _moon_pos(m)
	var off := _visor.distance_to(mp)
	if _moon_i < _moons.size():
		var rad := float(m["radius"])
		c.draw_circle(mp, rad, Color(String(m["color"])))
		c.draw_circle(mp + Vector2(-rad * 0.35, -rad * 0.2), rad * 0.18, Color(0, 0, 0, 0.18))
		c.draw_circle(mp + Vector2(rad * 0.3, rad * 0.35), rad * 0.12, Color(0, 0, 0, 0.18))
		c.draw_arc(mp, rad, 0.0, TAU, 28, Color(1, 1, 1, 0.25), 1.0)
	# Visor: cambia de color al acercarse (rojo, amarillo, verde) y "engancha" al centrarse.
	var h := 58.0
	var ac := _align_color(off, tol)
	var vc := Color(ac, 0.95)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := _visor + Vector2(sx * h, sy * h)
			c.draw_line(corner, corner - Vector2(sx * 14.0, 0.0), vc, 2.0)
			c.draw_line(corner, corner - Vector2(0.0, sy * 14.0), vc, 2.0)
	c.draw_line(_visor + Vector2(-6, 0), _visor + Vector2(6, 0), vc, 1.0)
	c.draw_line(_visor + Vector2(0, -6), _visor + Vector2(0, 6), vc, 1.0)
	c.draw_arc(_visor, tol, 0.0, TAU, 28, Color(ac, 0.65), 1.0)
	if _visor_target.distance_to(_visor) > 4.0:
		c.draw_circle(_visor_target, 2.0, Color(1, 1, 1, 0.5))
		c.draw_arc(_visor_target, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.25), 1.0)
	if off <= tol and _moon_i < _moons.size():
		var pulse := 0.5 + 0.5 * sin(c.t * 9.0)
		c.draw_arc(_visor, tol + 3.0 + pulse * 3.0, 0.0, TAU, 28, Color(ac, 0.35 + 0.3 * pulse), 1.0)
		if not _scanning:
			c.draw_string(font, _visor + Vector2(-26, h + 12), "ENFOCADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ac)
	# Barrido del escaneo dentro del visor.
	if _scanning:
		var sy2 := _visor.y - h + (_scan_t / _scan_dur) * h * 2.0
		c.draw_rect(Rect2(_visor.x - h, sy2 - 1.0, h * 2.0, 3.0), Color(0.5, 1.0, 1.0, 0.8))
		c.draw_rect(Rect2(_visor.x - h, sy2 - 7.0, h * 2.0, 6.0), Color(0.5, 1.0, 1.0, 0.18))
	# Medidor de radiación.
	MissionBase.draw_bar(c, Rect2(440, GAME_TOP + 62, 180, 8), _rad / 100.0, RED if _rad > 70.0 else Color("#d08a4a"), String(mm["radiation"]))
	# Panel de la foto que se está formando.
	var pr := Rect2(500, 106, 122, 130)
	c.draw_rect(pr, Color(0.01, 0.03, 0.04, 0.9))
	c.draw_rect(pr, Color(RetroTheme.PHOSPHOR, 0.7), false, 1.0)
	c.draw_string(font, pr.position + Vector2(5, 11), "FOTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
	var pc := pr.position + Vector2(61, 70)
	var mcol := Color(String(m["color"]))
	_draw_scan_image(c, pc, 46.0, mcol, _scan_lines, _scan_n, float(mi))
	if _scanning:
		var ly := pc.y - 46.0 + (_scan_t / _scan_dur) * 92.0
		c.draw_rect(Rect2(pr.position.x + 3, ly - 1.0, pr.size.x - 6, 2.0), Color(0.5, 1.0, 1.0, 0.9))
		c.draw_string(font, pr.position + Vector2(5, 125), "%d%%" % int(_live_quality() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, YELLOW)
	# Álbum: una ficha por foto, con sus estrellas.
	c.draw_string(font, Vector2(8, GAME_TOP + 66), String(mm["album"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RetroTheme.WHITE)
	for k in _photos.size():
		var slot := Rect2(8 + k * 36, GAME_TOP + 70, 32, 36)
		c.draw_rect(slot, Color(0, 0, 0, 0.55))
		c.draw_rect(slot, Color(YELLOW, 0.8) if _photos[k] else Color(1, 1, 1, 0.3), false, 1.0)
		if _photos[k]:
			c.draw_circle(slot.position + Vector2(16, 14), 9.0, Color(String(_moons[k]["color"])))
			c.draw_string(font, slot.position + Vector2(3, 31), "%d%%" % int(_photo_acc[k]), HORIZONTAL_ALIGNMENT_CENTER, 26, 9, _acc_color(int(_photo_acc[k])))
		else:
			c.draw_string(font, slot.position + Vector2(12, 22), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.4))
	# Polaroid con el dato de la luna.
	if _pol_active:
		_draw_polaroid(c)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, GAME_BOTTOM - GAME_TOP), Color(1, 1, 1, _flash * 0.6))
	# Ruido de radiación.
	if _rad > 55.0:
		for i in int((_rad - 55.0) * 6.0):
			c.draw_rect(Rect2(randf() * W, GAME_TOP + randf() * 244.0, 2, 1), Color(1, 1, 1, 0.5))


## Imagen de la luna formada línea a línea: las líneas fuera de encuadre salen corruptas.
func _draw_scan_image(c: CanvasItem, center: Vector2, radius: float, col: Color, lines: Array, n: int, seed_v: float) -> void:
	var lh := radius * 2.0 / float(maxi(1, n))
	for j in lines.size():
		var y := center.y - radius + j * lh
		var dy := y + lh * 0.5 - center.y
		var w := sqrt(maxf(0.0, radius * radius - dy * dy))
		if w <= 0.5:
			continue
		if bool(lines[j]):
			var shade := 1.0 - 0.38 * absf(dy) / radius + 0.07 * sin(j * 1.7 + seed_v)
			c.draw_rect(Rect2(center.x - w, y, w * 2.0, lh + 0.6), Color(col.r * shade, col.g * shade, col.b * shade))
			if (j + int(seed_v) * 3) % 7 == 0:
				c.draw_rect(Rect2(center.x - w * 0.3 + sin(seed_v + j) * w * 0.4, y, lh * 2.5, lh), Color(0, 0, 0, 0.22))
		else:
			var shift := sin(j * 12.9 + seed_v * 7.0) * radius * 0.35
			c.draw_rect(Rect2(center.x - w + shift, y, w * 2.0, lh + 0.6), Color(0.5, 0.56, 0.68, 0.55))
			for k in 5:
				c.draw_rect(Rect2(center.x - w + randf() * w * 2.0, y, 3, lh), Color(1, 1, 1, randf() * 0.7))


func _acc_color(acc: int) -> Color:
	if acc >= 90:
		return RetroTheme.PHOSPHOR
	if acc >= 70:
		return YELLOW
	return Color("#ff9a5a")


func _draw_polaroid(c: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	var m: Dictionary = _moons[int(_pol["i"])]
	var center := Vector2(320, _pol_y + 80.0)
	c.draw_set_transform(center, -0.035, Vector2.ONE)
	var card := Rect2(-170, -80, 340, 160)
	c.draw_rect(card.grow(3), Color(0, 0, 0, 0.5))
	c.draw_rect(card, Color("#ece7d6"))
	c.draw_rect(card, Color("#8a8470"), false, 1.0)
	var photo := Rect2(-160, -70, 112, 112)
	c.draw_rect(photo, Color("#0a0e18"))
	_draw_scan_image(c, photo.get_center(), 48.0, Color(String(m["color"])), _pol["lines"], _scan_n, float(int(_pol["i"])))
	var ink := Color("#2a2a34")
	c.draw_string(font, Vector2(-160, 58), String(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	c.draw_string(font, Vector2(-160, 72), String(data["scenes"][2]["minimission"]["stars_label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#6a6a74"))
	c.draw_string(font, Vector2(-40, -56), "%d%%" % int(_pol["acc"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, _acc_color(int(_pol["acc"])).darkened(0.25))
	c.draw_string(font, Vector2(30, -56), String(data["scenes"][2]["minimission"]["stars_label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#6a6a74"))
	c.draw_multiline_string(font, Vector2(-40, -40), String(m["fact"]), HORIZONTAL_ALIGNMENT_LEFT, 205.0, 10, -1, ink)
	c.draw_string(font, Vector2(60, 72), "ENTER: SEGUIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#8a8a94"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =========================================================================
# FASE 3 · Tormenta y magnetosfera (cinemática pendiente)
# =========================================================================
## Cinemática en tres planos: el Sol lanza la tormenta (Pioneer 9 y 10 la registran), la
## tormenta sacude la nave (única acción: apuntar la antena a la Tierra) y la nave cruza la
## magnetosfera de Júpiter mientras la temperatura del plasma sube unas cien veces.
func _scene_storm(sc: Dictionary) -> void:
	var cin: Dictionary = sc["cinematic"]
	_st_shot = 0
	_st_flare = 0.0
	_st_wave = -1.0
	_st_ant = 0.0
	_st_drift = 0.0
	_st_signal = 1.0
	_st_jup = 0.0
	_st_temp = 1.0
	_st_cross = 0.0
	_st_bars = 0.0
	_stars(Vector2(-4, 0), 120)
	_layer(_draw_storm.bind(cin))
	var tw := create_tween()
	tw.tween_property(self, "_st_bars", 1.0, 0.6)
	await tw.finished

	# Plano 1: erupción solar y frente de partículas.
	var t1 := create_tween()
	t1.tween_property(self, "_st_flare", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	await t1.finished
	var t2 := create_tween()
	t2.tween_property(self, "_st_wave", 0.45, 2.2)
	if not _retry:
		await say(cin["lines_storm"])
	if t2.is_running():
		await t2.finished

	# Plano 2: la tormenta golpea la nave. El jugador mantiene la antena sobre la Tierra.
	_st_shot = 1
	_st_wave = 0.0
	var t3 := create_tween()
	t3.tween_property(self, "_st_wave", 1.0, 1.6)
	await t3.finished
	_shake = 5.0
	_glitch = 0.8
	await say(cin["lines_antenna"])
	_mm_title.text = String(cin["antenna_title"])
	_mm_info.text = String(cin["antenna_info"])
	var tol := deg_to_rad(float(cin["antenna_tol_deg"]))
	var secs := float(cin["antenna_seconds"])
	var elapsed := 0.0
	var off_time := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1973
	_st_drift = 0.9
	while elapsed < secs:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		elapsed += dt
		# Las ráfagas de la tormenta empujan la nave; cambian de sentido cada cierto tiempo.
		if rng.randf() < dt * 0.9:
			_st_drift = rng.randf_range(0.7, 1.3) * (-1.0 if _st_drift > 0.0 else 1.0)
			_shake = maxf(_shake, 3.0)
		var turn := Input.get_action_strength("rotate_right") - Input.get_action_strength("rotate_left")
		_st_ant = clampf(_st_ant + (_st_drift * 0.55 + turn * 1.6) * dt, -PI * 0.5, PI * 0.5)
		var ok := absf(_st_ant) <= tol
		_st_signal = clampf(_st_signal + (0.5 if ok else -0.7) * dt, 0.0, 1.0)
		_static = (1.0 - _st_signal) * 0.35
		if not ok:
			off_time += dt
			_drain(float(sc["antenna_drain"]) * dt)
			if _depleted:
				return
		_mm_info.text = "%s · %s %d%%%s" % [cin["antenna_info"], cin["signal"], int(_st_signal * 100.0), "" if ok else "   " + String(cin["lost"])]
	_mm_title.text = ""
	_mm_info.text = ""
	_static = 0.0
	var t4 := create_tween()
	t4.tween_property(self, "_st_ant", 0.0, 0.5)
	await say(cin["lines_antenna_ok"] if off_time < secs * 0.35 else cin["lines_antenna_bad"])

	# Plano 3: Júpiter y su magnetosfera; la temperatura del plasma sube.
	_st_shot = 2
	var t5 := create_tween()
	t5.tween_property(self, "_st_jup", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t5.finished
	var t6 := create_tween()
	t6.tween_property(self, "_st_cross", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	t6.parallel().tween_property(self, "_st_temp", 100.0, 3.0).set_delay(1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await say(cin["lines_magnetosphere"])
	if t6.is_running():
		await t6.finished
	await wait(0.6)
	var t7 := create_tween()
	t7.tween_property(self, "_st_bars", 0.0, 0.5)
	await t7.finished
	_drain(float(sc["energy_cost"]))
	await say(sc["outro"])


func _draw_storm(c: DrawNode, cin: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var cy := 146.0
	if _st_shot == 0:
		# Sol a la izquierda con la erupción; Pioneer 9 cerca, Pioneer 10 lejos.
		var sun := Vector2(-40, cy)
		for k in 6:
			c.draw_circle(sun, 96.0 + k * 9.0 + _st_flare * 10.0, Color(1.0, 0.6, 0.15, 0.05))
		c.draw_circle(sun, 92.0, Color("#ffb347"))
		c.draw_circle(sun, 80.0, Color("#ffd24a"))
		# Prominencia que crece.
		var fl := _st_flare
		for i in 9:
			var a := -0.5 + i * 0.12
			var r := 92.0 + fl * (30.0 + 22.0 * sin(c.t * 5.0 + i))
			c.draw_line(sun + Vector2(cos(a), sin(a)) * 88.0, sun + Vector2(cos(a), sin(a)) * r, Color(1.0, 0.45, 0.1, 0.8 * fl), 3.0)
		_draw_wave(c, sun, lerpf(100.0, 700.0, clampf(_st_wave, 0.0, 1.0)))
		var p9 := Vector2(210, cy + 36)
		PioneerArt.draw_pioneer(c, p9, PI, 1.0)
		c.draw_string(font, p9 + Vector2(-26, 22), String(cin["pioneer9"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
		var p10 := Vector2(520, cy - 30)
		PioneerArt.draw_pioneer(c, p10, PI, 1.4)
		c.draw_string(font, p10 + Vector2(-30, 28), String(cin["pioneer10"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, YELLOW)
		c.draw_string(font, Vector2(14, GAME_BOTTOM - 40), String(cin["sun"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffd24a"))
		if _st_wave > 0.0:
			c.draw_string(font, Vector2(150, GAME_TOP + 46), String(cin["storm_label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.6, 0.3, 0.9))
	elif _st_shot == 1:
		# Primer plano: la nave, la Tierra (abajo a la izquierda) y el haz de la antena.
		var probe := Vector2(390, cy - 6)
		var earth := Vector2(70, GAME_BOTTOM - 46)
		var base := (earth - probe).angle()
		var ang := base + _st_ant
		_draw_wave(c, Vector2(-500, cy), lerpf(700.0, 1300.0, _st_wave))
		c.draw_circle(earth, 9.0, Color("#3a7bd5"))
		c.draw_circle(earth + Vector2(-2, -2), 4.0, Color("#5fbf6a"))
		c.draw_string(font, earth + Vector2(-16, 22), String(cin["earth"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
		var tol := deg_to_rad(float(cin["antenna_tol_deg"]))
		var ok := absf(_st_ant) <= tol
		var beam := Color(RetroTheme.PHOSPHOR, 0.35) if ok else Color(RED, 0.3)
		var far := probe.distance_to(earth) + 30.0
		var half := 0.07
		c.draw_colored_polygon(PackedVector2Array([probe, probe + Vector2.from_angle(ang - half) * far, probe + Vector2.from_angle(ang + half) * far]), beam)
		PioneerArt.draw_pioneer(c, probe, ang, 3.0)
		# Medidor de señal.
		var bar := Rect2(470, GAME_TOP + 60, 140, 8)
		c.draw_string(font, bar.position + Vector2(0, -4), String(cin["signal"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _st_signal, bar.size.y)), RetroTheme.PHOSPHOR if ok else RED)
		c.draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
	else:
		# Júpiter entra por la derecha; la nave cruza las líneas de la magnetosfera.
		var jc := Vector2(lerpf(860.0, 600.0, _st_jup), cy)
		for k in 5:
			var r := 230.0 + k * 34.0
			var col := Color(0.4, 0.9, 1.0, 0.14 + 0.05 * sin(c.t * 2.0 + k))
			c.draw_arc(jc, r, PI * 0.62, PI * 1.38, 48, col, 2.0)
		c.draw_arc(jc, 400.0, PI * 0.68, PI * 1.32, 48, Color(0.5, 1.0, 1.0, 0.55), 2.0)
		c.draw_circle(jc, 150.0, Color("#b98a5e"))
		for k in range(-6, 7):
			var dy := k * 22.0
			var wch := 2.0 * sqrt(maxf(0.0, 150.0 * 150.0 - dy * dy))
			c.draw_rect(Rect2(jc.x - wch * 0.5, jc.y + dy - 6.0, wch, 11.0), Color(Color("#d8b48a") if k % 2 == 0 else Color("#9a6a44"), 0.6))
		c.draw_string(font, Vector2(jc.x - 388, GAME_BOTTOM - 26), String(cin["magnetosphere"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 1.0, 1.0, 0.9 * _st_jup))
		var probe := Vector2(lerpf(40.0, 300.0, _st_cross), cy - 30.0 + 14.0 * _st_cross)
		PioneerArt.draw_pioneer(c, probe, PI * 0.88, 1.6)
		var inside := probe.distance_to(jc) < 400.0
		if inside:
			c.draw_circle(probe, 16.0 + 3.0 * sin(c.t * 9.0), Color(1.0, 0.45, 0.2, 0.18))
		var tx := 20.0
		var ty := GAME_TOP + 60.0
		c.draw_string(font, Vector2(tx, ty), String(cin["temperature"]) % int(round(_st_temp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, YELLOW if _st_temp < 50.0 else RED)
		var bar := Rect2(tx, ty + 5, 150, 7)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_st_temp / 100.0, 0.0, 1.0), bar.size.y)), YELLOW.lerp(RED, clampf(_st_temp / 100.0, 0.0, 1.0)))
		c.draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
	# Franjas de cine.
	var bh := 18.0 * _st_bars
	if bh > 0.0:
		c.draw_rect(Rect2(0, GAME_TOP, W, bh), Color.BLACK)
		c.draw_rect(Rect2(0, GAME_BOTTOM - bh, W, bh), Color.BLACK)


## Frente de la tormenta: arco de partículas que avanza desde el Sol.
func _draw_wave(c: DrawNode, origin: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	for k in 3:
		var r := radius - k * 18.0
		if r > 0.0:
			c.draw_arc(origin, r, -0.9, 0.9, 40, Color(1.0, 0.55, 0.2, 0.35 - k * 0.1), 3.0)
	for i in 70:
		var a := -0.9 + 1.8 * fposmod(i * 0.618, 1.0)
		var rr := radius - fposmod(i * 7.3 + c.t * 40.0, 60.0)
		if rr > 0.0:
			c.draw_rect(Rect2(origin + Vector2.from_angle(a) * rr, Vector2(2, 1)), Color(1.0, 0.8, 0.4, 0.7))


# =========================================================================
# FASE 4 · El silencio (línea de tiempo)
# =========================================================================
func _scene_silence(sc: Dictionary) -> void:
	var y0 := float(sc["year_start"])
	var y1 := float(sc["year_end"])
	var secs := float(sc["seconds"])
	var events: Array = sc["events"]
	var e0 := _energy
	var e1 := float(sc["energy_end"])
	_sil_year = y0
	_sil_log.clear()
	_sil_frac = 0.0
	_stars(Vector2(-6, 0), 110)
	_layer(func(c: DrawNode) -> void:
		var font := ThemeDB.fallback_font
		var x0 := 40.0
		var x1 := 600.0
		var ty := 108.0
		c.draw_line(Vector2(x0, ty), Vector2(x1, ty), Color(1, 1, 1, 0.35), 1.0)
		for yr in range(1976, 2004, 3):
			var xx := lerpf(x0, x1, (float(yr) - 1976.0) / 27.0)
			c.draw_line(Vector2(xx, ty - 3), Vector2(xx, ty + 3), Color(1, 1, 1, 0.5), 1.0)
			c.draw_string(font, Vector2(xx - 10, ty + 16), str(yr), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.55))
		var px := lerpf(x0, x1, clampf((_sil_year - 1976.0) / 27.0, 0.0, 1.0))
		c.draw_line(Vector2(x0, ty), Vector2(px, ty), YELLOW, 2.0)
		PioneerArt.draw_pioneer(c, Vector2(px, ty - 14), PI, 0.8)
		for ev in events:
			var ex := lerpf(x0, x1, (float(ev["year"]) - 1976.0) / 27.0)
			c.draw_rect(Rect2(ex - 2, ty - 2, 4, 4), YELLOW if float(ev["year"]) <= _sil_year else Color(1, 1, 1, 0.3))
		# Registro: "cartas sin respuesta".
		var y := 150.0
		for i in _sil_log.size():
			var row: Dictionary = _sil_log[i]
			var fade := 1.0 - _sil_frac * 0.45
			c.draw_string(font, Vector2(40, y), "%d · %s" % [int(row["year"]), String(row["text"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, fade))
			c.draw_string(font, Vector2(400, y), "> %s" % String(row["link"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(YELLOW, fade * (0.55 + 0.45 * float(i < 2))))
			y += 15.0
	)
	if not _retry:
		await say(sc["intro"])
	_mm_title.text = String(sc["objective"])
	var elapsed := 0.0
	var shown := 0
	while elapsed < secs:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		# ENTER / clic mantenido: acelera el paso del tiempo.
		var speed := 3.0 if (Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 1.0
		elapsed = minf(secs, elapsed + dt * speed)
		_sil_frac = elapsed / secs
		_sil_year = lerpf(y0, y1, _sil_frac)
		_set_year("%d" % int(_sil_year))
		_energy = lerpf(e0, e1, _sil_frac)
		# Enlace cada vez más intermitente.
		var glitch := 1.0 if sin(_t * 9.0) > 0.82 else 0.0
		_static = _sil_frac * 0.25 + glitch * _sil_frac * 0.35
		while shown < events.size() and float(events[shown]["year"]) <= _sil_year:
			_sil_log.append(events[shown])
			_mm_info.text = "ENLACE: %s" % String(events[shown]["link"])
			shown += 1
	_static = 0.0
	_set_year("2003")
	await say(sc["final"])
	# Pantalla en negro un segundo y luego la última posición calculada.
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	await tw.finished
	await wait(1.0)
	_fade_text.text = String(sc["final_text"])
	_fade_text.show()
	await wait(4.0)
	_fade_text.hide()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.5)
	await tw2.finished


# =========================================================================
# FASE 5 · La placa (púlsares y error)
# =========================================================================
func _scene_plate(sc: Dictionary) -> void:
	_plate_mm = sc["minimission"]
	var mm := _plate_mm
	_sun = MAP.position + Vector2(MAP.size.x * 0.52, MAP.size.y * 0.5)
	_pulsars.clear()
	for p in mm["pulsars"]:
		var a := deg_to_rad(float(p["angle"]))
		var d := float(p["dist"])
		var pos := (_sun + Vector2(cos(a), sin(a)) * d).clamp(MAP.position + Vector2(8, 8), MAP.end - Vector2(8, 8))
		_pulsars.append({"id": String(p["id"]), "period": float(p["period_s"]), "pos": pos, "len": pos.distance_to(_sun)})
	_cursor = MAP.get_center()
	_has_prop = false
	_signs.clear()
	_best_pct = 100.0
	_last_pct = 100.0
	_frags = 0
	_plate_won = false
	_attempts = _attempts_for_energy(mm)
	_static_decay = 0.9
	_stars()
	_layer(_draw_plate)
	if not _retry:
		await say(sc["intro"])
	_mm_title.text = String(mm["title"])
	_mm_info.text = String(mm["instruction"])
	_mode = "plate"
	var failed := 0
	var hint_shown := false
	while not _plate_won:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		var mv := Vector2(_axis_keys(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT), _axis_keys(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
		_cursor = (_cursor + mv * 130.0 * dt).clamp(MAP.position, MAP.end)
		if _attempts <= 0 and not _plate_won:
			# Se agotaron los intentos: la señal se pierde y se vuelve a empezar.
			_mode = ""
			_static = 0.9
			await toast(String(mm["lose"]), RED, 2.4)
			_frags = 0
			_best_pct = 100.0
			_has_prop = false
			_signs.clear()
			_attempts = _attempts_for_energy(mm)
			_mode = "plate"
		if not hint_shown and failed >= int(mm["hint_after"]) and not _plate_won:
			hint_shown = true
			dialog.show_hint("CONTROLADORA", String(mm["hint"]), 8.0)
		failed = maxi(failed, int(_attempts_used))
	_mode = ""
	_static = 0.0
	await wait(0.6)
	await toast(String(sc["reward"]), YELLOW, 2.8)
	await say(sc["outro"])


var _attempts_used := 0


func _attempts_for_energy(mm: Dictionary) -> int:
	_attempts_used = 0
	var n := int(mm["base_attempts"]) + int(_energy / float(mm["energy_per_attempt"]))
	return clampi(n, int(mm["base_attempts"]), int(mm["max_attempts"]))


func _propose(pos: Vector2) -> void:
	if _plate_won or _attempts <= 0 or not MAP.has_point(pos):
		return
	var mm := _plate_mm
	var thr: Array = mm["thresholds_pct"]
	var diag := MAP.size.length()
	_attempts -= 1
	_attempts_used += 1
	_proposal = pos
	_has_prop = true
	_last_pct = pos.distance_to(_sun) / diag * 100.0
	_best_pct = minf(_best_pct, _last_pct)
	_signs.clear()
	for p in _pulsars:
		var diff := float(p["len"]) - pos.distance_to(p["pos"])
		_signs.append("=" if absf(diff) <= 6.0 else ("+" if diff > 0.0 else "−"))
	# Cada umbral superado descifra un fragmento del mensaje.
	var unlocked := 0
	for th in thr:
		if _best_pct <= float(th):
			unlocked += 1
	if unlocked > _frags:
		_frags = unlocked
		var names: Array = mm["fragments"]
		toast(String(mm["unlock"]) % String(names[mini(_frags, names.size()) - 1]), YELLOW, 1.2)
		_flash = 0.6
	if _last_pct > float(thr[0]):
		_static = 0.45   # equivocarse mucho llena la pantalla de ruido
	if _frags >= thr.size():
		_plate_won = true
		_static = 0.0


func _draw_plate(c: DrawNode) -> void:
	var mm := _plate_mm
	var font := ThemeDB.fallback_font
	# Mapa de la galaxia con los 14 púlsares.
	c.draw_rect(MAP, Color(0.02, 0.03, 0.09, 0.9))
	c.draw_rect(MAP, Color(RetroTheme.PHOSPHOR, 0.6), false, 1.0)
	for gx in range(1, 8):
		c.draw_line(MAP.position + Vector2(gx * MAP.size.x / 8.0, 0), MAP.position + Vector2(gx * MAP.size.x / 8.0, MAP.size.y), Color(1, 1, 1, 0.04), 1.0)
	for gy in range(1, 4):
		c.draw_line(MAP.position + Vector2(0, gy * MAP.size.y / 4.0), MAP.position + Vector2(MAP.size.x, gy * MAP.size.y / 4.0), Color(1, 1, 1, 0.04), 1.0)
	# Líneas desde la propuesta hacia cada púlsar.
	if _has_prop:
		for i in _pulsars.size():
			var col := RetroTheme.PHOSPHOR if _signs[i] == "=" else (YELLOW if _plate_won else Color("#ff9a7a"))
			c.draw_line(_proposal, _pulsars[i]["pos"], Color(col, 0.5), 1.0)
	for i in _pulsars.size():
		var p: Dictionary = _pulsars[i]
		var pos: Vector2 = p["pos"]
		var period := maxf(float(p["period"]), 0.18)
		var phase := fmod(c.t, period) / period
		var lit := phase < 0.16
		c.draw_circle(pos, 4.0 if lit else 2.5, Color("#ffffff") if lit else Color("#8aa0ff"))
		if lit:
			c.draw_arc(pos, 8.0, 0.0, TAU, 14, Color(1, 1, 1, 0.5), 1.0)
		c.draw_string(font, pos + Vector2(6, -4), "%s %.2fs" % [p["id"], p["period"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.8))
		if _has_prop and i < _signs.size():
			var sg: String = _signs[i]
			c.draw_string(font, pos + Vector2(-4, 14), sg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RetroTheme.PHOSPHOR if sg == "=" else RED)
	if _plate_won:
		c.draw_circle(_sun, 6.0, YELLOW)
		c.draw_arc(_sun, 10.0 + 2.0 * sin(c.t * 4.0), 0.0, TAU, 20, YELLOW, 1.0)
	# Cursor y propuesta.
	c.draw_line(_cursor + Vector2(-7, 0), _cursor + Vector2(7, 0), Color(1, 1, 1, 0.7), 1.0)
	c.draw_line(_cursor + Vector2(0, -7), _cursor + Vector2(0, 7), Color(1, 1, 1, 0.7), 1.0)
	if _has_prop:
		c.draw_arc(_proposal, 5.0, 0.0, TAU, 12, YELLOW, 2.0)
	# Placa: cuatro fragmentos que se van descifrando.
	var plate := Rect2(398, 74, 234, 112)
	c.draw_rect(plate, Color("#2a2418"))
	c.draw_rect(plate, Color("#c8b070"), false, 2.0)
	var frag_names: Array = mm["fragments"]
	for i in 4:
		var cell := Rect2(plate.position + Vector2(4 + (i % 2) * 115, 4 + (i / 2) * 54), Vector2(111, 50))
		c.draw_rect(cell, Color("#3a3220"))
		if i < _frags:
			_draw_fragment(c, i, cell)
			c.draw_string(font, cell.position + Vector2(3, 10), String(frag_names[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#e8d8a0"))
		else:
			for k in 24:
				c.draw_rect(Rect2(cell.position + Vector2(randf() * 108.0, randf() * 48.0), Vector2(2, 1)), Color(1, 1, 1, 0.18))
			c.draw_string(font, cell.position + Vector2(44, 32), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.3))
	# Medidor de error, intentos y leyenda.
	var err_col := RetroTheme.PHOSPHOR if _last_pct <= float(mm["thresholds_pct"][3]) else (YELLOW if _last_pct <= float(mm["thresholds_pct"][1]) else RED)
	c.draw_string(font, Vector2(398, 202), "%s %s" % [mm["error_label"], ("--" if not _has_prop else "%d%%" % int(round(_last_pct)))], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RetroTheme.WHITE)
	var eb := Rect2(398, 208, 234, 8)
	c.draw_rect(eb, Color(0, 0, 0, 0.6))
	if _has_prop:
		c.draw_rect(Rect2(eb.position, Vector2(eb.size.x * clampf(_last_pct / 50.0, 0.04, 1.0), eb.size.y)), err_col)
	c.draw_rect(eb, err_col, false, 1.0)
	c.draw_string(font, Vector2(398, 232), "%s: %d" % [mm["attempts_label"], _attempts], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, YELLOW)
	c.draw_string(font, Vector2(398, 248), String(mm["legend"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.75))


func _draw_fragment(c: DrawNode, i: int, cell: Rect2) -> void:
	var o := cell.position + Vector2(55, 28)
	var ink := Color("#f0e4b0")
	match i:
		0:   # un hombre
			c.draw_circle(o + Vector2(0, -12), 4.0, ink)
			c.draw_rect(Rect2(o + Vector2(-4, -7), Vector2(8, 14)), ink)
			c.draw_line(o + Vector2(-4, -5), o + Vector2(-10, -14), ink, 2.0)
			c.draw_rect(Rect2(o + Vector2(-4, 7), Vector2(3, 10)), ink)
			c.draw_rect(Rect2(o + Vector2(1, 7), Vector2(3, 10)), ink)
		1:   # una mujer
			c.draw_circle(o + Vector2(0, -12), 4.0, ink)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-3, -7), o + Vector2(3, -7), o + Vector2(7, 8), o + Vector2(-7, 8)]), ink)
			c.draw_rect(Rect2(o + Vector2(-3, 8), Vector2(2, 9)), ink)
			c.draw_rect(Rect2(o + Vector2(1, 8), Vector2(2, 9)), ink)
		2:   # el sistema solar
			c.draw_circle(o + Vector2(-42, 0), 5.0, ink)
			for k in 9:
				c.draw_circle(o + Vector2(-30 + k * 9, 0), 1.5 + (1.5 if k == 4 or k == 5 else 0.0), ink)
			c.draw_line(o + Vector2(-3, 4), o + Vector2(20, 14), ink, 1.0)
		3:   # 14 púlsares alrededor del Sol
			c.draw_circle(o, 2.0, YELLOW)
			for k in 14:
				var a := k * TAU / 14.0
				c.draw_line(o, o + Vector2(cos(a), sin(a)) * (12.0 + (k % 4) * 4.0), ink, 1.0)


# =========================================================================
# EPÍLOGO · 2 millones de años
# =========================================================================
func _scene_epilogue(sc: Dictionary) -> void:
	_set_year("")
	_set_objective("")
	_stars(Vector2(-4, 0), 140)
	_layer(func(c: DrawNode) -> void:
		# Aldebarán: la estrella roja del ojo de Tauro.
		c.draw_circle(Vector2(560, 120), 16.0 + sin(c.t * 1.5), Color(1.0, 0.45, 0.25, 0.25))
		c.draw_circle(Vector2(560, 120), 6.0, Color("#ff7a44"))
		PioneerArt.draw_pioneer(c, Vector2(180.0 + fmod(c.t * 6.0, 120.0), 120.0 - fmod(c.t * 1.2, 20.0)), PI, 1.2)
	)
	var y := 160.0
	var lines: Array = sc["lines"]
	for k in lines.size():
		var l := _label(Vector2(40, y), Vector2(560, 18), 13, YELLOW, ui_layer)
		l.text = String(lines[k])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.8)
		await tw.finished
		await wait(1.0)
		y += 20.0
	await wait(0.8)
	var f := _label(Vector2(40, y + 12), Vector2(560, 40), 15, RetroTheme.WHITE, ui_layer)
	f.text = String(sc["final_text"])
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(f, "modulate:a", 1.0, 1.2)
	await tw2.finished
	await wait(1.2)
	var h := _label(Vector2(0, 240), Vector2(W, 14), 10, Color("#80f2ff"), ui_layer)
	h.text = String(data["hud"]["button_back"])
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		if k >= KEY_F1 and k <= KEY_F7:
			GameManager.set_start_phase(k - KEY_F1 + 1)
			SceneTransition.change_scene(scene_file_path, 0.2)
			return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not MissionHUD.hover_ui
	match _mode:
		"continue":
			if click or event.is_action_pressed("ui_accept"):
				_mode = ""
		"jupiter":
			if event is InputEventMouseMotion:
				_mouse_aim = true
				_visor_target = get_local_mouse_position().clamp(Vector2(70, GAME_TOP + 70), Vector2(W - 70, GAME_BOTTOM - 62))
			elif click or event.is_action_pressed("ui_accept"):
				_start_scan()
		"polaroid":
			if click or event.is_action_pressed("ui_accept"):
				_pol_skip = true
		"plate":
			if event is InputEventMouseMotion:
				_cursor = get_local_mouse_position().clamp(MAP.position, MAP.end)
			elif click:
				_propose(get_local_mouse_position())
			elif event.is_action_pressed("ui_accept"):
				_propose(_cursor)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		(_pause_panel.get_child(0).get_child(1) as Button).grab_focus()
