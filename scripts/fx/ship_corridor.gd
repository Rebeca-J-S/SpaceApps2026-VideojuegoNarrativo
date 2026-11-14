class_name ShipCorridor
extends Node2D
## Pasillo interior de una nave espacial en perspectiva de un punto (placeholder procedural).
## Se dibuja en "píxeles de arte" de 320x180 escalados x2.
## - Capa estática (_draw, una vez): techo, paredes, suelo, costillas, carteles de la Luna y Marte.
## - Capa animada (hijo FX): estrellas y Luna por la ventana, luces de alarma, viñeta roja,
##   polvo y objetos flotando en gravedad cero (cosas que los astronautas dejaron en la Luna).

const ART_SCALE := 2.0
const W := 320.0
const H := 180.0
## Rectángulo exterior algo más grande que la pantalla para que el balanceo no muestre bordes.
const OUTER := Rect2(-4, -3, 328, 186)
## Pared del fondo (ventana) — punto de fuga del pasillo.
const BACK := Rect2(130, 36, 60, 38)
## Profundidades de las "costillas" del pasillo (0 = pantalla, 1 = pared del fondo).
const FRAMES := [0.0, 0.38, 0.6, 0.74, 0.83, 0.89, 0.93, 0.965, 1.0]

# --- Paleta ---
const C_CEIL := Color("#7d8299")
const C_CEIL_DARK := Color("#5d6178")
const C_WALL := Color("#b3b7cc")
const C_WALL_R := Color("#a0a4bb")
const C_PANEL := Color("#8a8ea6")
const C_PANEL_DARK := Color("#6e7290")
const C_RIB := Color("#4a4e66")
const C_FLOOR := Color("#3b3e57")
const C_FLOOR_LIGHT := Color("#585c7c")
const C_FLOOR_DARK := Color("#2a2c40")
const C_LIGHT := Color("#f4f7ff")
const C_LIGHT_GLOW := Color("#bfe6ff")
const C_AMBER := Color("#ffb347")
const C_RED := Color("#e0402e")
const C_POSTER := Color("#e8e2d0")
const C_POSTER_BG := Color("#151827")
const C_MOON := Color("#b4b4c0")
const C_MOON_DARK := Color("#7c7c8a")
const C_MARS := Color("#c0532a")
const C_MARS_DARK := Color("#8c3a1e")
const C_WINDOW := Color("#04050d")

## Objetos flotantes: sprite, posición base (arte), escala, rotación y ficha informativa.
const ITEMS := [
	{"sprite": "BOOT", "pos": Vector2(92, 56), "scale": 1.5, "rot": 0.35,
		"title": "CUBREBOTAS LUNARES",
		"info": "Armstrong y Aldrin los dejaron en la Luna en 1969 para ahorrar peso en el despegue."},
	{"sprite": "BACKPACK", "pos": Vector2(228, 54), "scale": 1.5, "rot": -0.2,
		"title": "MOCHILA PLSS",
		"info": "El soporte vital de las caminatas lunares. Se abandonaba antes de despegar."},
	{"sprite": "CAMERA", "pos": Vector2(110, 86), "scale": 1.5, "rot": 0.5,
		"title": "CÁMARA HASSELBLAD",
		"info": "Las cámaras se quedaron en la Luna: solo volvieron los cartuchos de película."},
	{"sprite": "GOLF_BALL", "pos": Vector2(166, 84), "scale": 1.5, "rot": 1.2,
		"title": "PELOTA DE GOLF",
		"info": "Alan Shepard golpeó dos pelotas en la Luna durante el Apolo 14 (1971)."},
	{"sprite": "PHOTO", "pos": Vector2(250, 86), "scale": 1.5, "rot": -0.6,
		"title": "FOTO FAMILIAR",
		"info": "Charlie Duke dejó una foto de su familia en la Luna (Apolo 16, 1972)."},
	{"sprite": "BOOT", "pos": Vector2(62, 90), "scale": 1.5, "rot": -0.45,
		"title": "CUBREBOTAS LUNARES",
		"info": "Armstrong y Aldrin los dejaron en la Luna en 1969 para ahorrar peso en el despegue."},
]

