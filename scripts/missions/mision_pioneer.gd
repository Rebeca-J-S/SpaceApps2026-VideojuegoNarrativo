extends MissionBase
## MISIÓN 3 — "LA ÚLTIMA SEÑAL" (Pioneer 10 y 11, 1972-2003). Propuesta de juego.
## Sin aterrizaje: la precisión está en la navegación y en apuntar la antena a la Tierra.
## Guion en data/dialogos/mision_3.json (marcado con 'verificar' donde corresponde).

const EARTH_POS := Vector2(110, 190)
const JUPITER := Vector2(470, 210)

var _probe_pos := Vector2(380, 190)
var _probe_angle := 0.0          # dirección de la antena (rad)
var _probe_spin := 0.0
var _signal := 0.0
var _earth_r := 6.0
# Cinturón de asteroides
var _asteroids: Array = []       # [Vector3(x, y, radio), ...]
var _hits := 0
var _invuln := 0.0
var _probe_vy := 0.0
var _belt_time := 0.0
# Júpiter
var _path_s := 0.0
var _window := Vector2(0.42, 0.56)
var _slingshot_ok := false
var _noise := 0.0
var _show_belts := false
var _show_field := false
var _saturn := false
var _show_f_ring := false
# Silencio
var _year := 1995
# Placa
var _plaque_parts := {}


func _init() -> void:
	mission_id = "pioneer"
	mission_number = 3
	mission_name = "LA ÚLTIMA SEÑAL · PIONEER 10 Y 11"
	dialog_path = "res://data/dialogos/mision_3.json"
	phase_titles = [
		"EL LANZAMIENTO", "EL CINTURÓN DE ASTEROIDES", "EL ENCUENTRO CON JÚPITER",
		"LA CIENCIA DEL GIGANTE", "EL SILENCIO", "EL LEGADO ETERNO",
	]


func run_phase(i: int) -> void:
	match i:
		0: await _phase_0()
		1: await _phase_1()
		2: await _phase_2()
		3: await _phase_3()
		4: await _phase_4()
		5: await _phase_5()


## Sonda Pioneer: antena parabólica, cuerpo hexagonal, brazos de los RTG y del magnetómetro.
## PLACEHOLDER: reemplazar por un Sprite2D con el pixel art final.
static func draw_pioneer(c: CanvasItem, pos: Vector2, angle: float, s: float = 2.0) -> void:
	c.draw_set_transform(pos, angle, Vector2(s, s))
	c.draw_line(Vector2(-2, 0), Vector2(-12, 7), Color("#8a8ea6"), 1.0)   # brazo RTG
	c.draw_line(Vector2(-2, 0), Vector2(-12, -7), Color("#8a8ea6"), 1.0)  # brazo RTG
	c.draw_rect(Rect2(-14, 6, 4, 3), Color("#c0532a"))
	c.draw_rect(Rect2(-14, -9, 4, 3), Color("#c0532a"))
	c.draw_line(Vector2(-2, 0), Vector2(-20, 0), Color("#6c6e78"), 1.0)   # magnetómetro
	c.draw_rect(Rect2(-5, -3, 5, 6), Color("#e0b040"))                    # cuerpo
	# Antena de 2.74 m (apunta en la dirección del ángulo, eje +x).
	c.draw_colored_polygon(PackedVector2Array([Vector2(1, -9), Vector2(4, -6), Vector2(5, 0), Vector2(4, 6), Vector2(1, 9), Vector2(2, 0)]), Color("#e3e6f0"))
	c.draw_line(Vector2(3, 0), Vector2(9, 0), Color("#c8ccd8"), 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _antenna_error() -> float:
	var to_earth := (EARTH_POS - _probe_pos).angle()
	return absf(wrapf(_probe_angle - to_earth, -PI, PI))


func _steer(delta: float) -> void:
	var dir := Input.get_axis("rotate_left", "rotate_right")
	_probe_spin += dir * 2.2 * delta
	_probe_spin -= _probe_spin * 1.5 * delta
	_probe_angle += _probe_spin * delta


# =========================================================================
# FASE 0 — Apuntar la antena a la Tierra
# =========================================================================
func _phase_0() -> void:
	await begin_phase(0, "Apunta la antena a la Tierra y mantén la señal 3 s", "A/D o FLECHAS: GIRAR LA SONDA")
	add_starfield(160)
	_probe_pos = Vector2(400, 190)
	_probe_angle = 1.2
	_probe_spin = 0.0
	_signal = 0.0
	draw_layer(func(c: DrawNode) -> void:
		draw_earth(c, EARTH_POS, 7.0)
		c.draw_string(ThemeDB.fallback_font, EARTH_POS + Vector2(-20, 22), "TIERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#80b4ff"))
		var good := _antenna_error() < deg_to_rad(8.0)
		if good:
			c.draw_line(_probe_pos, EARTH_POS, Color(0.3, 1, 0.5, 0.35), 1.0)
		draw_pioneer(c, _probe_pos, _probe_angle)
		draw_bar(c, Rect2(240, 300, 160, 8), _signal / 3.0, RetroTheme.PHOSPHOR if good else Color("#ff5a4a"), "SEÑAL")
	)
	await say("f0_intro")
	while _signal < 3.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		_steer(dt)
		var err := rad_to_deg(_antenna_error())
		_signal = _signal + dt if err < 8.0 else maxf(0.0, _signal - dt * 2.0)
		set_telemetry("ERROR DE ANTENA: %.0f°\nENERGÍA: RTG (nuclear)" % err)
	await say("f0_ok")


