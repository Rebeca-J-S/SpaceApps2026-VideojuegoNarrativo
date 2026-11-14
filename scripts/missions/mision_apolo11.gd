extends MissionBase
## MISIÓN 1 — "GUARDIANES DE LA TRANQUILIDAD" (Apolo 11, 1969).
## Narradores: etapa de descenso del Eagle, Houston, EASEP y espejo láser LRRR.
## Guion literal en data/dialogos/mision_1.json.

const PPM := 5.0                    # píxeles por metro en el aterrizaje (9.4 m de patas = 48 px)
const HALF_SPAN := 4.7              # mitad de la envergadura de las patas (m)
const SAFE_VY := 2.0                # m/s
const SAFE_VX := 1.5                # m/s
const SAFE_TILT := 6.0              # grados
## Rocas del sitio de alunizaje: x (m), ancho (m), alto (m). Valores de juego.
const ROCKS := [
	Vector3(40, 8, 3.0), Vector3(52, 5, 2.0), Vector3(64, 11, 4.0),
	Vector3(77, 6, 2.5), Vector3(101, 7, 3.0), Vector3(6, 6, 2.0),
]

var _carry := {}                    # estado de la nave que pasa de la Fase 1 a la 2
var _lander: Lander
var _ground_y := 318.0
var _alarm := false
var _dust := 0.0
# Estado del sitio de alunizaje (fases 3-5)
var _easep_out := 0.0               # 0..1 el EASEP sale de la bodega y viaja 17 m al sur
var _panels := 0.0                  # 0..1 paneles solares desplegados
var _lrrr := false
var _signal_t := -1.0
var _ascent_y := 0.0
var _ascent_flying := false
var _seismo := false
var _laser_t := -1.0
var _plaque := false
var _astro_x := 0.0
var _stable := 0.0


func _init() -> void:
	mission_id = "apolo11"
	mission_number = 1
	mission_name = "GUARDIANES DE LA TRANQUILIDAD · APOLO 11"
	dialog_path = "res://data/dialogos/mision_1.json"
	phase_titles = [
		"EL VÍNCULO", "LOS 756.3 SEGUNDOS DE FUEGO", "EL VELO DE POLVO",
		"EL DESPERTAR DEL EASEP", "LA DESPEDIDA", "EL LEGADO ETERNO",
	]


func run_phase(i: int) -> void:
	match i:
		0: await _phase_0()
		1: await _phase_1()
		2: await _phase_2()
		3: await _phase_3()
		4: await _phase_4()
		5: await _phase_5()


# =========================================================================
# FASE 0 — Tutorial en órbita lunar a 14.5 km
# =========================================================================
func _phase_0() -> void:
	await begin_phase(0, "Estabiliza el Eagle: inclinación 0° y sin girar durante 2 s",
		"A/D o FLECHAS: PROPULSORES RCS")
	add_starfield(150, Vector2(-4, 0))
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, Vector2(560, 70), 10.0)
		# Horizonte lunar curvo visto desde la órbita.
		c.draw_circle(Vector2(320, 1250), 1000.0, Color("#5d5c69"))
		c.draw_arc(Vector2(320, 1250), 1000.0, PI * 1.3, PI * 1.7, 64, Color("#8d8d99"), 2.0)
	, false)
	_lander = Lander.new()
	_lander.style = Lander.Style.LM
	_lander.rotation_only = true
	_lander.position = Vector2(320, 160)
	_lander.angle = 0.55
	_lander.ang_vel = 0.9
	add_world(_lander)

	_stable = 0.0
	draw_layer(func(c: DrawNode) -> void:
		draw_bar(c, Rect2(240, 230, 160, 6), _stable / 2.0, RetroTheme.PHOSPHOR, "ESTABILIDAD")
	)
	_lander.active = false
	await say("f0_intro")
	_lander.active = true
	while _stable < 2.0:
		await get_tree().physics_frame
		var tilt := rad_to_deg(_lander.angle)
		var spin := rad_to_deg(_lander.ang_vel)
		set_telemetry("ALTITUD: 14.5 km\nINCLINACIÓN: %+.1f°\nGIRO: %+.1f °/s" % [tilt, spin])
		if absf(tilt) < 3.0 and absf(spin) < 4.0:
			_stable += get_physics_process_delta_time()
		else:
			_stable = 0.0
	_lander.active = false
	await toast("¡ESTABLE!", RetroTheme.PHOSPHOR, 1.0)
	await say("f0_ok")


