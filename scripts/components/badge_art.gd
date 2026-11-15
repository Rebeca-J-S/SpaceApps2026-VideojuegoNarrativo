class_name BadgeArt
extends RefCounted
## Dibujo de las insignias del cuaderno (PLACEHOLDER pixel art por código, como el resto del juego).
## Cada insignia es un parche circular con el fondo de su cuerpo (Luna, Marte, espacio profundo) y el
## icono del artefacto, dividido en tantas cuñas como piezas tiene: las piezas no ganadas se tapan.

const BODY_BG := {"moon": Color("#1c2236"), "mars": Color("#3a160e"), "deep": Color("#0a1030")}
const BODY_RIM := {"moon": Color("#c8ccd8"), "mars": Color("#ff8a4a"), "deep": Color("#80f2ff")}
const GOLD := Color("#ffd24a")
const LOCK := Color("#0c0f1a")
const WHITE := Color("#eef1f8")
const SILVER := Color("#b8bcc8")
const DARK := Color("#3a3e50")
const FOIL := Color("#d8a838")
const PANEL := Color("#2e5aa8")
const PANEL_L := Color("#5a8ae0")


## got: índices de las piezas ganadas. highlight: pieza recién ganada (destella). t: tiempo para animar.
static func draw_badge(c: CanvasItem, ctr: Vector2, r: float, badge: Dictionary, got: Array, t: float = 0.0, highlight: int = -1) -> void:
	var body := String(badge.get("body", "deep"))
	var n := maxi(1, int(badge.get("pieces", 6)))
	var complete := got.size() >= n
	var rim: Color = BODY_RIM.get(body, GOLD)
	var bg: Color = BODY_BG.get(body, BODY_BG["deep"])
	if complete:
		c.draw_circle(ctr, r + 5.0 + sin(t * 3.0), Color(GOLD, 0.16))
	c.draw_circle(ctr, r + 2.0, Color(0, 0, 0, 0.7))
	c.draw_circle(ctr, r, GOLD if complete else rim.darkened(0.25))
	var inner := r * 0.84
	c.draw_circle(ctr, inner, bg)
	_draw_backdrop(c, ctr, inner, body)
	_draw_icon(c, ctr, inner, String(badge.get("icon", "")))
	# Piezas: cuñas tapadas (no ganadas) y destello en la recién ganada.
	for i in n:
		var a0 := -PI * 0.5 + TAU * i / n
		var a1 := a0 + TAU / n
		var owned := i in got
		if not owned or i == highlight:
			var pts := PackedVector2Array([ctr])
			for k in 11:
				pts.append(ctr + Vector2.from_angle(lerpf(a0, a1, k / 10.0)) * (r + 0.6))
			var col := Color(LOCK, 0.9) if not owned else Color(1, 1, 1, 0.35 + 0.35 * sin(t * 12.0))
			c.draw_colored_polygon(pts, col)
		if n > 1:
			c.draw_line(ctr, ctr + Vector2.from_angle(a0) * r, Color(0, 0, 0, 0.6), 1.0)
	if got.is_empty():
		c.draw_string(ThemeDB.fallback_font, ctr + Vector2(-r, r * 0.22), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.8), Color(rim, 0.5))
	c.draw_arc(ctr, r, 0.0, TAU, 48, GOLD if complete else Color(rim, 0.7), 1.5)


## Parte inferior del disco (suelo) cortada por una cuerda horizontal a y = ctr.y + R * f.
static func _ground(c: CanvasItem, ctr: Vector2, R: float, f: float, col: Color) -> void:
	var a0 := asin(clampf(f, -0.99, 0.99))
	var pts := PackedVector2Array()
	for k in 17:
		pts.append(ctr + Vector2.from_angle(lerpf(a0, PI - a0, k / 16.0)) * R)
	c.draw_colored_polygon(pts, col)


static func _draw_backdrop(c: CanvasItem, ctr: Vector2, R: float, body: String) -> void:
	for p: Vector2 in [Vector2(-0.55, -0.45), Vector2(0.4, -0.6), Vector2(0.62, -0.15), Vector2(-0.2, -0.72), Vector2(-0.7, 0.05)]:
		c.draw_rect(Rect2(ctr + p * R, Vector2(1, 1)), Color(1, 1, 1, 0.7))
	match body:
		"moon":
			_ground(c, ctr, R, 0.42, Color("#7a7a88"))
			c.draw_circle(ctr + Vector2(R * 0.55, -R * 0.42), R * 0.12, Color("#3a7bd5"))   # la Tierra
		"mars":
			c.draw_circle(ctr, R, Color(0.6, 0.25, 0.12, 0.25))
			_ground(c, ctr, R, 0.42, Color("#a8482a"))
		_:
			c.draw_circle(ctr + Vector2(-R * 0.5, -R * 0.4), R * 0.1, Color("#ffd24a"))   # el Sol


