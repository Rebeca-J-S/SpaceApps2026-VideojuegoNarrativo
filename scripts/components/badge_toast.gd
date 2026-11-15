class_name BadgeToast
extends Control
## Aviso breve en las misiones: "INSIGNIA · X — PIEZA 3 / 6 DESBLOQUEADA", con la insignia y la pieza
## nueva destellando. Baja desde arriba, se queda unos segundos y vuelve a subir. No detiene el juego.
## Uso: add_child(BadgeToast.new()) y luego show_piece(insignia, piezas_ganadas, indice).

const PANEL_SIZE := Vector2(250, 58)
const Y_SHOWN := 40.0

var _badge: Dictionary = {}
var _got: Array = []
var _index := -1
var _t := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	position = Vector2((640.0 - PANEL_SIZE.x) * 0.5, -PANEL_SIZE.y - 4.0)
	z_index = 50
	hide()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func show_piece(badge: Dictionary, got: Array, index: int) -> void:
	_badge = badge
	_got = got
	_index = index
	_t = 0.0
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", Y_SHOWN, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(2.6)
	_tween.tween_property(self, "position:y", -PANEL_SIZE.y - 4.0, 0.3).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


func _draw() -> void:
	if _badge.is_empty():
		return
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	var complete := _got.size() >= int(_badge.get("pieces", 6))
	var edge := BadgeArt.GOLD if complete else RetroTheme.PHOSPHOR
	draw_rect(r, Color(0.02, 0.04, 0.1, 0.95))
	draw_rect(r, edge, false, 1.0)
	BadgeArt.draw_badge(self, Vector2(30, 29), 22.0, _badge, _got, _t, _index if _t < 2.4 else -1)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(60, 18), tr("INSIGNIA · %s") % String(_badge.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 184, 9, RetroTheme.AMBER)
	var line := tr("¡INSIGNIA COMPLETA!") if complete else tr("PIEZA %d / %d DESBLOQUEADA") % [_got.size(), int(_badge.get("pieces", 6))]
	draw_string(font, Vector2(60, 34), line, HORIZONTAL_ALIGNMENT_LEFT, 184, 11, edge)
	draw_string(font, Vector2(60, 48), tr("CUADERNO DE INSIGNIAS"), HORIZONTAL_ALIGNMENT_LEFT, 184, 8, RetroTheme.PHOSPHOR_DIM)
