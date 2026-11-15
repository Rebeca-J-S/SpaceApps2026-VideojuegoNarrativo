class_name MissionHUD
extends Control
## HUD común a todas las misiones (se añade encima del HUD propio de cada una):
##
## 1. FICHA DE MISIÓN: al empezar se muestra a pantalla completa (qué es, dónde, quién narra,
##    objetivo) y luego se minimiza en una insignia pequeña.
## 2. TRES BOTONES DE INFORMACIÓN: [C] CONTROLES · [O] OBJETIVOS · [I] MISIÓN.
##    Abren un panel que pausa el juego.
## 3. INDICADORES DE CONTROLES: teclas de la fase actual que se iluminan al pulsarlas.
## 4. RECORDATORIOS DEL CIENTÍFICO: al empezar cada fase y si el jugador pasa un rato sin
##    actuar, el científico de Control de Misión recuerda la pauta de la fase.
##
## El jugador es un OPERADOR externo: no es la nave ni un astronauta; interviene a distancia.
## Todos los textos vienen del bloque "hud" del JSON de cada misión.

## true mientras el ratón está sobre un botón del HUD (los diálogos ignoran ese clic).
static var hover_ui := false

const IDLE_SECONDS := 18.0

## Posiciones (cada misión las ajusta a su propio HUD antes de añadirlo).
var badge_pos := Vector2(462, 19)
var buttons_pos := Vector2(632, 3)      # esquina superior DERECHA de la fila de botones
var reminder_pos := Vector2(8, 40)
var keys_pos := Vector2(8, 340)
## Devuelve true si hay un diálogo en pantalla (para no interrumpir con recordatorios).
var busy_check: Callable = func() -> bool: return false
## Si se asigna, los recordatorios llaman a esto (con el texto) en lugar de mostrar el recuadro propio.
var reminder_callback: Callable = Callable()
## Si es > 0, la ficha inicial se minimiza sola pasado ese tiempo (ENTER / clic siguen adelantándola).
var briefing_auto_seconds := 0.0
## Si tiene tamaño, la ficha inicial se centra dentro de este rectángulo (el área de juego de la misión).
## Con el valor por defecto (vacío) la ficha queda donde estaba antes, en (70, 70).
var briefing_area := Rect2()

var _data: Dictionary = {}
var _phase_titles: Array = []
var _phase := -1
var _done: Dictionary = {}
var _objective := ""
var _fallback_controls := ""
var _keys: Array = []
var _tip := ""
var _tip_pending := false
var _calm := 0.0
var _idle := 0.0

var _badge: Button
var _buttons: HBoxContainer
var _keys_view: Control
var _reminder: PanelContainer
var _reminder_text: Label
var _reminder_tween: Tween
var _modal: Control
var _modal_title: Label
var _modal_body: RichTextLabel
var _modal_close: Button
var _card: PanelContainer
var _card_wait := false
var _paused_before := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## data = bloque "hud" del JSON: {briefing: {...}, phases: [{tip, keys}, ...], general_controls: [...]}
func setup(data: Dictionary, phase_titles: Array) -> void:
	_data = data
	_phase_titles = phase_titles
	var b: Dictionary = _data.get("briefing", {})
	_badge.text = "%s  [I]" % String(b.get("badge", "MISIÓN"))
	_reminder.get_node("Row/Col/Name").set("text", String(b.get("scientist", "CIENTÍFICO · CONTROL DE MISIÓN")))


# =========================================================================
# API para las misiones
# =========================================================================
func set_phase(index: int, title: String, objective: String, fallback_controls: String = "") -> void:
	if _phase >= 0 and _phase != index:
		_done[_phase] = true
	_phase = index
	_objective = objective
	_fallback_controls = fallback_controls
	var phases: Array = _data.get("phases", [])
	var p: Dictionary = phases[index] if index < phases.size() else {}
	_keys = p.get("keys", [])
	_tip = String(p.get("tip", ""))
	_tip_pending = _tip != ""
	_calm = 0.0
	_idle = 0.0
	if title != "":
		_phase_titles_set(index, title)
	_keys_view.queue_redraw()


func set_objective(text: String) -> void:
	_objective = text


