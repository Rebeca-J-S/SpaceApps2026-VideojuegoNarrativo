extends Control
## Escena 2 — Menú principal.
## Fondo: la Luna y Marte rotando, con los sitios donde la NASA dejó hardware marcados
## (pasa el ratón por un marcador para ver qué hay allí).
## UI: consola de control (verde fósforo / ámbar). Paneles modales con efecto "encendido CRT".

const MISSION_SCENE := "res://scenes/ui/planet_select.tscn"
const VOICE_INTERVAL := 8.0   # segundos entre frases de las máquinas
const VOICE_TYPE_SPEED := 40.0

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var game_title: Label = %GameTitle
@onready var btn_start: Button = %BtnStart
@onready var btn_archive: Button = %BtnArchive
@onready var btn_controls: Button = %BtnControls
@onready var btn_quit: Button = %BtnQuit
@onready var moon: PixelPlanet = %Moon
@onready var mars: PixelPlanet = %Mars
@onready var site_tooltip: PanelContainer = %SiteTooltip
@onready var site_tooltip_label: Label = %SiteTooltipLabel
@onready var dimmer: ColorRect = %Dimmer
@onready var archive_panel: PanelContainer = %ArchivePanel
@onready var section_tabs: HBoxContainer = %SectionTabs
@onready var machine_list: VBoxContainer = %MachineList
@onready var archive_body: RichTextLabel = %ArchiveBody
@onready var btn_close_archive: Button = %BtnCloseArchive
@onready var controls_panel: PanelContainer = %ControlsPanel
@onready var controls_body: RichTextLabel = %ControlsBody
@onready var btn_close_controls: Button = %BtnCloseControls
@onready var voice_speaker: Label = %VoiceSpeaker
@onready var voice_text: Label = %VoiceText
@onready var status_label: Label = %StatusLabel

var _menu_buttons: Array[Button] = []
var _open_panel: Control = null
var _focus_before_panel: Control = null
var _panel_tween: Tween
var _animating := false
var _leaving := false
var _voice_index := 0
var _voice_tween: Tween
var _current_section := ""


func _ready() -> void:
	theme = RetroTheme.build()
	game_title.text = tr("WHAT WAS LEFT\nBEHIND")
	add_child(LangButton.new())
	_menu_buttons = [btn_start, btn_archive, btn_controls, btn_quit]

	# En la versión Web "Salir" no tiene sentido (no se puede cerrar la pestaña).
	if OS.has_feature("web"):
		btn_quit.hide()

	for b in _menu_buttons:
		_decorate_button(b)
	_decorate_button(btn_close_archive)
	_decorate_button(btn_close_controls)

	btn_start.pressed.connect(_on_start_pressed)
	btn_archive.pressed.connect(_open.bind(archive_panel))
	btn_controls.pressed.connect(_open.bind(controls_panel))
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	btn_close_archive.pressed.connect(_close_panel)
	btn_close_controls.pressed.connect(_close_panel)
	dimmer.gui_input.connect(_on_dimmer_input)

	_build_section_tabs()
	controls_body.text = tr(MissionData.CONTROLS_BBCODE)

	archive_panel.hide()
	controls_panel.hide()
	dimmer.hide()
	site_tooltip.hide()

	_start_voice_loop()
	_start_status_pulse()
	await _play_menu_intro()
	btn_start.grab_focus()


func _process(_delta: float) -> void:
	_update_site_tooltip()


# -------------------------------------------------------------------------
# Botones estilo terminal: "> OPCIÓN" cuando tienen el foco.
# -------------------------------------------------------------------------
func _decorate_button(b: Button) -> void:
	var label := tr(b.text)
	b.text = "  " + label
	b.focus_entered.connect(func() -> void: b.text = "> " + label)
	b.focus_exited.connect(func() -> void: b.text = "  " + label)
	b.mouse_entered.connect(_on_button_hovered.bind(b))  # Ratón y teclado comparten cursor.


func _on_button_hovered(b: Button) -> void:
	if b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()


func _set_menu_interactive(enabled: bool) -> void:
	for b in _menu_buttons:
		b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