## Índice del objeto resaltado (lo fija la escena según el ratón). -1 = ninguno.
var highlighted := -1

var _t := 0.0
var _fx: Node2D
var _textures: Array[ImageTexture] = []
var _item_pos: Array[Vector2] = []     # posición actual en píxeles de arte
var _item_phase: Array[float] = []
var _window_stars: Array[Vector3] = []  # x, y, brillo
var _dust: Array[Vector3] = []          # x, y, fase


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for it in ITEMS:
		_textures.append(PixelSprites.make(PixelSprites.by_name(it["sprite"])))
		_item_pos.append(it["pos"])
		_item_phase.append(rng.randf() * TAU)
	for i in 26:
		_window_stars.append(Vector3(rng.randf_range(0, BACK.size.x), rng.randf_range(0, BACK.size.y), rng.randf_range(0.3, 1.0)))
	for i in 40:
		_dust.append(Vector3(rng.randf_range(0, W), rng.randf_range(10, H - 10), rng.randf() * TAU))

	_fx = Node2D.new()
	_fx.name = "FX"
	add_child(_fx)
	_fx.draw.connect(_draw_fx)


func _process(delta: float) -> void:
	_t += delta
	# Balanceo suave de la nave (en píxeles enteros para mantener el pixel art nítido).
	position = Vector2(roundf(sin(_t * 0.5) * 2.0), roundf(sin(_t * 0.8 + 1.0) * 1.0))
	for i in ITEMS.size():
		var base: Vector2 = ITEMS[i]["pos"]
		var ph := _item_phase[i]
		_item_pos[i] = base + Vector2(sin(_t * 0.45 + ph) * 6.0, cos(_t * 0.6 + ph) * 4.0)
	_fx.queue_redraw()


## Devuelve el índice del objeto bajo un punto (coordenadas locales de este nodo) o -1.
func get_item_at(local_point: Vector2) -> int:
	var art := local_point / ART_SCALE
	for i in range(ITEMS.size() - 1, -1, -1):
		var radius := maxf(_textures[i].get_size().x, _textures[i].get_size().y) * 0.6 * float(ITEMS[i]["scale"])
		if art.distance_to(_item_pos[i]) <= radius:
			return i
	return -1


func get_item_info(index: int) -> Dictionary:
	return ITEMS[index]


## Posición en pantalla (coordenadas locales) de un objeto.
func get_item_screen_pos(index: int) -> Vector2:
	return _item_pos[index] * ART_SCALE


# =========================================================================
# Utilidades de perspectiva
# =========================================================================
func _rect_at(d: float) -> Rect2:
	var outer := Rect2(0, 0, W, H)
	return Rect2(outer.position.lerp(BACK.position, d), outer.size.lerp(BACK.size, d))


func _xa(r: Rect2, f: float) -> float:
	return lerpf(r.position.x, r.end.x, f)


func _ya(r: Rect2, f: float) -> float:
	return lerpf(r.position.y, r.end.y, f)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)


