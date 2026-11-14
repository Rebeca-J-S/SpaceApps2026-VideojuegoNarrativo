class_name RetroTheme
extends RefCounted
## Tema UI generado por código: consola de Houston / telemetría banda S (1969).
## Verde fósforo + ámbar sobre negro espacial. Sin esquinas redondeadas ni antialiasing.

const PHOSPHOR := Color("#39ff7a")
const PHOSPHOR_DIM := Color("#1f8a45")
const PHOSPHOR_DARK := Color("#0b2e18")
const AMBER := Color("#ffb347")
const WHITE := Color("#e8f0ff")
const SPACE := Color("#04050d")
const PANEL_BG := Color(0.01, 0.04, 0.03, 0.92)


static func _box(bg: Color, border: Color, border_width: int = 1, margin: float = 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_content_margin_all(margin)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12

	# --- Label ---
	t.set_color("font_color", "Label", PHOSPHOR)

	# --- Button (también usado por las pestañas toggle) ---
	t.set_stylebox("normal", "Button", _box(Color(0, 0, 0, 0.35), PHOSPHOR_DIM))
	t.set_stylebox("hover", "Button", _box(PHOSPHOR_DARK, PHOSPHOR))
	t.set_stylebox("pressed", "Button", _box(PHOSPHOR_DIM, PHOSPHOR))
	t.set_stylebox("hover_pressed", "Button", _box(PHOSPHOR, PHOSPHOR))
	t.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0.2), PHOSPHOR_DARK))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER))
	t.set_color("font_color", "Button", PHOSPHOR)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", SPACE)
	t.set_color("font_hover_pressed_color", "Button", SPACE)
	t.set_color("font_disabled_color", "Button", PHOSPHOR_DARK)

	# --- Paneles ---
	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PHOSPHOR, 1, 8.0))

	# --- Texto enriquecido (fichas del archivo) ---
	t.set_color("default_color", "RichTextLabel", PHOSPHOR)
	t.set_font_size("normal_font_size", "RichTextLabel", 12)
	t.set_font_size("bold_font_size", "RichTextLabel", 12)

	# --- Separadores ---
	var line := StyleBoxLine.new()
	line.color = PHOSPHOR_DIM
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 6)
	var vline := StyleBoxLine.new()
	vline.color = PHOSPHOR_DIM
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "VSeparator", 6)

	# --- Contenedores ---
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 4)

	# --- Scroll del RichTextLabel ---
	t.set_stylebox("scroll", "VScrollBar", _box(Color(0, 0, 0, 0.4), PHOSPHOR_DARK, 1, 0.0))
	t.set_stylebox("grabber", "VScrollBar", _box(PHOSPHOR_DIM, PHOSPHOR_DIM, 0, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(PHOSPHOR, PHOSPHOR, 0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(AMBER, AMBER, 0, 0.0))
	return t
