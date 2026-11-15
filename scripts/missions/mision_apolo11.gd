extends MissionBase
## MISIÓN 1 — "GUARDIANES DE LA TRANQUILIDAD" (Apolo 11, Eagle LM-5, 1969).
##
## Flujo del capítulo (6 fases sobre MissionBase):
##   0 EL VIAJE             cinemática: despegue del Saturno V, órbita terrestre y travesía a la Luna
##   1 EL DESCENSO          cinemática: órbita lunar, separación del Columbia y descenso propulsado
##   2 LA ESTABILIZACIÓN    minijuego: mantener el indicador en la franja verde con pulsos de motor
##                          -> cinemática de aterrizaje suave en Mare Tranquillitatis
##   3 UN PEQUEÑO PASO      cinemática: Neil y Buzz bajan por la escalera y dialogan
##   4 LAS PRUEBAS          minijuego: recolección de muestras, tubos de núcleo, EASEP y LRRR
##   5 LA DESPEDIDA         cinemática: regreso a la cabina, pernos explosivos y ascenso
##
## Datos históricos: NSSDCA 1969-059C
##   https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1969-059C
## Guion en data/dialogos/mision_1.json. Los valores marcados "de juego" no son de la NASA.

const GROUND := 300.0
const EAGLE_X := 330.0              # Eagle en las cinemáticas del sitio
const CINE_SCALE := 5.0             # escala del Eagle en las cinemáticas (patas 9.4 m ≈ 120 px)

# --- Fase 2: estabilización (valores de juego) ---
const BAR_X := 60.0
const BAR_W := 380.0
const BAR_Y := 84.0
const GREEN_MIN := 0.33
const GREEN_MAX := 0.67
const STAB_PULL := 0.9              # turbulencia + gravedad empujan el indicador a la derecha
const STAB_KICK := 0.22             # cada pulso de motor lo empuja a la izquierda
const STAB_DAMP := 1.6
const STAB_START_ALT := 30.0        # m
const STAB_DESCENT := 3.0           # m/s de bajada mientras está en verde
const STAB_DANGER_S := 2.0          # s fuera del verde antes de abortar
const STAB_PPM := 5.5               # px por metro en esta vista

# --- Fase 4: recolección ---
const WORLD_W := 1600.0
const EVA_PPM := 16.0               # px por metro en la caminata
const EVA_SCALE_LM := 6.0           # escala del Eagle en la caminata
const EVA_EAGLE_X := 360.0
const EVA_EASEP_X := EVA_EAGLE_X + 17.0 * EVA_PPM   # 17 m al sur del LM (NSSDCA)
const EVA_LRRR_X := EVA_EASEP_X + 5.0 * EVA_PPM     # 5 m del EASEP (NSSDCA)
const EVA_FLAG_X := 250.0
const TARGET_KG := 21.55            # rocas y suelo traídos por el Apolo 11 (NSSDCA)
const CORE_TUBES := 2               # tubos de núcleo (NSSDCA)
const BAG_MAX := 6.0                # kg por viaje (de juego)
const EVA_GAME_S := 8098.0          # 02:56:15 -> 05:11:13 UT (NSSDCA)
const EVA_REAL_S := 210.0           # duración real de la partida (de juego)
const EVA_START_UT := 2.0 * 3600.0 + 56.0 * 60.0 + 15.0
const WALK_SPEED := 72.0            # px/s
const JUMP_V := 78.0                # px/s
const EVA_G := 40.0                 # px/s² (gravedad "lunar" de juego: saltos lentos y flotantes)
const HOLD_S := 1.8                 # s manteniendo E para clavar tubos o desplegar
const REACH := 18.0
## Montículos (x0, x1, altura px) para subir saltando.
const MOUNDS := [Vector3(150, 230, 34), Vector3(820, 900, 40), Vector3(1180, 1290, 48), Vector3(1430, 1510, 36)]
## Rocas: [x, tipo, kg]. Pesos de juego (suman 29.1 kg para dejar margen).
const ROCK_DEFS := [
	[40.0, "BASALTO", 2.5], [90.0, "BRECHA", 1.6], [190.0, "BASALTO", 2.2], [290.0, "SUELO LUNAR", 0.8],
	[470.0, "BASALTO VESICULAR", 1.9], [580.0, "BRECHA", 2.6], [780.0, "SUELO LUNAR", 1.1],
	[860.0, "BASALTO", 3.1], [960.0, "BRECHA", 1.4], [1035.0, "BRECHA", 1.7], [1130.0, "SUELO LUNAR", 0.9],
	[1240.0, "BASALTO VESICULAR", 2.8], [1350.0, "BRECHA", 2.0], [1470.0, "BASALTO", 3.3], [1560.0, "SUELO LUNAR", 1.2],
]
const TUBE_XS := [520.0, 1080.0]

const C_RED := Color("#ff5a4a")
const C_GREEN := Color("#9fd14a")

# --- Estado de cinemáticas ---
var _shot := ""
var _k := 0.0                       # progreso 0..1 de la toma actual
var _caption := ""
var _flash := 0.0
var _alarm := false

# --- Estado de la fase 2 ---
var _p := 0.5                       # posición del indicador (0 = izq., 1 = der.)
var _pv := 0.0
var _alt := STAB_START_ALT
var _danger := 0.0
var _gust := 0.0
var _pulse := 0.0                   # brillo del último pulso de motor
var _fuel_pct := 5.0
var _landed := false

# --- Estado del sitio (fases 3 y 5) ---
var _hatch := 0.0
var _neil := Vector2(-100, -100)
var _buzz := Vector2(-100, -100)
var _neil_face := -1.0
var _buzz_face := -1.0
var _neil_moving := false
var _buzz_moving := false
var _site_deployed := false
var _ascent_y := 0.0
var _ascent_fire := false
var _flag_angle := 0.0
var _footprints: Array[Vector2] = []

# --- Estado de la fase 4 ---
var _eva_root: Node2D
var _cam_x := 0.0
var _px := EVA_EAGLE_X - 60.0
var _py := GROUND
var _pvx := 0.0
var _pvy := 0.0
var _on_ground := true
var _facing := 1.0
var _walk := 0.0
var _bag_kg := 0.0
var _bag_n := 0
var _delivered := 0.0
var _rocks: Array = []              # [{x, kind, kg, taken}]
var _tubes: Array = []              # [{x, done}]
var _easep_state := 0               # 0 en la bodega, 1 cargándolo, 2 desplegado
var _lrrr_state := 0
var _hold := 0.0
var _hold_target := ""
var _prompt := ""
var _notice := ""
var _notice_t := 0.0
var _eva_left := EVA_GAME_S
var _warned := false


