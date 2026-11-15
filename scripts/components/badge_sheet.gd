class_name BadgeSheet
extends Control
## Ficha técnica de un artefacto: se desbloquea al completar su insignia. Página de libreta con la
## insignia, los datos (lanzamiento, masa, energía...), la historia y dónde está hoy.
## Los textos vienen del campo "sheet" de data/badges.json. ESC o < VOLVER la cierran (`closed`).
## Se abre desde el Cuaderno de insignias y desde el aviso de insignia completa de las misiones.

signal closed

const BOOK := Rect2(24, 14, 592, 332)
const TEXT_RECT := Rect2(196, 44, 404, 262)

var badge: Dictionary = {}
var _t := 0.0
var _text: RichTextLabel
var _btn_back: Button


static func open_for(parent: Node, b: Dictionary) -> BadgeSheet:
	var s := BadgeSheet.new()
	s.badge = b
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 2
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.position = TEXT_RECT.position
	_text.size = TEXT_RECT.size
	_text.scroll_active = true
	_text.focus_mode = Control.FOCUS_ALL
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.add_theme_font_size_override("normal_font_size", 10)
	_text.add_theme_font_size_override("bold_font_size", 10)
	_text.add_theme_color_override("default_color", RetroTheme.WHITE)
	_text.add_theme_constant_override("table_h_separation", 8)
	_text.add_theme_constant_override("table_v_separation", 3)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 4
	pad.content_margin_right = 6
	_text.add_theme_stylebox_override("normal", pad)
	_text.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(_text)
	_text.text = _bbcode()
	var row := HBoxContainer.new()
	row.position = Vector2(BOOK.end.x - 236, BOOK.end.y - 28)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_btn_back = Button.new()
	_btn_back.text = tr("< VOLVER")
	_btn_back.add_theme_font_size_override("font_size", 10)
	_btn_back.pressed.connect(_close)
	row.add_child(_btn_back)
	var link := Button.new()
	link.text = tr("> ENLACE NASA")
	link.add_theme_font_size_override("font_size", 10)
	link.pressed.connect(func() -> void: OS.shell_open(String(badge.get("link", ""))))
	row.add_child(link)
	_text.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _bbcode() -> String:
	var sheet: Dictionary = badge.get("sheet", {})
	var amber := RetroTheme.AMBER.to_html(false)
	var green := RetroTheme.PHOSPHOR.to_html(false)
	var s := "[color=#%s]%s[/color]\n[table=2]" % [green, tr("DATOS")]
	for spec in sheet.get("specs", []):
		s += "[cell][color=#%s]%s[/color][/cell][cell]%s[/cell]" % [amber, spec[0], spec[1]]
	s += "[/table]\n\n[color=#%s]%s[/color]\n" % [green, tr("HISTORIA")]
	for para in sheet.get("history", []):
		s += "%s\n\n" % para
	s += "[color=#%s]%s[/color]\n%s" % [green, tr("DÓNDE ESTÁ HOY"), sheet.get("today", "")]
	return s


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0.02, 0.8))
	draw_rect(Rect2(BOOK.position + Vector2(4, 4), BOOK.size), Color(0, 0, 0, 0.6))
	draw_rect(BOOK, Color(0.02, 0.05, 0.11, 0.99))
	for y in range(int(BOOK.position.y) + 22, int(BOOK.end.y) - 4, 14):
		draw_line(Vector2(BOOK.position.x + 24, y), Vector2(BOOK.end.x - 6, y), Color(RetroTheme.PHOSPHOR, 0.05), 1.0)
	draw_rect(BOOK, BadgeArt.GOLD, false, 1.0)
	draw_rect(Rect2(BOOK.position, Vector2(18, BOOK.size.y)), Color(0.01, 0.02, 0.05))
	for y in range(int(BOOK.position.y) + 12, int(BOOK.end.y) - 6, 16):
		draw_arc(Vector2(BOOK.position.x + 9, y), 5.0, PI * 0.5, PI * 1.9, 10, RetroTheme.WHITE.darkened(0.3), 2.0)
		draw_circle(Vector2(BOOK.position.x + 17, y), 2.0, Color(0, 0, 0))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(BOOK.position.x + 40, BOOK.position.y + 22), tr("FICHA TÉCNICA · %s") % String(badge.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, BOOK.size.x - 56, 13, RetroTheme.AMBER)
	draw_line(Vector2(BOOK.position.x + 40, BOOK.position.y + 27), Vector2(BOOK.end.x - 16, BOOK.position.y + 27), Color(BadgeArt.GOLD, 0.5), 1.0)
	# Insignia completa y nombre a la izquierda.
	var ctr := Vector2(BOOK.position.x + 92, BOOK.position.y + 100)
	BadgeArt.draw_badge(self, ctr, 50.0, badge, range(int(badge.get("pieces", 6))), _t)
	var site := GameManager.find_site(String(badge.get("site", "")))
	if not site.is_empty():
		draw_multiline_string(font, Vector2(ctr.x - 70, ctr.y + 70), String(site.get("place", "")), HORIZONTAL_ALIGNMENT_CENTER, 140, 9, 2, RetroTheme.WHITE)
		draw_string(font, Vector2(ctr.x - 70, ctr.y + 96), String(site.get("year", "")), HORIZONTAL_ALIGNMENT_CENTER, 140, 9, RetroTheme.PHOSPHOR_DIM)
	draw_string(font, Vector2(ctr.x - 70, ctr.y + 114), tr("COMPLETA"), HORIZONTAL_ALIGNMENT_CENTER, 140, 10, BadgeArt.GOLD)
	draw_line(Vector2(TEXT_RECT.position.x - 8, TEXT_RECT.position.y), Vector2(TEXT_RECT.position.x - 8, TEXT_RECT.end.y), Color(RetroTheme.PHOSPHOR, 0.3), 1.0)
	draw_string(font, Vector2(BOOK.position.x + 40, BOOK.end.y - 12), tr("RUEDA / FLECHAS: DESPLAZAR  ·  ESC: VOLVER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RetroTheme.PHOSPHOR_DIM)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventKey and event.pressed:
		# Las flechas desplazan el texto aunque el foco esté en un botón.
		var step := 0
		if event.is_action_pressed("ui_down"):
			step = 1
		elif event.is_action_pressed("ui_up"):
			step = -1
		if step != 0:
			get_viewport().set_input_as_handled()
			var sb := _text.get_v_scroll_bar()
			sb.value += step * 24.0


func _close() -> void:
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	closed.emit()
	queue_free()