# -------------------------------------------------------------------------
# Animación de entrada: el menú se desliza y los planetas aparecen.
# -------------------------------------------------------------------------
func _play_menu_intro() -> void:
	menu_panel.modulate.a = 0.0
	moon.modulate.a = 0.0
	mars.modulate.a = 0.0
	await get_tree().process_frame  # Esperamos a que los anchors calculen la posición.
	var target_x := menu_panel.position.x
	menu_panel.position.x = target_x - 40.0
	# La Luna llega "grande" (continuación del zoom de la intro) y se aleja a su sitio.
	moon.pivot_offset = moon.size / 2.0
	moon.scale = Vector2(2.2, 2.2)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(moon, "modulate:a", 1.0, 0.4)
	tw.tween_property(moon, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(menu_panel, "position:x", target_x, 0.6).set_delay(0.4)
	tw.tween_property(menu_panel, "modulate:a", 1.0, 0.6).set_delay(0.4)
	tw.tween_property(mars, "modulate:a", 1.0, 1.0).set_delay(0.6)
	await tw.finished


# -------------------------------------------------------------------------
# Marcadores de los planetas
# -------------------------------------------------------------------------
func _update_site_tooltip() -> void:
	var found := false
	for planet in [moon, mars]:
		var p := planet as PixelPlanet
		var index := -1
		if _open_panel == null:
			index = p.get_site_at(p.get_local_mouse_position())
		p.hovered = index
		if index >= 0 and not found:
			found = true
			var info := p.get_site_info(index)
			var state := tr("BLOQUEADO") if bool(info.get("locked", false)) else tr("MISIÓN JUGABLE")
			var text := "%s  [%s]\n%s · %s" % [info["name"], state, info.get("place", ""), info.get("year", "")]
			if site_tooltip_label.text != text:
				site_tooltip_label.text = text
				site_tooltip.reset_size()
	site_tooltip.visible = found
	if found:
		var pos := get_local_mouse_position() + Vector2(12, 10)
		pos.x = minf(pos.x, size.x - site_tooltip.size.x - 4)
		pos.y = minf(pos.y, size.y - site_tooltip.size.y - 4)
		site_tooltip.position = pos.floor()


# -------------------------------------------------------------------------
# Acciones del menú
# -------------------------------------------------------------------------
func _on_start_pressed() -> void:
	if _leaving or _open_panel:
		return
	_leaving = true
	_set_menu_interactive(false)
	SceneTransition.change_scene(MISSION_SCENE)


# -------------------------------------------------------------------------
# Paneles modales con efecto "encendido de monitor CRT":
# primero una línea horizontal que se ensancha, luego se abre en vertical.
# -------------------------------------------------------------------------
func _open(panel: PanelContainer) -> void:
	if _open_panel or _animating or _leaving:
		return
	_open_panel = panel
	_animating = true
	_focus_before_panel = get_viewport().gui_get_focus_owner()
	_set_menu_interactive(false)

	dimmer.modulate.a = 0.0
	dimmer.show()
	panel.show()
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.1, 0.03)
	panel.modulate.a = 0.0

	_panel_tween = create_tween()
	_panel_tween.tween_property(dimmer, "modulate:a", 1.0, 0.15)
	_panel_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.1)
	_panel_tween.parallel().tween_property(panel, "scale:x", 1.0, 0.14)
	_panel_tween.tween_property(panel, "scale:y", 1.0, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _panel_tween.finished
	_animating = false

	# Foco inicial dentro del panel para navegar con teclado / mando.
	if panel == archive_panel and section_tabs.get_child_count() > 0:
		(section_tabs.get_child(0) as Button).grab_focus()
	elif panel == controls_panel:
		btn_close_controls.grab_focus()


func _close_panel() -> void:
	if not _open_panel or _animating:
		return
	var panel := _open_panel
	_animating = true

	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "scale:y", 0.03, 0.1)
	_panel_tween.tween_property(panel, "scale:x", 0.0, 0.08)
	_panel_tween.parallel().tween_property(dimmer, "modulate:a", 0.0, 0.12)
	await _panel_tween.finished

	panel.hide()
	dimmer.hide()
	panel.scale = Vector2.ONE
	_open_panel = null
	_animating = false
	_set_menu_interactive(true)
	if _focus_before_panel and is_instance_valid(_focus_before_panel):
		_focus_before_panel.grab_focus()
	else:
		btn_start.grab_focus()


func _on_dimmer_input(event: InputEvent) -> void:
	# Clic fuera del panel = cerrar.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _open_panel:
		get_viewport().set_input_as_handled()
		_close_panel()


