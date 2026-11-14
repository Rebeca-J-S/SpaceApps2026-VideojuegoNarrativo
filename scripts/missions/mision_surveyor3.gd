extends MissionBase
## MISIÓN 2 — "HUELLAS EN EL POLVO: LA ODISEA DE SURVEYOR 3" (Luna, 1967).
## Narradores: etapa Centaur, Surveyor 3, su brazo mecánico y Alan Bean (Apolo 12).
## Guion literal en data/dialogos/mision_2.json.

const LAMP_COLORS := [Color("#ff5a4a"), Color("#39ff7a"), Color("#4da6ff"), Color("#ffd24a")]
const LAMP_CENTERS := [Vector2(230, 280), Vector2(290, 280), Vector2(350, 280), Vector2(410, 280)]
const PPM := 9.0   # píxeles por metro en el aterrizaje (patas de ~4.3 m)

var _lander: Lander
var _stable := 0.0
var _burn := 0.0
var _earth_scale := 1.0
var _lamp_lit := -1
var _accept_lamps := false
var _ground_y := 318.0
# Brazo (fase 3)
var _arm := 0.0
var _trench := 0.0
var _pressure := 0.0
# Noche (fase 4)
var _night := 0.0
var _battery := 1.0
# Reencuentro (fase 5)
var _astro_x := 100.0

signal lamp_pressed(index: int)