# =========================================================================
# FASE 1 — Cruzar el cinturón de asteroides
# =========================================================================
func _phase_1() -> void:
	await begin_phase(1, "Cruza el cinturón: esquiva los asteroides durante 25 s (máx. 3 impactos)",
		"W/ARRIBA: SUBIR  ·  S/ABAJO: BAJAR")
	add_starfield(120, Vector2(-40, 0))
	_asteroids.clear()
	_hits = 0
	_invuln = 0.0
	_belt_time = 0.0
	_probe_pos = Vector2(120, 190)
	_probe_vy = 0.0
	draw_layer(func(c: DrawNode) -> void:
		for a in _asteroids:
			var v: Vector3 = a
			c.draw_circle(Vector2(v.x, v.y), v.z, Color("#6b5a4a"))
			c.draw_circle(Vector2(v.x - v.z * 0.3, v.y - v.z * 0.3), v.z * 0.35, Color("#8a7660"))
		if _invuln <= 0.0 or fmod(c.t, 0.2) < 0.1:
			draw_pioneer(c, _probe_pos, 0.0)
		draw_bar(c, Rect2(160, 342, 320, 6), _belt_time / 25.0, RetroTheme.PHOSPHOR, "CRUCE DEL CINTURÓN")
	)
	await say("f1_inicio")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn := 0.0
	while _belt_time < 25.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		_belt_time += dt
		_invuln = maxf(0.0, _invuln - dt)
		var dir := Input.get_axis("thrust", "move_down")
		_probe_vy = lerpf(_probe_vy, dir * 160.0, 6.0 * dt)
		_probe_pos.y = clampf(_probe_pos.y + _probe_vy * dt, 50.0, 330.0)
		spawn -= dt
		if spawn <= 0.0:
			spawn = rng.randf_range(0.35, 0.75)
			_asteroids.append(Vector3(670, rng.randf_range(50, 330), rng.randf_range(6, 16)))
		var keep: Array = []
		for a in _asteroids:
			var v: Vector3 = a
			v.x -= (150.0 + v.z * 4.0) * dt
			if _invuln <= 0.0 and Vector2(v.x, v.y).distance_to(_probe_pos) < v.z + 9.0:
				_hits += 1
				_invuln = 1.0
				continue
			if v.x > -30.0:
				keep.append(v)
		_asteroids = keep
		set_telemetry("IMPACTOS: %d / 3\nTIEMPO: %.0f / 25 s" % [_hits, _belt_time])
		if _hits >= 3:
			await say("f1_fallo")
			await _phase_1()
			return
	_asteroids.clear()
	await say("f1_ok")