## Iconos en coordenadas locales (unas ±14 unidades; el suelo está en y = 8).
static func _draw_icon(c: CanvasItem, ctr: Vector2, R: float, icon: String) -> void:
	var u := R / 17.0
	c.draw_set_transform(ctr + Vector2(0, R * 0.05), 0.0, Vector2(u, u))
	match icon:
		"lm": _lm(c)
		"lrv": _lrv(c)
		"alsep": _alsep(c)
		"surveyor": _surveyor(c)
		"sojourner": _rover(c, Vector2.ZERO, 1.0)
		"twins":
			_rover(c, Vector2(-6, 0), 0.7)
			_rover(c, Vector2(6, 1), 0.7)
		"viking": _viking(c)
		"insight": _insight(c)
		"heli": _heli(c)
		"pioneer": _pioneer(c)
		"dawn": _dawn(c)
		"near": _near(c)
		"kepler": _kepler(c)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ellipse(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


static func _lm(c: CanvasItem) -> void:
	c.draw_line(Vector2(-6, 2), Vector2(-10, 8), SILVER, 1.0)
	c.draw_line(Vector2(6, 2), Vector2(10, 8), SILVER, 1.0)
	c.draw_rect(Rect2(-12, 8, 4, 1), SILVER)
	c.draw_rect(Rect2(8, 8, 4, 1), SILVER)
	c.draw_rect(Rect2(-7, -1, 14, 6), FOIL)
	c.draw_rect(Rect2(-7, -1, 14, 1), GOLD)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5, -1), Vector2(5, -1), Vector2(6, -5), Vector2(3, -9), Vector2(-3, -9), Vector2(-6, -5)]), SILVER)
	c.draw_rect(Rect2(-3, -7, 2, 2), DARK)
	c.draw_line(Vector2(3, -9), Vector2(5, -12), SILVER, 1.0)


static func _lrv(c: CanvasItem) -> void:
	c.draw_rect(Rect2(-11, 1, 22, 3), SILVER)
	c.draw_rect(Rect2(-4, -3, 6, 4), DARK)
	c.draw_line(Vector2(6, 1), Vector2(6, -5), SILVER, 1.0)
	c.draw_colored_polygon(_ellipse(6, -7, 3.5, 1.5), WHITE)
	for x in [-7.0, 7.0]:
		c.draw_circle(Vector2(x, 6), 3.0, DARK)
		c.draw_arc(Vector2(x, 6), 3.0, 0.0, TAU, 12, SILVER, 1.0)


static func _alsep(c: CanvasItem) -> void:
	c.draw_rect(Rect2(-13, 0, 8, 4), PANEL)
	c.draw_rect(Rect2(5, 0, 8, 4), PANEL)
	c.draw_rect(Rect2(-13, 0, 8, 1), PANEL_L)
	c.draw_rect(Rect2(5, 0, 8, 1), PANEL_L)
	c.draw_rect(Rect2(-4, -2, 8, 9), FOIL)
	c.draw_rect(Rect2(-4, -2, 8, 1), GOLD)
	c.draw_line(Vector2(0, -2), Vector2(0, -10), SILVER, 1.0)
	c.draw_colored_polygon(_ellipse(0, -11, 3.0, 1.2), WHITE)


static func _surveyor(c: CanvasItem) -> void:
	c.draw_line(Vector2(0, -2), Vector2(-9, 8), SILVER, 1.0)
	c.draw_line(Vector2(0, -2), Vector2(9, 8), SILVER, 1.0)
	c.draw_line(Vector2(0, -2), Vector2(0, 8), SILVER, 1.0)
	for x in [-10.0, 8.0, -1.0]:
		c.draw_rect(Rect2(x, 8, 3, 1), SILVER)
	c.draw_rect(Rect2(-3, -3, 6, 5), WHITE)
	c.draw_line(Vector2(0, -3), Vector2(0, -10), SILVER, 1.0)
	c.draw_rect(Rect2(-7, -12, 14, 3), PANEL)
	c.draw_rect(Rect2(-7, -12, 14, 1), PANEL_L)


static func _rover(c: CanvasItem, o: Vector2, s: float) -> void:
	c.draw_rect(Rect2(o + Vector2(-9, -4) * s, Vector2(18, 2) * s), PANEL)
	c.draw_rect(Rect2(o + Vector2(-6, -2) * s, Vector2(12, 5) * s), SILVER)
	c.draw_line(o + Vector2(4, -4) * s, o + Vector2(4, -10) * s, SILVER, 1.0)
	c.draw_rect(Rect2(o + Vector2(2, -12) * s, Vector2(5, 2) * s), WHITE)
	for x in [-6.0, 0.0, 6.0]:
		c.draw_circle(o + Vector2(x, 5) * s, 2.0 * s, DARK)


static func _viking(c: CanvasItem) -> void:
	c.draw_line(Vector2(-5, 3), Vector2(-10, 8), SILVER, 1.0)
	c.draw_line(Vector2(5, 3), Vector2(10, 8), SILVER, 1.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-7, -1), Vector2(7, -1), Vector2(9, 2), Vector2(7, 5), Vector2(-7, 5), Vector2(-9, 2)]), WHITE)
	c.draw_rect(Rect2(-7, 1, 14, 1), FOIL)
	c.draw_line(Vector2(3, -1), Vector2(3, -6), SILVER, 1.0)
	c.draw_colored_polygon(_ellipse(3, -8, 4.5, 2.0), WHITE)
	c.draw_line(Vector2(-6, -1), Vector2(-11, -5), SILVER, 1.0)          # brazo de muestras


