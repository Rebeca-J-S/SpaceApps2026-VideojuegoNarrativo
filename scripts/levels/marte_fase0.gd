extends Control
## PLACEHOLDER de la expedición a Marte. Se reemplazará por el gameplay real.

const BACK_SCENE := "res://scenes/ui/mission_select.tscn"


func _ready() -> void:
	theme = RetroTheme.build()
	%Info.text = "MARTE · EXPEDICIÓN 1976-2024\nViking 1 · Sojourner · Opportunity · InSight · Ingenuity\n\n(Escena en construcción)\n\nESC: volver a la selección de destino"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.change_scene(BACK_SCENE)
