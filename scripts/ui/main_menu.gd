extends Control
## Escena 2 — Menú principal.
## Fondo: superficie lunar silenciosa con el Eagle abandonado, el EASEP brillando y el LRRR.
## UI: consola de Houston (verde fósforo / ámbar). Paneles modales con animación "encendido CRT".

const MISSION_SCENE := "res://scenes/levels/fase0_orbita.tscn"
const VOICE_INTERVAL := 8.0   # segundos entre frases de las máquinas
const VOICE_TYPE_SPEED := 40.0

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var btn_start: Button = %BtnStart
@onready var btn_archive: Button = %BtnArchive
@onready var btn_controls: Button = %BtnControls
@onready var btn_quit: Button = %BtnQuit
@onready var dimmer: ColorRect = %Dimmer
@onready var archive_panel: PanelContainer = %ArchivePanel
@onready var archive_tabs: HBoxContainer = %ArchiveTabs
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


func _ready() -> void:
	theme = RetroTheme.build()
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

	_build_archive_tabs()
	controls_body.text = MissionData.CONTROLS_BBCODE

	archive_panel.hide()
	controls_panel.hide()
	dimmer.hide()

	_start_voice_loop()
	_start_status_pulse()
	await _play_menu_intro()
	btn_start.grab_focus()


# -------------------------------------------------------------------------
# Botones estilo terminal: "> OPCIÓN" cuando tienen el foco.
# -------------------------------------------------------------------------
func _decorate_button(b: Button) -> void:
	var label := b.text
	b.text = "  " + label
	b.focus_entered.connect(func() -> void: b.text = "> " + label)
	b.focus_exited.connect(func() -> void: b.text = "  " + label)
	# Ratón y teclado comparten el mismo "cursor".
	b.mouse_entered.connect(_on_button_hovered.bind(b))


func _on_button_hovered(b: Button) -> void:
	if b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()


func _set_menu_interactive(enabled: bool) -> void:
	for b in _menu_buttons:
		b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


# -------------------------------------------------------------------------
# Animación de entrada del menú (desliza desde la izquierda).
# -------------------------------------------------------------------------
func _play_menu_intro() -> void:
	menu_panel.modulate.a = 0.0
	await get_tree().process_frame  # Esperamos a que los anchors calculen la posición.
	var target_x := menu_panel.position.x
	menu_panel.position.x = target_x - 40.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu_panel, "position:x", target_x, 0.6)
	tw.tween_property(menu_panel, "modulate:a", 1.0, 0.6)
	await tw.finished


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
	if panel == archive_panel and archive_tabs.get_child_count() > 0:
		(archive_tabs.get_child(0) as Button).grab_focus()
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
# ARCHIVO CIENTÍFICO: pestañas generadas desde MissionData.ARCHIVE
# -------------------------------------------------------------------------
func _build_archive_tabs() -> void:
	var group := ButtonGroup.new()
	for i in MissionData.ARCHIVE.size():
		var entry: Dictionary = MissionData.ARCHIVE[i]
		var tab := Button.new()
		tab.text = entry["tab"]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 10)
		tab.toggled.connect(_on_archive_tab_toggled.bind(i))
		# Navegar con flechas cambia de ficha directamente.
		tab.focus_entered.connect(func() -> void: tab.button_pressed = true)
		archive_tabs.add_child(tab)
	(archive_tabs.get_child(0) as Button).button_pressed = true


func _on_archive_tab_toggled(on: bool, index: int) -> void:
	if on:
		_show_archive_entry(index)


func _show_archive_entry(index: int) -> void:
	var entry: Dictionary = MissionData.ARCHIVE[index]
	var amber := RetroTheme.AMBER.to_html(false)
	var dim := RetroTheme.PHOSPHOR_DIM.to_html(false)
	var white := RetroTheme.WHITE.to_html(false)

	var s := "[color=#%s]%s[/color]\n[color=#%s]%s[/color]\n\n" % [amber, entry["name"], dim, entry["id"]]
	for fact in entry["facts"]:
		s += "[color=#%s]»[/color] %s: [color=#%s]%s[/color]\n" % [dim, fact[0], white, fact[1]]
	s += "\n[color=#%s]>> TRANSMISIÓN DE LA MÁQUINA:[/color]\n\"%s\"" % [amber, entry["voice"]]

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
	_next_voice_line()  # La primera frase es la bienvenida del Eagle.


func _next_voice_line() -> void:
	var line: Dictionary = MissionData.VOICE_LINES[_voice_index % MissionData.VOICE_LINES.size()]
	_voice_index += 1
	voice_speaker.text = "[ %s ] >>" % line["speaker"]
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
