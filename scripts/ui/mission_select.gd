extends Control
## Selección de destino: la Luna o Marte.
## ← / → (o pasar el ratón) para elegir, ENTER / clic para confirmar, ESC para volver al menú.
## Al confirmar, la cámara hace zoom hacia el planeta elegido y carga su misión.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const DIM_ALPHA := 0.4

@onready var header: Label = %Header
@onready var sub_header: Label = %SubHeader
@onready var hint: Label = %Hint
@onready var selector: Node2D = %Selector

var _planets: Array[PixelPlanet] = []
var _cards: Array[PanelContainer] = []
var _selected := 0
var _confirmed := false
var _t := 0.0
var _fade_tweens: Array[Tween] = [null, null]


func _ready() -> void:
	theme = RetroTheme.build()
	_planets = [%Moon, %Mars]
	_cards = [%MoonCard, %MarsCard]
	for i in _cards.size():
		_fill_card(_cards[i], MissionData.DESTINATIONS[i])
	selector.draw.connect(_draw_selector)
	_select(0, true)
	_play_intro()


func _process(delta: float) -> void:
	_t += delta
	selector.queue_redraw()


func _fill_card(card: PanelContainer, dest: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_make_label(dest["name"], 14, RetroTheme.AMBER))
	box.add_child(_make_label(dest["mission"], 10, RetroTheme.PHOSPHOR_DIM))
	var desc := _make_label(dest["desc"], 10, RetroTheme.PHOSPHOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var hw := _make_label(dest["hardware"], 10, RetroTheme.WHITE)
	hw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hw)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _play_intro() -> void:
	for p in _planets:
		p.pivot_offset = p.size / 2.0
		p.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for p in _planets:
		tw.tween_property(p, "scale", Vector2.ONE, 0.6)


# -------------------------------------------------------------------------
# Selección
# -------------------------------------------------------------------------
func _select(index: int, instant: bool = false) -> void:
	if _confirmed:
		return
	_selected = index
	for i in _planets.size():
		var target := 1.0 if i == index else DIM_ALPHA
		if _fade_tweens[i] and _fade_tweens[i].is_valid():
			_fade_tweens[i].kill()
		if instant:
			_planets[i].modulate.a = target
			_cards[i].modulate.a = target
		else:
			var tw := create_tween().set_parallel()
			tw.tween_property(_planets[i], "modulate:a", target, 0.2)
			tw.tween_property(_cards[i], "modulate:a", target, 0.2)
			_fade_tweens[i] = tw


func _index_at(point: Vector2) -> int:
	for i in _planets.size():
		var p := _planets[i]
		var center := p.position + p.size / 2.0
		if point.distance_to(center) <= p.size.x / 2.0 or _cards[i].get_rect().has_point(point):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if _confirmed:
		return
	if event is InputEventMouseMotion:
		var i := _index_at(get_local_mouse_position())
		if i >= 0 and i != _selected:
			_select(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _index_at(get_local_mouse_position())
		if i >= 0:
			_select(i)
			_confirm()
	elif event.is_action_pressed("ui_left"):
		_select(0)
	elif event.is_action_pressed("ui_right"):
		_select(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_confirmed = true
		SceneTransition.change_scene(MENU_SCENE)
	else:
		return
	get_viewport().set_input_as_handled()


# -------------------------------------------------------------------------
# Confirmación: zoom hacia el planeta elegido
# -------------------------------------------------------------------------
func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	var dest: Dictionary = MissionData.DESTINATIONS[_selected]
	var planet := _planets[_selected]
	hint.text = "> RUMBO A %s <" % dest["name"]

	var tw := create_tween().set_parallel()
	for i in _planets.size():
		if i != _selected:
			tw.tween_property(_planets[i], "modulate:a", 0.0, 0.3)
	for c in _cards:
		tw.tween_property(c, "modulate:a", 0.0, 0.3)
	tw.tween_property(header, "modulate:a", 0.0, 0.3)
	tw.tween_property(sub_header, "modulate:a", 0.0, 0.3)
	tw.tween_property(selector, "modulate:a", 0.0, 0.2)
	# El planeta se centra y crece: la nave se acerca.
	planet.pivot_offset = planet.size / 2.0
	var center_pos := size / 2.0 - planet.size / 2.0
	tw.tween_property(planet, "position", center_pos, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(planet, "scale", Vector2(3.5, 3.5), 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw.finished
	SceneTransition.change_scene(dest["scene"], 0.35)


# -------------------------------------------------------------------------
# Corchetes ámbar alrededor del planeta seleccionado
# -------------------------------------------------------------------------
func _draw_selector() -> void:
	if _confirmed:
		return
	var p := _planets[_selected]
	var pad := 3.0 + roundf(1.0 + 1.0 * sin(_t * 4.0))  # "respiración" de 2 px (sin tocar la tarjeta)
	var r := Rect2(p.position - Vector2(pad, pad), p.size + Vector2(pad, pad) * 2.0)
	var l := 14.0
	var w := 2.0
	var c := RetroTheme.AMBER
	var tl := r.position
	var br := r.end
	selector.draw_rect(Rect2(tl, Vector2(l, w)), c)
	selector.draw_rect(Rect2(tl, Vector2(w, l)), c)
	selector.draw_rect(Rect2(Vector2(br.x - l, tl.y), Vector2(l, w)), c)
	selector.draw_rect(Rect2(Vector2(br.x - w, tl.y), Vector2(w, l)), c)
	selector.draw_rect(Rect2(Vector2(tl.x, br.y - w), Vector2(l, w)), c)
	selector.draw_rect(Rect2(Vector2(tl.x, br.y - l), Vector2(w, l)), c)
	selector.draw_rect(Rect2(br - Vector2(l, w), Vector2(l, w)), c)
	selector.draw_rect(Rect2(br - Vector2(w, l), Vector2(w, l)), c)