# =========================================================================
# FASE 1 — Descenso propulsado (aproximación)
# =========================================================================
func _phase_1() -> void:
	await begin_phase(1, "Baja hasta 100 m a menos de 12 m/s sin desviarte de Mare Tranquillitatis",
		"W/ESPACIO: MOTOR  ·  A/D: RCS")
	add_starfield(120)
	_lander = _make_flight_lander()
	_lander.x = 50.0
	_lander.alt = 600.0
	_lander.vy = -18.0
	_lander.vx = 4.0
	var target_x := 64.0
	draw_layer(func(c: DrawNode) -> void:
		# Superficie lejana que "sube" a medida que bajamos (parallax).
		var k := clampf(1.0 - _lander.alt / 600.0, 0.0, 1.0)
		var top := 300.0 - k * 70.0
		c.draw_rect(Rect2(0, top, W, H - top), Color("#4a4a55"))
		c.draw_rect(Rect2(0, top, W, 2), Color("#8d8d99"))
		for i in 12:
			var cx := fmod(i * 61.0 + 20.0, W)
			c.draw_set_transform(Vector2(cx, top + 12 + fmod(i * 17.0, 40.0)), 0.0, Vector2(1, 0.3))
			c.draw_circle(Vector2.ZERO, 4.0 + k * 6.0 + fmod(i * 3.0, 6.0), Color("#3b3b47"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Marcador del objetivo: Mare Tranquillitatis.
		var tx := target_x * PPM
		c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 6, top - 10), Vector2(tx + 6, top - 10), Vector2(tx, top - 2)]), RetroTheme.PHOSPHOR)
		c.draw_string(ThemeDB.fallback_font, Vector2(tx - 60, top - 14), "0.67° N · 23.47° E", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, RetroTheme.PHOSPHOR)
		if _alarm and fmod(c.t, 0.5) < 0.3:
			c.draw_string(ThemeDB.fallback_font, Vector2(0, 70), "ALARMA 1202 · COMPUTADORA SATURADA", HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color("#ff5a4a"))
	)
	add_world(_lander)
	_alarm = false
	landing_camera(_lander, PPM)
	await say("f1_ignicion")
	_lander.active = true
	var alarm_done := false
	while true:
		await get_tree().physics_frame
		_ground_y = landing_camera(_lander, PPM)
		_lander.x = clampf(_lander.x, 6.0, 122.0)
		var dev := _lander.x - target_x
		_flight_telemetry("DESVÍO: %+.0f m" % dev)
		if not alarm_done and _lander.alt < 380.0:
			alarm_done = true
			_alarm = true
			_lander.active = false
			await say("f1_alarma")
			_lander.active = true
		if _lander.alt <= 100.0:
			break
		if _lander.fuel <= 0.0:
			break
	_lander.active = false
	_alarm = false
	if _lander.fuel <= 0.0 or _lander.vy < -12.0 or absf(_lander.x - target_x) > 45.0:
		await toast("APROXIMACIÓN FALLIDA\nDemasiado rápido, sin combustible o fuera de rumbo", Color("#ff5a4a"), 2.2)
		await _phase_1()
		return
	_carry = {"x": _lander.x, "vx": _lander.vx, "vy": _lander.vy, "angle": _lander.angle, "fuel": _lander.fuel}
	await toast("100 METROS · ENTRANDO EN LA FASE FINAL", RetroTheme.PHOSPHOR, 1.2)


