extends Control
## Escena 1 — Pantalla de inicio dentro de la nave abandonada (Referencia A).
## Secuencia:
##   1) Fundido desde negro.  2) Aparece el título WHAT WAS LEFT BEHIND.
##   3) Transmisión de radio (RadioDialog) con estática y máquina de escribir.
##   4) "PRESIONA ENTER O HAZ CLIC PARA INICIAR" parpadeante.
## Una pulsación durante el texto lo completa; la siguiente avanza. Al iniciar, la cámara vuela
## por el pasillo hacia la Luna de la ventana y pasa al menú principal.
## Los objetos flotantes muestran su ficha al pasar el ratón.

const NEXT_SCENE := "res://scenes/ui/main_menu.tscn"
const DIALOG_FILE := "res://data/dialogos/intro.json"

enum State { INTRO, RADIO, READY, LEAVING }

@onready var corridor: ShipCorridor = %ShipCorridor
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var prompt: Label = %Prompt
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_label: Label = %TooltipLabel
@onready var fade: ColorRect = %FadeFromBlack

var _state: State = State.INTRO
var _sequence: Tween
var _blink: Tween
var _radio: RadioDialog


func _ready() -> void:
	theme = RetroTheme.build()
	title.text = MissionData.GAME_TITLE
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	prompt.modulate.a = 0.0
	tooltip.hide()
	_radio = RadioDialog.new()
	add_child(_radio)
	move_child(_radio, fade.get_index())  # Debajo del fundido y del overlay CRT.
	_play_sequence()


func _process(_delta: float) -> void:
	_update_tooltip()


func _play_sequence() -> void:
	_sequence = create_tween()
	# 1) Fundido desde negro en pasos (estilo retro).
	_sequence.tween_method(func(v: float) -> void: fade.modulate.a = snappedf(v, 0.125), 1.0, 0.0, 1.2)
	# 2) Título y subtítulo.
	_sequence.tween_property(title, "modulate:a", 1.0, 1.0)
	_sequence.tween_property(subtitle, "modulate:a", 1.0, 0.6)
	_sequence.tween_interval(0.3)
	_sequence.tween_callback(_start_radio)


## 3) Transmisión de radio. Al terminar, aparece el aviso para iniciar.
func _start_radio() -> void:
	if _state != State.INTRO:
		return
	_state = State.RADIO
	await _radio.play_file(DIALOG_FILE, "apertura")
	_state = State.READY
	_start_blink()


func _start_blink() -> void:
	# Parpadeo "duro" estilo arcade: encendido / apagado sin fundido.
	_blink = create_tween().set_loops()
	_blink.tween_property(prompt, "modulate:a", 1.0, 0.0)
	_blink.tween_interval(0.6)
	_blink.tween_property(prompt, "modulate:a", 0.0, 0.0)
	_blink.tween_interval(0.35)


## Si el jugador pulsa durante el fundido o el título, salta directamente a la radio.
func _skip_intro() -> void:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	fade.modulate.a = 0.0
	title.modulate.a = 1.0
	subtitle.modulate.a = 1.0
	_start_radio()


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
# Entrada (la radio gestiona sus propias pulsaciones mientras está activa)
# -------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not _is_advance_event(event) or _state == State.RADIO:
		return
	get_viewport().set_input_as_handled()
	match _state:
		State.INTRO:
			_skip_intro()
		State.READY:
			_leave()


func _is_advance_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):  # Enter, Espacio, botón A del mando.
		return true
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _leave() -> void:
	_state = State.LEAVING
	if _blink and _blink.is_valid():
		_blink.kill()
	tooltip.hide()
	corridor.highlighted = -1
	# Parpadeo rápido de confirmación.
	prompt.text = "> TRANSMISIÓN RECIBIDA <"
	var confirm := create_tween().set_loops(3)
	confirm.tween_property(prompt, "modulate:a", 1.0, 0.0)
	confirm.tween_interval(0.06)
	confirm.tween_property(prompt, "modulate:a", 0.2, 0.0)
	confirm.tween_interval(0.06)
	await confirm.finished
	# La interfaz se apaga y la cámara vuela por el pasillo hacia la Luna de la ventana.
	var fly := create_tween().set_parallel()
	for ui in [title, subtitle, prompt]:
		fly.tween_property(ui, "modulate:a", 0.0, 0.3)
	fly.tween_property(corridor, "zoom", 12.0, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await fly.finished
	SceneTransition.change_scene(NEXT_SCENE, 0.35)
