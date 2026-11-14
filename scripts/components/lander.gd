class_name Lander
extends Node2D
## Nave de aterrizaje en vista lateral con física simple y dibujo placeholder pixel art.
## Unidades físicas en METROS y SEGUNDOS (y hacia arriba = altitud positiva).
## La misión decide dónde se dibuja en pantalla (position) según su cámara.
##
## Controles (Input Map): thrust = motor principal, rotate_left / rotate_right = RCS.
## Estilos: LM (Módulo Lunar completo), LM_DESCENT (solo la etapa de descenso),
##          SURVEYOR, CENTAUR (etapa con la Surveyor encima).
## Reemplazo por sprites: cambiar _draw_* por un Sprite2D hijo con la textura final.

enum Style { LM, LM_DESCENT, SURVEYOR, CENTAUR }

@export var style: Style = Style.LM

# --- Estado físico ---
var active := false            ## Si es false no lee controles ni integra la física.
var rotation_only := false     ## Fase de órbita: solo gira (sin gravedad ni traslación).
var x := 0.0                   ## Posición horizontal (m)
var alt := 0.0                 ## Altitud (m)
var vx := 0.0                  ## Velocidad horizontal (m/s)
var vy := 0.0                  ## Velocidad vertical (m/s, + = subiendo)
var angle := 0.0               ## Inclinación (rad, + = hacia la derecha)
var ang_vel := 0.0             ## Velocidad de giro (rad/s)

# --- Parámetros (valores reales del LM-5 por defecto; ver MissionData) ---
var gravity := 1.62            ## m/s²
var dry_mass := 6855.0         ## kg (15,103 kg totales - 8,248 kg de propelente)
var fuel := 8248.0             ## kg
var fuel_capacity := 8248.0    ## kg
var max_thrust := 45000.0      ## N
## Consumo a empuje máximo (kg/s). Ajuste de jugabilidad: el descenso real duró 756.3 s;
## aquí el tiempo va acelerado para que la fase dure ~1 minuto.
var fuel_burn := 140.0
var rcs_accel := 1.4           ## rad/s² de los propulsores laterales
var rcs_damping := 0.6         ## amortiguación de giro (ayuda de jugabilidad)
var px_scale := 2.0            ## escala del dibujo pixel art

var thrusting := false
var rcs_dir := 0
var dust := 0.0                ## 0..1, nube de polvo bajo la nave
var _t := 0.0


## Distancia (en píxeles de pantalla) del centro del dibujo a las patas.
func feet_offset() -> float:
	match style:
		Style.SURVEYOR:
			return 8.0 * px_scale
		Style.CENTAUR:
			return 12.0 * px_scale
	return 10.0 * px_scale


func fuel_ratio() -> float:
	return fuel / fuel_capacity if fuel_capacity > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if active:
		rcs_dir = int(Input.is_action_pressed("rotate_right")) - int(Input.is_action_pressed("rotate_left"))
		thrusting = Input.is_action_pressed("thrust") and fuel > 0.0
		ang_vel += rcs_dir * rcs_accel * delta
		ang_vel -= ang_vel * rcs_damping * delta
		angle = clampf(angle + ang_vel * delta, -PI * 0.5, PI * 0.5)
		if not rotation_only:
			var acc := Vector2(0.0, -gravity)
			if thrusting:
				var a := max_thrust / (dry_mass + fuel)
				acc += Vector2(sin(angle), cos(angle)) * a
			vx += acc.x * delta
			vy += acc.y * delta
			x += vx * delta
			alt += vy * delta
		if thrusting:
			fuel = maxf(0.0, fuel - fuel_burn * delta)
	else:
		thrusting = false
		rcs_dir = 0
	rotation = angle
	queue_redraw()


# =========================================================================
# Dibujo placeholder
# =========================================================================
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px_scale, px_scale))
	match style:
		Style.LM, Style.LM_DESCENT:
			_draw_lm(style == Style.LM)
		Style.SURVEYOR:
			_draw_surveyor()
		Style.CENTAUR:
			_draw_centaur()
	_draw_flame()
	_draw_rcs()


func _draw_lm(with_ascent: bool) -> void:
	var gold := Color("#c8962e")
	var gold_l := Color("#f0c862")
	var metal := Color("#a7a9b4")
	var metal_d := Color("#6c6e78")
	# Patas y almohadillas (envergadura 9.4 m).
	draw_line(Vector2(-6, 2), Vector2(-10, 9), metal, 1.0)
	draw_line(Vector2(6, 2), Vector2(10, 9), metal, 1.0)
	draw_line(Vector2(0, 4), Vector2(0, 9), metal_d, 1.0)
	draw_rect(Rect2(-12, 9, 4, 1), metal)
	draw_rect(Rect2(8, 9, 4, 1), metal)
	draw_rect(Rect2(-2, 9, 4, 1), metal_d)
	# Tobera del motor de descenso.
	draw_colored_polygon(PackedVector2Array([Vector2(-2, 4), Vector2(2, 4), Vector2(3, 7), Vector2(-3, 7)]), metal_d)
	# Etapa de descenso: octágono dorado (4.2 m de ancho).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -2), Vector2(6, -2), Vector2(7, -1), Vector2(7, 3),
		Vector2(6, 4), Vector2(-6, 4), Vector2(-7, 3), Vector2(-7, -1),
	]), gold)
	draw_rect(Rect2(-6, -2, 12, 1), gold_l)
	draw_rect(Rect2(-2, -1, 4, 4), Color("#22222a"))
	if with_ascent:
		_draw_ascent_stage(Vector2.ZERO)


