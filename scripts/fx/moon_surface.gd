class_name MoonSurface
extends Node2D
## Superficie lunar procedural (placeholder hasta tener sprites finales).
## Dibuja en "píxeles de arte" de 320x180 escalados x2 -> pixel art grueso y nítido.
## - Capa estática (se dibuja una sola vez): Tierra, terreno, cráteres, Eagle, EASEP, LRRR.
## - Capa animada (hijo FX, se redibuja cada frame): brillo del EASEP, señal 2119 MHz,
##   pulso láser Tierra-LRRR y destello de la placa.

const ART_SCALE := 2.0
const ART_SIZE := Vector2(320, 180)
const HORIZON := 126.0

# --- Paleta ---
const C_GROUND_FAR := Color("#34333f")
const C_GROUND := Color("#5d5c69")
const C_GROUND_DARK := Color("#45444f")
const C_GROUND_DEEP := Color("#2e2d36")
const C_GROUND_LIGHT := Color("#7f7e8c")
const C_ROCK := Color("#4a4955")
const C_GOLD := Color("#c8962e")
const C_GOLD_LIGHT := Color("#f0c862")
const C_GOLD_DARK := Color("#7a5516")
const C_FOIL_BLACK := Color("#22222a")
const C_METAL := Color("#a7a9b4")
const C_METAL_DARK := Color("#6c6e78")
const C_SILVER := Color("#e3e6f0")
const C_PANEL := Color("#1e3f8f")
const C_PANEL_LIGHT := Color("#3d6fd6")
const C_GLOW := Color("#7ffcff")
const C_LASER := Color("#4dff6a")
const C_EARTH := Color("#2e6bd1")
const C_EARTH_LAND := Color("#3f9a52")
const C_CLOUD := Color("#e8f0ff")
const C_LABEL := Color(0.22, 1.0, 0.48, 0.75)

@export var eagle_x: float = 175.0
@export var easep_x: float = 222.0
@export var lrrr_x: float = 254.0
@export var earth_pos: Vector2 = Vector2(286, 30)
@export var show_labels: bool = true
@export var laser_period: float = 5.0

var _t := 0.0
var _fx: Node2D
var _eagle_gy := 0.0
var _easep_gy := 0.0
var _lrrr_gy := 0.0
var _speckles: Array[Vector2] = []
var _speckle_colors: Array[Color] = []
var _rocks: Array[Rect2] = []
var _craters: Array[Vector3] = [  # x, y, radio (en píxeles de arte)
	Vector3(40, 150, 14), Vector3(122, 141, 7), Vector3(300, 162, 18),
	Vector3(200, 170, 9), Vector3(150, 160, 5), Vector3(272, 139, 5),
]


func _ready() -> void:
	_eagle_gy = _ground_y(eagle_x)
	_easep_gy = _ground_y(easep_x)
	_lrrr_gy = _ground_y(lrrr_x)

	var rng := RandomNumberGenerator.new()
	rng.seed = 19690720
	for i in 240:
		var x := floorf(rng.randf_range(0.0, ART_SIZE.x))
		var y := floorf(rng.randf_range(_ground_y(x) + 2.0, ART_SIZE.y))
		_speckles.append(Vector2(x, y))
		_speckle_colors.append(C_GROUND_LIGHT if rng.randf() < 0.5 else C_GROUND_DARK)
	for i in 18:
		var x := floorf(rng.randf_range(0.0, ART_SIZE.x))
		var y := floorf(rng.randf_range(_ground_y(x) + 4.0, ART_SIZE.y - 2.0))
		_rocks.append(Rect2(x, y, rng.randi_range(2, 5), rng.randi_range(1, 3)))

	# Capa animada: un hijo cuyo "draw" lo pintamos desde este script.
	_fx = Node2D.new()
	_fx.name = "FX"
	add_child(_fx)
	_fx.draw.connect(_draw_fx)


func _process(delta: float) -> void:
	_t += delta
	_fx.queue_redraw()  # Solo la capa FX se redibuja; el terreno queda cacheado.


## Altura del terreno (en píxeles de arte) para una x dada. Ondulación suave.
func _ground_y(x: float) -> float:
	return floorf(HORIZON + 1.5 * sin(x * 0.045) + 1.0 * sin(x * 0.13 + 2.0))