# =========================================================================
# FASE 2 — Los últimos 100 metros: rocas y polvo
# =========================================================================
func _phase_2() -> void:
	await begin_phase(2, "Posa las 4 patas en suelo plano: < 2 m/s y < 6° de inclinación",
		"W/ESPACIO: MOTOR  ·  A/D: RCS")
	add_starfield(80)
	_lander = _make_flight_lander()
	_lander.x = _carry.get("x", 64.0)
	_lander.vx = _carry.get("vx", 0.0)
	_lander.vy = clampf(_carry.get("vy", -6.0), -10.0, 0.0)
	_lander.angle = _carry.get("angle", 0.0)
	# Si se gastó casi todo en la Fase 1, se deja un mínimo para que sea jugable.
	_lander.fuel = maxf(_carry.get("fuel", 2000.0), _lander.fuel_capacity * 0.12)
	_lander.fuel_burn = 70.0  # Regulador al mínimo: maniobras finas.
	_lander.alt = 100.0
	_dust = 0.0
	draw_layer(_draw_landing_site)
	add_world(_lander)
	landing_camera(_lander, PPM)
	_lander.active = true
	var said_50 := false
	var said_10 := false
	while _lander.alt > 0.0:
		await get_tree().physics_frame
		_ground_y = landing_camera(_lander, PPM)
		_lander.x = clampf(_lander.x, 6.0, 122.0)
		_dust = clampf((15.0 - _lander.alt) / 10.0, 0.0, 1.0) if _lander.thrusting or _dust > 0.0 else 0.0
		_flight_telemetry("")
		if not said_50 and _lander.alt < 50.0:
			said_50 = true
			_lander.active = false
			await say("f2_50m")
			_lander.active = true
		if not said_10 and _lander.alt < 10.0:
			said_10 = true
			_lander.active = false
			_lander.fuel = minf(_lander.fuel, _lander.fuel_capacity * 0.049)
			await say("f2_10m")
			_lander.active = true
	_lander.active = false
	_lander.alt = 0.0
	landing_camera(_lander, PPM)
	var reason := _landing_problem()
	if reason != "":
		await toast("CONTACTO INSEGURO\n" + reason, Color("#ff5a4a"), 2.4)
		await say("f2_fallo")
		await _phase_2()
		return
	_dust = 0.0
	await toast("20:17:40 UT · LUZ DE CONTACTO", RetroTheme.PHOSPHOR, 1.4)
	await say("f2_touchdown")


func _make_flight_lander() -> Lander:
	var l := Lander.new()
	l.style = Lander.Style.LM
	l.gravity = MissionData.MOON_GRAVITY
	l.max_thrust = MissionData.DESCENT_THRUST_N
	l.fuel_capacity = MissionData.DESCENT_FUEL_KG
	l.fuel = MissionData.DESCENT_FUEL_KG
	l.dry_mass = MissionData.LM_TOTAL_MASS_KG - MissionData.DESCENT_FUEL_KG
	return l


func _flight_telemetry(extra: String) -> void:
	var used := 1.0 - _lander.fuel_ratio()
	var txt := "ALTITUD: %.0f m\nV/V: %+.1f m/s\nV/H: %+.1f m/s\nINCL: %+.1f°\nCOMB: %.0f kg (%.0f%%)\nIGNICIÓN: T+%.1f / 756.3 s" % [
		_lander.alt, _lander.vy, _lander.vx, rad_to_deg(_lander.angle),
		_lander.fuel, _lander.fuel_ratio() * 100.0, used * MissionData.DESCENT_BURN_S,
	]
	if extra != "":
		txt += "\n" + extra
	set_telemetry(txt)


## Devuelve "" si el aterrizaje es seguro, o el motivo del fallo.
func _landing_problem() -> String:
	for r: Vector3 in ROCKS:
		if absf(_lander.x - r.x) < HALF_SPAN + r.y * 0.5:
			return "Las patas cayeron sobre rocas."
	if _lander.vy < -SAFE_VY:
		return "Velocidad vertical %.1f m/s (máx. %.0f)." % [absf(_lander.vy), SAFE_VY]
	if absf(_lander.vx) > SAFE_VX:
		return "Te desplazabas de lado a %.1f m/s." % absf(_lander.vx)
	if absf(rad_to_deg(_lander.angle)) > SAFE_TILT:
		return "Inclinación %.0f° (máx. %.0f°)." % [absf(rad_to_deg(_lander.angle)), SAFE_TILT]
	return ""


