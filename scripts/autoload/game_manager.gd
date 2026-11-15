extends Node
## Autoload "GameManager": datos del juego (JSON), progreso guardado y acciones de entrada.
##
## - Los datos de sitios, archivo y diálogos viven en res://data/ para poder corregirlos
##   sin tocar el código.
## - El progreso (misiones completadas) se guarda en user://progreso.cfg con ConfigFile.
## - Las acciones del Input Map se registran aquí por código. Si prefieres crearlas a mano
##   en Project Settings > Input Map, usa los mismos nombres y teclas (ver INPUT_ACTIONS).
## - Idioma: inglés por defecto, español con el botón EN | ES. Los textos fuente están en español
##   (JSON y código); data/i18n/en/*.json guarda las parejas "texto en español" -> "English text".
##   Los JSON se traducen al cargarse y el código usa tr() (el catálogo se registra en Godot).
##   Si falta una traducción se muestra el texto en español y, en depuración, avisa por consola.

const SAVE_PATH := "user://progreso.cfg"
const SITES_PATH := "res://data/sites.json"
const ARCHIVE_PATH := "res://data/archive.json"
const BADGES_PATH := "res://data/badges.json"
const PLANET_SELECT_SCENE := "res://scenes/ui/planet_select.tscn"
const I18N_DIR := "res://data/i18n/en/"
## Archivos del catálogo inglés (lista fija: en una exportación no conviene listar carpetas).
const I18N_FILES := ["ui", "sites", "archive", "intro", "apolo11", "spirit_opportunity", "pioneer10", "badges"]
## Claves de los JSON que son identificadores (no se traducen).
const I18N_SKIP_KEYS := ["id", "speaker", "portrait", "mode", "scene", "color", "kind", "twin", "action", "missions", "mission", "sections", "link", "site", "icon", "body"]

signal language_changed(lang: String)

## Acciones del Input Map: nombre -> teclas (físicas).
## ui_accept (Enter/Espacio) y ui_cancel (Esc) ya vienen con Godot.
const INPUT_ACTIONS := {
	"thrust": [KEY_W, KEY_UP, KEY_SPACE],       # empuje principal / acción de la fase
	"move_down": [KEY_S, KEY_DOWN],             # bajar (Pioneer en el cinturón)
	"rotate_left": [KEY_A, KEY_LEFT],           # propulsores RCS / girar / empujar a la izquierda
	"rotate_right": [KEY_D, KEY_RIGHT],         # propulsores RCS / girar / empujar a la derecha
	"interact": [KEY_E],                        # recoger / usar (Apolo 11: recolección)
}

## Sitio elegido en el selector (lo leen las misiones: p. ej. qué gemela de Marte).
var current_site: Dictionary = {}

var _completed: Dictionary = {}
## Insignias: id -> piezas ganadas (índices de fase).
var _badges: Dictionary = {}

signal badge_piece_unlocked(badge_id: String, index: int, total: int)
var _cache: Dictionary = {}
var _start_phase := 0

## Idioma actual: "en" (por defecto) o "es".
var lang := "en"
var _en: Dictionary = {}
var _tr_en: Translation
var _missing: Dictionary = {}
var _IDENT := RegEx.create_from_string("^[a-z0-9_]+$")


func _ready() -> void:
	_register_input_actions()
	_load_progress()
	_load_catalog()
	_apply_locale()


# -------------------------------------------------------------------------
# Idioma
# -------------------------------------------------------------------------
func set_language(code: String) -> void:
	if code == lang:
		return
	lang = code
	_apply_locale()
	_cache.clear()
	_save()
	language_changed.emit(lang)


func toggle_language() -> void:
	set_language("es" if lang == "en" else "en")


## Traduce un texto fuente (en español) al idioma actual.
func t(text: String) -> String:
	if lang != "en" or text == "":
		return text
	if _en.has(text):
		return _en[text]
	_warn_missing(text)
	return text