func mark_all_done() -> void:
	for i in _phase_titles.size():
		_done[i] = true


## Muestra un recordatorio del científico (por defecto, la pauta de la fase).
func remind(text: String = "") -> void:
	var t := text if text != "" else _tip
	if t == "":
		return
	# Opcional: la misión puede mostrar la pista en su propia caja de diálogo en vez de este recuadro.
	if reminder_callback.is_valid():
		reminder_callback.call(t)
		_idle = 0.0
		return
	_reminder_text.text = t
	_reminder.reset_size()
	_reminder.show()
	if _reminder_tween and _reminder_tween.is_valid():
		_reminder_tween.kill()
	_reminder.modulate.a = 0.0
	_reminder_tween = create_tween()
	_reminder_tween.tween_property(_reminder, "modulate:a", 1.0, 0.25)
	_reminder_tween.tween_interval(7.0)
	_reminder_tween.tween_property(_reminder, "modulate:a", 0.0, 0.5)
	_reminder_tween.tween_callback(_reminder.hide)
	_idle = 0.0


## Ficha de misión a pantalla completa; al confirmar se minimiza en la insignia.
func show_briefing() -> void:
	_badge.hide()
	_buttons.hide()
	_build_card()
	if briefing_area.size != Vector2.ZERO:
		await get_tree().process_frame   # espera a que el panel calcule su tamaño real
		_card.position = (briefing_area.position + (briefing_area.size - _card.size) * 0.5).round()
	_card_wait = true
	var waited := 0.0
	while _card_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if briefing_auto_seconds > 0.0 and waited >= briefing_auto_seconds and not get_tree().paused:
			_card_wait = false
	# Animación: la ficha se encoge hasta convertirse en la insignia.
	var target_scale := Vector2(_badge.size.x / _card.size.x, _badge.size.y / _card.size.y)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_card, "position", _badge.position, 0.6)
	tw.tween_property(_card, "scale", target_scale, 0.6)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6).set_delay(0.25)
	await tw.finished
	_card.queue_free()
	_card = null
	minimize_now()


## Sin animación (al reiniciar una fase o saltar con debug).
func minimize_now() -> void:
	_badge.show()
	_buttons.show()


# =========================================================================
# Bucle: indicadores, recordatorios automáticos
# =========================================================================
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_keys_view.queue_redraw()
	var busy: bool = busy_check.call() or _card != null
	if busy:
		_calm = 0.0
		return
	_calm += delta
	# Pauta al empezar la fase, en cuanto no hay diálogo en pantalla.
	if _tip_pending and _calm > 0.8:
		_tip_pending = false
		remind()
	# Si el jugador lleva un rato sin actuar, el científico se lo recuerda.
	_idle += delta
	if _idle > IDLE_SECONDS:
		remind()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_idle = 0.0
	# Ficha inicial: ENTER / clic para comenzar.
	if _card_wait and _card != null:
		if event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			_card_wait = false
		return
	# Panel de información abierto: ESC o la misma tecla lo cierran.
	if _modal.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_modal()
		elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_C, KEY_O, KEY_I]:
			get_viewport().set_input_as_handled()
			_open_modal(_section_for_key(event.physical_keycode))
		return
	if get_tree().paused or not _buttons.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
		and event.physical_keycode in [KEY_C, KEY_O, KEY_I]:
		get_viewport().set_input_as_handled()
		_open_modal(_section_for_key(event.physical_keycode))


func _section_for_key(k: int) -> String:
	match k:
		KEY_C: return "controles"
		KEY_O: return "objetivos"
	return "mision"