# =========================================================================
# CAPA ESTÁTICA
# =========================================================================
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	var o := OUTER
	var b := BACK

	# Superficies principales.
	_quad(o.position, Vector2(o.end.x, o.position.y), Vector2(b.end.x, b.position.y), b.position, C_CEIL)
	_quad(Vector2(o.position.x, o.end.y), o.end, b.end, Vector2(b.position.x, b.end.y), C_FLOOR)
	_quad(o.position, b.position, Vector2(b.position.x, b.end.y), Vector2(o.position.x, o.end.y), C_WALL)
	_quad(Vector2(o.end.x, o.position.y), Vector2(o.end.x, o.end.y), b.end, Vector2(b.end.x, b.position.y), C_WALL_R)
	draw_rect(b, C_WINDOW)

	# Segmentos del pasillo.
	for i in FRAMES.size() - 1:
		var f0: float = FRAMES[i]
		var f1: float = FRAMES[i + 1]
		var r0 := _rect_at(lerpf(f0, f1, 0.12))
		var r1 := _rect_at(lerpf(f0, f1, 0.88))
		_draw_ceiling_lights(r0, r1)
		_draw_floor_segment(_rect_at(f0), _rect_at(f1))
		_draw_wall_panels(r0, r1, i)

	# Costillas estructurales y lámparas ámbar.
	for i in range(1, FRAMES.size() - 1):
		var f: float = FRAMES[i]
		var r := _rect_at(f)
		var thick := maxf(1.0, roundf(3.0 * (1.0 - f)))
		draw_rect(r, C_RIB, false, thick)
		var s := maxf(1.0, roundf(6.0 * (1.0 - f)))
		draw_rect(Rect2(r.position.x + thick, _ya(r, 0.3), s * 0.6, s), C_AMBER)
		draw_rect(Rect2(r.end.x - thick - s * 0.6, _ya(r, 0.3), s * 0.6, s), C_AMBER)

	# Marco de la ventana del fondo.
	draw_rect(b, C_RIB, false, 2.0)
	draw_rect(Rect2(b.position.x + b.size.x * 0.5 - 0.5, b.position.y, 1, b.size.y), C_RIB)
	draw_rect(Rect2(b.position.x - 2, b.end.y, b.size.x + 4, 3), C_PANEL_DARK)  # Consola bajo la ventana.


func _draw_ceiling_lights(r0: Rect2, r1: Rect2) -> void:
	for band in [[0.28, 0.4], [0.6, 0.72]]:
		var a: float = band[0]
		var c: float = band[1]
		_quad(Vector2(_xa(r0, a - 0.02), r0.position.y), Vector2(_xa(r0, c + 0.02), r0.position.y),
			Vector2(_xa(r1, c + 0.02), r1.position.y), Vector2(_xa(r1, a - 0.02), r1.position.y), C_LIGHT_GLOW)
		_quad(Vector2(_xa(r0, a), r0.position.y), Vector2(_xa(r0, c), r0.position.y),
			Vector2(_xa(r1, c), r1.position.y), Vector2(_xa(r1, a), r1.position.y), C_LIGHT)


func _draw_floor_segment(r0: Rect2, r1: Rect2) -> void:
	# Pasarela central más clara con rejilla.
	_quad(Vector2(_xa(r0, 0.33), r0.end.y), Vector2(_xa(r0, 0.67), r0.end.y),
		Vector2(_xa(r1, 0.67), r1.end.y), Vector2(_xa(r1, 0.33), r1.end.y), C_FLOOR_LIGHT)
	for k in 4:
		var r := _rect_at(lerpf(_depth_of(r0), _depth_of(r1), (k + 0.5) / 4.0))
		draw_rect(Rect2(_xa(r, 0.33), r.end.y, _xa(r, 0.67) - _xa(r, 0.33), 1), C_FLOOR_DARK)
	# Bandas laterales oscuras junto a las paredes.
	_quad(Vector2(_xa(r0, 0.0), r0.end.y), Vector2(_xa(r0, 0.08), r0.end.y),
		Vector2(_xa(r1, 0.08), r1.end.y), Vector2(_xa(r1, 0.0), r1.end.y), C_FLOOR_DARK)
	_quad(Vector2(_xa(r0, 0.92), r0.end.y), Vector2(_xa(r0, 1.0), r0.end.y),
		Vector2(_xa(r1, 1.0), r1.end.y), Vector2(_xa(r1, 0.92), r1.end.y), C_FLOOR_DARK)


func _depth_of(r: Rect2) -> float:
	return r.position.x / BACK.position.x