# =========================================================================
# FASE 2 — Sobrevuelo de Júpiter: soltar el control en la ventana
# =========================================================================
func _jupiter_path(s: float) -> Vector2:
	var a := lerpf(PI * 1.0, PI * 2.05, s)
	var r := 210.0 - 95.0 * sin(clampf(s, 0.0, 1.0) * PI)
	return JUPITER + Vector2(cos(a), sin(a) * 0.8) * r


func _draw_jupiter(c: DrawNode, r: float) -> void:
	var bands := [Color("#d9b48a"), Color("#b98a5e"), Color("#e6cfa8"), Color("#a8744a"), Color("#d9b48a")]
	c.draw_circle(JUPITER, r, bands[0])
	for i in 5:
		var y := -r + (i + 0.5) * (2.0 * r / 5.0)
		var half := sqrt(maxf(0.0, r * r - y * y))
		c.draw_rect(Rect2(JUPITER.x - half, JUPITER.y + y - r * 0.12, half * 2.0, r * 0.16), bands[i])
	c.draw_set_transform(JUPITER + Vector2(r * 0.3, r * 0.3), 0.0, Vector2(1, 0.6))
	c.draw_circle(Vector2.ZERO, r * 0.16, Color("#c0532a"))  # Gran Mancha Roja.
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _phase_2() -> void:
	await begin_phase(2, "Pulsa ESPACIO cuando la sonda esté en la ventana verde", "W/ESPACIO: SOLTAR EL CONTROL")
	add_starfield(120)
	_path_s = 0.0
	_slingshot_ok = false
	_noise = 0.0
	draw_layer(func(c: DrawNode) -> void:
		_draw_jupiter(c, 70.0)
		# Trayectoria punteada y ventana correcta.
		for k in 60:
			var s := k / 60.0
			var col := RetroTheme.PHOSPHOR if s >= _window.x and s <= _window.y else Color(1, 1, 1, 0.3)
			c.draw_rect(Rect2(_jupiter_path(s), Vector2(2, 2)), col)
		var p := _jupiter_path(_path_s)
		var ahead := _jupiter_path(_path_s + 0.01)
		draw_pioneer(c, p, (ahead - p).angle(), 1.5)
		# Interferencia por radiación.
		for i in int(_noise * 400):
			var g := randf()
			c.draw_rect(Rect2(randf() * W, randf() * H, 2, 1), Color(g, g, g, 0.6))
	)
	await say("f2_inicio")
	var said := false
	while _path_s < 1.0:
		await get_tree().process_frame
		_path_s += get_process_delta_time() * 0.16
		_noise = clampf(1.0 - absf(_path_s - 0.5) * 3.0, 0.0, 0.8)
		if not said and _path_s > 0.3:
			said = true
			await say("f2_radiacion")
		if Input.is_action_just_pressed("thrust"):
			_slingshot_ok = _path_s >= _window.x and _path_s <= _window.y
			break
		set_telemetry("DISTANCIA A JÚPITER: %.0f mil km" % (130.0 + absf(_path_s - 0.5) * 900.0))
	if not _slingshot_ok:
		await say("f2_fallo")
		await _phase_2()
		return
	# Éxito: la gravedad de Júpiter lanza la sonda.
	while _path_s < 1.1:
		await get_tree().process_frame
		_path_s += get_process_delta_time() * 0.3
	_noise = 0.0
	await toast("¡IMPULSO GRAVITATORIO!\nDiciembre de 1973", RetroTheme.PHOSPHOR, 1.6)