# =========================================================================
# Paneles de información
# =========================================================================
func _open_modal(section: String) -> void:
	if not _modal.visible:
		_paused_before = get_tree().paused
	get_tree().paused = true
	_modal.show()
	var b: Dictionary = _data.get("briefing", {})
	var amber := RetroTheme.AMBER.to_html(false)
	var dim := RetroTheme.PHOSPHOR_DIM.to_html(false)
	var white := RetroTheme.WHITE.to_html(false)
	var s := ""
	match section:
		"controles":
			_modal_title.text = tr("CONTROLES")
			s += tr("[color=#%s]FASE ACTUAL[/color]\n") % amber
			if _keys.is_empty():
				s += (_fallback_controls if _fallback_controls != "" else tr("ENTER / CLIC para avanzar")) + "\n"
			for k in _keys:
				s += tr("[color=#%s]%s[/color]  %s\n") % [white, k[0], k[2]]
			s += tr("\n[color=#%s]SIEMPRE[/color]\n") % amber
			for g in _data.get("general_controls", [
				["ENTER / CLIC", tr("avanzar los mensajes de radio")],
				["ESC", "pausa"],
				["C · O · I", tr("controles, objetivos e información de la misión")],
			]):
				s += tr("[color=#%s]%s[/color]  %s\n") % [white, g[0], g[1]]
		"objetivos":
			_modal_title.text = tr("OBJETIVOS")
			s += tr("[color=#%s]OBJETIVO DE LA MISIÓN[/color]\n%s\n\n") % [amber, b.get("objective", "")]
			s += tr("[color=#%s]AHORA[/color]\n%s\n") % [amber, _objective]
			if _tip != "":
				s += tr("[color=#%s]Consejo: %s[/color]\n") % [dim, _tip]
			s += tr("\n[color=#%s]FASES[/color]\n") % amber
			for i in _phase_titles.size():
				var mark := "[x]" if _done.get(i, false) else ("[>]" if i == _phase else "[ ]")
				s += "%s %s\n" % [mark, _phase_titles[i]]
		_:
			_modal_title.text = tr("MISIÓN")
			s += tr("[color=#%s]%s[/color]\n") % [amber, b.get("title", "")]
			s += tr("[color=#%s]%s · %s[/color]\n\n") % [dim, b.get("year", ""), b.get("place", "")]
			s += tr("[color=#%s]EQUIPOS:[/color] %s\n") % [amber, b.get("equipment", "")]
			s += tr("[color=#%s]NARRADORES:[/color] %s\n") % [amber, b.get("narrators", "")]
	_modal_body.text = s
	_modal_close.grab_focus()


func _close_modal() -> void:
	_modal.hide()
	get_tree().paused = _paused_before
	hover_ui = false


func _phase_titles_set(index: int, title: String) -> void:
	while _phase_titles.size() <= index:
		_phase_titles.append("")
	_phase_titles[index] = title


# =========================================================================
# Construcción
# =========================================================================
func _build() -> void:
	# Insignia (la ficha minimizada): clic = ver la ficha de la misión.
	_badge = Button.new()
	_badge.position = badge_pos
	_badge.add_theme_font_size_override("font_size", 9)
	_badge.focus_mode = Control.FOCUS_NONE
	_badge.pressed.connect(_open_modal.bind("mision"))
	_hoverable(_badge)
	add_child(_badge)
	_badge.hide()

	# Tres botones de información.
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 3)
	add_child(_buttons)
	for def in [[tr("[C] CONTROLES"), "controles"], [tr("[O] OBJETIVOS"), "objetivos"], [tr("[I] MISIÓN"), "mision"]]:
		var b := Button.new()
		b.text = def[0]
		b.add_theme_font_size_override("font_size", 9)
		b.focus_mode = Control.FOCUS_NONE  # Que ESPACIO / ENTER sigan siendo de la misión.
		b.pressed.connect(_open_modal.bind(def[1]))
		_hoverable(b)
		_buttons.add_child(b)
	_buttons.hide()

	# Teclas de la fase (se iluminan al pulsarlas).
	_keys_view = Control.new()
	_keys_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_view.size = Vector2(620, 16)
	_keys_view.draw.connect(_draw_keys)
	add_child(_keys_view)

	# Recordatorio del científico.
	_reminder = PanelContainer.new()
	_reminder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reminder)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 6)
	_reminder.add_child(row)
	var face := ColorRect.new()
	face.color = Color("#7a5a2a")
	face.custom_minimum_size = Vector2(26, 26)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var initials := Label.new()
	initials.text = "CM"  # PLACEHOLDER del retrato del científico.
	initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 11)
	initials.add_theme_color_override("font_color", RetroTheme.SPACE)
	face.add_child(initials)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var who := Label.new()
	who.name = "Name"
	who.add_theme_font_size_override("font_size", 9)
	who.add_theme_color_override("font_color", RetroTheme.AMBER)
	col.add_child(who)
	_reminder_text = Label.new()
	_reminder_text.custom_minimum_size = Vector2(230, 0)
	_reminder_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reminder_text.add_theme_font_size_override("font_size", 10)
	_reminder_text.add_theme_color_override("font_color", RetroTheme.WHITE)
	col.add_child(_reminder_text)
	_reminder.hide()

	# Panel modal de información.
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(110, 40)
	panel.size = Vector2(420, 280)
	_modal.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_modal_title = Label.new()
	_modal_title.add_theme_font_size_override("font_size", 14)
	_modal_title.add_theme_color_override("font_color", RetroTheme.AMBER)
	box.add_child(_modal_title)
	box.add_child(HSeparator.new())
	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.custom_minimum_size = Vector2(400, 200)
	box.add_child(_modal_body)
	_modal_close = Button.new()
	_modal_close.text = tr("[ESC] CERRAR")
	_modal_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_modal_close.pressed.connect(_close_modal)
	box.add_child(_modal_close)
	_modal.hide()


