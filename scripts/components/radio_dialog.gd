class_name RadioDialog
extends Control
## Caja de diálogo tipo radio, reutilizable en la intro y en todas las misiones.
##
## - Encabezado "TRANSMISIÓN ENTRANTE", retrato del equipo, nombre de quien habla.
## - Ráfaga de estática al cambiar de hablante y efecto máquina de escribir con "bip".
## - ENTER / ESPACIO / clic: la primera pulsación completa el texto, la segunda avanza.
## - Los textos largos se dividen en páginas automáticamente (frases cortas, fáciles de leer).
##
## Uso:   await radio.play(lineas)      # lineas = [{speaker, text, portrait}, ...]
##        await radio.play_file("res://data/dialogos/mision_1.json", "f0_intro")
##
## Retratos: si existe res://assets/sprites/portraits/<portrait>.png se usa esa imagen;
## si no, se dibuja un placeholder pixel (iniciales sobre un color).

signal finished
signal line_started(index: int)

const TYPE_SPEED := 40.0        # caracteres por segundo
const STATIC_TIME := 0.35       # segundos de estática al cambiar de hablante
const PAGE_CHARS := 170         # máximo de caracteres por página
const INPUT_GRACE := 0.25       # ignora pulsaciones justo al aparecer (evita saltos accidentales)

const PORTRAIT_COLORS := {
	"eagle": Color("#c8962e"), "houston": Color("#2e6bd1"), "easep": Color("#3d6fd6"),
	"lrrr": Color("#9aa0b4"), "neil": Color("#e8ecf4"), "buzz": Color("#d8dce8"),
	"pioneer10": Color("#e0b040"),
	"pioneer11": Color("#d0902a"), "spirit": Color("#c0532a"), "opportunity": Color("#cf7440"),
	"gemelas": Color("#b5532a"), "senal": Color("#39ff7a"), "cientifico": Color("#c8963e"),
}

var _pages: Array = []
var _index := -1
var _active := false
var _accept_after := 0.0
var _static_left := 0.0
var _clock := 0.0
var _last_speaker := ""
var _type_tween: Tween
var _last_chars := 0

var _panel: PanelContainer
var _header: Label
var _speaker: Label
var _text: Label
var _hint: Label
var _portrait_box: Control
var _portrait_tex: TextureRect
var _portrait_code: Label
var _portrait_key := ""
var _static_layer: Control
var _blip: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


func is_active() -> bool:
	return _active


## Reproduce una lista de líneas y espera a que el jugador termine de leerlas.
func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_pages = _paginate(lines)
	_index = -1
	_active = true
	_last_speaker = ""
	show()
	_next()
	await finished


func play_file(path: String, key: String) -> void:
	var data: Dictionary = GameManager.load_json(path)
	await play(data.get(key, []))


# -------------------------------------------------------------------------
# Construcción de la interfaz (por código para poder usarlo con RadioDialog.new())
# -------------------------------------------------------------------------
func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 12
	_panel.offset_right = -12
	_panel.offset_top = -112
	_panel.offset_bottom = -8
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	# Retrato (placeholder o sprite).
	_portrait_box = Control.new()
	_portrait_box.custom_minimum_size = Vector2(64, 64)
	_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_box.draw.connect(_draw_portrait)
	row.add_child(_portrait_box)
	_portrait_tex = TextureRect.new()
	_portrait_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_box.add_child(_portrait_tex)
	_portrait_code = Label.new()
	_portrait_code.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_code.add_theme_font_size_override("font_size", 18)
	_portrait_code.add_theme_color_override("font_color", RetroTheme.SPACE)
	_portrait_box.add_child(_portrait_code)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	_header = Label.new()
	_header.text = tr("((·)) TRANSMISIÓN ENTRANTE")
	_header.add_theme_font_size_override("font_size", 10)
	_header.add_theme_color_override("font_color", Color("#ff5a4a"))
	top.add_child(_header)
	_speaker = Label.new()
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speaker.add_theme_font_size_override("font_size", 12)
	_speaker.add_theme_color_override("font_color", RetroTheme.AMBER)
	top.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", RetroTheme.WHITE)
	col.add_child(_text)

	_hint = Label.new()
	_hint.text = tr("ENTER / CLIC >>")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", RetroTheme.PHOSPHOR_DIM)
	col.add_child(_hint)

	# Capa de estática encima del panel.
	_static_layer = Control.new()
	_static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_static_layer.draw.connect(_draw_static)
	_panel.add_child(_static_layer)

	_blip = AudioStreamPlayer.new()
	_blip.stream = _make_blip()
	_blip.volume_db = -16.0
	add_child(_blip)


# -------------------------------------------------------------------------
# Flujo de líneas
# -------------------------------------------------------------------------
func _paginate(lines: Array) -> Array:
	var out: Array = []
	for line in lines:
		var text: String = line.get("text", "")
		var page := ""
		# Corta por frases para que cada página sea corta y legible.
		var sentences := _split_sentences(text)
		for s in sentences:
			if page.length() > 0 and page.length() + s.length() + 1 > PAGE_CHARS:
				out.append({"speaker": line.get("speaker", ""), "portrait": line.get("portrait", ""), "text": page})
				page = s
			else:
				page = s if page.is_empty() else page + " " + s
		if not page.is_empty():
			out.append({"speaker": line.get("speaker", ""), "portrait": line.get("portrait", ""), "text": page})
	return out


