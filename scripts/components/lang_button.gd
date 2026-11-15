class_name LangButton
extends Button
## Botón de idioma "EN | ES" (inglés por defecto). Al pulsarlo (o la tecla L) cambia el idioma
## y recarga la escena actual para que todos los textos (JSON y código) se vuelvan a cargar.
## Uso: add_child(LangButton.new()) en pantallas de menú (no dentro de una misión en curso).

func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", 10)
	tooltip_text = "Language / Idioma (L)"


func _ready() -> void:
	_refresh()
	pressed.connect(_toggle)
	if position == Vector2.ZERO:
		# Esquina superior derecha por defecto.
		await get_tree().process_frame
		position = Vector2(640.0 - size.x - 6.0, 6.0)


func _refresh() -> void:
	text = "[EN] ES" if GameManager.lang == "en" else "EN [ES]"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		get_viewport().set_input_as_handled()
		_toggle()


func _toggle() -> void:
	GameManager.toggle_language()
	_refresh()
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		SceneTransition.change_scene(scene.scene_file_path, 0.2)
