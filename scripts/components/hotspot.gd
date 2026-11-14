class_name Hotspot
extends Node2D
## Punto interactivo brillante para las fases de ciencia.
## Se activa con clic o con la tecla de su número (1, 2, 3...). Emite "activated".

signal activated(hotspot: Hotspot)

@export var label_text := ""
@export var number := 1
@export var radius := 9.0
@export var color := Color("#39ff7a")

var used := false
var enabled := true
var _t := 0.0
var _hover := false


func _init(text: String = "", num: int = 1, pos: Vector2 = Vector2.ZERO) -> void:
	label_text = text
	number = num
	position = pos


func _process(delta: float) -> void:
	_t += delta
	_hover = enabled and not used and get_local_mouse_position().length() <= radius + 4.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or used or get_tree().paused:
		return
	var hit := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = get_local_mouse_position().length() <= radius + 4.0
	elif event is InputEventKey and event.pressed and not event.echo:
		hit = event.physical_keycode == KEY_1 + number - 1 or event.physical_keycode == KEY_KP_1 + number - 1
	if hit:
		get_viewport().set_input_as_handled()
		used = true
		activated.emit(self)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if used:
		draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 16, Color(color, 0.4), 1.0)
		draw_string(font, Vector2(radius + 4, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color, 0.45))
		return
	if not enabled:
		return
	# Anillos pulsantes (estilo radar).
	var pulse := fmod(_t * 1.2, 1.0)
	draw_arc(Vector2.ZERO, radius + pulse * 10.0, 0.0, TAU, 20, Color(color, 1.0 - pulse), 1.0)
	draw_circle(Vector2.ZERO, radius * 0.55, Color(color, 0.85 if _hover else 0.55))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(1, 0.7, 0.28) if _hover else color, 1.0)
	# Etiqueta "[1] TEXTO" con fondo para que se lea sobre cualquier decorado.
	var text := "[%d] %s" % [number, label_text]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_rect(Rect2(radius + 3, -8, w + 6, 13), Color(0.01, 0.03, 0.03, 0.8))
	draw_string(font, Vector2(radius + 6, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.7, 0.28) if _hover else color)