# =========================================================================
# CAPA ESTÁTICA
# =========================================================================
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	_draw_earth()
	_draw_terrain()
	_draw_footprints()
	_draw_eagle(eagle_x, _eagle_gy)
	_draw_easep(easep_x, _easep_gy)
	_draw_lrrr(lrrr_x, _lrrr_gy)

	if show_labels:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_label(Vector2(eagle_x, _eagle_gy - 27), "EAGLE LM-5")
		_label(Vector2(easep_x, _easep_gy - 20), "EASEP")
		_label(Vector2(lrrr_x + 4, _lrrr_gy - 13), "LRRR")
		_label(Vector2(earth_pos.x, earth_pos.y + 18), "TIERRA")


func _label(art_pos: Vector2, text: String) -> void:
	var w := 120.0
	var p := art_pos * ART_SCALE + Vector2(-w * 0.5, 0.0)
	draw_string(ThemeDB.fallback_font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, 10, C_LABEL)


func _draw_earth() -> void:
	var e := earth_pos
	draw_arc(e, 10.0, 0.0, TAU, 32, Color(C_GLOW, 0.35), 1.0)  # Atmósfera.
	draw_circle(e, 9.0, C_EARTH)
	draw_circle(e + Vector2(-3, -2), 3.5, C_EARTH_LAND)
	draw_circle(e + Vector2(3, 3), 2.5, C_EARTH_LAND)
	draw_rect(Rect2(e.x - 6, e.y + 1, 4, 1), C_CLOUD)
	draw_rect(Rect2(e.x + 1, e.y - 5, 5, 1), C_CLOUD)
	draw_rect(Rect2(e.x - 2, e.y + 6, 3, 1), C_CLOUD)
	# Lado nocturno: oscurecemos fila a fila (terminador pixelado).
	for row in range(-9, 10):
		var half := floorf(sqrt(81.0 - row * row))
		var start := floorf(half * 0.1)
		draw_rect(Rect2(e.x + start, e.y + row, half - start + 1, 1), Color(0, 0, 0.05, 0.55))


func _draw_terrain() -> void:
	# Colinas lejanas.
	var far := PackedVector2Array()
	for x in range(0, 321, 4):
		far.append(Vector2(x, floorf(HORIZON - 6 + 3.0 * sin(x * 0.03 + 1.0) + 2.0 * sin(x * 0.09))))
	far.append(Vector2(320, HORIZON + 6))
	far.append(Vector2(0, HORIZON + 6))
	draw_colored_polygon(far, C_GROUND_FAR)

	# Suelo principal.
	var ground := PackedVector2Array()
	for x in range(0, 321, 2):
		ground.append(Vector2(x, _ground_y(x)))
	ground.append(Vector2(320, 180))
	ground.append(Vector2(0, 180))
	draw_colored_polygon(ground, C_GROUND)
	for x in range(0, 320, 2):  # Borde iluminado por el Sol.
		draw_rect(Rect2(x, _ground_y(x), 2, 1), C_GROUND_LIGHT)

	# Bandas de sombra hacia el primer plano.
	draw_rect(Rect2(0, 152, 320, 28), Color(C_GROUND_DARK, 0.45))
	draw_rect(Rect2(0, 168, 320, 12), Color(C_GROUND_DEEP, 0.5))

	# Cráteres (elipses: escalamos el eje Y).
	for c in _craters:
		draw_set_transform(Vector2(c.x, c.y) * ART_SCALE, 0.0, Vector2(ART_SCALE, ART_SCALE * 0.35))
		draw_circle(Vector2(0, -1.5), c.z + 1.0, C_GROUND_LIGHT)
		draw_circle(Vector2.ZERO, c.z, C_GROUND_DARK)
		draw_circle(Vector2(c.z * 0.15, c.z * 0.2), c.z * 0.6, C_GROUND_DEEP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))

	# Polvo (regolito) y rocas.
	for i in _speckles.size():
		draw_rect(Rect2(_speckles[i], Vector2.ONE), _speckle_colors[i])
	for r in _rocks:
		draw_rect(r, C_ROCK)
		draw_rect(Rect2(r.position, Vector2(1, 1)), C_GROUND_LIGHT)