func _draw_wall_panels(r0: Rect2, r1: Rect2, segment: int) -> void:
	# Panel izquierdo y derecho (quad en perspectiva sobre cada pared).
	for side in [0, 1]:
		var x0 := r0.position.x if side == 0 else r0.end.x
		var x1 := r1.position.x if side == 0 else r1.end.x
		var tl := Vector2(x0, _ya(r0, 0.14))
		var tr := Vector2(x1, _ya(r1, 0.14))
		var br := Vector2(x1, _ya(r1, 0.86))
		var bl := Vector2(x0, _ya(r0, 0.86))
		_quad(tl, tr, br, bl, C_PANEL_DARK)
		var i_tl := Vector2(lerpf(x0, x1, 0.1), lerpf(tl.y, tr.y, 0.1) + 1)
		var i_tr := Vector2(lerpf(x0, x1, 0.9), lerpf(tl.y, tr.y, 0.9) + 1)
		var i_br := Vector2(lerpf(x0, x1, 0.9), lerpf(bl.y, br.y, 0.9) - 1)
		var i_bl := Vector2(lerpf(x0, x1, 0.1), lerpf(bl.y, br.y, 0.1) - 1)
		_quad(i_tl, i_tr, i_br, i_bl, C_PANEL)

		# Carteles en el primer segmento: la Luna (izq.) y Marte (der.).
		if segment == 0:
			_draw_poster(i_tl, i_tr, i_br, i_bl, side == 0)
		elif segment == 1:
			# Caja de emergencia roja abajo del panel.
			var ex := lerpf(i_bl.x, i_br.x, 0.4)
			var ey := lerpf(i_bl.y, i_br.y, 0.4) - 7
			draw_rect(Rect2(ex - 2, ey, 4, 4), C_RIB)
			draw_rect(Rect2(ex - 1, ey + 1, 2, 2), C_RED)


func _draw_poster(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2, is_moon: bool) -> void:
	# Esquinas del cartel, encogidas hacia el centro del panel (orden: tl, tr, br, bl).
	var p_tl := tl.lerp(br, 0.18)
	var p_br := tl.lerp(br, 0.82)
	var p_tr := tr.lerp(bl, 0.18)
	var p_bl := tr.lerp(bl, 0.82)
	_quad(p_tl, p_tr, p_br, p_bl, C_POSTER)
	_quad(p_tl.lerp(p_br, 0.1), p_tr.lerp(p_bl, 0.1), p_br.lerp(p_tl, 0.1), p_bl.lerp(p_tr, 0.1), C_POSTER_BG)
	var center := (p_tl + p_tr + p_bl + p_br) * 0.25
	var radius := maxf(3.0, absf(p_br.y - p_tl.y) * 0.22)
	if is_moon:
		draw_circle(center, radius, C_MOON)
		draw_circle(center + Vector2(-radius * 0.3, -radius * 0.2), radius * 0.3, C_MOON_DARK)
		draw_circle(center + Vector2(radius * 0.35, radius * 0.3), radius * 0.22, C_MOON_DARK)
	else:
		draw_circle(center, radius, C_MARS)
		draw_circle(center + Vector2(radius * 0.25, radius * 0.1), radius * 0.35, C_MARS_DARK)
		draw_rect(Rect2(center.x - radius * 0.4, center.y - radius, radius * 0.8, 1), C_POSTER)  # Casquete polar.


# =========================================================================
# CAPA ANIMADA (FX)
# =========================================================================
func _draw_fx() -> void:
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	_draw_window_view()
	_draw_alarm_lights()
	_draw_dust()
	_draw_items()
	_draw_red_alert()
	_draw_light_flicker()


func _draw_window_view() -> void:
	# Estrellas que se desplazan: la nave avanza.
	for s in _window_stars:
		var x := fposmod(s.x - _t * 3.0 * s.z, BACK.size.x)
		var col := Color(1, 1, 1, snappedf(s.z, 0.25))
		_fx.draw_rect(Rect2(floorf(BACK.position.x + x), floorf(BACK.position.y + s.y), 1, 1), col)
	# La Luna asomando por la ventana (creciente).
	var m := BACK.position + Vector2(BACK.size.x * 0.74, BACK.size.y * 0.42)
	_fx.draw_circle(m, 6.0, C_MOON)
	_fx.draw_circle(m + Vector2(-2, -1), 1.5, C_MOON_DARK)
	_fx.draw_circle(m + Vector2(-3.5, 0), 5.5, Color(C_WINDOW, 0.85))
	# Marco por encima para que la Luna no se salga del cristal.
	_fx.draw_rect(BACK, C_RIB, false, 2.0)
	_fx.draw_rect(Rect2(BACK.position.x + BACK.size.x * 0.5 - 0.5, BACK.position.y, 1, BACK.size.y), C_RIB)


