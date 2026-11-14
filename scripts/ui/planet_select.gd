extends Control
## Escena 3 — Selector de destinos (Referencia B).
## Tres destinos de data/sites.json: LUNA y MARTE (planetas con shader pixelado) y
## ESPACIO PROFUNDO (mini sistema solar). Los puntos verdes marcan los sitios reales.
##
## Árbol generado por código (para poder añadir destinos sin tocar la escena):
##   PlanetSelect (Control)
##   ├─ Background (ColorRect azul marino) + Grid (DrawNode) + Starfield (con estrellas fugaces)
##   ├─ Title / Subtitle (Label)
##   ├─ Body0..2 (PixelPlanet / DeepSpaceView) + Orbits (DrawNode: órbita punteada y anillos)
##   ├─ Card0..2 (PanelContainer con borde azul)
##   ├─ Footer (Label)
##   ├─ SitePanel (PanelContainer modal: ficha del sitio + INICIAR MISIÓN)
##   └─ Radar (DrawNode: ondas verdes de la transición) + CRTOverlay
##
## Controles: ←/→ elegir destino · ENTER ver sitios · clic en punto verde: ver misión · ESC menú.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const NAVY := Color("#0a1030")
const CARD_BLUE := Color("#4da6ff")
const BODY_SIZE := 120.0
const CENTERS := [Vector2(120, 138), Vector2(320, 138), Vector2(520, 138)]

var _destinations: Array = []
var _bodies: Array[Control] = []
var _cards: Array[PanelContainer] = []
var _card_titles: Array[Label] = []
var _selected := 0
var _t := 0.0
var _busy := false
var _radar_t := -1.0

var _site_panel: PanelContainer
var _site_title: Label
var _site_buttons: HBoxContainer
var _site_info: Label
var _start_btn: Button
var _panel_dest := -1
var _panel_site := -1


func _ready() -> void:
	theme = RetroTheme.build()
	_destinations = GameManager.get_destinations()
	_build()
	_select(0)


# =========================================================================
# Construcción
# =========================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Cuadrícula sutil.
	add_child(DrawNode.new(func(c: DrawNode) -> void:
		for x in range(0, 641, 32):
			c.draw_rect(Rect2(x, 0, 1, 360), Color(0.4, 0.6, 1.0, 0.06))
		for y in range(0, 361, 32):
			c.draw_rect(Rect2(0, y, 640, 1), Color(0.4, 0.6, 1.0, 0.06))
	, false))
	var stars := Starfield.new()
	stars.star_count = 150
	stars.shooting_stars = true
	add_child(stars)

	var title := _label("WHAT WAS LEFT BEHIND", 24, RetroTheme.AMBER, Vector2(0, 8), Vector2(640, 30))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.1))
	title.add_theme_constant_override("outline_size", 6)
	_label("– SELECCIONA UN DESTINO –", 10, RetroTheme.WHITE, Vector2(0, 38), Vector2(640, 14))

	# Órbitas punteadas y anillos del seleccionado (detrás de los cuerpos).
	add_child(DrawNode.new(_draw_orbits))

	for i in _destinations.size():
		var dest: Dictionary = _destinations[i]
		var body: Control
		match String(dest["kind"]):
			"moon", "mars":
				var p := PixelPlanet.new()
				p.kind = PixelPlanet.Kind.MARS if dest["kind"] == "mars" else PixelPlanet.Kind.MOON
				p.pixels = BODY_SIZE / 2.0
				p.spin_speed = 0.01 if dest["kind"] == "mars" else 0.007
				p.sites = dest["sites"]
				body = p
			_:
				var d := DeepSpaceView.new()
				d.sites = dest["sites"]
				body = d
		body.size = Vector2(BODY_SIZE, BODY_SIZE)
		body.position = CENTERS[i] - body.size * 0.5
		add_child(body)
		_bodies.append(body)
		_build_card(i, dest)

	_label("<-> ELEGIR DESTINO   ·   ENTER: VER SITIOS   ·   CLIC EN PUNTO VERDE: VER MISIÓN   ·   ESC: MENÚ",
		10, Color("#80f2ff"), Vector2(0, 340), Vector2(640, 14))

	_build_site_panel()
	add_child(DrawNode.new(_draw_radar))

	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/crt_overlay.gdshader")
	mat.set_shader_parameter("scanline_strength", 0.12)
	mat.set_shader_parameter("vignette_strength", 0.4)
	crt.material = mat
	add_child(crt)


