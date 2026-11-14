extends Control
## PLACEHOLDER de la Fase 0 (estabilización orbital a 14.5 km).
## Existe solo para que "INICIAR MISIÓN" tenga destino. Se reemplazará por el gameplay real.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	theme = RetroTheme.build()
	%Info.text = "FASE 0 · ESTABILIZACIÓN ORBITAL\nALTITUD: %.1f km · GRAVEDAD LUNAR: %.2f m/s²\n\n(Escena en construcción)\n\nESC: volver al menú" % [
		MissionData.ORBIT_ALT_KM, MissionData.MOON_GRAVITY,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.change_scene(MENU_SCENE)