func _split_sentences(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var current := ""
	for i in text.length():
		var ch := text[i]
		current += ch
		var next_is_space := i + 1 >= text.length() or text[i + 1] == " "
		if (ch == "." or ch == "!" or ch == "?") and next_is_space and current.strip_edges().length() > 12:
			result.append(current.strip_edges())
			current = ""
	if not current.strip_edges().is_empty():
		result.append(current.strip_edges())
	return result


func _next() -> void:
	_index += 1
	if _index >= _pages.size():
		_active = false
		hide()
		finished.emit()
		return
	var page: Dictionary = _pages[_index]
	var speaker: String = page["speaker"]
	_speaker.text = speaker
	_set_portrait(page["portrait"])
	_text.text = page["text"]
	_text.visible_characters = 0
	_last_chars = 0
	_hint.modulate.a = 0.0
	_accept_after = _clock + INPUT_GRACE

	var delay := 0.0
	if speaker != _last_speaker:
		_static_left = STATIC_TIME  # Ráfaga de estática: "sintonizando" a otro emisor.
		delay = STATIC_TIME
	_last_speaker = speaker

	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	var n := _text.text.length()
	_type_tween = create_tween()
	_type_tween.tween_interval(delay)
	_type_tween.tween_method(_set_chars, 0, n, n / TYPE_SPEED)
	_type_tween.tween_callback(func() -> void: _hint.modulate.a = 1.0)
	line_started.emit(_index)


func _set_chars(n: int) -> void:
	_text.visible_characters = n
	if n > _last_chars and n % 2 == 0 and n <= _text.text.length() and _text.text[n - 1] != " ":
		_blip.pitch_scale = _rng.randf_range(0.9, 1.15)
		_blip.play()
	_last_chars = n


func _is_typing() -> bool:
	return _text.visible_characters >= 0 and _text.visible_characters < _text.text.length()


func _process(delta: float) -> void:
	_clock += delta
	if not _active:
		return
	# Encabezado parpadeante y estática.
	_header.modulate.a = 1.0 if fmod(_clock, 0.8) < 0.55 else 0.35
	if _static_left > 0.0:
		_static_left -= delta
	_static_layer.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var pressed: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not MissionHUD.hover_ui)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _clock < _accept_after:
		return
	if _is_typing() or _static_left > 0.0:
		# Primera pulsación: completa el texto al instante.
		if _type_tween and _type_tween.is_valid():
			_type_tween.kill()
		_static_left = 0.0
		_text.visible_characters = -1
		_hint.modulate.a = 1.0
	else:
		_next()


# -------------------------------------------------------------------------
# Retrato y estática
# -------------------------------------------------------------------------
func _set_portrait(key: String) -> void:
	_portrait_key = key
	var path := "res://assets/sprites/portraits/%s.png" % key
	if ResourceLoader.exists(path):
		_portrait_tex.texture = load(path)
		_portrait_code.text = ""
	else:
		# PLACEHOLDER: iniciales sobre un color. Reemplazar con assets/sprites/portraits/<key>.png
		_portrait_tex.texture = null
		_portrait_code.text = "CM" if key == "cientifico" else key.substr(0, 2).to_upper()
	_portrait_box.queue_redraw()


func _draw_portrait() -> void:
	var r := Rect2(Vector2.ZERO, _portrait_box.size)
	var col: Color = PORTRAIT_COLORS.get(_portrait_key, RetroTheme.PHOSPHOR_DIM)
	_portrait_box.draw_rect(r, RetroTheme.SPACE)
	if _portrait_tex.texture == null:
		_portrait_box.draw_rect(r.grow(-4), col)
	# Líneas de escaneo y marco.
	var y := 4.0
	while y < r.size.y - 4:
		_portrait_box.draw_rect(Rect2(4, y, r.size.x - 8, 1), Color(0, 0, 0, 0.18))
		y += 2.0
	_portrait_box.draw_rect(r, RetroTheme.PHOSPHOR, false, 1.0)


func _draw_static() -> void:
	if _static_left <= 0.0:
		return
	var s := _static_layer.size
	var amount := int(500 * (_static_left / STATIC_TIME))
	for i in amount:
		var g := _rng.randf_range(0.3, 1.0)
		_static_layer.draw_rect(Rect2(floorf(_rng.randf() * s.x), floorf(_rng.randf() * s.y), 2, 1), Color(g, g, g, 0.8))


## "Bip" de máquina de escribir generado por código (onda cuadrada de 30 ms).
func _make_blip() -> AudioStreamWAV:
	var rate := 22050
	var samples := int(rate * 0.03)
	var data := PackedByteArray()
	data.resize(samples)
	for i in samples:
		var on := int(i * 900.0 / rate * 2.0) % 2 == 0
		var env := 1.0 - float(i) / samples
		data[i] = int((40.0 if on else -40.0) * env) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