func _draw_landing_site(c: DrawNode) -> void:
	draw_earth(c, Vector2(560, 60), 9.0)
	draw_moon_ground(c, _ground_y)
	for r: Vector3 in ROCKS:
		var x := r.x * PPM
		var w := r.y * PPM
		var h := r.z * PPM
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, _ground_y + 1), Vector2(x - w * 0.35, _ground_y - h),
			Vector2(x + w * 0.2, _ground_y - h * 1.1), Vector2(x + w * 0.5, _ground_y + 1),
		]), Color("#3b3a45"))
		c.draw_line(Vector2(x - w * 0.35, _ground_y - h), Vector2(x + w * 0.2, _ground_y - h * 1.1), Color("#8d8d99"), 2.0)
	# Polvo levantado por el motor: tapa el suelo ("¡Ya no veo el suelo!").
	if _dust > 0.0:
		var a := _dust * 0.85
		c.draw_rect(Rect2(0, _ground_y - 50, W, 60), Color(0.55, 0.55, 0.6, a))
		for i in 60:
			var px := fmod(i * 37.0 + c.t * 90.0 * (1.0 if i % 2 == 0 else -1.0), W)
			c.draw_rect(Rect2(px, _ground_y - 8 - fmod(i * 13.0, 50.0), 2, 1), Color(0.8, 0.8, 0.85, a))


# =========================================================================
# Escenario del sitio de alunizaje (fases 3, 4 y 5)
# =========================================================================
const SITE_GROUND := 300.0
const EAGLE_X := 200.0
const EASEP_X := 430.0      # 17 m al sur (escala libre en esta vista)
const LRRR_X := 490.0       # 5 m al nor-noroeste del EASEP


func _build_site(with_ascent: bool) -> void:
	add_starfield(140)
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, Vector2(560, 64), 11.0)
		draw_moon_ground(c, SITE_GROUND)
		_draw_easep(c)
		_draw_lrrr(c)
		_draw_astronauts(c)
		_draw_signal(c)
		_draw_laser(c)
		_draw_plaque(c)
	)
	var eagle := Lander.new()
	eagle.style = Lander.Style.LM if with_ascent else Lander.Style.LM_DESCENT
	eagle.position = Vector2(EAGLE_X, SITE_GROUND - eagle.feet_offset())
	add_world(eagle)
	_lander = eagle


func _draw_easep(c: DrawNode) -> void:
	if _easep_out <= 0.0:
		return
	var x := lerpf(EAGLE_X + 20.0, EASEP_X, _easep_out)
	var y := SITE_GROUND
	# Cuerpo (sismómetro) y paneles solares este / oeste.
	c.draw_rect(Rect2(x - 6, y - 10, 12, 10), Color("#a7a9b4"))
	c.draw_rect(Rect2(x - 4, y - 14, 6, 4), Color("#f0c862"))
	var pw := 18.0 * _panels
	if _panels > 0.0:
		c.draw_rect(Rect2(x - 6 - pw, y - 14, pw, 6), Color("#1e3f8f"))
		c.draw_rect(Rect2(x + 6, y - 14, pw, 6), Color("#1e3f8f"))
		c.draw_rect(Rect2(x - 6 - pw, y - 14, pw, 1), Color("#3d6fd6"))
		c.draw_rect(Rect2(x + 6, y - 14, pw, 1), Color("#3d6fd6"))
	c.draw_line(Vector2(x + 2, y - 14), Vector2(x + 4, y - 24), Color("#a7a9b4"), 1.0)
	if _seismo:
		# Sismograma: lunamotos llegando.
		var base := Vector2(x - 60, y - 70)
		c.draw_rect(Rect2(base, Vector2(120, 40)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(base, Vector2(120, 40)), RetroTheme.PHOSPHOR, false, 1.0)
		var prev := base + Vector2(0, 20)
		for i in 120:
			var amp := 2.0 + 14.0 * maxf(0.0, sin(i * 0.08 - c.t * 2.0)) * absf(sin(i * 0.9 + c.t * 9.0))
			var p := base + Vector2(i, 20 + amp * sin(i * 1.7 + c.t * 20.0) * 0.5)
			c.draw_line(prev, p, RetroTheme.PHOSPHOR, 1.0)
			prev = p
		c.draw_string(ThemeDB.fallback_font, base + Vector2(2, -3), "SISMÓMETRO PASIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RetroTheme.PHOSPHOR)


func _draw_lrrr(c: DrawNode) -> void:
	if not _lrrr:
		return
	var x := LRRR_X
	var y := SITE_GROUND
	c.draw_line(Vector2(x - 8, y), Vector2(x - 8, y - 6), Color("#6c6e78"), 2.0)
	c.draw_line(Vector2(x + 8, y), Vector2(x + 8, y - 10), Color("#6c6e78"), 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 11, y - 10), Vector2(x + 11, y - 15), Vector2(x + 11, y - 7), Vector2(x - 11, y - 3)]), Color("#a7a9b4"))
	for i in 5:
		c.draw_rect(Rect2(x - 9 + i * 4, y - 9 - i, 2, 2), Color("#3b3e57"))