# =========================================================================
# FASE 3 — Escanear Júpiter y, con Pioneer 11, los anillos de Saturno
# =========================================================================
func _phase_3() -> void:
	await begin_phase(3, "Escanea Júpiter: activa los tres puntos", "CLIC o TECLAS 1-2-3: ESCANEAR")
	add_starfield(120)
	_saturn = false
	_show_belts = false
	_show_field = false
	_show_f_ring = false
	draw_layer(func(c: DrawNode) -> void:
		if _saturn:
			_draw_saturn(c)
			return
		if _show_field:
			for k in 4:
				var rr := 120.0 + k * 22.0
				c.draw_arc(JUPITER + Vector2(0, -rr * 0.5), rr * 0.5, 0.0, TAU, 40, Color(0.5, 0.8, 1.0, 0.35), 1.0)
				c.draw_arc(JUPITER + Vector2(0, rr * 0.5), rr * 0.5, 0.0, TAU, 40, Color(0.5, 0.8, 1.0, 0.35), 1.0)
		if _show_belts:
			for k in 3:
				c.draw_set_transform(JUPITER, 0.0, Vector2(1, 0.3))
				c.draw_arc(Vector2.ZERO, 110.0 + k * 14.0 + sin(c.t * 3.0 + k) * 2.0, 0.0, TAU, 48, Color(1, 0.4, 0.3, 0.5), 2.0)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_jupiter(c, 90.0)
	)
	var spots := spawn_hotspots([
		["CINTURONES DE RADIACIÓN", JUPITER + Vector2(-125, 10)],
		["CAMPO MAGNÉTICO", JUPITER + Vector2(-30, -125)],
		["GRAN MANCHA ROJA", JUPITER + Vector2(27, 27)],
	])
	for n in 3:
		var h := await wait_hotspot()
		if h == spots[0]:
			_show_belts = true
			await say("f3_cinturones")
		elif h == spots[1]:
			_show_field = true
			await say("f3_magnetico")
		else:
			await say("f3_mancha")
	await say("f3_pioneer11")
	for s in spots:
		s.queue_free()
	_saturn = true
	set_objective("Pioneer 11 en Saturno (septiembre de 1979): escanea los anillos")
	var ring: Hotspot = spawn_hotspots([["ANILLOS DE SATURNO", JUPITER + Vector2(150, 0)]])[0]
	await wait_specific(ring)
	_show_f_ring = true
	await say("f3_anillo")


func _draw_saturn(c: DrawNode) -> void:
	var center := JUPITER
	c.draw_set_transform(center, -0.15, Vector2(1, 0.32))
	c.draw_arc(Vector2.ZERO, 150.0, PI, TAU, 48, Color("#c9b58a"), 10.0)
	c.draw_arc(Vector2.ZERO, 128.0, PI, TAU, 48, Color("#a8946a"), 8.0)
	if _show_f_ring:
		c.draw_arc(Vector2.ZERO, 168.0, 0.0, TAU, 60, Color(RetroTheme.PHOSPHOR, 0.9), 1.5)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_circle(center, 70.0, Color("#e0c890"))
	c.draw_rect(Rect2(center.x - 66, center.y - 10, 132, 10), Color("#c9b07a"))
	c.draw_set_transform(center, -0.15, Vector2(1, 0.32))
	c.draw_arc(Vector2.ZERO, 150.0, 0.0, PI, 48, Color("#c9b58a"), 10.0)
	c.draw_arc(Vector2.ZERO, 128.0, 0.0, PI, 48, Color("#a8946a"), 8.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =========================================================================
# FASE 4 — El silencio: la señal se apaga aunque apuntes bien
# =========================================================================
func _phase_4() -> void:
	await begin_phase(4, "Mantén la antena apuntando a casa... todo lo que puedas", "A/D o FLECHAS: GIRAR LA SONDA")
	add_starfield(200, Vector2(-2, 0))
	_probe_pos = Vector2(470, 190)
	_probe_angle = PI
	_earth_r = 6.0
	_year = 1995
	draw_layer(func(c: DrawNode) -> void:
		if _earth_r > 0.6:
			draw_earth(c, EARTH_POS, _earth_r)
		else:
			c.draw_rect(Rect2(EARTH_POS, Vector2(1, 1)), Color("#80b4ff"))
		c.draw_string(ThemeDB.fallback_font, EARTH_POS + Vector2(-60, 26), "un punto azul pálido", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.5, 0.7, 1.0, 0.7))
		draw_pioneer(c, _probe_pos, _probe_angle)
		draw_bar(c, Rect2(240, 300, 160, 8), _signal, RetroTheme.PHOSPHOR if _signal > 0.3 else Color("#ff5a4a"), "SEÑAL")
		c.draw_string(ThemeDB.fallback_font, Vector2(0, 60), "AÑO %d" % _year, HORIZONTAL_ALIGNMENT_CENTER, W, 16, RetroTheme.AMBER)
	)
	await say("f4_p11")
	var t := 0.0
	while t < 12.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		_steer(dt)
		var aim := clampf(1.0 - rad_to_deg(_antenna_error()) / 30.0, 0.0, 1.0)
		_signal = aim * (1.0 - t / 12.0)  # Aunque apuntes perfecto, la voz se apaga.
		_earth_r = lerpf(6.0, 0.4, t / 12.0)
		_year = int(lerpf(1995.0, 2003.0, t / 12.0))
		set_telemetry("DISTANCIA: %.1f mil millones de km" % lerpf(6.0, 12.0, t / 12.0))
	_signal = 0.0
	await say("f4_p10")


