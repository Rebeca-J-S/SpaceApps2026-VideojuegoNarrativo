extends Node
## Autoload "GameManager": datos del juego (JSON), progreso guardado y acciones de entrada.
##
## - Los datos de sitios, archivo y diálogos viven en res://data/ para poder corregirlos
##   sin tocar el código.
## - El progreso (misiones completadas) se guarda en user://progreso.cfg con ConfigFile.
## - Las acciones del Input Map se registran aquí por código. Si prefieres crearlas a mano
##   en Project Settings > Input Map, usa los mismos nombres y teclas (ver INPUT_ACTIONS).

const SAVE_PATH := "user://progreso.cfg"
const SITES_PATH := "res://data/sites.json"
const ARCHIVE_PATH := "res://data/archive.json"
const PLANET_SELECT_SCENE := "res://scenes/ui/planet_select.tscn"

## Acciones del Input Map: nombre -> teclas (físicas).
## ui_accept (Enter/Espacio) y ui_cancel (Esc) ya vienen con Godot.
const INPUT_ACTIONS := {
	"thrust": [KEY_W, KEY_UP, KEY_SPACE],       # empuje principal / acción de la fase
	"move_down": [KEY_S, KEY_DOWN],             # bajar (Pioneer en el cinturón)
	"rotate_left": [KEY_A, KEY_LEFT],           # propulsores RCS / girar / empujar a la izquierda
	"rotate_right": [KEY_D, KEY_RIGHT],         # propulsores RCS / girar / empujar a la derecha
}

## Sitio elegido en el selector (lo leen las misiones: p. ej. qué gemela de Marte).
var current_site: Dictionary = {}

var _completed: Dictionary = {}
var _cache: Dictionary = {}
var _start_phase := 0


func _ready() -> void:
	_register_input_actions()
	_load_progress()


# -------------------------------------------------------------------------
# Datos JSON
# -------------------------------------------------------------------------
func load_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("GameManager: no existe %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("GameManager: JSON inválido en %s" % path)
		return {}
	_cache[path] = parsed
	return parsed


func get_destinations() -> Array:
	var data: Dictionary = load_json(SITES_PATH)
	return data.get("destinations", [])


func get_archive() -> Dictionary:
	return load_json(ARCHIVE_PATH)


## Busca un sitio por id en todos los destinos.
func find_site(site_id: String) -> Dictionary:
	for dest in get_destinations():
		for site in dest["sites"]:
			if site["id"] == site_id:
				return site
	return {}


# -------------------------------------------------------------------------
# Progreso
# -------------------------------------------------------------------------
func is_completed(mission_id: String) -> bool:
	return _completed.get(mission_id, false)


func mark_completed(mission_id: String) -> void:
	_completed[mission_id] = true
	var cfg := ConfigFile.new()
	for id in _completed.keys():
		cfg.set_value("misiones", id, true)
	cfg.save(SAVE_PATH)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("misiones"):
		for id in cfg.get_section_keys("misiones"):
			_completed[id] = bool(cfg.get_value("misiones", id, false))


# -------------------------------------------------------------------------
# Reinicio de fase: la escena de misión se recarga y empieza en esta fase.
# -------------------------------------------------------------------------
func set_start_phase(index: int) -> void:
	_start_phase = index


func consume_start_phase() -> int:
	var p := _start_phase
	_start_phase = 0
	return p


func go_to_planet_select() -> void:
	get_tree().paused = false
	SceneTransition.change_scene(PLANET_SELECT_SCENE)


# -------------------------------------------------------------------------
# Input Map
# -------------------------------------------------------------------------
func _register_input_actions() -> void:
	for action in INPUT_ACTIONS.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in INPUT_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