## Coloca los elementos según las posiciones configuradas por la misión.
func apply_layout() -> void:
	_badge.position = badge_pos
	_buttons.reset_size()
	_buttons.position = Vector2(buttons_pos.x - _buttons.get_combined_minimum_size().x, buttons_pos.y)
	_reminder.position = reminder_pos
	_keys_view.position = keys_pos


func _hoverable(c: Control) -> void:
	c.mouse_entered.connect(func() -> void: MissionHUD.hover_ui = true)
	c.mouse_exited.connect(func() -> void: MissionHUD.hover_ui = false)


func _build_card() -> void:
	var b: Dictionary = _data.get("briefing", {})
	_card = PanelContainer.new()
	_card.position = Vector2(70, 70)
	_card.custom_minimum_size = Vector2(500, 0)
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_card.add_child(box)
	box.add_child(_card_label(String(b.get("header", "")), 11, RetroTheme.PHOSPHOR))
	var title := _card_label(String(b.get("title", "")), 22, RetroTheme.AMBER)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.1))
	title.add_theme_constant_override("outline_size", 5)
	box.add_child(title)
	box.add_child(_card_label("%s · %s" % [b.get("year", ""), b.get("place", "")], 12, RetroTheme.WHITE))
	box.add_child(HSeparator.new())
	box.add_child(_card_label(tr("EQUIPOS: ") + String(b.get("equipment", "")), 11, RetroTheme.WHITE))
	box.add_child(_card_label(tr("NARRADORES: ") + String(b.get("narrators", "")), 11, RetroTheme.WHITE))
	box.add_child(_card_label(tr("OBJETIVO: ") + String(b.get("objective", "")), 11, RetroTheme.PHOSPHOR))
	box.add_child(HSeparator.new())
	var hint := _card_label(tr("ENTER / CLIC PARA COMENZAR   ·   C · O · I: CONTROLES, OBJETIVOS, MISIÓN"), 10, RetroTheme.AMBER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	# Entrada con un pequeño "encendido".
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.35)


func _card_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _draw_keys() -> void:
	var c := _keys_view
	var font := ThemeDB.fallback_font
	var x := 0.0
	var list: Array = _keys
	if list.is_empty() and _fallback_controls != "":
		c.draw_string(font, Vector2(0, 11), _fallback_controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#80f2ff"))
		return
	for k in list:
		var cap := String(k[0])
		var action := String(k[1])
		var label := String(k[2])
		var on := action != "" and InputMap.has_action(action) and Input.is_action_pressed(action)
		var w := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0
		var r := Rect2(x, 0, w, 14)
		c.draw_rect(r, RetroTheme.AMBER if on else Color(0.05, 0.08, 0.1, 0.85))
		c.draw_rect(r, RetroTheme.AMBER if on else Color("#80f2ff"), false, 1.0)
		c.draw_string(font, Vector2(x + 4, 11), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.SPACE if on else RetroTheme.WHITE)
		x += w + 3.0
		c.draw_string(font, Vector2(x, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.85))
		x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