# =========================================================================
# FASE 5 — La placa de oro
# =========================================================================
func _phase_5() -> void:
	await begin_phase(5, "Examina la placa de oro: activa sus cuatro partes", "CLIC o TECLAS 1-4: EXAMINAR")
	add_starfield(120)
	var plate := Rect2(150, 70, 340, 200)
	draw_layer(func(c: DrawNode) -> void:
		# PLACEHOLDER de la placa (aluminio anodizado en oro). Reemplazar por sprite fiel al original.
		c.draw_rect(plate, Color("#c9a24a"))
		c.draw_rect(plate, Color("#8a6a24"), false, 2.0)
		var ink := Color("#5a4214")
		# Hidrógeno (arriba a la izquierda).
		c.draw_circle(plate.position + Vector2(30, 28), 6.0, ink)
		c.draw_circle(plate.position + Vector2(52, 28), 6.0, ink)
		c.draw_circle(plate.position + Vector2(30, 28), 4.5, Color("#c9a24a"))
		c.draw_circle(plate.position + Vector2(52, 28), 4.5, Color("#c9a24a"))
		c.draw_line(plate.position + Vector2(36, 28), plate.position + Vector2(46, 28), ink, 1.0)
		# Mapa de púlsares (líneas radiales).
		var o := plate.position + Vector2(95, 95)
		for k in 14:
			var a := k * TAU / 14.0 + 0.2
			c.draw_line(o, o + Vector2(cos(a), sin(a)) * (25.0 + fmod(k * 13.0, 40.0)), ink, 1.0)
		# Sistema solar (abajo) con la trayectoria de la sonda.
		var y := plate.end.y - 22
		for k in 10:
			c.draw_circle(Vector2(plate.position.x + 30 + k * 26, y), 2.0 + (4.0 if k == 0 else (2.0 if k in [5, 6] else 0.0)), ink)
		c.draw_line(Vector2(plate.position.x + 108, y - 4), Vector2(plate.position.x + 190, y - 30), ink, 1.0)
		# Dos figuras humanas (siluetas simples) frente a la silueta de la sonda.
		var hx := plate.position.x + 250
		c.draw_line(Vector2(hx + 40, plate.position.y + 30), Vector2(hx + 40, plate.position.y + 150), Color(ink, 0.4), 1.0)
		for k in 2:
			var fx := hx + k * 26
			var top := plate.position.y + 70 + k * 6
			c.draw_circle(Vector2(fx, top), 5.0, ink)
			c.draw_line(Vector2(fx, top + 5), Vector2(fx, top + 45 - k * 6), ink, 2.0)
			c.draw_line(Vector2(fx - 8, top + 16), Vector2(fx + 8, top + 16), ink, 2.0)
			c.draw_line(Vector2(fx, top + 45 - k * 6), Vector2(fx - 5, top + 75 - k * 6), ink, 2.0)
			c.draw_line(Vector2(fx, top + 45 - k * 6), Vector2(fx + 5, top + 75 - k * 6), ink, 2.0)
	)
	var spots := spawn_hotspots([
		["HIDRÓGENO", plate.position + Vector2(41, 46)],
		["MAPA DE PÚLSARES", plate.position + Vector2(95, 95)],
		["SISTEMA SOLAR", plate.position + Vector2(150, plate.size.y - 40)],
		["FIGURAS HUMANAS", plate.position + Vector2(262, 60)],
	])
	var keys := {spots[0]: "f5_hidrogeno", spots[1]: "f5_pulsares", spots[2]: "f5_sistema", spots[3]: "f5_humanos"}
	for n in 4:
		var h := await wait_hotspot()
		await say(keys[h])
	await say("f5_cierre")
