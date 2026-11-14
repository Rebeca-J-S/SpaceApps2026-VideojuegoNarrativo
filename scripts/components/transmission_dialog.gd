class_name TransmissionDialog
extends Control
## Diálogo con efectos de transmisión por radio (capítulo Spirit y Opportunity).
## Componente nuevo y reutilizable; no reemplaza a RadioDialog.
##
## - Emisor normal (CIENTÍFICO): máquina de escribir a ~30 car/s con "blip" de voz.
## - Emisor por radio (SPIRIT / OPPORTUNITY): etiqueta TX o RX con el color del robot,
##   "SEÑAL EN TRÁNSITO..." durante 1-1.5 s, crepitar de radio, primeras letras con glitch
##   que se resuelven en el texto real y ruido/scanlines sobre la caja.
## - ENTER / ESPACIO / clic: la primera pulsación completa el texto, la segunda avanza.
##
## Uso:  dialog.speakers = datos["speakers"]
##       await dialog.play([{"speaker": "SPIRIT", "mode": "TX", "text": "..."}])
## Retratos: res://assets/sprites/portraits/<portrait>.png si existe; si no, placeholder.

signal finished
signal robot_speaking_changed(speaking: bool)

const TYPE_SPEED := 30.0
const GLITCH_CHARS := 14
const GLITCH_SYMBOLS := "#$%&*@!?/<>=+~^:;01"
const INPUT_GRACE := 0.25

var speakers: Dictionary = {}
var transit_text := "SEÑAL EN TRÁNSITO"

var _lines: Array = []
var _index := -1
var _active := false
var _phase := 0            # 0 inactivo, 1 en tránsito, 2 escribiendo, 3 esperando
var _transit_left := 0.0
var _reveal_t := 0.0
var _chars := 0.0
var _full := ""
var _radio := false
var _clock := 0.0
var _accept_after := 0.0
var _robot_speaking := false
var _rng := RandomNumberGenerator.new()
var _portrait_color := Color.GRAY
var _portrait_code := ""

var _portrait: Control
var _portrait_tex: TextureRect
var _box: Control
var _name: Label
var _tag: Label
var _text: Label
var _hint: Label
var _transit: Label
var _noise_mat: ShaderMaterial
var _blip: AudioStreamPlayer
var _crackle: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_build()
	_idle()


func is_active() -> bool:
	return _active


func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = -1
	_active = true
	_next()
	await finished


# -------------------------------------------------------------------------
# Construcción
# -------------------------------------------------------------------------
func _build() -> void:
	# Retrato (izquierda).
	_portrait = Control.new()
	_portrait.position = Vector2.ZERO
	_portrait.size = Vector2(72, 72)
	_portrait.draw.connect(_draw_portrait)
	add_child(_portrait)
	_portrait_tex = TextureRect.new()
	_portrait_tex.position = Vector2(4, 4)
	_portrait_tex.size = Vector2(64, 64)
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.add_child(_portrait_tex)

	# Caja de diálogo (centro).
	_box = Control.new()
	_box.position = Vector2(80, 0)
	_box.size = Vector2(size.x - 80, 82)
	_box.draw.connect(_draw_box)
	add_child(_box)
	_name = _label(Vector2(8, 3), 12, RetroTheme.AMBER)
	_tag = _label(Vector2(150, 3), 10, RetroTheme.SPACE)
	_text = _label(Vector2(8, 20), 12, RetroTheme.WHITE)
	_text.size = Vector2(_box.size.x - 16, 50)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(Vector2(_box.size.x - 70, 68), 9, RetroTheme.PHOSPHOR_DIM)
	_hint.text = "ENTER >>"
	_transit = _label(Vector2(8, 32), 12, RetroTheme.PHOSPHOR)

	# Ruido sobre la caja (shader ligero).
	var noise := ColorRect.new()
	noise.position = Vector2.ZERO
	noise.size = _box.size
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise_mat = ShaderMaterial.new()
	_noise_mat.shader = preload("res://assets/shaders/radio_noise.gdshader")
	noise.material = _noise_mat
	_box.add_child(noise)

	_blip = AudioStreamPlayer.new()
	_blip.stream = _make_wave(0.03, false)
	_blip.volume_db = -16.0
	add_child(_blip)
	_crackle = AudioStreamPlayer.new()
	_crackle.stream = _make_wave(0.4, true)
	_crackle.volume_db = -14.0
	add_child(_crackle)


func _label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