func _load_catalog() -> void:
	for name in I18N_FILES:
		var path: String = I18N_DIR + name + ".json"
		if not FileAccess.file_exists(path):
			push_warning("i18n: no existe %s" % path)
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			for k in d:
				if not String(k).begins_with("_"):
					_en[k] = d[k]
	var tr_en := Translation.new()
	tr_en.locale = "en"
	_tr_en = tr_en
	for k in _en:
		tr_en.add_message(k, _en[k])
		# Las escenas .tscn guardadas con CRLF traen los saltos de línea como \r\n.
		if String(k).contains("\n"):
			tr_en.add_message(String(k).replace("\n", "\r\n"), _en[k])


## El catálogo inglés solo está registrado en inglés: Godot usa "en" como idioma de respaldo y,
## si siguiera registrado, traduciría al inglés también en español.
func _apply_locale() -> void:
	TranslationServer.set_locale(lang)
	if _tr_en == null:
		return
	var registered := TranslationServer.get_translation_object("en") == _tr_en
	if lang == "en" and not registered:
		TranslationServer.add_translation(_tr_en)
	elif lang != "en":
		TranslationServer.remove_translation(_tr_en)


func _warn_missing(text: String) -> void:
	if not OS.is_debug_build() or _missing.has(text):
		return
	var letters := RegEx.create_from_string("[A-Za-zÁÉÍÓÚÑáéíóúñ]{2}")
	if letters.search(text) == null:
		return
	_missing[text] = true
	push_warning("i18n: falta la traducción al inglés de: \"%s\"" % text)


func _translate_data(v: Variant) -> Variant:
	if v is String:
		# Identificadores (acciones del Input Map, claves): no se traducen.
		return v if _IDENT.search(v) != null else t(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_translate_data(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			var key := String(k)
			out[k] = v[k] if (key in I18N_SKIP_KEYS or key.begins_with("_") or key.begins_with("verificar")) else _translate_data(v[k])
		return out
	return v


# -------------------------------------------------------------------------
# Datos JSON
# -------------------------------------------------------------------------
func load_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var parsed: Variant = _load_json_raw(path)
	if lang == "en":
		parsed = _translate_data(parsed)
	_cache[path] = parsed
	return parsed


func _load_json_raw(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameManager: no existe %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("GameManager: JSON inválido en %s" % path)
		return {}
	return parsed


func get_destinations() -> Array:
	var data: Dictionary = load_json(SITES_PATH)
	return data.get("destinations", [])


func get_archive() -> Dictionary:
	return load_json(ARCHIVE_PATH)


# -------------------------------------------------------------------------
# Cuaderno de insignias: cada fase completada de una misión gana una pieza.
# -------------------------------------------------------------------------
func get_badges() -> Array:
	var data: Dictionary = load_json(BADGES_PATH)
	return data.get("badges", [])


func find_badge(badge_id: String) -> Dictionary:
	for b in get_badges():
		if b["id"] == badge_id:
			return b
	return {}


## Índices de las piezas ganadas de una insignia.
func badge_pieces(badge_id: String) -> Array:
	return _badges.get(badge_id, [])


func is_badge_complete(badge_id: String) -> bool:
	var b := find_badge(badge_id)
	return not b.is_empty() and badge_pieces(badge_id).size() >= int(b["pieces"])


## Gana la pieza `index` de la insignia. Devuelve true si es nueva.
func unlock_badge_piece(badge_id: String, index: int) -> bool:
	var got: Array = _badges.get(badge_id, []).duplicate()
	if index in got:
		return false
	got.append(index)
	got.sort()
	_badges[badge_id] = got
	_save()
	var b := find_badge(badge_id)
	badge_piece_unlocked.emit(badge_id, index, int(b.get("pieces", 6)))
	return true


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
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in _completed.keys():
		cfg.set_value("misiones", id, true)
	cfg.set_value("ajustes", "idioma", lang)
	for id in _badges.keys():
		cfg.set_value("insignias", id, _badges[id])
	cfg.save(SAVE_PATH)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	lang = String(cfg.get_value("ajustes", "idioma", "en"))
	if cfg.has_section("insignias"):
		for id in cfg.get_section_keys("insignias"):
			var v: Variant = cfg.get_value("insignias", id, [])
			if v is Array:
				_badges[id] = v
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