# -------------------------------------------------------------------------
# ARCHIVO CIENTÍFICO: secciones (LUNA / MARTE / MISIÓN) -> lista de máquinas -> ficha
# -------------------------------------------------------------------------
func _build_section_tabs() -> void:
	var group := ButtonGroup.new()
	for section in GameManager.get_archive()["sections"]:
		var tab := _make_toggle(tr(section), group, 12)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.toggled.connect(_on_section_toggled.bind(section))
		section_tabs.add_child(tab)
	# Cuaderno de insignias: se abre como una libreta encima del archivo.
	var nb := Button.new()
	nb.text = tr("CUADERNO DE INSIGNIAS")
	nb.add_theme_font_size_override("font_size", 12)
	nb.add_theme_color_override("font_color", RetroTheme.AMBER)
	nb.pressed.connect(_open_badge_notebook.bind(nb))
	section_tabs.add_child(nb)
	(section_tabs.get_child(0) as Button).button_pressed = true


func _open_badge_notebook(from: Button) -> void:
	var notebook := BadgeNotebook.new()
	add_child(notebook)
	notebook.closed.connect(func() -> void:
		if is_instance_valid(from):
			from.grab_focus())


func _make_toggle(text: String, group: ButtonGroup, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", font_size)
	# Navegar con flechas selecciona directamente.
	b.focus_entered.connect(func() -> void: b.button_pressed = true)
	return b


func _on_section_toggled(on: bool, section: String) -> void:
	if not on or section == _current_section:
		return
	_current_section = section
	for c in machine_list.get_children():
		machine_list.remove_child(c)
		c.queue_free()
	var group := ButtonGroup.new()
	var entries: Array = GameManager.get_archive()["entries"][section]
	for i in entries.size():
		var b := _make_toggle(entries[i]["tab"], group, 10)
		b.toggled.connect(_on_machine_toggled.bind(section, i))
		machine_list.add_child(b)
	(machine_list.get_child(0) as Button).button_pressed = true


func _on_machine_toggled(on: bool, section: String, index: int) -> void:
	if on:
		_show_archive_entry(GameManager.get_archive()["entries"][section][index])


func _show_archive_entry(entry: Dictionary) -> void:
	var amber := RetroTheme.AMBER.to_html(false)
	var dim := RetroTheme.PHOSPHOR_DIM.to_html(false)
	var white := RetroTheme.WHITE.to_html(false)

	var s := tr("[color=#%s]%s[/color]\n[color=#%s]%s[/color]\n\n") % [amber, entry["name"], dim, tr(entry["id"])]
	for fact in entry["facts"]:
		s += tr("[color=#%s]»[/color] %s: [color=#%s]%s[/color]\n") % [dim, fact[0], white, fact[1]]
	# La historia del equipo se desbloquea al completar su misión.
	if GameManager.is_completed(String(entry.get("mission", ""))):
		s += tr("\n[color=#%s]>> SU HISTORIA:[/color]\n%s") % [amber, entry["voice"]]
	else:
		s += tr("\n[color=#%s]>> HISTORIA BLOQUEADA[/color]\n[color=#%s]Completa su misión para desbloquearla.[/color]") % [amber, dim]

	archive_body.text = s
	archive_body.scroll_to_line(0)
	# Efecto "datos llegando por telemetría".
	archive_body.visible_ratio = 0.0
	create_tween().tween_property(archive_body, "visible_ratio", 1.0, 0.6)


# -------------------------------------------------------------------------
# Voz de las máquinas (esquina inferior derecha)
# -------------------------------------------------------------------------
func _start_voice_loop() -> void:
	var timer := Timer.new()
	timer.wait_time = VOICE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_next_voice_line)
	add_child(timer)
	_next_voice_line()  # Datos breves de los equipos, en tercera persona.


func _next_voice_line() -> void:
	var voices: Array = GameManager.get_archive()["voices"]
	var line: Dictionary = voices[_voice_index % voices.size()]
	_voice_index += 1
	voice_speaker.text = tr("ARCHIVO · %s") % tr(line["speaker"])
	voice_text.text = line["text"]
	voice_text.visible_characters = 0
	if _voice_tween and _voice_tween.is_valid():
		_voice_tween.kill()
	var n: int = voice_text.text.length()
	_voice_tween = create_tween()
	_voice_tween.tween_property(voice_text, "visible_characters", n, n / VOICE_TYPE_SPEED)


func _start_status_pulse() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(status_label, "modulate:a", 0.55, 1.2)
	tw.tween_property(status_label, "modulate:a", 1.0, 1.2)