func _init() -> void:
	mission_id = "apolo11"
	mission_number = 1
	mission_name = "GUARDIANES DE LA TRANQUILIDAD · APOLO 11"
	dialog_path = "res://data/dialogos/mision_1.json"
	phase_titles = [
		"EL VIAJE", "EL DESCENSO DEL EAGLE", "LA ESTABILIZACIÓN",
		"UN PEQUEÑO PASO", "RECOLECCIÓN DE PRUEBAS", "LA DESPEDIDA",
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
# Utilidades de cinemática
# =========================================================================
## Avanza _k de 0 a 1 en `seconds` (la toma se anima leyendo _k).
func _play(shot: String, caption: String, seconds: float, trans := Tween.TRANS_SINE) -> void:
	_shot = shot
	_caption = caption
	_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_k", 1.0, seconds).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _tween_to(prop: String, value: Variant, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, prop, value, seconds)
	await tw.finished


## Recorre una ruta de puntos (escalera, caminata) con un astronauta.
func _walk_path(who: String, points: Array, speed: float) -> void:
	var prop := "_neil" if who == "neil" else "_buzz"
	set(prop + "_moving", true)
	for pt: Vector2 in points:
		var from: Vector2 = get(prop)
		if absf(pt.x - from.x) > 0.5:
			set(prop + "_face", signf(pt.x - from.x))
		await _tween_to(prop, pt, maxf(from.distance_to(pt) / speed, 0.05))
	set(prop + "_moving", false)


func _cine_layer() -> DrawNode:
	return draw_layer(_draw_cine)


func _draw_caption(c: CanvasItem) -> void:
	# Bandas de cine y rótulo con fecha / lugar.
	c.draw_rect(Rect2(0, 34, W, 10), Color(0, 0, 0, 0.85))
	c.draw_rect(Rect2(0, H - 30, W, 30), Color(0, 0, 0, 0.85))
	if _caption != "":
		c.draw_string(ThemeDB.fallback_font, Vector2(0, H - 36), _caption, HORIZONTAL_ALIGNMENT_CENTER, W, 11, RetroTheme.AMBER)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, _flash))


# =========================================================================
# FASE 0 — EL VIAJE (cinemática)
# =========================================================================
func _phase_0() -> void:
	await begin_phase(0, "Observa el viaje del Apolo 11 de la Tierra a la Luna", "ENTER / CLIC: AVANZAR")
	add_starfield(160)
	_cine_layer()
	await _play("launch", "16 JUL 1969 · 13:32 UT · CENTRO ESPACIAL KENNEDY, FLORIDA", 4.5, Tween.TRANS_QUAD)
	await say("c0_despegue")
	await _play("earth_orbit", "ÓRBITA TERRESTRE · INYECCIÓN TRANSLUNAR", 4.5)
	await say("c0_tli")
	await _play("transfer", "3 DÍAS DE VIAJE · ~384,400 km HASTA LA LUNA", 5.5)
	await say("c0_travesia")


# =========================================================================
# FASE 1 — EL DESCENSO DEL EAGLE (cinemática)
# =========================================================================
func _phase_1() -> void:
	await begin_phase(1, "Acompaña al Eagle desde la órbita lunar hasta la superficie", "ENTER / CLIC: AVANZAR")
	add_starfield(160)
	_cine_layer()
	await _play("lunar_orbit", "19 JUL 1969 · ÓRBITA LUNAR", 4.0)
	await say("c1_orbita")
	await _play("undock", "20 JUL 1969 · 17:44 UT · EL EAGLE SE SEPARA DEL COLUMBIA", 4.5)
	await say("c1_separacion")
	_alarm = false
	_shot = "powered"
	_caption = "20:05 UT · DESCENSO PROPULSADO · 756.3 s DE FUEGO"
	_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_k", 0.45, 2.5)
	await tw.finished
	_alarm = true
	await say("c1_alarma")
	var tw2 := create_tween()
	tw2.tween_property(self, "_k", 1.0, 2.5)
	await tw2.finished
	_alarm = false
	await _play("final", "ALTITUD 30 m · FASE DE CONTACTO", 2.5)
	await say("c1_contacto")


# =========================================================================
# FASE 2 — LA ESTABILIZACIÓN (minijuego de precisión)
# =========================================================================
func _phase_2() -> void:
	await begin_phase(2, "Mantén el indicador en la franja VERDE con pulsos de motor hasta tocar el suelo",
		"CLIC / ESPACIO / ENTER: PULSO DE MOTOR")
	add_starfield(120)
	_shot = "stab"
	_caption = ""
	_p = 0.5
	_pv = 0.0
	_alt = STAB_START_ALT
	_danger = 0.0
	_fuel_pct = 5.0
	_landed = false
	_cine_layer()
	draw_layer(_draw_stab_hud)
	await say("c2_instrucciones")
	await toast("¡AHORA!", RetroTheme.PHOSPHOR, 0.6)
	var on_pulse := func() -> void:
		_pv -= STAB_KICK
		_pulse = 1.0
	accept_pressed.connect(on_pulse)
	var gust_t := 1.0
	var failed := false
	while _alt > 0.0:
		await get_tree().physics_frame
		if get_tree().paused or radio.is_active():
			continue
		var dt := get_physics_process_delta_time()
		var depth := 1.0 - _alt / STAB_START_ALT        # más turbulencia cerca del suelo
		gust_t -= dt
		if gust_t <= 0.0:
			gust_t = randf_range(0.6, 1.4)
			_gust = randf_range(-0.5, 0.5) * (0.6 + depth)
		_pv += (STAB_PULL + _gust + sin(Time.get_ticks_msec() * 0.004) * 0.35 * depth) * dt
		_pv -= _pv * STAB_DAMP * dt
		_p = clampf(_p + _pv * dt, 0.0, 1.0)
		if _p <= 0.0 or _p >= 1.0:
			_pv = 0.0
		_pulse = maxf(0.0, _pulse - dt * 4.0)
		var in_green := _p >= GREEN_MIN and _p <= GREEN_MAX
		if in_green:
			_alt = maxf(0.0, _alt - STAB_DESCENT * dt)
			_danger = maxf(0.0, _danger - dt / STAB_DANGER_S * 0.5)
		else:
			_danger += dt / STAB_DANGER_S
		_fuel_pct = maxf(1.2, 5.0 - depth * 3.6)
		var vv := -STAB_DESCENT if in_green else (-STAB_DESCENT * 2.2 if _p > GREEN_MAX else 0.8)
		set_telemetry("ALTITUD: %.1f m\nV/V: %+.1f m/s\nINCL: %+.1f°\nCOMB.: %.1f %%\nESTADO: %s" % [
			_alt, vv, (_p - 0.5) * 30.0, _fuel_pct, "ESTABLE" if in_green else "¡INESTABLE!"])
		if _danger >= 1.0:
			failed = true
			break
	accept_pressed.disconnect(on_pulse)
	set_telemetry("")
	if failed:
		await toast("DESCENSO INESTABLE\n" + ("Demasiado empuje: el Eagle sube" if _p < GREEN_MIN else "Caída demasiado rápida"), C_RED, 2.0)
		await say("c2_fallo")
		await _phase_2()
		return
	# Aterrizaje suave: el polvo se asienta y se apaga el motor.
	_landed = true
	_alt = 0.0
	await toast("20:17:40 UT · LUZ DE CONTACTO", RetroTheme.PHOSPHOR, 1.4)
	await _play("touchdown", "20 JUL 1969 · 20:17:40 UT · MARE TRANQUILLITATIS · 0.674° N, 23.473° E", 3.0)
	await say("c2_aterrizaje")