func _build_card(i: int, dest: Dictionary) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.12, 0.85)
	sb.border_color = CARD_BLUE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(CENTERS[i].x - 88, 222)
	card.custom_minimum_size = Vector2(176, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var t := _label(dest["name"], 14, RetroTheme.AMBER, Vector2.ZERO, Vector2.ZERO, box)
	_card_titles.append(t)
	_label(dest["missions_line"], 10, RetroTheme.WHITE, Vector2.ZERO, Vector2.ZERO, box)
	var done := 0
	for s in dest["sites"]:
		if GameManager.is_completed(_mission_id_for(s)):
			done += 1
	var count := String(dest["count_label"])
	if done > 0:
		count += "  ·  %d COMPLETADO" % done
	_label(count, 10, RetroTheme.PHOSPHOR, Vector2.ZERO, Vector2.ZERO, box)
	_cards.append(card)


func _build_site_panel() -> void:
	_site_panel = PanelContainer.new()
	_site_panel.position = Vector2(150, 90)
	_site_panel.custom_minimum_size = Vector2(340, 0)
	add_child(_site_panel)
	var box := VBoxContainer.new()
	_site_panel.add_child(box)
	_site_title = _label("", 14, RetroTheme.AMBER, Vector2.ZERO, Vector2.ZERO, box)
	_site_buttons = HBoxContainer.new()
	box.add_child(_site_buttons)
	_site_info = _label("", 11, RetroTheme.WHITE, Vector2.ZERO, Vector2.ZERO, box)
	_site_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_site_info.custom_minimum_size = Vector2(320, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var close := Button.new()
	close.text = "[ESC] CERRAR"
	close.pressed.connect(_close_site_panel)
	row.add_child(close)
	_start_btn = Button.new()
	_start_btn.text = "> INICIAR MISIÓN"
	_start_btn.pressed.connect(_on_start_pressed)
	row.add_child(_start_btn)
	_site_panel.hide()


func _label(text: String, font_size: int, color: Color, pos: Vector2, sz: Vector2, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent == null:
		l.position = pos
		l.size = sz
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
	else:
		parent.add_child(l)
	return l


func _mission_id_for(site: Dictionary) -> String:
	var scene := String(site.get("scene", ""))
	if scene.contains("apolo11"):
		return "apolo11"
	if scene.contains("surveyor3"):
		return "surveyor3"
	if scene.contains("pioneer"):
		return "pioneer"
	return "gemelas"


# =========================================================================
# Dibujo: órbitas punteadas, anillos del seleccionado y radar de la transición
# =========================================================================
func _draw_orbits(c: DrawNode) -> void:
	_t = c.t
	if _busy:
		return
	for i in _bodies.size():
		var center: Vector2 = CENTERS[i]
		for k in 40:
			var a := k * TAU / 40.0 + c.t * 0.1
			c.draw_rect(Rect2(center + Vector2(cos(a), sin(a) * 0.3) * 80.0, Vector2(2, 1)), Color(1, 1, 1, 0.25))
	# Anillos concéntricos que se expanden alrededor del destino elegido.
	var sc: Vector2 = CENTERS[_selected]
	for k in 3:
		var f := fmod(c.t * 0.6 + k / 3.0, 1.0)
		c.draw_arc(sc, 64.0 + f * 26.0, 0.0, TAU, 48, Color(RetroTheme.AMBER, (1.0 - f) * 0.6), 1.0)


func _draw_radar(c: DrawNode) -> void:
	if _radar_t < 0.0:
		return
	var center := Vector2(320, 180)
	for k in 4:
		var f := fmod(c.t * 0.8 + k * 0.25, 1.0)
		c.draw_arc(center, 6.0 + f * 160.0, 0.0, TAU, 64, Color(RetroTheme.PHOSPHOR, (1.0 - f) * 0.9), 2.0)
	c.draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), RetroTheme.PHOSPHOR)


# =========================================================================
# Selección
# =========================================================================
func _select(i: int) -> void:
	_selected = clampi(i, 0, _bodies.size() - 1)
	for k in _cards.size():
		var on := k == _selected
		_cards[k].modulate.a = 1.0 if on else 0.6
		var dest: Dictionary = _destinations[k]
		_card_titles[k].text = ("> " if on else "") + String(dest["name"])


func _process(_delta: float) -> void:
	if _busy:
		return
	# Resaltar el punto verde bajo el ratón.
	for b in _bodies:
		b.set("hovered", -1 if _site_panel.visible else b.call("get_site_at", b.get_local_mouse_position()))


func _input(event: InputEvent) -> void:
	if _busy:
		return
	if _site_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_site_panel()
		return
	if event.is_action_pressed("ui_left"):
		_select(_selected - 1)
	elif event.is_action_pressed("ui_right"):
		_select(_selected + 1)
	elif event.is_action_pressed("ui_accept"):
		_open_site_panel(_selected, 0)
	elif event.is_action_pressed("ui_cancel"):
		_busy = true
		SceneTransition.change_scene(MENU_SCENE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _bodies.size():
			var b := _bodies[i]
			var idx: int = b.call("get_site_at", b.get_local_mouse_position())
			if idx >= 0:
				_select(i)
				_open_site_panel(i, idx)
				break
			if (CENTERS[i] as Vector2).distance_to(get_local_mouse_position()) < BODY_SIZE * 0.5 \
				or _cards[i].get_rect().has_point(get_local_mouse_position()):
				_select(i)
				break
	elif event is InputEventMouseMotion:
		for i in _bodies.size():
			if (CENTERS[i] as Vector2).distance_to(get_local_mouse_position()) < BODY_SIZE * 0.55 and i != _selected:
				_select(i)
	else:
		return
	get_viewport().set_input_as_handled()


# =========================================================================
# Ficha del sitio
# =========================================================================
func _open_site_panel(dest_index: int, site_index: int) -> void:
	_panel_dest = dest_index
	var dest: Dictionary = _destinations[dest_index]
	_site_title.text = String(dest["name"]) + " · SITIOS DETECTADOS"
	for c in _site_buttons.get_children():
		_site_buttons.remove_child(c)
		c.queue_free()
	var group := ButtonGroup.new()
	var sites: Array = dest["sites"]
	for i in sites.size():
		var b := Button.new()
		b.text = String(sites[i]["name"])
		b.toggle_mode = true
		b.button_group = group
		b.toggled.connect(_on_site_toggled.bind(i))
		b.focus_entered.connect(func() -> void: b.button_pressed = true)
		_site_buttons.add_child(b)
	_site_panel.show()
	var chosen := _site_buttons.get_child(site_index) as Button
	chosen.button_pressed = true
	_show_site(site_index)
	_start_btn.grab_focus()


func _on_site_toggled(on: bool, i: int) -> void:
	if on:
		_show_site(i)


func _show_site(i: int) -> void:
	_panel_site = i
	var site: Dictionary = _destinations[_panel_dest]["sites"][i]
	var done := GameManager.is_completed(_mission_id_for(site))
	_site_info.text = "%s · %s\n%s\n\nMISIÓN: \"%s\"%s" % [
		site["place"], site["year"], site["equipment"], site.get("mission_title", ""),
		"\n[COMPLETADA]" if done else "",
	]


func _close_site_panel() -> void:
	_site_panel.hide()


# =========================================================================
# Transición: zoom hacia el punto verde con ondas de radar
# =========================================================================
func _on_start_pressed() -> void:
	if _busy or _panel_site < 0:
		return
	_busy = true
	_site_panel.hide()
	var body := _bodies[_panel_dest]
	var site: Dictionary = _destinations[_panel_dest]["sites"][_panel_site]
	GameManager.current_site = site
	if body is PixelPlanet:
		await (body as PixelPlanet).face_site(_panel_site, 0.6)
	else:
		await (body as DeepSpaceView).face_site(_panel_site, 0.6)

	var fade := create_tween().set_parallel()
	for i in _bodies.size():
		if i != _panel_dest:
			fade.tween_property(_bodies[i], "modulate:a", 0.0, 0.4)
	for c in _cards:
		fade.tween_property(c, "modulate:a", 0.0, 0.4)

	# El punto del sitio queda fijo en el centro de la pantalla mientras el cuerpo crece.
	var local: Vector2 = body.call("get_site_local_pos", _panel_site)
	body.pivot_offset = local
	var zoom := create_tween().set_parallel()
	zoom.tween_property(body, "position", Vector2(320, 180) - local, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(body, "scale", Vector2(6, 6), 1.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.9).timeout
	_radar_t = 0.0
	await zoom.finished
	await get_tree().create_timer(0.6).timeout
	SceneTransition.change_scene(String(site["scene"]), 0.4)
