extends Control
## PLACEHOLDER de la Fase 0 (estabilización orbital a 14.5 km).
## Existe solo para que el destino "LA LUNA" tenga escena. Se reemplazará por el gameplay real.

const BACK_SCENE := "res://scenes/ui/mission_select.tscn"


func _ready() -> void:
	theme = RetroTheme.build()
	%Info.text = "LA LUNA · APOLO 11\nFASE 0 · ESTABILIZACIÓN ORBITAL\nALTITUD: %.1f km · GRAVEDAD LUNAR: %.2f m/s²\n\n(Escena en construcción)\n\nESC: volver a la selección de destino" % [
		MissionData.ORBIT_ALT_KM, MissionData.MOON_GRAVITY,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.change_scene(BACK_SCENE)