func _draw_stab_hud(c: DrawNode) -> void:
	if _landed:
		return
	var font := ThemeDB.fallback_font
	var y := BAR_Y
	var h := 16.0
	# Barra roja | verde | roja con dos postes blancos (como en el boceto).
	c.draw_rect(Rect2(BAR_X - 6, y - 26, BAR_W + 12, 58), Color(0, 0, 0, 0.75))
	c.draw_rect(Rect2(BAR_X, y - h * 0.5, BAR_W, h), C_RED)
	c.draw_rect(Rect2(BAR_X + BAR_W * GREEN_MIN, y - h * 0.5, BAR_W * (GREEN_MAX - GREEN_MIN), h), C_GREEN)
	for m in [GREEN_MIN, GREEN_MAX]:
		c.draw_rect(Rect2(BAR_X + BAR_W * m - 2, y - 20, 4, 40), Color("#f4f4ee"))
	# Indicador: la "nube" gris que se mueve con la turbulencia.
	var ix := BAR_X + BAR_W * _p
	var col := Color("#c8ccd8").lerp(Color.WHITE, _pulse)
	for o in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
		c.draw_circle(Vector2(ix, y) + o, 7.0, col)
	c.draw_circle(Vector2(ix, y), 8.0, col)
	c.draw_string(font, Vector2(BAR_X, y + 26), "◄ DEMASIADO EMPUJE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_RED)
	c.draw_string(font, Vector2(BAR_X, y + 26), "CAÍDA RÁPIDA ►", HORIZONTAL_ALIGNMENT_RIGHT, BAR_W, 9, C_RED)
	c.draw_string(font, Vector2(BAR_X, y - 14), "EQUILIBRIO DE EMPUJE", HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 10, RetroTheme.PHOSPHOR)
	# Alerta: tiempo fuera de la zona verde.
	if _danger > 0.05:
		draw_bar(c, Rect2(BAR_X + BAR_W * 0.3, y + 34, BAR_W * 0.4, 5), _danger, C_RED, "")
		if fmod(c.t, 0.4) < 0.25:
			c.draw_string(font, Vector2(BAR_X, y + 52), "¡VUELVE A LA ZONA VERDE!", HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 11, C_RED)


# =========================================================================
# FASE 3 — UN PEQUEÑO PASO (cinemática de los astronautas)
# =========================================================================
func _site_points() -> Dictionary:
	var cy := GROUND - 10.0 * CINE_SCALE
	return {
		"hatch": Vector2(EAGLE_X - 18, cy - 10),          # dentro de la escotilla
		"porch": Vector2(EAGLE_X - 36, cy - 10),          # porche sobre la etapa de descenso
		"foot": Vector2(EAGLE_X - 54, GROUND),            # almohadilla de la pata con escalera
	}


func _phase_3() -> void:
	await begin_phase(3, "Neil Armstrong y Buzz Aldrin salen del Eagle", "ENTER / CLIC: AVANZAR")
	add_starfield(150)
	_shot = "site"
	_site_deployed = false
	_ascent_y = 0.0
	_flag_angle = 0.0
	_hatch = 0.0
	_footprints.clear()
	_neil = Vector2(-100, -100)
	_buzz = Vector2(-100, -100)
	_cine_layer()
	var pts := _site_points()
	_caption = "21 JUL 1969 · 02:39 UT · SE ABRE LA ESCOTILLA"
	await wait(1.0)
	await _tween_to("_hatch", 1.0, 1.2)
	_neil = pts["hatch"]
	_neil_face = -1.0
	await _walk_path("neil", [pts["porch"]], 16.0)
	_caption = "NEIL ARMSTRONG BAJA POR LA ESCALERA"
	await _walk_path("neil", [pts["foot"]], 14.0)
	await wait(0.6)
	_caption = "21 JUL 1969 · 02:56:15 UT · PRIMER PASO"
	await _walk_path("neil", [pts["foot"] + Vector2(-14, 0)], 10.0)
	_footprints.append(pts["foot"] + Vector2(-10, 0))
	await say("c3_paso")
	_caption = "19 MINUTOS DESPUÉS · BUZZ ALDRIN"
	await _walk_path("neil", [Vector2(EAGLE_X - 140, GROUND)], 26.0)
	_neil_face = 1.0
	_buzz = pts["hatch"]
	_buzz_face = -1.0
	await _walk_path("buzz", [pts["porch"], pts["foot"]], 18.0)
	await say("c3_buzz")
	_caption = "FRENTE A LA BASE DEL EAGLE"
	await _walk_path("buzz", [Vector2(EAGLE_X - 104, GROUND)], 26.0)
	_buzz_face = -1.0
	_neil_face = 1.0
	await wait(0.6)
	_caption = ""
	await say("c3_dialogo")


# =========================================================================
# FASE 4 — RECOLECCIÓN DE PRUEBAS (minijuego de baja gravedad)
# =========================================================================
func _phase_4() -> void:
	await begin_phase(4, "Entrega %.2f kg de muestras, clava %d tubos de núcleo y despliega el EASEP y el LRRR" % [TARGET_KG, CORE_TUBES],
		"A/D: CAMINAR · W/ESPACIO: SALTAR · E: RECOGER / USAR")
	add_starfield(150)
	draw_layer(func(c: DrawNode) -> void: draw_earth(c, Vector2(540, 70), 12.0), false)
	_eva_reset()
	_eva_root = Node2D.new()
	add_world(_eva_root)
	_eva_root.add_child(DrawNode.new(_draw_eva_world))
	draw_layer(_draw_eva_hud)
	await say("c4_inicio")
	var result := ""
	while result == "":
		await get_tree().physics_frame
		if get_tree().paused or radio.is_active():
			continue
		var dt := get_physics_process_delta_time()
		_eva_step(dt)
		_cam_x = lerpf(_cam_x, clampf(_px - W * 0.5, 0.0, WORLD_W - W), clampf(dt * 6.0, 0.0, 1.0))
		_eva_root.position.x = -roundf(_cam_x)
		_eva_left -= dt * EVA_GAME_S / EVA_REAL_S
		if not _warned and _eva_left < EVA_GAME_S * 0.2:
			_warned = true
			await say("c4_aviso")
		if _eva_complete():
			result = "ok"
		elif _eva_left <= 0.0:
			result = "tiempo"
	if result == "tiempo":
		await toast("FIN DE LA VENTANA DE ACTIVIDAD\nNo se completó la recolección", C_RED, 2.2)
		await say("c4_tiempo")
		await _phase_4()
		return
	await toast("¡RECOLECCIÓN COMPLETA!", RetroTheme.PHOSPHOR, 1.4)
	await say("c4_exito")


func _eva_reset() -> void:
	_px = EVA_EAGLE_X - 70.0
	_py = GROUND
	_pvx = 0.0
	_pvy = 0.0
	_on_ground = true
	_facing = 1.0
	_bag_kg = 0.0
	_bag_n = 0
	_delivered = 0.0
	_easep_state = 0
	_lrrr_state = 0
	_hold = 0.0
	_hold_target = ""
	_notice = ""
	_eva_left = EVA_GAME_S
	_warned = false
	_cam_x = clampf(_px - W * 0.5, 0.0, WORLD_W - W)
	_rocks.clear()
	for d in ROCK_DEFS:
		_rocks.append({"x": d[0], "kind": d[1], "kg": d[2], "taken": false})
	_tubes.clear()
	for x in TUBE_XS:
		_tubes.append({"x": x, "done": false})


func _eva_complete() -> bool:
	var tubes := 0
	for t in _tubes:
		tubes += int(t["done"])
	return _delivered >= TARGET_KG - 0.001 and tubes >= CORE_TUBES and _easep_state == 2 and _lrrr_state == 2


func _surface_at(x: float) -> float:
	var y := GROUND
	for m: Vector3 in MOUNDS:
		if x >= m.x and x <= m.y:
			y = minf(y, GROUND - m.z)
	return y


func _carrying() -> String:
	if _easep_state == 1:
		return "EASEP"
	if _lrrr_state == 1:
		return "LRRR"
	return ""


func _eva_step(dt: float) -> void:
	var burden := _bag_kg / BAG_MAX
	var speed := WALK_SPEED * (1.0 - 0.35 * burden) * (0.75 if _carrying() != "" else 1.0)
	var ax := Input.get_axis("rotate_left", "rotate_right")
	if ax != 0.0:
		_facing = signf(ax)
	_pvx = move_toward(_pvx, ax * speed, (380.0 if _on_ground else 110.0) * dt)
	if _on_ground and Input.is_action_just_pressed("thrust"):
		_pvy = -JUMP_V * (1.0 - 0.25 * burden)
		_on_ground = false
	_pvy += EVA_G * dt
	var nx := clampf(_px + _pvx * dt, 8.0, WORLD_W - 8.0)
	if _surface_at(nx) < _py - 3.0:      # choca con el costado de un montículo
		nx = _px
		_pvx = 0.0
	_px = nx
	_py += _pvy * dt
	var s := _surface_at(_px)
	if _py >= s:
		_py = s
		_pvy = 0.0
		_on_ground = true
	else:
		_on_ground = false
	_walk = _walk + dt * 9.0 if _on_ground and absf(_pvx) > 4.0 else 0.0
	if _notice_t > 0.0:
		_notice_t -= dt
	_eva_interact(dt)


## Decide qué se puede hacer donde está el astronauta y aplica la tecla E.
func _eva_interact(dt: float) -> void:
	_prompt = ""
	var target := ""
	var idx := -1
	if _on_ground:
		var carry := _carrying()
		if absf(_px - EVA_EAGLE_X) < 44.0:
			target = "eagle"
		elif carry == "EASEP" and absf(_px - EVA_EASEP_X) < 22.0:
			target = "deploy_easep"
		elif carry == "LRRR" and absf(_px - EVA_LRRR_X) < 22.0:
			target = "deploy_lrrr"
		else:
			for i in _tubes.size():
				if not _tubes[i]["done"] and absf(_px - float(_tubes[i]["x"])) < REACH:
					target = "tube"
					idx = i
			if target == "":
				var best := REACH
				for i in _rocks.size():
					var r: Dictionary = _rocks[i]
					var d := absf(_px - float(r["x"]))
					if not r["taken"] and d < best and absf(_py - _surface_at(r["x"])) < 4.0:
						best = d
						target = "rock"
						idx = i
	var pressed := Input.is_action_just_pressed("interact")
	var held := Input.is_action_pressed("interact")
	var key := "%s%d" % [target, idx]
	if key != _hold_target or not held:
		_hold = 0.0
	_hold_target = key
	match target:
		"eagle":
			var parts: Array[String] = []
			if _bag_kg > 0.0:
				parts.append("DESCARGAR %.1f kg" % _bag_kg)
			var next_pkg := _next_package()
			if next_pkg != "":
				parts.append("SACAR " + next_pkg + " DE LA BODEGA")
			if parts.is_empty():
				_prompt = "EAGLE · CAJA DE MUESTRAS: %.2f kg" % _delivered
			else:
				_prompt = "[E] " + " + ".join(parts)
				if pressed:
					if _bag_kg > 0.0:
						_delivered += _bag_kg
						_notice_msg("+%.1f kg EN LA CAJA DE MUESTRAS" % _bag_kg, RetroTheme.PHOSPHOR)
						_bag_kg = 0.0
						_bag_n = 0
					if next_pkg == "EASEP":
						_easep_state = 1
					elif next_pkg == "LRRR":
						_lrrr_state = 1
		"deploy_easep", "deploy_lrrr":
			var label := "EASEP (SISMÓMETRO)" if target == "deploy_easep" else "ESPEJO LÁSER LRRR"
			_prompt = "[MANTÉN E] DESPLEGAR " + label
			if held:
				_hold += dt / HOLD_S
				if _hold >= 1.0:
					_hold = 0.0
					if target == "deploy_easep":
						_easep_state = 2
						_notice_msg("EASEP DESPLEGADO · 17 m AL SUR DEL EAGLE", RetroTheme.PHOSPHOR)
					else:
						_lrrr_state = 2
						_notice_msg("LRRR COLOCADO · 5 m DEL EASEP", RetroTheme.PHOSPHOR)
		"tube":
			_prompt = "[MANTÉN E] CLAVAR TUBO DE NÚCLEO"
			if held:
				_hold += dt / HOLD_S
				if _hold >= 1.0:
					_hold = 0.0
					_tubes[idx]["done"] = true
					_notice_msg("TUBO DE NÚCLEO EXTRAÍDO", RetroTheme.PHOSPHOR)
		"rock":
			var r: Dictionary = _rocks[idx]
			_prompt = "[E] RECOGER %s · %.1f kg" % [r["kind"], r["kg"]]
			if pressed:
				if _bag_kg + float(r["kg"]) > BAG_MAX + 0.001:
					_notice_msg("¡BOLSA LLENA! (%.1f / %.0f kg) · DESCARGA EN EL EAGLE" % [_bag_kg, BAG_MAX], C_RED)
				else:
					r["taken"] = true
					_bag_kg += float(r["kg"])
					_bag_n += 1


func _next_package() -> String:
	if _carrying() != "":
		return ""
	if _easep_state == 0:
		return "EASEP"
	if _lrrr_state == 0:
		return "LRRR"
	return ""


var _notice_col := RetroTheme.PHOSPHOR


func _notice_msg(text: String, col: Color) -> void:
	_notice = text
	_notice_col = col
	_notice_t = 2.2


func _draw_eva_world(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	# Suelo y cráteres de todo el recorrido.
	var tint := Color("#5d5c69")
	c.draw_rect(Rect2(-20, GROUND, WORLD_W + 40, 80), tint)
	c.draw_rect(Rect2(-20, GROUND, WORLD_W + 40, 2), tint.lightened(0.25))
	for i in 22:
		var cx := fmod(i * 173.0 + 40.0, WORLD_W)
		var cy := GROUND + 12.0 + fmod(i * 23.0, 36.0)
		var r := 6.0 + fmod(i * 7.0, 14.0)
		c.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.0, 0.35))
		c.draw_circle(Vector2(0, -2), r + 1, tint.lightened(0.15))
		c.draw_circle(Vector2.ZERO, r, tint.darkened(0.25))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m: Vector3 in MOUNDS:
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(m.x - 10, GROUND + 1), Vector2(m.x, GROUND - m.z), Vector2(m.y, GROUND - m.z), Vector2(m.y + 10, GROUND + 1),
		]), Color("#6a6976"))
		c.draw_line(Vector2(m.x, GROUND - m.z), Vector2(m.y, GROUND - m.z), Color("#9a99a6"), 2.0)
	# Bandera (plantada cerca del Eagle).
	_draw_flag(c, Vector2(EVA_FLAG_X, GROUND), 0.0, 1.0)
	# Eagle.
	var cy := GROUND - 10.0 * EVA_SCALE_LM
	c.draw_set_transform(Vector2(EVA_EAGLE_X, cy), 0.0, Vector2(EVA_SCALE_LM, EVA_SCALE_LM))
	Lander.draw_lm_on(c, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_string(font, Vector2(EVA_EAGLE_X - 60, cy - 100), "EAGLE · CAJA DE MUESTRAS", HORIZONTAL_ALIGNMENT_CENTER, 120, 9, RetroTheme.AMBER)
	# Buzz trabaja junto al Eagle (bodega de equipo).
	_draw_astro(c, Vector2(EVA_EAGLE_X + 48, GROUND), -1.0, 0.0, "BUZZ")
	# Sitios de despliegue.
	var carry := _carrying()
	if _easep_state == 2:
		_draw_easep(c, EVA_EASEP_X, 1.0)
	elif carry == "EASEP":
		_draw_marker(c, EVA_EASEP_X, "EASEP")
	if _lrrr_state == 2:
		_draw_lrrr(c, EVA_LRRR_X)
	elif carry == "LRRR":
		_draw_marker(c, EVA_LRRR_X, "LRRR")
	# Tubos de núcleo.
	for t in _tubes:
		var x := float(t["x"])
		var y := _surface_at(x)
		if t["done"]:
			c.draw_circle(Vector2(x, y + 2), 3.0, Color("#3b3a45"))
		else:
			c.draw_line(Vector2(x, y), Vector2(x, y - 16), Color("#f0c862"), 2.0)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 16), Vector2(x + 8, y - 13), Vector2(x, y - 10)]), Color("#ff8c3a"))
			if fmod(c.t + x, 1.2) < 0.6:
				c.draw_arc(Vector2(x, y - 8), 10.0, 0.0, TAU, 16, Color(RetroTheme.AMBER, 0.6), 1.0)
	# Rocas.
	for r in _rocks:
		if r["taken"]:
			continue
		var x := float(r["x"])
		var y := _surface_at(x)
		var s := 3.0 + float(r["kg"]) * 1.2
		var col := Color("#8d8d99") if String(r["kind"]) != "SUELO LUNAR" else Color("#a49d8c")
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x - s, y + 1), Vector2(x - s * 0.7, y - s * 0.8), Vector2(x + s * 0.3, y - s), Vector2(x + s, y - s * 0.3), Vector2(x + s, y + 1),
		]), col)
		c.draw_rect(Rect2(x - s * 0.4, y - s * 0.8, 2, 1), Color.WHITE)
		if absf(_px - x) < REACH:
			c.draw_arc(Vector2(x, y - s * 0.5), s + 5.0, 0.0, TAU, 18, RetroTheme.PHOSPHOR, 1.0)
	# Astronauta del jugador (Neil) con la bolsa de muestras.
	_draw_astro(c, Vector2(_px, _py), _facing, _walk, "NEIL")
	var bag_s := 3.0 + 4.0 * (_bag_kg / BAG_MAX)
	c.draw_rect(Rect2(_px - _facing * 3.0 - bag_s * 0.5, _py - 12.0, bag_s, bag_s), Color("#d8c9a0"))
	if carry != "":
		c.draw_rect(Rect2(_px + _facing * 6.0 - 5.0, _py - 20.0, 10, 8), Color("#a7a9b4"))
		c.draw_rect(Rect2(_px + _facing * 6.0 - 5.0, _py - 20.0, 10, 2), Color("#f0c862"))
	# Progreso de las acciones "mantener E".
	if _hold > 0.0:
		c.draw_arc(Vector2(_px, _py - 40), 8.0, -PI * 0.5, -PI * 0.5 + TAU * _hold, 24, RetroTheme.AMBER, 3.0)
	if _prompt != "":
		c.draw_string(font, Vector2(_px - 120, _py - 52), _prompt, HORIZONTAL_ALIGNMENT_CENTER, 240, 10, RetroTheme.WHITE)