func _draw_alarm_lights() -> void:
	# Tres luces rojas sobre la ventana que se encienden en secuencia.
	var step := int(_t * 3.0) % 4
	for i in 3:
		var on := step == i or step == 3
		var x := BACK.position.x + BACK.size.x * 0.5 - 10 + i * 8
		_fx.draw_rect(Rect2(x, BACK.position.y - 4, 4, 2), C_RED if on else C_RIB)


func _draw_dust() -> void:
	for d in _dust:
		var p := Vector2(fposmod(d.x + _t * 2.0, W), d.y + sin(_t * 0.7 + d.z) * 3.0).floor()
		var a := 0.25 + 0.25 * sin(_t * 1.3 + d.z)
		_fx.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, snappedf(a, 0.125)))


func _draw_items() -> void:
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var tex := _textures[i]
		var p := _item_pos[i]
		var ang: float = float(it["rot"]) + sin(_t * 0.3 + _item_phase[i]) * 0.6
		var sc: float = ART_SCALE * float(it["scale"])
		_fx.draw_set_transform(p * ART_SCALE, ang, Vector2(sc, sc))
		_fx.draw_texture(tex, -tex.get_size() * 0.5)
		if i == highlighted:
			_draw_scan_brackets(p, tex.get_size() * float(it["scale"]))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))


func _draw_scan_brackets(center: Vector2, size: Vector2) -> void:
	# Esquinas ámbar de "escáner" alrededor del objeto señalado.
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	var half := size * 0.5 + Vector2(3, 3)
	var tl := (center - half).floor()
	var br := (center + half).floor()
	var c := C_AMBER
	var l := 3.0
	_fx.draw_rect(Rect2(tl, Vector2(l, 1)), c)
	_fx.draw_rect(Rect2(tl, Vector2(1, l)), c)
	_fx.draw_rect(Rect2(Vector2(br.x - l + 1, tl.y), Vector2(l, 1)), c)
	_fx.draw_rect(Rect2(Vector2(br.x, tl.y), Vector2(1, l)), c)
	_fx.draw_rect(Rect2(Vector2(tl.x, br.y), Vector2(l, 1)), c)
	_fx.draw_rect(Rect2(Vector2(tl.x, br.y - l + 1), Vector2(1, l)), c)
	_fx.draw_rect(Rect2(Vector2(br.x - l + 1, br.y), Vector2(l, 1)), c)
	_fx.draw_rect(Rect2(Vector2(br.x, br.y - l + 1), Vector2(1, l)), c)


func _draw_red_alert() -> void:
	# Viñeta roja pulsante en los laterales, en bandas escalonadas (gradiente pixelado).
	var pulse := 0.5 + 0.5 * sin(_t * 1.8)
	var strength := 0.10 + 0.10 * pulse
	for k in 6:
		var bw := 6.0 * (k + 1)
		var a := strength * (1.0 - k / 6.0)
		var col := Color(C_RED, a)
		_fx.draw_rect(Rect2(OUTER.position.x, OUTER.position.y, bw, OUTER.size.y), col)
		_fx.draw_rect(Rect2(OUTER.end.x - bw, OUTER.position.y, bw, OUTER.size.y), col)


func _draw_light_flicker() -> void:
	# Parpadeo ocasional de las luces del techo (breve, cada ~9 s).
	var c := fmod(_t, 9.0)
	if (c > 5.0 and c < 5.06) or (c > 5.14 and c < 5.2):
		_fx.draw_rect(OUTER, Color(0, 0, 0.05, 0.35))
