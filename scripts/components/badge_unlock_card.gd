class_name BadgeUnlockCard
extends Control
## Aviso a pantalla completa cuando una misión completa su insignia: insignia dorada,
## "FICHA TÉCNICA DESBLOQUEADA" y dos botones: VER FICHA (abre BadgeSheet aquí mismo) y CONTINUAR.
## Pausa el juego mientras está abierto.  Uso:  await BadgeUnlockCard.present(self, insignia)

signal finished

var badge: Dictionary = {}
var _t := 0.0
var _box: VBoxContainer
var _btn_view: Button
var _sheet: BadgeSheet
var _paused_before := false


static func present(parent: Node, b: Dictionary) -> void:
	var c := BadgeUnlockCard.new()
	c.badge = b
	parent.add_child(c)
	await c.finished


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 95
	_paused_before = get_tree().paused
	get_tree().paused = true
	_box = VBoxContainer.new()
	_box.position = Vector2(150, 206)
	_box.custom_minimum_size = Vector2(340, 0)
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	_box.add_child(_label(String(badge.get("name", "")), 14, RetroTheme.WHITE))
	_box.add_child(_label(tr("FICHA TÉCNICA DESBLOQUEADA"), 11, RetroTheme.PHOSPHOR))
	_box.add_child(_label(tr("La encontrarás en ARCHIVO CIENTÍFICO > CUADERNO DE INSIGNIAS."), 9, RetroTheme.PHOSPHOR_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	_btn_view = Button.new()
	_btn_view.text = tr("> VER FICHA")
	_btn_view.pressed.connect(_view)
	row.add_child(_btn_view)
	var cont := Button.new()
	cont.text = tr("CONTINUAR")
	cont.pressed.connect(_close)
	row.add_child(cont)
	_btn_view.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0.02, 0.8))
	var r := Rect2(140, 30, 360, 300)
	draw_rect(r, Color(0.02, 0.04, 0.1, 0.97))
	draw_rect(r, BadgeArt.GOLD, false, 1.0)
	var font := ThemeDB.fallback_font
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 24), tr("¡INSIGNIA COMPLETA!"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color(BadgeArt.GOLD, pulse))
	# Rayos que giran detrás de la insignia.
	var ctr := Vector2(320, 118)
	for i in 12:
		var a := _t * 0.4 + i * TAU / 12.0
		draw_line(ctr + Vector2.from_angle(a) * 60.0, ctr + Vector2.from_angle(a) * 76.0, Color(BadgeArt.GOLD, 0.35), 2.0)
	BadgeArt.draw_badge(self, ctr, 54.0, badge, range(int(badge.get("pieces", 6))), _t)


func _view() -> void:
	if _sheet:
		return
	_box.hide()
	_sheet = BadgeSheet.open_for(self, badge)
	_sheet.closed.connect(func() -> void:
		_sheet = null
		_box.show()
		_btn_view.grab_focus())


func _input(event: InputEvent) -> void:
	if _sheet:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	set_process_input(false)
	get_tree().paused = _paused_before
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	finished.emit()
	queue_free()
