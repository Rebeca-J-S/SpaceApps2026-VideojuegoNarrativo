extends Control
## Escena 1 — Pantalla de inicio dentro de la nave.
## Secuencia: título -> registro de a bordo (máquina de escribir) -> "INICIAR" parpadeante.
## Los objetos que flotan en el pasillo son cosas reales que los astronautas dejaron en la Luna:
## al pasar el ratón por encima se muestra su ficha.

const NEXT_SCENE := "res://scenes/ui/main_menu.tscn"
const TYPE_SPEED := 32.0      # caracteres por segundo
const LINE_PAUSE := 0.4       # pausa entre líneas (s)

## Primera línea en ámbar (cabecera del registro), el resto es la narración.
const OPENING_LINES := [
	"REGISTRO DE A BORDO · AÑO 2026 · RUMBO: LA LUNA Y MARTE",
	"Desde 1969, la humanidad ha dejado máquinas en otros mundos.",
	"Módulos, rovers, sismómetros... y hasta botas y fotografías.",
	"Algunas siguen funcionando. Otras solo esperan ser recordadas.",
	"Esta nave va a escuchar sus historias.",
]

enum State { INTRO, TYPING, READY, LEAVING }

@onready var corridor: ShipCorridor = %ShipCorridor
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var narrative_panel: PanelContainer = %NarrativePanel
@onready var narrative_box: VBoxContainer = %NarrativeBox
@onready var prompt: Label = %Prompt
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_label: Label = %TooltipLabel

var _state: State = State.INTRO
var _sequence: Tween
var _blink: Tween
var _lines: Array[Label] = []


func _ready() -> void:
	theme = RetroTheme.build()
	title.text = MissionData.GAME_TITLE
	_build_narrative_labels()
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	narrative_panel.modulate.a = 0.0
	prompt.modulate.a = 0.0
	tooltip.hide()
	_play_sequence()


func _process(_delta: float) -> void:
	_update_tooltip()


## Un Label por línea: el efecto máquina de escribir usa visible_characters
## y el texto centrado no "baila" mientras se escribe.
func _build_narrative_labels() -> void:
	for i in OPENING_LINES.size():
		var l := Label.new()
		l.text = OPENING_LINES[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible_characters = 0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			l.add_theme_color_override("font_color", RetroTheme.AMBER)
			l.add_theme_font_size_override("font_size", 10)
		narrative_box.add_child(l)
		_lines.append(l)


func _play_sequence() -> void:
	_sequence = create_tween()
	# 1) Título, subtítulo y panel del registro.
	_sequence.tween_interval(0.4)
	_sequence.tween_property(title, "modulate:a", 1.0, 1.0)
	_sequence.tween_property(subtitle, "modulate:a", 1.0, 0.6)
	_sequence.tween_property(narrative_panel, "modulate:a", 1.0, 0.3)
	_sequence.tween_callback(func() -> void: _state = State.TYPING)
	# 2) Máquina de escribir, línea a línea.
	for l in _lines:
		var duration := l.text.length() / TYPE_SPEED
		_sequence.tween_property(l, "visible_characters", l.text.length(), duration).from(0)
		_sequence.tween_interval(LINE_PAUSE)
	# 3) Listo para avanzar.
	_sequence.tween_callback(_on_sequence_done)


func _on_sequence_done() -> void:
	_state = State.READY
	_start_blink()


func _start_blink() -> void:
	# Parpadeo "duro" estilo arcade: encendido / apagado sin fundido.
	_blink = create_tween().set_loops()
	_blink.tween_property(prompt, "modulate:a", 1.0, 0.0)
	_blink.tween_interval(0.6)
	_blink.tween_property(prompt, "modulate:a", 0.0, 0.0)
	_blink.tween_interval(0.35)


## Completa la secuencia de golpe (el jugador tiene prisa).
func _skip_sequence() -> void:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	title.modulate.a = 1.0
	subtitle.modulate.a = 1.0
	narrative_panel.modulate.a = 1.0
	for l in _lines:
		l.visible_characters = -1
	_on_sequence_done()


# -------------------------------------------------------------------------
# Ficha flotante de los objetos del pasillo
# -------------------------------------------------------------------------
func _update_tooltip() -> void:
	var index := corridor.get_item_at(corridor.get_local_mouse_position())
	corridor.highlighted = index
	if index < 0 or _state == State.LEAVING:
		tooltip.hide()
		return
	var info := corridor.get_item_info(index)
	var text := "%s\n%s" % [info["title"], info["info"]]
	if tooltip_label.text != text:
		tooltip_label.text = text
		tooltip.reset_size()
	tooltip.show()
	var p := get_local_mouse_position() + Vector2(12, 10)
	p.x = minf(p.x, size.x - tooltip.size.x - 4)
	p.y = minf(p.y, size.y - tooltip.size.y - 4)
	tooltip.position = p.floor()


# -------------------------------------------------------------------------
# Entrada
# -------------------------------------------------------------------------
# _input (y no _unhandled_input) para capturar clics aunque haya Controls encima.
func _input(event: InputEvent) -> void:
	if not _is_advance_event(event):
		return
	get_viewport().set_input_as_handled()
	match _state:
		State.INTRO, State.TYPING:
			_skip_sequence()
		State.READY:
			_leave()


func _is_advance_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):  # Enter, Espacio, botón A del mando.
		return true
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:  # Tablets / móviles en la versión web.
		return event.pressed
	return false


func _leave() -> void:
	_state = State.LEAVING
	if _blink and _blink.is_valid():
		_blink.kill()
	# Parpadeo rápido de confirmación y fundido al menú.
	prompt.text = "> TRANSMISIÓN RECIBIDA <"
	var confirm := create_tween().set_loops(4)
	confirm.tween_property(prompt, "modulate:a", 1.0, 0.0)
	confirm.tween_interval(0.06)
	confirm.tween_property(prompt, "modulate:a", 0.2, 0.0)
	confirm.tween_interval(0.06)
	await confirm.finished
	prompt.modulate.a = 1.0
	SceneTransition.change_scene(NEXT_SCENE)