## Etapa de ascenso (la "cabina" que despega en la Fase 4). Origen: su base.
func _draw_ascent_stage(base: Vector2) -> void:
	Lander.draw_ascent_stage_on(self, base)


## Versión estática para dibujar la cabina sobre cualquier lienzo (p. ej. al despegar).
static func draw_ascent_stage_on(c: CanvasItem, base: Vector2 = Vector2.ZERO) -> void:
	var silver := Color("#c8ccd8")
	var dark := Color("#5a5e72")
	c.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-5, -2), base + Vector2(5, -2), base + Vector2(6, -6),
		base + Vector2(3, -10), base + Vector2(-3, -10), base + Vector2(-6, -6),
	]), silver)
	c.draw_rect(Rect2(base + Vector2(-3, -7), Vector2(2, 2)), Color("#1c1d26"))  # Ventanas.
	c.draw_rect(Rect2(base + Vector2(1, -7), Vector2(2, 2)), Color("#1c1d26"))
	c.draw_rect(Rect2(base + Vector2(-5, -3), Vector2(10, 1)), dark)
	c.draw_line(base + Vector2(3, -10), base + Vector2(5, -13), dark, 1.0)  # Antena.
	c.draw_rect(Rect2(base + Vector2(4, -14), Vector2(3, 1)), silver)


func _draw_surveyor() -> void:
	var white := Color("#e3e6f0")
	var metal := Color("#a7a9b4")
	var metal_d := Color("#6c6e78")
	# Tres patas con amortiguadores.
	draw_line(Vector2(-3, 2), Vector2(-8, 7), metal, 1.0)
	draw_line(Vector2(3, 2), Vector2(8, 7), metal, 1.0)
	draw_line(Vector2(0, 3), Vector2(0, 7), metal_d, 1.0)
	draw_rect(Rect2(-10, 7, 4, 1), metal)
	draw_rect(Rect2(6, 7, 4, 1), metal)
	draw_rect(Rect2(-1, 7, 2, 1), metal_d)
	# Cuerpo triangular y caja térmica.
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 3), Vector2(5, 3), Vector2(0, -3)]), metal_d)
	draw_rect(Rect2(-3, -1, 6, 3), white)
	# Mástil con panel solar y antena plana.
	draw_line(Vector2(0, -3), Vector2(0, -10), metal, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -12), Vector2(0, -10), Vector2(0, -8), Vector2(-6, -10)]), Color("#1e3f8f"))
	draw_rect(Rect2(1, -11, 4, 3), white)
	# Cámara de TV (lo que se llevará el Apolo 12).
	draw_rect(Rect2(3, 0, 2, 2), Color("#1c1d26"))


func _draw_centaur() -> void:
	var white := Color("#e3e6f0")
	var band := Color("#a7a9b4")
	draw_rect(Rect2(-4, -10, 8, 20), white)
	draw_rect(Rect2(-4, -4, 8, 1), band)
	draw_rect(Rect2(-4, 3, 8, 1), band)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 10), Vector2(-1, 10), Vector2(-1, 12), Vector2(-4, 12)]), band)
	draw_colored_polygon(PackedVector2Array([Vector2(1, 10), Vector2(3, 10), Vector2(4, 12), Vector2(1, 12)]), band)
	# Surveyor plegada encima (cono de carga).
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -10), Vector2(4, -10), Vector2(0, -16)]), Color("#c9c9d2"))


func _draw_flame() -> void:
	if not thrusting:
		return
	var base_y := 7.0
	match style:
		Style.SURVEYOR:
			base_y = 4.0
		Style.CENTAUR:
			base_y = 12.0
	var flame_len := 6.0 + 3.0 * sin(_t * 40.0) + randf() * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-2, base_y), Vector2(2, base_y), Vector2(0, base_y + flame_len)]), Color("#ffb347"))
	draw_colored_polygon(PackedVector2Array([Vector2(-1, base_y), Vector2(1, base_y), Vector2(0, base_y + flame_len * 0.6)]), Color("#fff4c0"))


func _draw_rcs() -> void:
	if rcs_dir == 0:
		return
	# Chorritos laterales: empujan en sentido contrario al giro.
	var y := -6.0 if style == Style.LM else -2.0
	var side := -1.0 if rcs_dir > 0 else 1.0
	draw_rect(Rect2(Vector2(side * 8 - 1, y), Vector2(2, 1)), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(Vector2(-side * 8 - 1, y + 4), Vector2(2, 1)), Color(1, 1, 1, 0.6))