# -------------------------------------------------------------------------
# Flujo
# -------------------------------------------------------------------------
func _idle() -> void:
	_phase = 0
	_name.text = ""
	_tag.text = ""
	_text.text = "— CANAL ABIERTO —"
	_text.visible_characters = -1
	_text.add_theme_color_override("font_color", RetroTheme.PHOSPHOR_DIM)
	_transit.text = ""
	_hint.visible = false
	_portrait_code = ""
	_portrait_color = Color("#1a2a2a")
	_portrait_tex.texture = null
	_noise_mat.set_shader_parameter("intensity", 0.0)
	_set_robot_speaking(false)
	_portrait.queue_redraw()
	_box.queue_redraw()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_active = false
		_idle()
		finished.emit()
		return
	var line: Dictionary = _lines[_index]
	var key := String(line.get("speaker", "CIENTIFICO"))
	var sp: Dictionary = speakers.get(key, {})
	_radio = bool(sp.get("radio", false))
	var col := Color(String(sp.get("color", "#ffb347")))
	_name.text = String(sp.get("name", key))
	_name.add_theme_color_override("font_color", col)
	var mode := String(line.get("mode", ""))
	_tag.text = (" %s " % mode) if _radio and mode != "" else ""
	_tag.position.x = 8 + _name.get_minimum_size().x + 8
	_portrait_color = col
	_set_portrait(String(sp.get("portrait", key.to_lower())), key)
	_full = String(line.get("text", ""))
	_text.add_theme_color_override("font_color", RetroTheme.WHITE)
	_text.text = _full
	_text.visible_characters = 0
	_chars = 0.0
	_reveal_t = 0.0
	_hint.visible = false
	_accept_after = _clock + INPUT_GRACE
	if _radio:
		_phase = 1
		_transit_left = _rng.randf_range(1.0, 1.5)
		_crackle.play()
		_set_robot_speaking(true)
	else:
		_phase = 2
		_transit.text = ""
		_set_robot_speaking(false)
	_noise_mat.set_shader_parameter("intensity", 0.22 if _radio else 0.0)
	_box.queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	match _phase:
		1:
			_transit_left -= delta
			var dots := int(_clock * 4.0) % 4
			_transit.text = transit_text + ".".repeat(dots)
			if _transit_left <= 0.0:
				_transit.text = ""
				_phase = 2
		2:
			_reveal_t += delta
			var before := int(_chars)
			_chars = minf(_chars + delta * TYPE_SPEED, _full.length())
			var n := int(_chars)
			if n > before and not _radio and n % 2 == 0 and _full[n - 1] != " ":
				_blip.pitch_scale = _rng.randf_range(0.9, 1.15)
				_blip.play()
			_text.text = _compose()
			_text.visible_characters = n
			if n >= _full.length() and _glitch_done():
				_finish_line()


## Texto con las primeras letras "con interferencia" que se resuelven poco a poco.
func _compose() -> String:
	if not _radio:
		return _full
	var out := ""
	for i in _full.length():
		var ch := _full[i]
		var resolve_at := 0.25 + i * 0.06
		if i < GLITCH_CHARS and _reveal_t < resolve_at and ch != " ":
			out += GLITCH_SYMBOLS[_rng.randi() % GLITCH_SYMBOLS.length()]
		else:
			out += ch
	return out


func _glitch_done() -> bool:
	return not _radio or _reveal_t >= 0.25 + GLITCH_CHARS * 0.06


func _finish_line() -> void:
	_phase = 3
	_text.text = _full
	_text.visible_characters = -1
	_transit.text = ""
	_hint.visible = true
	_noise_mat.set_shader_parameter("intensity", 0.08 if _radio else 0.0)
	_set_robot_speaking(false)


func _set_robot_speaking(on: bool) -> void:
	if on != _robot_speaking:
		_robot_speaking = on
		robot_speaking_changed.emit(on)


func _input(event: InputEvent) -> void:
	if not _active or get_tree().paused:
		return
	var pressed: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _clock < _accept_after:
		return
	match _phase:
		1:
			_transit_left = 0.0
		2:
			_finish_line()
		3:
			_next()


# -------------------------------------------------------------------------
# Dibujo
# -------------------------------------------------------------------------
func _set_portrait(portrait: String, key: String) -> void:
	var path := "res://assets/sprites/portraits/%s.png" % portrait
	if ResourceLoader.exists(path):
		_portrait_tex.texture = load(path)
		_portrait_code = ""
	else:
		# PLACEHOLDER: iniciales. Reemplazar con assets/sprites/portraits/<portrait>.png
		_portrait_tex.texture = null
		_portrait_code = "CM" if key == "CIENTIFICO" else key.substr(0, 2)
	_portrait.queue_redraw()


func _draw_portrait() -> void:
	var r := Rect2(Vector2.ZERO, _portrait.size)
	_portrait.draw_rect(r, Color(0.02, 0.03, 0.05, 0.95))
	if _portrait_tex.texture == null:
		_portrait.draw_rect(r.grow(-4), _portrait_color.darkened(0.35))
		if _portrait_code != "":
			_portrait.draw_string(ThemeDB.fallback_font, Vector2(0, 44), _portrait_code, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, RetroTheme.SPACE)
	var y := 4.0
	while y < r.size.y - 4:
		_portrait.draw_rect(Rect2(4, y, r.size.x - 8, 1), Color(0, 0, 0, 0.18))
		y += 2.0
	_portrait.draw_rect(r, RetroTheme.PHOSPHOR, false, 1.0)


func _draw_box() -> void:
	var r := Rect2(Vector2.ZERO, _box.size)
	_box.draw_rect(r, Color(0.01, 0.04, 0.03, 0.92))
	_box.draw_rect(r, RetroTheme.PHOSPHOR, false, 1.0)
	if _tag.text != "":
		# Fondo de color del robot detrás de la etiqueta TX / RX.
		var tag_size := _tag.get_minimum_size()
		_box.draw_rect(Rect2(_tag.position + Vector2(0, 1), tag_size), _portrait_color)


## Sonidos placeholder generados por código (sin audio con copyright).
## crackle = ráfaga de ruido con chasquidos; si no, "blip" de onda cuadrada.
func _make_wave(seconds: float, crackle: bool) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2004
	for i in samples:
		var env := 1.0 - float(i) / samples
		var v := 0.0
		if crackle:
			v = rng.randf_range(-1.0, 1.0) * 30.0 * env
			if rng.randf() < 0.01:
				v = rng.randf_range(-1.0, 1.0) * 90.0
		else:
			v = (40.0 if int(i * 1100.0 / rate * 2.0) % 2 == 0 else -40.0) * env
		data[i] = int(v) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