## PROPUESTA (tercer minijuego): la placa del Eagle vista de cerca.
func _draw_plaque(c: DrawNode) -> void:
	if not _plaque:
		return
	var r := Rect2(EAGLE_X - 70, 90, 140, 80)
	c.draw_rect(r, Color("#d9dce6"))
	c.draw_rect(r, Color("#6c6e78"), false, 2.0)
	c.draw_circle(r.position + Vector2(45, 26), 16.0, Color("#8d93a8"))  # Hemisferio occidental.
	c.draw_circle(r.position + Vector2(95, 26), 16.0, Color("#8d93a8"))  # Hemisferio oriental.
	for i in 4:
		c.draw_rect(Rect2(r.position + Vector2(18, 52 + i * 6), Vector2(104 - (i % 2) * 20, 2)), Color("#5a5e72"))


func _draw_astronauts(c: DrawNode) -> void:
	if _astro_x <= 0.0:
		return
	for k in 2:
		var x := _astro_x + k * 14.0
		var bob := absf(sin(c.t * 12.0 + k)) * 2.0
		var y := SITE_GROUND - 14 - bob
		c.draw_rect(Rect2(x - 3, y, 6, 9), Color("#eef1f8"))
		c.draw_rect(Rect2(x - 2, y - 5, 5, 5), Color("#eef1f8"))
		c.draw_rect(Rect2(x - 1, y - 4, 3, 2), Color("#e0b040"))
		c.draw_rect(Rect2(x - 3, y + 9, 2, 5), Color("#c8ccd8"))
		c.draw_rect(Rect2(x + 1, y + 9, 2, 5), Color("#c8ccd8"))


