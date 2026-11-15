class_name PauseMenu
extends Control
## Menú de pausa común a todas las misiones: botón de tres puntos en la esquina superior derecha
## (o la tecla ESC). Páginas:
##   PAUSA  -> CONTINUAR · CONTROLES · OBJETIVOS · MISIÓN · SONIDO · AYUDA · SALIR DE LA MISIÓN
##   SONIDO -> volumen de música y de efectos (se guarda en user://progreso.cfg)
##   AYUDA  -> cómo se juega cada minijuego de la misión (data/guia.json) y preguntas frecuentes
##   SALIR  -> elegir otra misión, menú principal o cerrar el juego
## ESC vuelve atrás una página; en la principal, continúa la partida.
## Uso: var pm := PauseMenu.new(); pm.setup("apolo11", data["scenes"]); add_child(pm); pm.toggle()

const DOTS_SIZE := Vector2(18, 15)
const PANEL_POS := Vector2(70, 40)
const PANEL_SIZE := Vector2(500, 280)

## Esquina superior DERECHA del botón de tres puntos (cada misión lo ajusta).
var dots_pos := Vector2(634, 25)

var _mission := ""
## HUD de la misión: sus paneles CONTROLES / OBJETIVOS / MISIÓN se abren desde este menú.
var hud: MissionHUD
var _scenes: Array = []
var _open := false
var _page := ""
var _dots: Button
var _overlay: Control
var _panel: PanelContainer
var _pages: Dictionary = {}
var _help_list: VBoxContainer
var _help_view: VBoxContainer
var _help_scroll: ScrollContainer
var _help_first: Button
var _sliders: Dictionary = {}
var _sfx_test: AudioStreamPlayer
var _sfx_test_cd := 0.0


func setup(mission: String, scenes: Array) -> void:
	_mission = mission
	_scenes = scenes


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	MissionHUD.hover_ui = false
	_overlay.show()
	_show_page("main")


func close() -> void:
	if not _open:
		return
	_open = false
	_overlay.hide()
	get_tree().paused = false
	MissionHUD.hover_ui = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	_build()
	# Que quede por encima de todo lo que la misión añada después.
	(func() -> void: get_parent().move_child(self, -1)).call_deferred()


func _process(delta: float) -> void:
	_sfx_test_cd = maxf(_sfx_test_cd - delta, 0.0)


# -------------------------------------------------------------------------
# Construcción
# -------------------------------------------------------------------------
func _build() -> void:
	_dots = Button.new()
	_dots.focus_mode = Control.FOCUS_NONE
	_dots.tooltip_text = tr("MENÚ (ESC)")
	_dots.custom_minimum_size = DOTS_SIZE
	_dots.size = DOTS_SIZE
	_dots.position = dots_pos - Vector2(DOTS_SIZE.x, 0)
	_dots.pressed.connect(toggle)
	_dots.draw.connect(_draw_dots)
	_dots.mouse_entered.connect(func() -> void: MissionHUD.hover_ui = true)
	_dots.mouse_exited.connect(func() -> void: MissionHUD.hover_ui = false)
	add_child(_dots)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	_panel = PanelContainer.new()
	_overlay.add_child(_panel)
	_pages["main"] = _build_main()
	_pages["sound"] = _build_sound()
	_pages["help"] = _build_help()
	_pages["exit"] = _build_exit()
	for k in _pages:
		_panel.add_child(_pages[k])   # una página visible a la vez (el panel toma su tamaño)
	_overlay.hide()

	_sfx_test = AudioStreamPlayer.new()
	_sfx_test.stream = _make_blip()
	_sfx_test.bus = &"SFX"
	add_child(_sfx_test)


## Mueve el botón de tres puntos (llamar después de cambiar dots_pos).
func apply_layout() -> void:
	if _dots:
		_dots.position = dots_pos - Vector2(DOTS_SIZE.x, 0)


