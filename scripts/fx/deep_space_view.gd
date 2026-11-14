class_name DeepSpaceView
extends Control
## "Espacio profundo" del selector: mini sistema solar pixel art (Sol, órbitas, Júpiter y
## Saturno) con dos puntos verdes (Pioneer 10 y 11) que se alejan lentamente hacia el borde.
## Misma interfaz que PixelPlanet (get_site_at, get_site_info, face_site...) para el selector.
## PLACEHOLDER: todo se dibuja con _draw(); se puede sustituir por sprites.

const C_SITE := Color("#39ff7a")
const C_HOVER := Color("#ffb347")

var sites: Array = []
var hovered := -1
var frozen := false

var _t := 0.0
var _progress: Array[float] = []   # 0..1 distancia recorrida de cada sonda


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sites.is_empty():
		for dest in GameManager.get_destinations():
			if dest["kind"] == "deep_space":
				sites = dest["sites"]
	for i in sites.size():
		_progress.append(0.45 + i * 0.2)


func _process(delta: float) -> void:
	if not frozen:
		_t += delta
		for i in _progress.size():
			_progress[i] += delta * 0.02
			if _progress[i] > 1.0:
				_progress[i] = 0.35  # Vuelven a aparecer para que siempre se vean.
	queue_redraw()


func _center() -> Vector2:
	return size * 0.5


func get_site_local_pos(index: int) -> Vector2:
	var a := deg_to_rad(float(sites[index].get("angle", 0.0)))
	var r := size.x * 0.5 * _progress[index]
	return (_center() + Vector2(cos(a), sin(a) * 0.75) * r).floor()


func _draw() -> void:
	var c := _center()
	var r := size.x * 0.5
	# Órbitas punteadas de Júpiter y Saturno.
	for orbit in [0.32, 0.52]:
		for k in 48:
			var a := k * TAU / 48.0
			draw_rect(Rect2(c + Vector2(cos(a), sin(a) * 0.75) * r * orbit, Vector2(1, 1)), Color(1, 1, 1, 0.35))
	# El Sol.
	draw_circle(c, 6.0, Color("#ffd24a"))
	draw_circle(c, 9.0, Color(1, 0.8, 0.3, 0.25))
	# Júpiter y Saturno moviéndose por sus órbitas.
	var ja := _t * 0.12
	draw_circle(c + Vector2(cos(ja), sin(ja) * 0.75) * r * 0.32, 4.0, Color("#d9b48a"))
	var sa := _t * 0.07 + 2.0
	var sp := c + Vector2(cos(sa), sin(sa) * 0.75) * r * 0.52
	draw_circle(sp, 3.0, Color("#e0c890"))
	draw_line(sp - Vector2(6, 1), sp + Vector2(6, -1), Color("#c9b58a"), 1.0)
	# Sondas Pioneer con su estela.
	for i in sites.size():
		var p := get_site_local_pos(i)
		var a := deg_to_rad(float(sites[i].get("angle", 0.0)))
		var dir := Vector2(cos(a), sin(a) * 0.75)
		for k in 6:
			draw_rect(Rect2(p - dir * (k * 4.0 + 4.0), Vector2(1, 1)), Color(C_SITE, 0.5 - k * 0.08))
		var col := C_HOVER if i == hovered else C_SITE
		var pulse := fmod(_t * 0.9 + i * 0.4, 1.0)
		draw_arc(p, 3.0 + pulse * 8.0, 0.0, TAU, 16, Color(col, 1.0 - pulse), 1.0)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
		if i == hovered:
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col, false, 1.0)


func get_site_at(local_point: Vector2, max_dist: float = 9.0) -> int:
	var best := -1
	var best_d := max_dist
	for i in sites.size():
		var d := local_point.distance_to(get_site_local_pos(i))
		if d <= best_d:
			best_d = d
			best = i
	return best


func get_site_info(index: int) -> Dictionary:
	return sites[index]


func is_site_visible(_index: int) -> bool:
	return true


func face_site(_index: int, _seconds: float = 0.6) -> void:
	frozen = true
	await get_tree().process_frame