func _draw_footprints() -> void:
	# Huellas entre el Eagle y el EASEP: la historia también está en el suelo.
	var x := eagle_x + 6.0
	var i := 0
	while x < easep_x - 14.0:
		draw_rect(Rect2(x, _ground_y(x) + 2 + (i % 2), 2, 1), C_GROUND_DARK)
		x += 4.0
		i += 1


func _draw_eagle(cx: float, gy: float) -> void:
	# Patas traseras (más oscuras, detrás del cuerpo).
	draw_line(Vector2(cx - 9, gy - 14), Vector2(cx - 13, gy - 1), C_METAL_DARK, 1.0)
	draw_line(Vector2(cx + 9, gy - 14), Vector2(cx + 13, gy - 1), C_METAL_DARK, 1.0)
	draw_rect(Rect2(cx - 15, gy - 1, 5, 1), C_METAL_DARK)
	draw_rect(Rect2(cx + 10, gy - 1, 5, 1), C_METAL_DARK)

	# Patas laterales con puntal secundario (envergadura 9.4 m).
	draw_line(Vector2(cx - 12, gy - 16), Vector2(cx - 18, gy - 1), C_METAL, 1.0)
	draw_line(Vector2(cx - 12, gy - 10), Vector2(cx - 17, gy - 2), C_METAL_DARK, 1.0)
	draw_line(Vector2(cx + 12, gy - 16), Vector2(cx + 18, gy - 1), C_METAL, 1.0)
	draw_line(Vector2(cx + 12, gy - 10), Vector2(cx + 17, gy - 2), C_METAL_DARK, 1.0)
	draw_rect(Rect2(cx - 21, gy - 1, 6, 2), C_METAL)
	draw_rect(Rect2(cx + 15, gy - 1, 6, 2), C_METAL)

	# Tobera del motor de descenso.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 3, gy - 9), Vector2(cx + 3, gy - 9),
		Vector2(cx + 4, gy - 5), Vector2(cx - 4, gy - 5),
	]), C_METAL_DARK)

	# Cuerpo octogonal con lámina dorada.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, gy - 19), Vector2(cx + 10, gy - 19),
		Vector2(cx + 12, gy - 17), Vector2(cx + 12, gy - 11),
		Vector2(cx + 10, gy - 9), Vector2(cx - 10, gy - 9),
		Vector2(cx - 12, gy - 11), Vector2(cx - 12, gy - 17),
	]), C_GOLD)
	draw_rect(Rect2(cx - 10, gy - 19, 20, 1), C_GOLD_LIGHT)
	draw_rect(Rect2(cx - 10, gy - 10, 20, 1), C_GOLD_DARK)
	draw_rect(Rect2(cx - 4, gy - 18, 8, 8), C_FOIL_BLACK)  # Lámina negra central.
	draw_rect(Rect2(cx - 8, gy - 18, 1, 8), C_GOLD_DARK)  # Costuras.
	draw_rect(Rect2(cx + 7, gy - 18, 1, 8), C_GOLD_DARK)
	for p in [Vector2(cx - 10, gy - 15), Vector2(cx - 6, gy - 13), Vector2(cx + 9, gy - 16), Vector2(cx + 5, gy - 12)]:
		draw_rect(Rect2(p, Vector2.ONE), C_GOLD_LIGHT)  # Arrugas de la lámina.

	# Plataforma superior vacía: aquí estaba la etapa de ascenso.
	draw_rect(Rect2(cx - 11, gy - 20, 22, 1), C_METAL)

	# Pata delantera con escalera y placa conmemorativa.
	draw_rect(Rect2(cx - 1, gy - 9, 2, 8), C_METAL)
	draw_rect(Rect2(cx - 2, gy - 8, 4, 3), C_SILVER)  # Placa.
	draw_rect(Rect2(cx - 2, gy - 4, 4, 1), C_METAL_DARK)
	draw_rect(Rect2(cx - 2, gy - 2, 4, 1), C_METAL_DARK)
	draw_rect(Rect2(cx - 3, gy - 1, 6, 2), C_METAL)


