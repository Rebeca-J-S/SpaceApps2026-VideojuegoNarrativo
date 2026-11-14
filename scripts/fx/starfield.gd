class_name Starfield
extends Node2D
## Campo de estrellas procedural en pixel art con titileo cuantizado.
## No usa texturas: dibuja rectángulos de 1 px con _draw().

@export var star_count: int = 160
@export var area: Vector2 = Vector2(640, 360)
@export var seed_value: int = 1969
@export var twinkle_speed: float = 1.6
## Desplazamiento lento (px/s) para dar sensación de parallax.
@export var drift: Vector2 = Vector2.ZERO
## Estrellas fugaces ocasionales cruzando en diagonal.
@export var shooting_stars: bool = false

const PALETTE := [
	Color("#ffffff"), Color("#cfd8ff"), Color("#ffe9b0"), Color("#9fb4ff"),
]


class Star:
	var pos: Vector2
	var bright: bool  # Estrella grande con destello en cruz.
	var phase: float
	var speed: float
	var base: float
	var color: Color


var _stars: Array[Star] = []
var _t := 0.0
var _shoot_pos := Vector2(-100, -100)
var _shoot_life := 0.0
var _shoot_wait := 2.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in star_count:
		var s := Star.new()
		s.pos = Vector2(rng.randi_range(0, int(area.x) - 1), rng.randi_range(0, int(area.y) - 1))
		s.bright = rng.randf() < 0.07
		s.phase = rng.randf() * TAU
		s.speed = rng.randf_range(0.4, 1.4) * twinkle_speed
		s.base = rng.randf_range(0.35, 1.0)
		s.color = PALETTE[rng.randi() % PALETTE.size()]
		_stars.append(s)


func _process(delta: float) -> void:
	_t += delta
	if shooting_stars:
		_shoot_wait -= delta
		if _shoot_wait <= 0.0 and _shoot_life <= 0.0:
			_shoot_life = 0.7
			_shoot_pos = Vector2(randf_range(80, area.x), randf_range(0, area.y * 0.4))
			_shoot_wait = randf_range(2.5, 6.0)
		if _shoot_life > 0.0:
			_shoot_life -= delta
			_shoot_pos += Vector2(-260, 130) * delta
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var p := s.pos + drift * _t
		p = Vector2(fposmod(p.x, area.x), fposmod(p.y, area.y)).floor()
		var tw := 0.5 + 0.5 * sin(_t * s.speed + s.phase)
		# Opacidad en 4 niveles: el titileo "salta" como en un juego de 16 bits.
		var a := snappedf(clampf(s.base * (0.35 + 0.65 * tw), 0.0, 1.0), 0.25)
		if a <= 0.0:
			continue
		var c := s.color
		c.a = a
		draw_rect(Rect2(p, Vector2.ONE), c)
		if s.bright and tw > 0.8:
			# Destello en cruz de 1 px alrededor de la estrella.
			var arm := c
			arm.a = a * 0.5
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2.ONE), arm)
			draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), arm)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), arm)
			draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), arm)
	if shooting_stars and _shoot_life > 0.0:
		# Estrella fugaz: cabeza brillante y estela de píxeles en diagonal.
		for k in 10:
			var p := (_shoot_pos - Vector2(-2, 1) * k * 2.0).floor()
			draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, (1.0 - k / 10.0) * minf(_shoot_life * 2.0, 1.0)))
