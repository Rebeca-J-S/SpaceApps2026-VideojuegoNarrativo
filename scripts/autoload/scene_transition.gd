extends CanvasLayer
## Autoload "SceneTransition": fundido a negro escalonado (look retro) entre escenas.
## Uso: SceneTransition.change_scene("res://scenes/ui/main_menu.tscn")

signal transition_finished

## Número de "pasos" del fundido. Menos pasos = más retro/escalonado.
const FADE_STEPS := 8.0

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100  # Siempre por encima de todo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func is_busy() -> bool:
	return _busy


## Fundido a negro -> cambio de escena -> fundido desde negro.
func change_scene(path: String, duration: float = 0.6) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # Bloquea clics durante la transición.

	await _fade_to(1.0, duration)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: no se pudo cargar '%s' (error %d)" % [path, err])
	# change_scene_to_file es diferido: esperamos a que la nueva escena exista.
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade_to(0.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	transition_finished.emit()


func _fade_to(target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_stepped_alpha, _rect.modulate.a, target, duration)
	await tw.finished


func _set_stepped_alpha(value: float) -> void:
	# Cuantiza la opacidad en pasos discretos: fundido "pixelado" estilo 8/16 bits.
	_rect.modulate.a = snappedf(value, 1.0 / FADE_STEPS)