func _draw_easep(ex: float, gy: float) -> void:
	# Soportes de los paneles.
	draw_rect(Rect2(ex - 9, gy - 3, 1, 3), C_METAL_DARK)
	draw_rect(Rect2(ex + 8, gy - 3, 1, 3), C_METAL_DARK)
	# Paneles solares oeste / este.
	for px in [ex - 13, ex + 4]:
		draw_rect(Rect2(px, gy - 7, 9, 4), C_PANEL)
		draw_rect(Rect2(px, gy - 7, 9, 1), C_PANEL_LIGHT)
		draw_rect(Rect2(px + 3, gy - 7, 1, 4), C_PANEL_LIGHT)
		draw_rect(Rect2(px + 6, gy - 7, 1, 4), C_PANEL_LIGHT)
	# Cuerpo central (sismómetro pasivo).
	draw_rect(Rect2(ex - 3, gy - 5, 6, 5), C_METAL)
	draw_rect(Rect2(ex - 3, gy - 5, 6, 1), C_SILVER)
	draw_rect(Rect2(ex - 3, gy - 1, 6, 1), C_METAL_DARK)
	draw_rect(Rect2(ex - 2, gy - 7, 3, 2), C_GOLD_LIGHT)  # Domo del sismómetro.
	# Antena.
	draw_rect(Rect2(ex + 1, gy - 11, 1, 6), C_METAL)
	draw_rect(Rect2(ex, gy - 12, 3, 1), C_METAL)


func _draw_lrrr(lx: float, gy: float) -> void:
	draw_rect(Rect2(lx - 5, gy - 3, 1, 3), C_METAL_DARK)
	draw_rect(Rect2(lx + 4, gy - 5, 1, 5), C_METAL_DARK)
	# Panel inclinado apuntando a la Tierra.
	draw_colored_polygon(PackedVector2Array([
		Vector2(lx - 6, gy - 6), Vector2(lx + 6, gy - 9),
		Vector2(lx + 6, gy - 5), Vector2(lx - 6, gy - 2),
	]), C_METAL)
	# Prismas (rejilla de puntos).
	for i in 4:
		for j in 2:
			draw_rect(Rect2(lx - 5 + i * 3, floorf(gy - 5 - i * 0.75 + j * 2), 1, 1), C_METAL_DARK)


# =========================================================================
# CAPA ANIMADA (FX)
# =========================================================================
func _draw_fx() -> void:
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	_draw_easep_glow()
	_draw_laser()
	_draw_plaque_glint()


func _draw_easep_glow() -> void:
	var tip := Vector2(easep_x + 1.5, _easep_gy - 11.5)
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	_fx.draw_circle(tip, 4.0, Color(C_GLOW, 0.08 + 0.10 * pulse))
	_fx.draw_circle(tip, 2.0, Color(C_GLOW, 0.20 + 0.25 * pulse))
	_fx.draw_rect(Rect2(tip.floor(), Vector2.ONE), Color(1, 1, 1, 0.6 + 0.4 * pulse))
	# Brillo tenue sobre los paneles solares.
	_fx.draw_rect(Rect2(easep_x - 13, _easep_gy - 7, 26, 4), Color(C_GLOW, 0.06 * pulse))
	# Ondas de señal (2119 MHz), radio cuantizado a píxeles enteros.
	for k in 3:
		var r := floorf(fmod(_t * 8.0 + k * 6.0, 18.0))
		var a := (1.0 - r / 18.0) * 0.6
		_fx.draw_arc(tip, r + 2.0, -PI * 0.8, -PI * 0.2, 8, Color(C_GLOW, a), 1.0)


func _draw_laser() -> void:
	# Pulso láser de un observatorio terrestre que rebota en el LRRR y vuelve.
	var target := Vector2(lrrr_x, _lrrr_gy - 6)
	var travel := 0.35
	var cycle := fmod(_t, laser_period)
	if cycle < travel:
		var k := cycle / travel
		_fx.draw_line(earth_pos.lerp(target, maxf(k - 0.3, 0.0)), earth_pos.lerp(target, k), Color(C_LASER, 0.8), 1.0)
	elif cycle < travel * 2.0:
		var k := (cycle - travel) / travel
		_fx.draw_line(target.lerp(earth_pos, maxf(k - 0.3, 0.0)), target.lerp(earth_pos, k), Color(C_LASER, 0.8), 1.0)
		_fx.draw_circle(target, 2.5 * (1.0 - k) + 0.5, Color(C_LASER, 1.0 - k))


func _draw_plaque_glint() -> void:
	if fmod(_t, 4.0) < 0.15:
		_fx.draw_rect(Rect2(eagle_x + 1, _eagle_gy - 8, 1, 1), Color.WHITE)