func _init() -> void:
	mission_id = "surveyor3"
	mission_number = 2
	mission_name = "HUELLAS EN EL POLVO · SURVEYOR 3"
	dialog_path = "res://data/dialogos/mision_2.json"
	phase_titles = [
		"EL DESPEGUE Y EL IMPULSO CENTAUR", "EL DESCENSO CIEGO", "EL VEREDICTO DE LA ARENA HÚMEDA",
		"LA EXCAVACIÓN Y EL GRAN DESCUBRIMIENTO", "LA NOCHE LUNAR Y EL SILENCIO", "EL REENCUENTRO CON EL APOLO 12",
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
# FASE 0 — Etapa Centaur: alinear y dos encendidos
# =========================================================================
func _phase_0() -> void:
	await begin_phase(0, "Alinea la Centaur (0°) y haz 2 encendidos de 1.5 s",
		"A/D: ALINEAR  ·  W/ESPACIO: ENCENDER")
	add_starfield(150)
	_earth_scale = 1.0
	draw_layer(func(c: DrawNode) -> void:
		# La Tierra se hace pequeña con cada encendido.
		var r := 140.0 * _earth_scale
		c.draw_circle(Vector2(90, 420 - (1.0 - _earth_scale) * 200.0), r, Color("#2e6bd1"))
		c.draw_circle(Vector2(60, 400 - (1.0 - _earth_scale) * 200.0), r * 0.4, Color("#3f9a52"))
		c.draw_circle(Vector2(560, 70), 14.0, Color("#b4b4c0"))  # La Luna, destino.
		draw_bar(c, Rect2(240, 300, 160, 6), _burn / 1.5, Color("#ffb347"), "ENCENDIDO")
		draw_bar(c, Rect2(240, 270, 160, 6), _stable / 1.5, RetroTheme.PHOSPHOR, "ALINEACIÓN")
	)
	_lander = Lander.new()
	_lander.style = Lander.Style.CENTAUR
	_lander.rotation_only = true
	_lander.fuel = 9999.0
	_lander.fuel_capacity = 9999.0
	_lander.fuel_burn = 0.0
	_lander.position = Vector2(320, 150)
	_lander.angle = -0.5
	_lander.ang_vel = -0.6
	add_world(_lander)
	await say("f0_intro")
	_lander.active = true
	for burn_index in 2:
		_burn = 0.0
		_stable = 0.0
		set_objective("Encendido %d de 2: alinea a 0° y mantén W 1.5 s" % (burn_index + 1))
		while _burn < 1.5:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			var tilt := rad_to_deg(_lander.angle)
			var aligned := absf(tilt) < 5.0
			_stable = clampf(_stable + (dt if aligned else -dt * 2.0), 0.0, 1.5)
			if _lander.thrusting and aligned:
				_burn += dt
			set_telemetry("INCLINACIÓN: %+.1f°\nENCENDIDOS: %d / 2" % [tilt, burn_index])
		_earth_scale = 0.55 if burn_index == 0 else 0.15
		await toast("ENCENDIDO %d COMPLETADO" % (burn_index + 1), RetroTheme.PHOSPHOR, 1.0)
	_lander.active = false
	await say("f0_ok")


# =========================================================================
# FASE 1 — Radar confundido y rebotes: secuencia de destellos
# =========================================================================
func _phase_1() -> void:
	await begin_phase(1, "Repite los destellos de emergencia en el mismo orden",
		"TECLAS 1-2-3-4 o CLIC EN LAS LUCES")
	add_starfield(100)
	draw_layer(func(c: DrawNode) -> void:
		draw_moon_ground(c, 330)
		for i in 4:
			var lit := _lamp_lit == i
			var p: Vector2 = LAMP_CENTERS[i]
			var col: Color = LAMP_COLORS[i]
			c.draw_rect(Rect2(p - Vector2(20, 20), Vector2(40, 40)), Color(0, 0, 0, 0.7))
			c.draw_circle(p, 15.0, col if lit else col.darkened(0.7))
			if lit:
				c.draw_arc(p, 19.0, 0.0, TAU, 20, Color.WHITE, 2.0)
			c.draw_string(ThemeDB.fallback_font, p + Vector2(-4, 34), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RetroTheme.WHITE)
	)
	_lander = Lander.new()
	_lander.style = Lander.Style.SURVEYOR
	_lander.px_scale = 3.0
	_lander.position = Vector2(320, 120)
	add_world(_lander)
	await say("f1_frenado")
	# Rebote: sube a "10 m" y cae a "3 m".
	var tw := create_tween()
	tw.tween_property(_lander, "position:y", 170.0, 0.5)
	tw.tween_property(_lander, "position:y", 90.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lander, "position:y", 180.0, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_property(_lander, "position:y", 150.0, 0.4).set_ease(Tween.EASE_OUT)
	await tw.finished
	await say("f1_rebote")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while true:
		var seq: Array[int] = []
		for i in 5:
			seq.append(rng.randi_range(0, 3))
		set_objective("Observa la secuencia...")
		await wait(0.6)
		for idx in seq:
			_lamp_lit = idx
			await wait(0.45)
			_lamp_lit = -1
			await wait(0.18)
		set_objective("¡Tu turno! Repite los %d destellos" % seq.size())
		var ok := true
		_accept_lamps = true
		for idx in seq:
			var pressed: int = await lamp_pressed
			_lamp_lit = pressed
			await wait(0.15)
			_lamp_lit = -1
			if pressed != idx:
				ok = false
				break
		_accept_lamps = false
		if ok:
			await toast("¡PATAS ESTABILIZADAS!", RetroTheme.PHOSPHOR, 1.2)
			return
		await say("f1_fallo")


func _unhandled_input(event: InputEvent) -> void:
	if _accept_lamps and not get_tree().paused and not radio.is_active():
		if event is InputEventKey and event.pressed and not event.echo:
			for i in 4:
				if event.physical_keycode == KEY_1 + i or event.physical_keycode == KEY_KP_1 + i:
					get_viewport().set_input_as_handled()
					lamp_pressed.emit(i)
					return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var m := get_local_mouse_position()
			for i in 4:
				if m.distance_to(LAMP_CENTERS[i]) < 20.0:
					get_viewport().set_input_as_handled()
					lamp_pressed.emit(i)
					return
	super._unhandled_input(event)


# =========================================================================
# FASE 2 — Toque final en Oceanus Procellarum
# =========================================================================
func _phase_2() -> void:
	await begin_phase(2, "Posa las 3 patas con suavidad: < 2.5 m/s y < 8° de inclinación",
		"W/ESPACIO: MOTORES VERNIER  ·  A/D: GIRAR")
	add_starfield(80)
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, Vector2(560, 60), 9.0)
		draw_moon_ground(c, _ground_y, Color("#66656f"))
	)
	_lander = Lander.new()
	_lander.style = Lander.Style.SURVEYOR
	# Valores de juego (no son los parámetros reales de la Surveyor).
	_lander.dry_mass = 290.0
	_lander.fuel = 60.0
	_lander.fuel_capacity = 60.0
	_lander.max_thrust = 1000.0
	_lander.fuel_burn = 5.0
	_lander.gravity = MissionData.MOON_GRAVITY
	_lander.x = 35.0
	_lander.alt = 14.0
	_lander.vy = -1.0
	add_world(_lander)
	landing_camera(_lander, PPM)
	_lander.active = true
	while _lander.alt > 0.0:
		await get_tree().physics_frame
		_ground_y = landing_camera(_lander, PPM)
		_lander.x = clampf(_lander.x, 3.0, 68.0)
		set_telemetry("ALTITUD: %.1f m\nV/V: %+.1f m/s\nINCL: %+.1f°\nCOMB: %.0f%%" % [
			_lander.alt, _lander.vy, rad_to_deg(_lander.angle), _lander.fuel_ratio() * 100.0])
	_lander.active = false
	_lander.alt = 0.0
	landing_camera(_lander, PPM)
	if _lander.vy < -2.5 or absf(rad_to_deg(_lander.angle)) > 8.0:
		await toast("GOLPE DEMASIADO FUERTE", Color("#ff5a4a"), 1.6)
		await say("f2_fallo")
		await _phase_2()
		return
	await toast("20 DE ABRIL DE 1967 · CONTACTO", RetroTheme.PHOSPHOR, 1.4)
	await say("f2_touchdown")


