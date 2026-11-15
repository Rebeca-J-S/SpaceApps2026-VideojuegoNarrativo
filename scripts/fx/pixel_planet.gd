class_name PixelPlanet
extends ColorRect
## Planeta pixel art (Luna o Marte) que rota lentamente, generado sin assets:
## ruido FastNoiseLite -> paleta posterizada -> shader de esfera (pixel_planet.gdshader).
## Encima dibuja PUNTOS VERDES pulsantes en los sitios de data/sites.json (lat/lon reales),
## que giran con el planeta y se ocultan cuando quedan en el lado oculto.

enum Kind { MOON, MARS }

const SHADER := preload("res://assets/shaders/pixel_planet.gdshader")
const C_SITE := Color("#39ff7a")
const C_HOVER := Color("#ffb347")
const C_LOCKED := Color("#c8ccd8")       # sitio bloqueado (aún sin misión)

@export var kind: Kind = Kind.MOON
## Resolución del disco: con size 120 y pixels 60, cada píxel del planeta mide 2 px.
@export var pixels: float = 72.0
## Vueltas por segundo.
@export var spin_speed: float = 0.008
@export var start_spin: float = 0.0

## Sitios a marcar. Si se deja vacío, se cargan de data/sites.json según el tipo de planeta.
var sites: Array = []
## Índice del sitio resaltado (lo fija la escena según el ratón). -1 = ninguno.
var hovered := -1
## Si es true el planeta deja de girar (durante el zoom).
var frozen := false

var _spin := 0.0
var _t := 0.0
var _site_pos: Array[Vector2] = []
var _site_visible: Array[bool] = []
var _markers: Node2D
var _mat: ShaderMaterial


func _ready() -> void:
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin = start_spin
	if sites.is_empty():
		var wanted := "mars" if kind == Kind.MARS else "moon"
		for dest in GameManager.get_destinations():
			if dest["kind"] == wanted:
				sites = dest["sites"]
	for i in sites.size():
		_site_pos.append(Vector2.ZERO)
		_site_visible.append(false)

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("surface", _make_surface())
	_mat.set_shader_parameter("pixels", pixels)
	if kind == Kind.MARS:
		_mat.set_shader_parameter("polar_caps", 0.1)
		_mat.set_shader_parameter("rim_color", Color(1.0, 0.6, 0.4, 0.55))
		_mat.set_shader_parameter("shadow_color", Color(0.1, 0.03, 0.03, 1.0))
	else:
		_mat.set_shader_parameter("shadow_color", Color(0.03, 0.03, 0.06, 1.0))
	material = _mat

	# Los marcadores van en un hijo: los hijos no heredan el material del padre.
	_markers = Node2D.new()
	add_child(_markers)
	_markers.draw.connect(_draw_markers)


func _process(delta: float) -> void:
	_t += delta
	if not frozen:
		_spin = fposmod(_spin + delta * spin_speed, 1.0)
	_mat.set_shader_parameter("spin", _spin)
	_update_sites()
	_markers.queue_redraw()


func _make_surface() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.018
	noise.seed = 1976 if kind == Kind.MARS else 1969

	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	if kind == Kind.MARS:
		grad.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.6, 0.78])
		grad.colors = PackedColorArray([
			Color("#5a2316"), Color("#8c3a1e"), Color("#b5532a"), Color("#cf7440"), Color("#e09a62"),
		])
	else:
		# Los "mares" lunares son las zonas oscuras (basalto).
		grad.offsets = PackedFloat32Array([0.0, 0.36, 0.5, 0.64, 0.8])
		grad.colors = PackedColorArray([
			Color("#4a4a55"), Color("#6b6b78"), Color("#8d8d99"), Color("#adadb8"), Color("#c9c9d2"),
		])

	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	return tex


## Proyecta cada sitio (lat/lon) sobre la esfera con la misma rotación que el shader.
func _update_sites() -> void:
	var r := size.x * 0.5
	var c := size * 0.5
	var px := size.x / pixels
	for i in sites.size():
		var s: Dictionary = sites[i]
		var a := TAU * (float(s["lon"]) / 360.0 - _spin)
		var lat := deg_to_rad(float(s["lat"]))
		var n := Vector3(sin(a) * cos(lat), -sin(lat), cos(a) * cos(lat))
		_site_visible[i] = n.z > 0.2
		_site_pos[i] = (c + Vector2(n.x, n.y) * r).snapped(Vector2(px, px))


func _draw_markers() -> void:
	for i in sites.size():
		if not _site_visible[i]:
			continue
		var p := _site_pos[i]
		var locked := bool(sites[i].get("locked", false))
		var col := C_HOVER if i == hovered else (C_LOCKED if locked else C_SITE)
		# Punto verde pulsante con onda expansiva (los bloqueados: punto gris, sin onda).
		if not locked:
			var pulse := fmod(_t * 0.9 + i * 0.37, 1.0)
			_markers.draw_arc(p, 3.0 + pulse * 8.0, 0.0, TAU, 16, Color(col, 1.0 - pulse), 1.0)
		if locked:
			_markers.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.05, 0.05, 0.1, 0.9))
		_markers.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
		if i == hovered:
			_markers.draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col, false, 1.0)


## Índice del sitio visible más cercano a un punto local (o -1).
func get_site_at(local_point: Vector2, max_dist: float = 8.0) -> int:
	var best := -1
	var best_d := max_dist
	for i in sites.size():
		if not _site_visible[i]:
			continue
		var d := local_point.distance_to(_site_pos[i])
		if d <= best_d:
			best_d = d
			best = i
	return best


func get_site_info(index: int) -> Dictionary:
	return sites[index]


func get_site_local_pos(index: int) -> Vector2:
	return _site_pos[index]


func is_site_visible(index: int) -> bool:
	return _site_visible[index]


## Gira el planeta hasta que el sitio quede de frente (para el zoom).
func face_site(index: int, seconds: float = 0.6) -> void:
	frozen = true
	var target := float(sites[index]["lon"]) / 360.0
	var delta := wrapf(target - _spin, -0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "_spin", _spin + delta, seconds).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