static func _insight(c: CanvasItem) -> void:
	for x in [-10.0, 10.0]:
		c.draw_circle(Vector2(x, 0), 5.0, PANEL)
		c.draw_arc(Vector2(x, 0), 5.0, 0.0, TAU, 10, PANEL_L, 1.0)
		for k in 5:
			c.draw_line(Vector2(x, 0), Vector2(x, 0) + Vector2.from_angle(TAU * k / 5.0) * 5.0, PANEL_L, 1.0)
	c.draw_rect(Rect2(-5, -2, 10, 5), FOIL)
	c.draw_line(Vector2(-4, 3), Vector2(-6, 8), SILVER, 1.0)
	c.draw_line(Vector2(4, 3), Vector2(6, 8), SILVER, 1.0)
	c.draw_colored_polygon(_ellipse(0, 7, 2.5, 1.5), WHITE)               # sismómetro


static func _heli(c: CanvasItem) -> void:
	c.draw_line(Vector2(-12, -7), Vector2(12, -7), SILVER, 1.0)
	c.draw_line(Vector2(-10, -10), Vector2(10, -10), WHITE, 1.0)
	c.draw_line(Vector2(0, -12), Vector2(0, -2), SILVER, 1.0)
	c.draw_rect(Rect2(-3, -13, 6, 1), PANEL_L)
	c.draw_rect(Rect2(-3, -2, 6, 5), WHITE)
	for x in [-7.0, -3.0, 3.0, 7.0]:
		c.draw_line(Vector2(signf(x) * 2.0, 3), Vector2(x, 8), SILVER, 1.0)


static func _pioneer(c: CanvasItem) -> void:
	c.draw_colored_polygon(_ellipse(0, -5, 10.0, 3.5), WHITE)
	c.draw_line(Vector2(0, -5), Vector2(0, -11), SILVER, 1.0)
	c.draw_rect(Rect2(-3, -2, 6, 5), FOIL)
	c.draw_rect(Rect2(-1, 0, 2, 1), GOLD)                                 # la placa
	c.draw_line(Vector2(-3, 2), Vector2(-11, 7), SILVER, 1.0)
	c.draw_line(Vector2(3, 2), Vector2(11, 7), SILVER, 1.0)
	c.draw_rect(Rect2(-13, 6, 4, 3), Color("#c0532a"))
	c.draw_rect(Rect2(9, 6, 4, 3), Color("#c0532a"))


static func _dawn(c: CanvasItem) -> void:
	c.draw_circle(Vector2(8, 8), 5.0, Color("#6a6a74"))                   # Ceres
	for x in [-14.0, 4.0]:
		c.draw_rect(Rect2(x, -2, 10, 4), PANEL)
		for k in 3:
			c.draw_line(Vector2(x + 3.0 + k * 3.0, -2), Vector2(x + 3.0 + k * 3.0, 2), PANEL_L, 1.0)
	c.draw_rect(Rect2(-3, -3, 6, 6), FOIL)
	c.draw_colored_polygon(_ellipse(0, -5, 3.0, 1.2), WHITE)


static func _near(c: CanvasItem) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(-13, 6), Vector2(-8, 2), Vector2(0, 3), Vector2(9, 1), Vector2(14, 5), Vector2(10, 10), Vector2(-6, 11)]), Color("#8a7a68"))
	c.draw_circle(Vector2(-5, 7), 1.5, Color("#5a4e44"))
	c.draw_circle(Vector2(6, 6), 1.2, Color("#5a4e44"))
	c.draw_rect(Rect2(-8, -4, 5, 2), PANEL)
	c.draw_rect(Rect2(3, -4, 5, 2), PANEL)
	c.draw_rect(Rect2(-3, -5, 6, 5), FOIL)
	c.draw_line(Vector2(0, -5), Vector2(0, -9), SILVER, 1.0)
	c.draw_line(Vector2(-2, 0), Vector2(-3, 2), SILVER, 1.0)
	c.draw_line(Vector2(2, 0), Vector2(3, 2), SILVER, 1.0)


static func _kepler(c: CanvasItem) -> void:
	c.draw_circle(Vector2(-10, -8), 2.5, Color("#3a7bd5"))               # la Tierra, delante
	c.draw_rect(Rect2(-4, -9, 8, 16), WHITE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-4, -9), Vector2(4, -12), Vector2(4, -9)]), SILVER)
	c.draw_rect(Rect2(-3, -8, 6, 2), DARK)                                # apertura
	c.draw_rect(Rect2(4, -3, 6, 10), PANEL)
	c.draw_rect(Rect2(4, -3, 6, 1), PANEL_L)
	c.draw_rect(Rect2(-4, 7, 8, 2), FOIL)