# =========================================================================
# FASE 3 — El brazo excavador
# =========================================================================
func _phase_3() -> void:
	await begin_phase(3, "Ordena las pruebas de suelo con el brazo mecánico",
		"CLIC o TECLAS 1-2-3: ACTIVAR PUNTO")
	_arm = 0.0
	_trench = 0.0
	_pressure = 0.0
	add_starfield(100)
	var surveyor_pos := Vector2(240, 300 - 8 * 3)
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, Vector2(560, 60), 9.0)
		draw_moon_ground(c, 300, Color("#66656f"))
		# Zanja excavada.
		if _trench > 0.0:
			c.draw_rect(Rect2(330, 300, 70 * _trench, 8), Color("#2e2d36"))
		# Brazo: dos segmentos desde el cuerpo hasta el suelo.
		var shoulder := surveyor_pos + Vector2(12, -2)
		var reach := lerpf(20.0, 110.0, _arm)
		var elbow := shoulder + Vector2(reach * 0.55, -18.0 + _arm * 6.0)
		var scoop := shoulder + Vector2(reach, 22.0 + _trench * 6.0)
		c.draw_line(shoulder, elbow, Color("#c8ccd8"), 3.0)
		c.draw_line(elbow, scoop, Color("#c8ccd8"), 3.0)
		c.draw_rect(Rect2(scoop - Vector2(4, 3), Vector2(8, 6)), Color("#e0b040"))
		if _pressure > 0.0:
			draw_bar(c, Rect2(400, 120, 180, 8), _pressure, RetroTheme.PHOSPHOR, "RESISTENCIA DEL SUELO")
			c.draw_string(ThemeDB.fallback_font, Vector2(400, 145), "Como arena húmeda: firme", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RetroTheme.PHOSPHOR)
	)
	_lander = Lander.new()
	_lander.style = Lander.Style.SURVEYOR
	_lander.px_scale = 3.0
	_lander.position = surveyor_pos
	add_world(_lander)
	var spots := spawn_hotspots([
		["EXTENDER EL BRAZO", Vector2(290, 250)],
		["CAVAR UNA ZANJA", Vector2(360, 285)],
		["MEDIR LA RESISTENCIA", Vector2(420, 260)],
	])
	spots[1].enabled = false
	spots[2].enabled = false
	await wait_specific(spots[0])
	await _tween_prop("_arm", 1.0, 1.2)
	spots[1].enabled = true
	await wait_specific(spots[1])
	await _tween_prop("_trench", 1.0, 1.5)
	spots[2].enabled = true
	await wait_specific(spots[2])
	await _tween_prop("_pressure", 0.7, 1.2)
	await say("f3_brazo")


