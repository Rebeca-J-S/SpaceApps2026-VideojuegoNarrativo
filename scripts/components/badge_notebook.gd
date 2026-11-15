class_name BadgeNotebook
extends Control
## Cuaderno de insignias (se abre desde el Archivo científico). Una libreta con espiral y renglones:
## las insignias de cada cuerpo (Luna, Marte, espacio profundo), completas, a medias o sin piezas.
## Clic / ENTER en una insignia abre su ficha: insignia grande, estado, descripción y enlace NASA.
## Con la insignia completa, el botón FICHA TÉCNICA abre la ficha histórica y técnica (BadgeSheet).
## ESC: vuelve de la ficha a la libreta, o cierra la libreta. Emite `closed` al cerrarse.

signal closed

const BOOK := Rect2(24, 14, 592, 332)
const ROWS := [["moon", "LUNA"], ["mars", "MARTE"], ["deep", "ESPACIO PROFUNDO"]]
const ROW_Y := [100.0, 184.0, 268.0]
const COL_X0 := 172.0
const COL_W := 92.0
const R_SMALL := 24.0
const R_BIG := 72.0

var _badges: Array = []
var _cells: Array = []          # [{center, badge}]
var _sel := 0
var _detail := -1               # índice abierto en la ficha (-1 = libreta)
var _t := 0.0
var _detail_box: VBoxContainer
var _detail_title: Label
var _detail_meta: Label
var _detail_state: Label
var _detail_desc: Label
var _detail_link: Label
var _btn_open: Button
var _btn_sheet: Button
var _sheet: BadgeSheet
var _btn_back: Button
var _btn_close: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_badges = GameManager.get_badges()
	for row in ROWS.size():
		var x := COL_X0
		for b in _badges:
			if String(b["body"]) != ROWS[row][0]:
				continue
			_cells.append({"center": Vector2(x, ROW_Y[row]), "badge": b})
			x += COL_W
	_build_detail()
	_btn_close = _button(tr("[ESC] CERRAR"), Vector2(BOOK.end.x - 96, BOOK.end.y - 26), _close)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _build_detail() -> void:
	_detail_box = VBoxContainer.new()
	_detail_box.position = Vector2(300, 46)
	_detail_box.custom_minimum_size = Vector2(296, 0)
	_detail_box.add_theme_constant_override("separation", 5)
	add_child(_detail_box)
	_detail_title = _detail_label(15, RetroTheme.AMBER)
	_detail_meta = _detail_label(10, RetroTheme.WHITE)
	_detail_state = _detail_label(10, RetroTheme.PHOSPHOR)
	_detail_desc = _detail_label(11, RetroTheme.WHITE)
	_detail_label(9, RetroTheme.AMBER).text = tr("REFERENCIA NASA")
	_detail_link = _detail_label(8, Color("#80f2ff"))
	var row := HBoxContainer.new()
	_detail_box.add_child(row)
	_btn_back = Button.new()
	_btn_back.text = tr("< VOLVER")
	_btn_back.pressed.connect(_back)
	row.add_child(_btn_back)
	_btn_open = Button.new()
	_btn_open.text = tr("> ABRIR ENLACE")
	_btn_open.pressed.connect(_open_link)
	row.add_child(_btn_open)
	# Ficha técnica: solo con la insignia completa.
	_btn_sheet = Button.new()
	_btn_sheet.pressed.connect(_open_sheet)
	row.add_child(_btn_sheet)
	_detail_box.hide()