func _draw_signal(c: DrawNode) -> void:
	if _signal_t < 0.0:
		return
	# Ondas de radio desde la Tierra hasta el EASEP (2119 MHz).
	var from := Vector2(560, 64)
	var to := Vector2(EASEP_X + 4, SITE_GROUND - 24)
	for k in 4:
		var f := fmod(c.t * 0.8 + k * 0.25, 1.0)
		var p := from.lerp(to, f)
		c.draw_arc(p, 4.0 + f * 4.0, 0.0, TAU, 12, Color(RetroTheme.PHOSPHOR, 1.0 - f), 1.0)
	c.draw_string(ThemeDB.fallback_font, to + Vector2(10, -20), "2119 MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RetroTheme.PHOSPHOR)


func _draw_laser(c: DrawNode) -> void:
	if _laser_t < 0.0:
		return
	var from := Vector2(560, 64)
	var to := Vector2(LRRR_X, SITE_GROUND - 10)
	var f := fmod(c.t * 0.9, 2.0)
	var col := Color("#4dff6a")
	if f < 1.0:
		c.draw_line(from.lerp(to, maxf(f - 0.3, 0.0)), from.lerp(to, f), col, 2.0)
	else:
		var g := f - 1.0
		c.draw_line(to.lerp(from, maxf(g - 0.3, 0.0)), to.lerp(from, g), col, 2.0)
		c.draw_circle(to, 6.0 * (1.0 - g), Color(col, 1.0 - g))
	c.draw_string(ThemeDB.fallback_font, Vector2(380, 110), "DISTANCIA TIERRA-LUNA ~384,400 km\nLa Luna se aleja 3.8 cm/año", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


# =========================================================================
# FASE 3 — Despliegue del EASEP (clics en los puntos brillantes)
# =========================================================================
func _phase_3() -> void:
	await begin_phase(3, "Despliega los experimentos: activa los puntos en orden",
		"CLIC o TECLAS 1-2-3: ACTIVAR PUNTO")
	_easep_out = 0.0
	_panels = 0.0
	_lrrr = false
	_signal_t = -1.0
	_astro_x = 0.0
	_build_site(true)
	var spots := spawn_hotspots([
		["SACAR EL EASEP DE LA BODEGA", Vector2(EAGLE_X + 26, SITE_GROUND - 30)],
		["DESPLEGAR PANELES SOLARES", Vector2(EASEP_X, SITE_GROUND - 40)],
		["COLOCAR EL ESPEJO LRRR", Vector2(LRRR_X, SITE_GROUND - 40)],
	])
	spots[1].enabled = false
	spots[2].enabled = false

	await wait_specific(spots[0])
	_astro_x = EAGLE_X + 20.0
	var tw := create_tween().set_parallel()  # Cámara rápida: los astronautas trabajan.
	tw.tween_property(self, "_easep_out", 1.0, 1.6)
	tw.tween_property(self, "_astro_x", EASEP_X - 30.0, 1.6)
	await tw.finished
	spots[1].enabled = true

	await wait_specific(spots[1])
	var tw2 := create_tween()
	tw2.tween_property(self, "_panels", 1.0, 1.0)
	await tw2.finished
	spots[2].enabled = true

	await wait_specific(spots[2])
	var tw3 := create_tween()
	tw3.tween_property(self, "_astro_x", LRRR_X - 30.0, 0.8)
	await tw3.finished
	_lrrr = true
	await wait(0.5)
	_signal_t = 0.0
	set_objective("04:40 UT · Señal de la Tierra a 2119 MHz")
	await wait(1.5)
	await say("f3_easep")


# =========================================================================
# FASE 4 — La despedida: despega la etapa de ascenso
# =========================================================================
func _phase_4() -> void:
	await begin_phase(4, "21 h 36 min después del alunizaje: enciende el motor de ascenso",
		"W/ESPACIO: DESPEGAR")
	_easep_out = 1.0
	_panels = 1.0
	_lrrr = true
	_signal_t = -1.0
	_astro_x = 0.0
	_build_site(false)  # El Eagle de abajo se queda; la cabina se dibuja aparte.
	_ascent_y = 0.0
	_ascent_flying = false
	var ascent := draw_layer(func(c: DrawNode) -> void:
		var base := Vector2(EAGLE_X, SITE_GROUND - _lander.feet_offset() - _ascent_y)
		c.draw_set_transform(base, 0.0, Vector2(2, 2))
		Lander.draw_ascent_stage_on(c)
		if _ascent_flying:
			var fl := 4.0 + randf() * 4.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(0, fl)]), Color("#ffb347"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _ascent_flying and _ascent_y < 60.0:
			c.draw_rect(Rect2(EAGLE_X - 60, SITE_GROUND - 20, 120, 20), Color(0.6, 0.6, 0.65, 0.5 * (1.0 - _ascent_y / 60.0)))
	)
	ascent.z_index = 1
	while not Input.is_action_just_pressed("thrust"):
		await get_tree().process_frame
	_ascent_flying = true
	set_objective("Motor de ascenso: 15,000 N · Neil y Buzz vuelven a casa")
	var tw := create_tween()
	tw.tween_property(self, "_ascent_y", 380.0, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_ascent_flying = false
	await say("f4_despedida")


# =========================================================================
# FASE 5 — El legado eterno (minijuegos de un clic)
# =========================================================================
func _phase_5() -> void:
	await begin_phase(5, "Descubre el legado: activa los tres puntos",
		"CLIC o TECLAS 1-2-3: ACTIVAR PUNTO")
	_easep_out = 1.0
	_panels = 1.0
	_lrrr = true
	_seismo = false
	_laser_t = -1.0
	_build_site(false)
	var spots := spawn_hotspots([
		["SISMÓMETRO DEL EASEP", Vector2(EASEP_X, SITE_GROUND - 34)],
		["PLACA DEL EAGLE", Vector2(EAGLE_X, SITE_GROUND - 12)],
		["ESPEJO LÁSER LRRR", Vector2(LRRR_X + 10, SITE_GROUND - 34)],
	])
	spots[2].enabled = false  # El LRRR es el cierre emocional: se deja para el final.
	var done := 0
	while done < 2:
		var h := await wait_hotspot()
		if h == spots[0]:
			_seismo = true
			await say("f5_sismometro")
			_seismo = false
		elif h == spots[1]:
			_plaque = true
			await say("f5_placa")  # PROPUESTA: tercer minijuego (no está en el guion aprobado).
			_plaque = false
		done += 1
	spots[2].enabled = true
	await wait_specific(spots[2])
	_laser_t = 0.0
	await wait(1.2)
	await say("f5_lrrr")
	_laser_t = -1.0