func _tween_prop(prop: String, value: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, prop, value, seconds)
	await tw.finished


# =========================================================================
# FASE 4 — La noche lunar
# =========================================================================
func _phase_4() -> void:
	await begin_phase(4, "4 de mayo de 1967: observa cómo llega la noche lunar", "SOLO OBSERVA · ENTER PARA AVANZAR EL DIÁLOGO")
	_night = 0.0
	_battery = 1.0
	add_starfield(160)
	draw_layer(func(c: DrawNode) -> void:
		# El Sol baja por el horizonte y todo se oscurece.
		var sun := Vector2(520, lerpf(80.0, 330.0, _night))
		c.draw_circle(sun, 14.0, Color("#fff4c0"))
		draw_moon_ground(c, 300, Color("#66656f").darkened(_night * 0.7))
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0.03, _night * 0.55))
		draw_bar(c, Rect2(40, 60, 160, 8), _battery, Color("#ffb347") if _battery > 0.25 else Color("#ff5a4a"), "BATERÍA")
	)
	_lander = Lander.new()
	_lander.style = Lander.Style.SURVEYOR
	_lander.px_scale = 3.0
	_lander.position = Vector2(300, 300 - 24)
	add_world(_lander)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_night", 1.0, 9.0)
	tw.tween_property(self, "_battery", 0.0, 9.0)
	await say("f4_noche")
	if tw.is_running():
		await tw.finished
	await toast("SILENCIO", Color("#80f2ff"), 1.5)


# =========================================================================
# FASE 5 — El reencuentro con el Apolo 12
# =========================================================================
func _phase_5() -> void:
	await begin_phase(5, "Guía a los astronautas del Apolo 12 hasta la Surveyor 3",
		"A/D o FLECHAS: CAMINAR")
	_astro_x = 110.0
	var target_x := 540.0
	add_starfield(120)
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, Vector2(80, 60), 9.0)
		draw_moon_ground(c, 300)
		# Cráter donde descansa la Surveyor.
		c.draw_set_transform(Vector2(target_x, 304), 0.0, Vector2(1, 0.3))
		c.draw_circle(Vector2.ZERO, 70.0, Color("#45444f"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Pete Conrad y Alan Bean.
		for k in 2:
			var x := _astro_x - k * 16.0
			var y := 300.0 - 15.0 - absf(sin(c.t * 8.0 + k)) * 2.0
			c.draw_rect(Rect2(x - 3, y, 6, 9), Color("#eef1f8"))
			c.draw_rect(Rect2(x - 2, y - 5, 5, 5), Color("#eef1f8"))
			c.draw_rect(Rect2(x - 1, y - 4, 3, 2), Color("#e0b040"))
			c.draw_rect(Rect2(x - 3, y + 9, 2, 6), Color("#c8ccd8"))
			c.draw_rect(Rect2(x + 1, y + 9, 2, 6), Color("#c8ccd8"))
		var dist := maxf(0.0, (target_x - 30.0 - _astro_x) / (target_x - 140.0) * 180.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(0, 80), "DISTANCIA A LA SURVEYOR 3: %.0f m" % dist, HORIZONTAL_ALIGNMENT_CENTER, W, 12, RetroTheme.PHOSPHOR)
	)
	var intrepid := Lander.new()  # El módulo lunar Intrepid del Apolo 12.
	intrepid.style = Lander.Style.LM
	intrepid.position = Vector2(60, 300 - intrepid.feet_offset())
	add_world(intrepid)
	var surveyor := Lander.new()
	surveyor.style = Lander.Style.SURVEYOR
	surveyor.position = Vector2(target_x, 300 - surveyor.feet_offset() + 6)
	add_world(surveyor)
	while _astro_x < target_x - 40.0:
		await get_tree().process_frame
		var dir := Input.get_axis("rotate_left", "rotate_right")
		_astro_x = clampf(_astro_x + dir * 70.0 * get_process_delta_time(), 100.0, target_x - 30.0)
	await say("f5_bean")
	var spot: Hotspot = spawn_hotspots([["DESMONTAR LA CÁMARA DE TV", Vector2(target_x + 8, 270)]])[0]
	await wait_specific(spot)
	await say("f5_surveyor")