func _draw_dots() -> void:
	var c := RetroTheme.AMBER if _dots.is_hovered() or _open else RetroTheme.WHITE
	var x := DOTS_SIZE.x * 0.5
	for i in 3:
		_dots.draw_rect(Rect2(x - 1.5, 2.5 + i * 4.0, 3, 3), c)


func _page_box(title: String, sep := 6) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	var t := _label(title, 14, RetroTheme.AMBER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(HSeparator.new())
	return box


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(parent: Node, text: String, cb: Callable, font_size := 11) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_main() -> VBoxContainer:
	var box := _page_box(tr("PAUSA"), 7)
	box.custom_minimum_size = Vector2(220, 0)
	_button(box, tr("> CONTINUAR"), close)
	_button(box, tr("[C] CONTROLES"), _open_info.bind("controles"))
	_button(box, tr("[O] OBJETIVOS"), _open_info.bind("objetivos"))
	_button(box, tr("[I] MISIÓN"), _open_info.bind("mision"))
	_button(box, tr("SONIDO"), _show_page.bind("sound"))
	_button(box, tr("AYUDA"), _show_page.bind("help"))
	_button(box, tr("SALIR DE LA MISIÓN"), _show_page.bind("exit"))
	box.add_child(_hint(tr("ESC: VOLVER")))
	return box


func _hint(text: String) -> Label:
	var l := _label(text, 8, RetroTheme.PHOSPHOR_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_sound() -> VBoxContainer:
	var box := _page_box(tr("SONIDO"), 8)
	box.custom_minimum_size = Vector2(300, 0)
	for def in [["music", tr("MÚSICA")], ["sfx", tr("EFECTOS")]]:
		var kind: String = def[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var name_l := _label(def[1], 11, RetroTheme.WHITE)
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_l.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.custom_minimum_size = Vector2(130, 16)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(s)
		var val := _label("", 11, RetroTheme.AMBER)
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.custom_minimum_size = Vector2(40, 0)
		row.add_child(val)
		s.value_changed.connect(func(v: float) -> void:
			val.text = "%d %%" % int(v)
			GameManager.set_volume(kind, v / 100.0, false)
			if kind == "sfx" and _sfx_test_cd <= 0.0 and _page == "sound":
				_sfx_test_cd = 0.12
				_sfx_test.play())
		_sliders[kind] = s
	_button(box, tr("< VOLVER"), _show_page.bind("main"))
	box.add_child(_hint(tr("FLECHAS: ELEGIR Y AJUSTAR  ·  ESC: VOLVER")))
	return box


func _build_help() -> VBoxContainer:
	var box := _page_box(tr("AYUDA · CÓMO JUGAR"), 5)
	box.custom_minimum_size = Vector2(PANEL_SIZE.x - 12, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_help_list = VBoxContainer.new()
	_help_list.add_theme_constant_override("separation", 3)
	_help_list.custom_minimum_size = Vector2(150, 0)
	row.add_child(_help_list)
	_help_scroll = ScrollContainer.new()
	_help_scroll.custom_minimum_size = Vector2(PANEL_SIZE.x - 180, 196)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_help_scroll)
	_help_view = VBoxContainer.new()
	_help_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_scroll.add_child(_help_view)
	_button(box, tr("< VOLVER"), _show_page.bind("main")).size_flags_horizontal = Control.SIZE_SHRINK_END
	return box


## Rellena la lista de la ayuda: un botón por minijuego de la misión y las preguntas frecuentes.
func _fill_help() -> void:
	for c in _help_list.get_children():
		c.queue_free()
	_help_first = null
	for sc in _scenes:
		var card := GameManager.get_tutorial(_mission, String(sc.get("id", "")))
		if card.is_empty():
			continue
		var b := _button(_help_list, String(sc.get("title", card["title"])), _show_help.bind(card), 8)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(150, 0)
		b.focus_entered.connect(_show_help.bind(card))
		if _help_first == null:
			_help_first = b
	var faq := _button(_help_list, tr("PREGUNTAS FRECUENTES"), _show_faq, 8)
	faq.alignment = HORIZONTAL_ALIGNMENT_LEFT
	faq.custom_minimum_size = Vector2(150, 0)
	faq.focus_entered.connect(_show_faq)
	if _help_first == null:
		_help_first = faq


func _clear_help_view() -> void:
	for c in _help_view.get_children():
		c.queue_free()
	_help_scroll.scroll_vertical = 0


func _show_help(card: Dictionary) -> void:
	_clear_help_view()
	_help_view.add_child(TutorialCard.build_content(card, PANEL_SIZE.x - 196))


func _show_faq() -> void:
	_clear_help_view()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_help_view.add_child(box)
	box.add_child(_wrapped(tr("PREGUNTAS FRECUENTES"), 15, RetroTheme.AMBER))
	for item in GameManager.get_faq():
		var q := _wrapped(String(item["q"]), 10, RetroTheme.PHOSPHOR)
		box.add_child(q)
		box.add_child(_wrapped(String(item["a"]), 10, RetroTheme.WHITE))


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.custom_minimum_size = Vector2(PANEL_SIZE.x - 196, 0)
	return l


func _build_exit() -> VBoxContainer:
	var box := _page_box(tr("¿SALIR DE LA MISIÓN?"), 7)
	box.custom_minimum_size = Vector2(300, 0)
	var info := _label(tr("Las piezas de insignia que ya ganaste se quedan guardadas. La fase actual empezará de nuevo."), 10, RetroTheme.WHITE)
	info.custom_minimum_size = Vector2(300, 0)
	box.add_child(info)
	_button(box, tr("> ELEGIR OTRA MISIÓN"), _leave.bind("select"))
	_button(box, tr("> MENÚ PRINCIPAL"), _leave.bind("menu"))
	if OS.get_name() != "Web":
		_button(box, tr("> CERRAR EL JUEGO"), _leave.bind("quit"))
	_button(box, tr("< VOLVER"), _show_page.bind("main"))
	return box


# -------------------------------------------------------------------------
# Navegación
# -------------------------------------------------------------------------
func _show_page(page: String) -> void:
	_page = page
	for k in _pages:
		_pages[k].visible = k == page
	var box: VBoxContainer = _pages[page]
	if page == "sound":
		_sfx_test_cd = 0.3   # sin pitido al abrir la página
		for kind in _sliders:
			_sliders[kind].set_value_no_signal(roundf(GameManager.volume[kind] * 100.0))
			_sliders[kind].value_changed.emit(_sliders[kind].value)
	elif page == "help":
		_fill_help()
	# Tamaño y posición del panel según la página (cuando el contenido ya calculó su tamaño).
	await get_tree().process_frame
	_panel.reset_size()
	_panel.position = ((get_viewport_rect().size - _panel.size) * 0.5).round()
	# Foco para jugar con teclado.
	if page == "help" and _help_first:
		_help_first.grab_focus()
		return
	if page == "sound":
		_sliders["music"].grab_focus()
		return
	for c in box.get_children():
		if c is Button:
			c.grab_focus()
			return


## Cierra la pausa y abre el panel de información del HUD (que pausa por su cuenta).
func _open_info(section: String) -> void:
	if hud == null:
		return
	close()
	hud.open_section(section)


func _back() -> void:
	match _page:
		"main":
			close()
		"sound":
			GameManager.set_volume("music", GameManager.volume["music"])   # guarda
			_show_page("main")
		_:
			_show_page("main")


func _leave(where: String) -> void:
	GameManager.set_volume("music", GameManager.volume["music"])
	_open = false
	get_tree().paused = false
	match where:
		"select": GameManager.go_to_planet_select()
		"menu": GameManager.go_to_main_menu()
		"quit": get_tree().quit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _make_blip() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.06)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		bytes.encode_s16(i * 2, int(sin(TAU * 880.0 * i / rate) * env * 0.35 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	return w