func _draw_marker(c: DrawNode, x: float, label: String) -> void:
	var a := 0.5 + 0.5 * sin(c.t * 5.0)
	c.draw_line(Vector2(x - 8, GROUND - 2), Vector2(x + 8, GROUND + 4), Color(RetroTheme.PHOSPHOR, a), 2.0)
	c.draw_line(Vector2(x + 8, GROUND - 2), Vector2(x - 8, GROUND + 4), Color(RetroTheme.PHOSPHOR, a), 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, GROUND - 30), Vector2(x + 6, GROUND - 30), Vector2(x, GROUND - 20)]), Color(RetroTheme.PHOSPHOR, a))
	c.draw_string(ThemeDB.fallback_font, Vector2(x - 50, GROUND - 34), "SITIO " + label, HORIZONTAL_ALIGNMENT_CENTER, 100, 9, RetroTheme.PHOSPHOR)


func _draw_eva_hud(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	var tubes := 0
	for t in _tubes:
		tubes += int(t["done"])
	# Panel izquierdo: muestras y bolsa.
	c.draw_rect(Rect2(6, 290, 196, 40), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(6, 290, 196, 40), Color("#80f2ff"), false, 1.0)
	draw_bar(c, Rect2(12, 303, 184, 6), _delivered / TARGET_KG, RetroTheme.AMBER, "MUESTRAS ENTREGADAS %.2f / %.2f kg" % [_delivered, TARGET_KG])
	var bag_col := C_RED if _bag_kg > BAG_MAX * 0.85 else RetroTheme.PHOSPHOR
	draw_bar(c, Rect2(12, 321, 184, 6), _bag_kg / BAG_MAX, bag_col, "BOLSA %.1f / %.0f kg · %d piezas" % [_bag_kg, BAG_MAX, _bag_n])
	# Panel derecho: reloj, oxígeno y tareas.
	var ut := EVA_START_UT + (EVA_GAME_S - maxf(_eva_left, 0.0))
	var left := maxf(_eva_left, 0.0)
	c.draw_rect(Rect2(W - 214, 268, 208, 62), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(W - 214, 268, 208, 62), Color("#80f2ff"), false, 1.0)
	var low := left < EVA_GAME_S * 0.2
	c.draw_string(font, Vector2(W - 208, 280), "HORA %s UT · FIN 05:11:13" % _hms(ut), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RetroTheme.WHITE)
	c.draw_string(font, Vector2(W - 208, 292), "VENTANA EVA: %s" % _hms(left), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_RED if low else RetroTheme.AMBER)
	draw_bar(c, Rect2(W - 208, 303, 196, 5), left / EVA_GAME_S, Color("#4aa8ff") if not low else C_RED, "")
	var ok := RetroTheme.PHOSPHOR
	var no := Color(1, 1, 1, 0.55)
	c.draw_string(font, Vector2(W - 208, 318), "TUBOS %d/%d" % [tubes, CORE_TUBES], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ok if tubes >= CORE_TUBES else no)
	c.draw_string(font, Vector2(W - 140, 318), "EASEP %s" % ("✔" if _easep_state == 2 else "·"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ok if _easep_state == 2 else no)
	c.draw_string(font, Vector2(W - 78, 318), "LRRR %s" % ("✔" if _lrrr_state == 2 else "·"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ok if _lrrr_state == 2 else no)
	c.draw_string(font, Vector2(W - 208, 328), "OXÍGENO / ENERGÍA DE LA MOCHILA PLSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, no)
	if _notice_t > 0.0:
		c.draw_string(font, Vector2(0, 130), _notice, HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color(_notice_col, clampf(_notice_t, 0.0, 1.0)))


static func _hms(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


# =========================================================================
# FASE 5 — LA DESPEDIDA (cinemática de ascenso)
# =========================================================================
func _phase_5() -> void:
	await begin_phase(5, "El Eagle despega y su etapa de descenso se queda en la Luna", "ENTER / CLIC: AVANZAR")
	add_starfield(150)
	_shot = "site"
	_site_deployed = true
	_ascent_y = 0.0
	_ascent_fire = false
	_flag_angle = 0.0
	_hatch = 1.0
	_footprints = [Vector2(EAGLE_X - 70, GROUND), Vector2(EAGLE_X - 110, GROUND), Vector2(EAGLE_X - 160, GROUND), Vector2(EAGLE_X + 90, GROUND)]
	var pts := _site_points()
	_buzz = Vector2(EAGLE_X - 90, GROUND)
	_neil = Vector2(EAGLE_X - 150, GROUND)
	_buzz_face = 1.0
	_neil_face = 1.0
	_cine_layer()
	_caption = "21 JUL 1969 · FIN DE LA CAMINATA LUNAR"
	await wait(0.8)
	# Buzz entra primero; Neil lo sigue unos 12 minutos después (NSSDCA).
	await _walk_path("buzz", [pts["foot"], pts["porch"], pts["hatch"]], 18.0)
	_buzz = Vector2(-100, -100)
	await _walk_path("neil", [pts["foot"], pts["porch"], pts["hatch"]], 18.0)
	_neil = Vector2(-100, -100)
	_caption = "05:11:13 UT · SE CIERRA LA ESCOTILLA"
	await _tween_to("_hatch", 0.0, 1.0)
	await say("c5_regreso")
	_caption = "21 JUL 1969 · 17:54:01 UT · 21 h 36 min EN LA LUNA"
	await say("c5_pernos")
	for n in ["3", "2", "1"]:
		await toast(n, RetroTheme.AMBER, 0.35)
	# Pernos explosivos: destello en la unión de las dos etapas.
	_flash = 0.9
	var tf := create_tween()
	tf.tween_property(self, "_flash", 0.0, 0.5)
	_ascent_fire = true
	_caption = "SEPARACIÓN DE ETAPAS · MOTOR DE ASCENSO 15,000 N"
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_ascent_y", 420.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_flag_angle", -1.45, 1.2).set_delay(0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_ascent_fire = false
	_caption = "LA ETAPA DE DESCENSO SE QUEDA EN EL MAR DE LA TRANQUILIDAD"
	await wait(2.0)
	await say("c5_silencio")


# =========================================================================
# Dibujo de las cinemáticas
# =========================================================================
func _draw_cine(c: DrawNode) -> void:
	match _shot:
		"launch": _draw_launch(c)
		"earth_orbit": _draw_earth_orbit(c)
		"transfer": _draw_transfer(c)
		"lunar_orbit": _draw_lunar_orbit(c)
		"undock": _draw_undock(c)
		"powered": _draw_powered(c)
		"final", "stab", "touchdown": _draw_final(c)
		"site": _draw_site(c)
	_draw_caption(c)


func _draw_launch(c: DrawNode) -> void:
	var rise := _k * _k * 300.0
	var cam := maxf(0.0, rise - 120.0)
	c.draw_rect(Rect2(0, 0, W, H), Color("#5b8fd0").lerp(RetroTheme.SPACE, clampf(_k * 1.4, 0.0, 1.0)))
	var gy := GROUND + cam
	c.draw_rect(Rect2(0, gy, W, H), Color("#3d5a3a"))
	c.draw_rect(Rect2(0, gy, W, 3), Color("#8aa070"))
	c.draw_rect(Rect2(0, gy + 26, W, 40), Color("#2e5d8a"))  # el océano Atlántico
	# Torre de lanzamiento.
	for i in 12:
		c.draw_rect(Rect2(270, gy - 140 + i * 12, 14, 1), Color("#b04030"))
	c.draw_rect(Rect2(270, gy - 140, 2, 140), Color("#b04030"))
	c.draw_rect(Rect2(282, gy - 140, 2, 140), Color("#b04030"))
	var base := Vector2(320, gy - rise)
	_draw_saturn(c, base, true)
	# Humo en la plataforma.
	for i in 14:
		var spread := 20.0 + _k * 160.0
		var px := 320.0 + (fmod(i * 37.0, 2.0 * spread) - spread)
		var r := 10.0 + fmod(i * 13.0, 14.0) + _k * 16.0
		c.draw_circle(Vector2(px, gy - 6.0 - fmod(i * 7.0, 20.0)), r, Color(0.9, 0.9, 0.92, 0.55 * (1.0 - _k * 0.6)))


func _draw_saturn(c: CanvasItem, base: Vector2, flame: bool) -> void:
	var w := Color("#eef1f8")
	var b := Color("#1c1d26")
	if flame:
		var fl := 30.0 + randf() * 14.0
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-8, 0), base + Vector2(8, 0), base + Vector2(0, fl)]), Color("#ffb347"))
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(4, 0), base + Vector2(0, fl * 0.6)]), Color("#fff4c0"))
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-7, -10), base + Vector2(-11, 0), base + Vector2(-7, 0)]), b)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(7, -10), base + Vector2(11, 0), base + Vector2(7, 0)]), b)
	c.draw_rect(Rect2(base + Vector2(-7, -60), Vector2(14, 60)), w)        # S-IC
	c.draw_rect(Rect2(base + Vector2(-7, -60), Vector2(7, 8)), b)
	c.draw_rect(Rect2(base + Vector2(0, -20), Vector2(7, 8)), b)
	c.draw_rect(Rect2(base + Vector2(-6, -88), Vector2(12, 28)), w)        # S-II
	c.draw_rect(Rect2(base + Vector2(-6, -62), Vector2(12, 2)), b)
	c.draw_rect(Rect2(base + Vector2(-5, -104), Vector2(10, 16)), w)       # S-IVB
	c.draw_rect(Rect2(base + Vector2(-5, -96), Vector2(5, 4)), b)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, -104), base + Vector2(5, -104), base + Vector2(2, -114), base + Vector2(-2, -114)]), Color("#c8ccd8"))
	c.draw_line(base + Vector2(0, -114), base + Vector2(0, -126), Color("#b04030"), 1.0)  # torre de escape


