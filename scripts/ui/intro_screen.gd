extends Control
## Escena 1 — Pantalla de inicio.
## Secuencia: título aparece -> narración del Eagle (máquina de escribir) -> prompt parpadeante.
## Cualquier pulsación durante la secuencia la completa al instante; la siguiente avanza al menú.

const NEXT_SCENE := "res://scenes/ui/main_menu.tscn"
const TYPE_SPEED := 30.0      # caracteres por segundo
const LINE_PAUSE := 0.45      # pausa entre líneas (s)

## Primera línea en ámbar (cabecera de telemetría), el resto es la voz del Eagle.
const OPENING_LINES := [
	"20 DE JULIO DE 1969 · MARE TRANQUILLITATIS · 20:17 UTC",
	"Soy la Etapa de Descenso del Eagle. Me llamaban LM-5.",
	"Traje a dos humanos hasta aquí... y después me quedé.",
	"Esta es la historia de las máquinas que nunca volvieron.",
]

enum State { INTRO, TYPING, READY, LEAVING }

@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var narrative_box: VBoxContainer = %NarrativeBox
@onready var prompt: Label = %Prompt

var _state: State = State.INTRO
var _sequence: Tween
var _blink: Tween
var _lines: Array[Label] = []


func _ready() -> void:
	theme = RetroTheme.build()
	_build_narrative_labels()
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	prompt.modulate.a = 0.0
	_play_sequence()


## Crea un Label por línea. Así el efecto máquina de escribir usa visible_characters
## sin problemas de saltos de línea, y el texto centrado no "baila" al escribirse.
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
	# 1) Título y subtítulo.
	_sequence.tween_property(title, "modulate:a", 1.0, 1.2)
	_sequence.tween_property(subtitle, "modulate:a", 1.0, 0.8)
	_sequence.tween_interval(0.5)
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


## Completa toda la secuencia de golpe (el jugador tiene prisa).
func _skip_sequence() -> void:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	title.modulate.a = 1.0
	subtitle.modulate.a = 1.0
	for l in _lines:
		l.visible_characters = -1
	_on_sequence_done()


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
	# Parpadeo rápido de confirmación ("TRANSMISIÓN RECIBIDA") y fundido al menú.
	prompt.text = "TRANSMISIÓN RECIBIDA"
	var confirm := create_tween().set_loops(4)
	confirm.tween_property(prompt, "modulate:a", 1.0, 0.0)
	confirm.tween_interval(0.06)
	confirm.tween_property(prompt, "modulate:a", 0.2, 0.0)
	confirm.tween_interval(0.06)
	await confirm.finished
	prompt.modulate.a = 1.0
	SceneTransition.change_scene(NEXT_SCENE)
