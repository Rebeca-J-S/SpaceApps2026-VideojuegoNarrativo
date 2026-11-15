class_name TutorialCard
extends Control
## Tarjeta "CÓMO SE JUEGA" que aparece antes de cada minijuego: objetivo, teclas y reglas.
## Pausa el juego mientras está en pantalla; ENTER, ESPACIO, clic o ESC la cierran.
## Uso (dentro de una misión):  await TutorialCard.present(self, tarjeta, "FASE 1 · ...")
## La misma tarjeta se ve en MENÚ (ESC) > AYUDA con TutorialCard.build_content().
## Los datos vienen de data/guia.json (GameManager.get_tutorial).

signal finished

const PANEL_W := 540.0

var _card: Dictionary = {}
var _phase := ""
var _panel: PanelContainer
var _ready_at := 0.0
var _paused_before := false


## Muestra la tarjeta y espera a que el jugador la cierre. Si la tarjeta está vacía, no hace nada.
static func present(parent: Node, card: Dictionary, phase_title: String = "") -> void:
	if card.is_empty():
		return
	var tc := TutorialCard.new()
	tc._card = card
	tc._phase = phase_title
	parent.add_child(tc)
	await tc.finished


## Contenido de la tarjeta (sin marco): lo usan la tarjeta y la ayuda del menú de pausa.
static func build_content(card: Dictionary, width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_text(String(card.get("title", "")), 14, RetroTheme.AMBER, width))
	box.add_child(_section(tr_s("OBJETIVO")))
	box.add_child(_text(String(card.get("goal", "")), 10, RetroTheme.WHITE, width))
	var keys: Array = card.get("keys", [])
	if not keys.is_empty():
		box.add_child(_section(tr_s("CONTROLES")))
		for k in keys:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.add_child(_keycap(String(k[0])))
			var desc := _text(String(k[1]), 10, RetroTheme.WHITE, width - 156.0)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(desc)
			box.add_child(row)
	var rules: Array = card.get("rules", [])
	if not rules.is_empty():
		box.add_child(_section(tr_s("REGLAS")))
		for r in rules:
			box.add_child(_text("· " + String(r), 10, Color(1, 1, 1, 0.88), width))
	return box


## tr() desde una función estática (el catálogo es global).
static func tr_s(text: String) -> String:
	return TranslationServer.translate(text)


static func _text(text: String, font_size: int, color: Color, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # ya viene traducido del JSON
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", RetroTheme.PHOSPHOR)
	return l


## Tecla dibujada como una tapa de teclado.
static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.1, 0.95)
	sb.border_color = Color("#80f2ff")
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", sb)
	cap.custom_minimum_size = Vector2(140, 0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", RetroTheme.WHITE)
	cap.add_child(l)
	return cap


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 95
	_paused_before = get_tree().paused
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var head := _text(tr("CÓMO SE JUEGA") + ("  ·  " + _phase if _phase != "" else ""), 9, RetroTheme.PHOSPHOR_DIM, PANEL_W - 16.0)
	box.add_child(head)
	box.add_child(build_content(_card, PANEL_W - 16.0))
	box.add_child(HSeparator.new())
	var go := _text(tr("ENTER / CLIC: ¡A JUGAR!"), 11, RetroTheme.AMBER, PANEL_W - 16.0)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(go)
	var again := _text(tr("Vuelve a verla en MENÚ (ESC) > AYUDA"), 8, RetroTheme.PHOSPHOR_DIM, PANEL_W - 16.0)
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(again)
	# Centrada en cuanto el panel conoce su tamaño, con un pequeño "encendido".
	modulate.a = 0.0
	await get_tree().process_frame
	_panel.reset_size()
	_panel.position = ((get_viewport_rect().size - _panel.size) * 0.5).round()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_ready_at = Time.get_ticks_msec() / 1000.0 + 0.35   # evita cerrarla con el mismo clic que la abrió


func _input(event: InputEvent) -> void:
	var accept: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()   # mientras está la tarjeta, la misión no recibe nada
	if accept and Time.get_ticks_msec() / 1000.0 >= _ready_at and _ready_at > 0.0:
		_close()


func _close() -> void:
	set_process_input(false)
	get_tree().paused = _paused_before
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	finished.emit()
	queue_free()