## Columbia (CSM) con el Eagle acoplado en la nariz. pos = centro, rot en rad.
func _draw_stack(c: CanvasItem, pos: Vector2, rot: float, s: float, with_lm: bool, flame: bool) -> void:
	c.draw_set_transform(pos, rot, Vector2(s, s))
	if flame:
		var fl := 6.0 + randf() * 3.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(-3, 18), Vector2(3, 18), Vector2(0, 18 + fl)]), Color("#bfe6ff"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-2.5, 13), Vector2(2.5, 13), Vector2(3.5, 18), Vector2(-3.5, 18)]), Color("#6c6e78"))
	c.draw_rect(Rect2(-5, 0, 10, 13), Color("#a7a9b4"))
	c.draw_rect(Rect2(-5, 3, 10, 1), Color("#6c6e78"))
	c.draw_rect(Rect2(-2, 6, 4, 3), Color("#5a5e72"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(1.5, -7), Vector2(-1.5, -7)]), Color("#d8dce6"))
	c.draw_rect(Rect2(-1, -4, 2, 1), Color("#1c1d26"))
	if with_lm:
		c.draw_rect(Rect2(-4, -11, 8, 4), Color("#c8ccd8"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -17), Vector2(6, -17), Vector2(7, -14), Vector2(6, -11), Vector2(-6, -11), Vector2(-7, -14)]), Color("#c8962e"))
		c.draw_line(Vector2(-6, -15), Vector2(-8, -20), Color("#a7a9b4"), 0.6)
		c.draw_line(Vector2(6, -15), Vector2(8, -20), Color("#a7a9b4"), 0.6)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_earth_orbit(c: DrawNode) -> void:
	# Imagen 1: el borde de la Tierra con el amanecer y la nave rumbo a la Luna.
	var ctr := Vector2(300, 1210)
	var r := 920.0
	for i in 6:
		c.draw_circle(ctr, r + 4.0 + i * 5.0, Color(0.35, 0.7, 1.0, 0.09 - i * 0.012))
	c.draw_circle(ctr, r, Color("#1d4f9a"))
	for i in 18:
		var a := -PI * 0.5 + (i - 9) * 0.045 + fmod(i * 0.37, 0.03)
		var p := ctr + Vector2(cos(a), sin(a)) * (r - 18.0 - fmod(i * 23.0, 40.0))
		c.draw_set_transform(p, 0.0, Vector2(1.0, 0.3))
		c.draw_circle(Vector2.ZERO, 14.0 + fmod(i * 11.0, 18.0), Color("#e8f0ff") if i % 3 == 0 else Color("#3f7a4a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 30:
		var a := -PI * 0.5 + 0.08 + fmod(i * 0.013, 0.32)
		var p := ctr + Vector2(cos(a), sin(a)) * (r - 6.0 - fmod(i * 17.0, 60.0))
		c.draw_rect(Rect2(p, Vector2(2, 1)), Color("#ffc860"))
	for i in 8:
		c.draw_circle(Vector2(620, 292), 12.0 + i * 16.0, Color(1.0, 0.6, 0.2, 0.07))
	var pos := Vector2(170, 210).lerp(Vector2(470, 110), _k)
	_draw_stack(c, pos, 0.55, 3.0, true, true)


func _bezier(a: Vector2, b: Vector2, d: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(d, t), t)


func _draw_transfer(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	draw_earth(c, Vector2(80, 270), 30.0)
	var moon_r := 12.0 + 22.0 * _k
	_draw_moon_disc(c, Vector2(560, 110), moon_r)
	var a := Vector2(110, 250)
	var b := Vector2(300, 40)
	var d := Vector2(560 - moon_r - 8.0, 110)
	for i in 40:
		var t := i / 40.0
		c.draw_rect(Rect2(_bezier(a, b, d, t), Vector2(2, 2)), Color(1, 1, 1, 0.25 if t > _k else 0.7))
	var p := _bezier(a, b, d, _k)
	var ahead := _bezier(a, b, d, minf(_k + 0.01, 1.0))
	var rot := (ahead - p).angle() + PI * 0.5
	for i in 6:
		var tp := _bezier(a, b, d, maxf(_k - i * 0.015, 0.0))
		c.draw_circle(tp, 4.0 - i * 0.5, Color(0.6, 0.9, 1.0, 0.3 - i * 0.04))
	_draw_stack(c, p, rot, 2.0, true, false)
	c.draw_string(font, Vector2(20, 70), "DÍA %d" % (1 + mini(int(_k * 3.0), 2)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RetroTheme.PHOSPHOR)


func _draw_moon_disc(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_circle(p, r + 2.0, Color(1, 1, 1, 0.08))
	c.draw_circle(p, r, Color("#b4b4c0"))
	var maria := [Vector3(-0.3, -0.25, 0.28), Vector3(0.15, -0.3, 0.2), Vector3(0.25, 0.05, 0.22), Vector3(-0.1, 0.2, 0.18), Vector3(-0.45, 0.15, 0.15)]
	for m: Vector3 in maria:
		c.draw_circle(p + Vector2(m.x, m.y) * r, m.z * r, Color("#7c7c8a"))
	for i in 8:
		var q := p + Vector2(fmod(i * 0.37, 1.2) - 0.6, fmod(i * 0.53, 1.2) - 0.6) * r
		if q.distance_to(p) < r * 0.9:
			c.draw_arc(q, r * 0.05 + 1.0, 0.0, TAU, 10, Color("#d6d6e0"), 1.0)


func _draw_lunar_orbit(c: DrawNode) -> void:
	# Imagen 2: la Luna enorme a la izquierda y la Tierra al fondo.
	draw_earth(c, Vector2(560, 80), 24.0)
	var mc := Vector2(40, 330)
	var mr := 290.0
	_draw_moon_disc(c, mc, mr)
	var a := lerpf(-1.2, -0.45, _k)
	var p := mc + Vector2(cos(a), sin(a)) * (mr + 38.0)
	_draw_stack(c, p, a + PI, 2.4, true, false)


func _draw_undock(c: DrawNode) -> void:
	var mc := Vector2(320, 980)
	c.draw_circle(mc, 700.0, Color("#8d8d99"))
	c.draw_arc(mc, 700.0, PI * 1.2, PI * 1.8, 64, Color("#c8c8d2"), 2.0)
	draw_earth(c, Vector2(560, 70), 14.0)
	# Columbia sigue en órbita con Michael Collins.
	var csm := Vector2(260, 140) + Vector2(60, -10) * _k
	_draw_stack(c, csm, -PI * 0.5, 3.0, false, false)
	c.draw_string(ThemeDB.fallback_font, csm + Vector2(-50, -36), "COLUMBIA · M. COLLINS", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, RetroTheme.WHITE)
	# El Eagle se aleja con las patas desplegadas.
	var lm := Vector2(220, 150) + Vector2(-40, 70) * _k
	c.draw_set_transform(lm, 0.2 * _k, Vector2(3, 3))
	Lander.draw_lm_on(c, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_string(ThemeDB.fallback_font, lm + Vector2(-50, 40), "EAGLE · N. ARMSTRONG Y B. ALDRIN", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, RetroTheme.AMBER)


func _draw_powered(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	var horizon := lerpf(330.0, 220.0, _k)
	var mc := Vector2(320, horizon + 900.0)
	c.draw_circle(mc, 900.0, Color("#6c6b78"))
	c.draw_arc(mc, 900.0, PI * 1.2, PI * 1.8, 64, Color("#a8a8b4"), 2.0)
	for i in 10:
		var x := fmod(i * 71.0 + _k * 200.0, W)
		c.draw_set_transform(Vector2(x, horizon + 20 + fmod(i * 19.0, 60.0)), 0.0, Vector2(1, 0.3))
		c.draw_circle(Vector2.ZERO, 5.0 + _k * 10.0, Color("#4a4a55"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_earth(c, Vector2(560, 70), 10.0)
	# El Eagle frena de espaldas y luego se endereza (de juego: inclinación aproximada).
	var lm := Vector2(320, 150)
	var tilt := lerpf(-1.1, 0.0, clampf(_k * 1.3, 0.0, 1.0))
	c.draw_set_transform(lm, tilt, Vector2(4, 4))
	var fl := 6.0 + randf() * 4.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(-2, 7), Vector2(2, 7), Vector2(0, 7 + fl)]), Color("#ffb347"))
	Lander.draw_lm_on(c, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var alt := lerpf(14500.0, 150.0, _k)
	c.draw_string(font, Vector2(20, 70), "ALTITUD: %s m" % _thousands(alt), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RetroTheme.PHOSPHOR)
	c.draw_string(font, Vector2(20, 86), "IGNICIÓN: T+%.0f / 756.3 s" % (_k * 756.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RetroTheme.PHOSPHOR)
	if _alarm and fmod(c.t, 0.5) < 0.3:
		c.draw_string(font, Vector2(0, 110), "ALARMA 1202 · COMPUTADORA SATURADA", HORIZONTAL_ALIGNMENT_CENTER, W, 14, C_RED)


static func _thousands(v: float) -> String:
	var n := int(v)
	return "%d,%03d" % [n / 1000, n % 1000] if n >= 1000 else str(n)


## Últimos metros: se usa en la cinemática final, en el minijuego y en el aterrizaje.
func _draw_final(c: DrawNode) -> void:
	draw_earth(c, Vector2(560, 62), 10.0)
	draw_moon_ground(c, GROUND)
	var alt := 0.0
	var tilt := 0.0
	var dust := 0.0
	var fire := true
	match _shot:
		"final":
			alt = lerpf(60.0, STAB_START_ALT, _k)
			dust = 0.4 * _k
		"stab":
			alt = _alt
			tilt = (_p - 0.5) * 0.7 + sin(c.t * 13.0) * 0.02 * (1.0 - _alt / STAB_START_ALT)
			dust = 0.4 + 0.5 * (1.0 - _alt / STAB_START_ALT)
		"touchdown":
			alt = 0.0
			dust = 0.9 * (1.0 - _k)
			fire = _k < 0.15
	var sc := 4.0
	var cy := GROUND - alt * STAB_PPM - 10.0 * sc
	var pos := Vector2(EAGLE_X, cy)
	c.draw_set_transform(pos, tilt, Vector2(sc, sc))
	if fire:
		var fl := 6.0 + randf() * 4.0 + (3.0 * _pulse if _shot == "stab" else 0.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-2, 7), Vector2(2, 7), Vector2(0, 7 + fl)]), Color("#ffb347"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(-1, 7), Vector2(1, 7), Vector2(0, 7 + fl * 0.6)]), Color("#fff4c0"))
	Lander.draw_lm_on(c, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Velo de polvo gris (como en la imagen 2).
	if dust > 0.0:
		c.draw_rect(Rect2(0, GROUND - 46, W, 52), Color(0.62, 0.6, 0.58, dust * 0.55))
		for i in 70:
			var dir := 1.0 if i % 2 == 0 else -1.0
			var px := fmod(EAGLE_X + dir * fmod(i * 23.0 + c.t * 140.0, 340.0) + W, W)
			c.draw_rect(Rect2(px, GROUND - 4 - fmod(i * 13.0, 46.0), 3, 1), Color(0.85, 0.82, 0.78, dust))


# =========================================================================
# Sitio de alunizaje (fases 3 y 5)
# =========================================================================
func _draw_site(c: DrawNode) -> void:
	var font := ThemeDB.fallback_font
	draw_earth(c, Vector2(560, 64), 11.0)
	draw_moon_ground(c, GROUND)
	for f in _footprints:
		c.draw_rect(Rect2(f + Vector2(-3, 1), Vector2(4, 2)), Color("#44434f"))
		c.draw_rect(Rect2(f + Vector2(3, 3), Vector2(4, 2)), Color("#44434f"))
	if _site_deployed:
		_draw_flag(c, Vector2(EAGLE_X - 190, GROUND), _flag_angle, 1.3)
		_draw_easep(c, EAGLE_X + 140, 1.3)
		_draw_lrrr(c, EAGLE_X + 210)
	var cy := GROUND - 10.0 * CINE_SCALE
	# Etapa de descenso (se queda) y etapa de ascenso (sube en la Fase 5).
	c.draw_set_transform(Vector2(EAGLE_X, cy), 0.0, Vector2(CINE_SCALE, CINE_SCALE))
	Lander.draw_lm_on(c, false)
	c.draw_set_transform(Vector2(EAGLE_X, cy - _ascent_y), 0.0, Vector2(CINE_SCALE, CINE_SCALE))
	if _ascent_fire:
		var fl := 4.0 + randf() * 5.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(0, fl)]), Color("#ffb347"))
	Lander.draw_ascent_stage_on(c)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _ascent_fire and _ascent_y < 80.0:
		c.draw_rect(Rect2(EAGLE_X - 90, GROUND - 24, 180, 26), Color(0.62, 0.6, 0.58, 0.5 * (1.0 - _ascent_y / 80.0)))
	# Escotilla y escalera (pata izquierda).
	if _ascent_y < 1.0:
		var hatch := Rect2(EAGLE_X - 26, cy - 30, 9, 14)
		c.draw_rect(hatch, Color("#1c1d26").lerp(Color("#ffe9a8"), _hatch))
	var top := Vector2(EAGLE_X - 31, cy + 10)
	var bottom := Vector2(EAGLE_X - 50, GROUND - 4)
	for i in 9:
		var p := top.lerp(bottom, i / 8.0)
		c.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color("#a7a9b4"), 1.0)
	c.draw_rect(Rect2(EAGLE_X - 44, cy - 12, 12, 2), Color("#a7a9b4"))  # porche
	# Astronautas.
	if _neil.x > 0.0:
		_draw_astro(c, _neil, _neil_face, c.t * 9.0 if _neil_moving else 0.0, "NEIL")
	if _buzz.x > 0.0:
		_draw_astro(c, _buzz, _buzz_face, c.t * 9.0 if _buzz_moving else 0.0, "BUZZ")
	if _ascent_y > 200.0:
		c.draw_string(font, Vector2(0, 90), "...", HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color(1, 1, 1, 0.4))


func _draw_astro(c: CanvasItem, feet: Vector2, facing: float, walk: float, tag: String = "") -> void:
	var white := Color("#eef1f8")
	var shade := Color("#c8ccd8")
	var dark := Color("#5a5e72")
	var step := sin(walk) * 3.0
	var bob := absf(sin(walk)) * 1.5
	var f := feet - Vector2(0, bob)
	c.draw_rect(Rect2(f.x - 4 + step * 0.5, f.y - 10, 3, 10), shade)
	c.draw_rect(Rect2(f.x + 1 - step * 0.5, f.y - 10, 3, 10), white)
	c.draw_rect(Rect2(f.x - 5 + step * 0.5, f.y - 2, 4, 2), dark)
	c.draw_rect(Rect2(f.x + 1 - step * 0.5, f.y - 2, 4, 2), dark)
	c.draw_rect(Rect2(f.x - facing * 7.0 - 3.0, f.y - 25, 6, 13), shade)   # mochila PLSS
	c.draw_rect(Rect2(f.x - 5, f.y - 22, 10, 13), white)
	c.draw_rect(Rect2(f.x - 3, f.y - 18, 6, 3), dark)                      # unidad de control
	c.draw_line(f + Vector2(facing * 4.0, -20), f + Vector2(facing * 8.0, -13 + step * 0.4), white, 2.0)
	c.draw_circle(f + Vector2(0, -27), 5.0, white)
	c.draw_rect(Rect2(f.x - 2.0 + facing * 1.5, f.y - 29, 4, 4), Color("#e0b040"))  # visor dorado
	if tag != "":
		c.draw_string(ThemeDB.fallback_font, f + Vector2(-20, -36), tag, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(1, 1, 1, 0.7))


func _draw_flag(c: CanvasItem, base: Vector2, angle: float, s: float) -> void:
	c.draw_set_transform(base, angle, Vector2(s, s))
	c.draw_line(Vector2.ZERO, Vector2(0, -30), Color("#c8ccd8"), 1.0)
	c.draw_line(Vector2(0, -30), Vector2(16, -30), Color("#c8ccd8"), 1.0)
	c.draw_rect(Rect2(1, -30, 15, 10), Color("#e8e8e8"))
	for i in 3:
		c.draw_rect(Rect2(1, -30 + i * 4, 15, 2), Color("#c0392b"))
	c.draw_rect(Rect2(1, -30, 6, 5), Color("#2e4a9a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_easep(c: CanvasItem, x: float, s: float) -> void:
	c.draw_set_transform(Vector2(x, GROUND), 0.0, Vector2(s, s))
	c.draw_rect(Rect2(-6, -10, 12, 10), Color("#a7a9b4"))
	c.draw_rect(Rect2(-4, -14, 6, 4), Color("#f0c862"))
	c.draw_rect(Rect2(-24, -14, 18, 6), Color("#1e3f8f"))
	c.draw_rect(Rect2(6, -14, 18, 6), Color("#1e3f8f"))
	c.draw_rect(Rect2(-24, -14, 18, 1), Color("#3d6fd6"))
	c.draw_rect(Rect2(6, -14, 18, 1), Color("#3d6fd6"))
	c.draw_line(Vector2(2, -14), Vector2(4, -24), Color("#a7a9b4"), 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lrrr(c: CanvasItem, x: float) -> void:
	var y := GROUND
	c.draw_line(Vector2(x - 8, y), Vector2(x - 8, y - 6), Color("#6c6e78"), 2.0)
	c.draw_line(Vector2(x + 8, y), Vector2(x + 8, y - 10), Color("#6c6e78"), 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 11, y - 10), Vector2(x + 11, y - 15), Vector2(x + 11, y - 7), Vector2(x - 11, y - 3)]), Color("#a7a9b4"))
	for i in 5:
		c.draw_rect(Rect2(x - 9 + i * 4, y - 9 - i, 2, 2), Color("#3b3e57"))