func _detail_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(296, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_detail_box.add_child(l)
	return l


## Reparte un texto en líneas que quepan en `width` (como máximo `max_lines`).
func _wrap(font: Font, text: String, fsize: int, width: float, max_lines: int = 2) -> Array[String]:
	var lines: Array[String] = []
	var cur := ""
	for w in text.split(" "):
		var test := w if cur == "" else cur + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x <= width or cur == "":
			cur = test
		else:
			lines.append(cur)
			cur = w
	if cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		var rest := " ".join(lines.slice(max_lines - 1))
		lines = lines.slice(0, max_lines - 1)
		lines.append(rest)
	return lines


func _draw_wrapped(font: Font, text: String, pos: Vector2, width: float, fsize: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var y := pos.y
	for line in _wrap(font, text, fsize, width):
		draw_string(font, Vector2(pos.x, y), line, align, width, fsize, col)
		y += fsize + 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# -------------------------------------------------------------------------
# Dibujo: libreta, renglones, espiral, insignias
# -------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0.02, 0.75))
	draw_rect(Rect2(BOOK.position + Vector2(4, 4), BOOK.size), Color(0, 0, 0, 0.6))     # sombra
	draw_rect(BOOK, Color(0.02, 0.05, 0.11, 0.98))
	# Renglones y margen, como una libreta.
	for y in range(int(BOOK.position.y) + 22, int(BOOK.end.y) - 4, 14):
		draw_line(Vector2(BOOK.position.x + 24, y), Vector2(BOOK.end.x - 6, y), Color(RetroTheme.PHOSPHOR, 0.07), 1.0)
	draw_line(Vector2(BOOK.position.x + 40, BOOK.position.y + 4), Vector2(BOOK.position.x + 40, BOOK.end.y - 4), Color(RetroTheme.AMBER, 0.25), 1.0)
	draw_rect(BOOK, RetroTheme.PHOSPHOR, false, 1.0)
	# Espiral.
	draw_rect(Rect2(BOOK.position, Vector2(18, BOOK.size.y)), Color(0.01, 0.02, 0.05))
	for y in range(int(BOOK.position.y) + 12, int(BOOK.end.y) - 6, 16):
		draw_arc(Vector2(BOOK.position.x + 9, y), 5.0, PI * 0.5, PI * 1.9, 10, RetroTheme.WHITE.darkened(0.3), 2.0)
		draw_circle(Vector2(BOOK.position.x + 17, y), 2.0, Color(0, 0, 0))
	var font := ThemeDB.fallback_font
	if _detail >= 0:
		_draw_detail(font)
		return
	draw_string(font, Vector2(BOOK.position.x + 52, BOOK.position.y + 24), tr("CUADERNO DE INSIGNIAS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RetroTheme.AMBER)
	var done := 0
	var got_total := 0
	var all_total := 0
	for b in _badges:
		var g := GameManager.badge_pieces(String(b["id"])).size()
		got_total += mini(g, int(b["pieces"]))
		all_total += int(b["pieces"])
		if g >= int(b["pieces"]):
			done += 1
	draw_string(font, Vector2(BOOK.position.x + 52, BOOK.position.y + 40), tr("%d / %d INSIGNIAS COMPLETAS  ·  %d / %d PIEZAS") % [done, _badges.size(), got_total, all_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.PHOSPHOR)
	for row in ROWS.size():
		_draw_wrapped(font, tr(ROWS[row][1]), Vector2(BOOK.position.x + 52, ROW_Y[row]), 70.0, 10, RetroTheme.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for i in _cells.size():
		var cell: Dictionary = _cells[i]
		var b: Dictionary = cell["badge"]
		var ctr: Vector2 = cell["center"]
		if i == _sel:
			draw_rect(Rect2(ctr - Vector2(COL_W * 0.5 - 2, R_SMALL + 4), Vector2(COL_W - 4, R_SMALL * 2 + 32)), Color(RetroTheme.AMBER, 0.6 + 0.3 * sin(_t * 5.0)), false, 1.0)
		var got := GameManager.badge_pieces(String(b["id"]))
		BadgeArt.draw_badge(self, ctr, R_SMALL, b, got, _t)
		var ncol := RetroTheme.AMBER if i == _sel else (RetroTheme.WHITE if not got.is_empty() else RetroTheme.PHOSPHOR_DIM)
		_draw_wrapped(font, String(b["name"]), Vector2(ctr.x - COL_W * 0.5 + 2, ctr.y + R_SMALL + 11), COL_W - 4, 8, ncol)
	draw_string(font, Vector2(BOOK.position.x + 52, BOOK.end.y - 12), tr("CLIC O ENTER: VER INSIGNIA  ·  FLECHAS: ELEGIR  ·  ESC: CERRAR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RetroTheme.PHOSPHOR_DIM)


func _draw_detail(font: Font) -> void:
	var b: Dictionary = _cells[_detail]["badge"]
	var got := GameManager.badge_pieces(String(b["id"]))
	var ctr := Vector2(BOOK.position.x + 150, BOOK.position.y + 150)
	BadgeArt.draw_badge(self, ctr, R_BIG, b, got, _t)
	draw_string(font, Vector2(ctr.x - 100, ctr.y + R_BIG + 22), tr("PIEZAS: %d / %d") % [mini(got.size(), int(b["pieces"])), int(b["pieces"])], HORIZONTAL_ALIGNMENT_CENTER, 200, 11, RetroTheme.AMBER)
	draw_line(Vector2(BOOK.position.x + 268, BOOK.position.y + 16), Vector2(BOOK.position.x + 268, BOOK.end.y - 16), Color(RetroTheme.PHOSPHOR, 0.3), 1.0)


# -------------------------------------------------------------------------
# Ficha
# -------------------------------------------------------------------------
func _open_detail(i: int) -> void:
	if i < 0 or i >= _cells.size():
		return
	_detail = i
	var b: Dictionary = _cells[i]["badge"]
	var site := GameManager.find_site(String(b.get("site", "")))
	var got := GameManager.badge_pieces(String(b["id"]))
	var n := int(b["pieces"])
	_detail_title.text = String(b["name"])
	_detail_meta.text = "%s · %s" % [site.get("place", ""), site.get("year", "")] if not site.is_empty() else ""
	var complete := got.size() >= n
	_btn_sheet.text = tr("> FICHA TÉCNICA") if complete else tr("FICHA BLOQUEADA")
	_btn_sheet.disabled = not complete
	if complete:
		_detail_state.text = tr("COMPLETA")
		_detail_state.add_theme_color_override("font_color", BadgeArt.GOLD)
	elif bool(site.get("locked", false)) or String(site.get("scene", "")) == "":
		_detail_state.text = tr("BLOQUEADA: este artefacto todavía no tiene misión.")
		_detail_state.add_theme_color_override("font_color", RetroTheme.PHOSPHOR_DIM)
	else:
		_detail_state.text = "%s · %s %s" % [tr("EN PROGRESO") if not got.is_empty() else tr("Completa las fases de su misión para armarla."), tr("Cada fase completada de la misión desbloquea una pieza."), tr("Completa la insignia para desbloquear su ficha técnica.")]
		_detail_state.add_theme_color_override("font_color", RetroTheme.PHOSPHOR)
	_detail_desc.text = String(b["desc"])
	_detail_link.text = String(b["link"])
	_detail_box.show()
	_btn_close.hide()
	(_btn_sheet if complete else _btn_open).grab_focus()


func _open_sheet() -> void:
	if _detail < 0 or _sheet:
		return
	_sheet = BadgeSheet.open_for(self, _cells[_detail]["badge"])
	_sheet.closed.connect(func() -> void:
		_sheet = null
		_btn_sheet.grab_focus())


func _back() -> void:
	_detail = -1
	_detail_box.hide()
	_btn_close.show()


func _open_link() -> void:
	if _detail >= 0:
		OS.shell_open(String(_cells[_detail]["badge"]["link"]))


func _close() -> void:
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	closed.emit()
	queue_free()


func _cell_at(p: Vector2) -> int:
	for i in _cells.size():
		var ctr: Vector2 = _cells[i]["center"]
		if Rect2(ctr - Vector2(COL_W * 0.5, R_SMALL + 4), Vector2(COL_W, R_SMALL * 2 + 32)).has_point(p):
			return i
	return -1


## Mientras la libreta está abierta se queda con el teclado (el menú de atrás no reacciona).
func _input(event: InputEvent) -> void:
	if event is InputEventMouse or _sheet:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _detail >= 0:
			_back()
		else:
			_close()
		return
	if _detail >= 0:
		return              # en la ficha, los botones usan el foco normal
	var moved := true
	if event.is_action_pressed("ui_right"):
		_sel = mini(_sel + 1, _cells.size() - 1)
	elif event.is_action_pressed("ui_left"):
		_sel = maxi(_sel - 1, 0)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var cur: Vector2 = _cells[_sel]["center"]
		var dy := 1.0 if event.is_action_pressed("ui_down") else -1.0
		var best := _sel
		var best_d := INF
		for i in _cells.size():
			var c: Vector2 = _cells[i]["center"]
			if signf(c.y - cur.y) == dy:
				var d := absf(c.x - cur.x) + absf(c.y - cur.y) * 0.1
				if d < best_d:
					best_d = d
					best = i
		_sel = best
	elif event.is_action_pressed("ui_accept"):
		_open_detail(_sel)
	else:
		moved = false
	if moved:
		get_viewport().set_input_as_handled()
	

func _gui_input(event: InputEvent) -> void:
	if _detail >= 0 or _sheet:
		return
	if event is InputEventMouseMotion:
		var i := _cell_at(event.position)
		if i >= 0:
			_sel = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _cell_at(event.position)
		if i >= 0:
			_sel = i
			_open_detail(i)
			accept_event()
