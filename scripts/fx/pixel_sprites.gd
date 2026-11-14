class_name PixelSprites
extends RefCounted
## Sprites placeholder definidos como "arte ASCII": cada carácter es un píxel.
## Se convierten en ImageTexture en tiempo de ejecución (con contorno oscuro automático),
## así el juego funciona sin assets externos. Sustituir por PNG finales cuando existan.

const PALETTE := {
	"w": Color("#eef1f8"),  # blanco traje
	"g": Color("#a9adc0"),  # gris claro
	"d": Color("#5a5e72"),  # gris oscuro
	"k": Color("#1c1d26"),  # casi negro
	"b": Color("#5d7fb8"),  # azul suela
	"y": Color("#e0b040"),  # dorado
	"r": Color("#d0452e"),  # rojo
	"c": Color("#6fd6ff"),  # cian / vidrio
	"n": Color("#8a5a2b"),  # marrón (marco)
	"s": Color("#c8ccd8"),  # plateado
}
const OUTLINE := Color("#14141c")

# Cubrebotas lunar (overshoe) del Apolo.
const BOOT := [
	"...wwww.....",
	"...wggw.....",
	"...wwww.....",
	"...wggw.....",
	"..wwwwww....",
	"..wwwwwwww..",
	".wwwwwwwwww.",
	".wggggggggw.",
	".bbbbbbbbbb.",
	"..bdbdbdbd..",
]

# Cámara Hasselblad.
const CAMERA := [
	"...ssssss...",
	"..sdddddds..",
	"ssssssssssss",
	"sggkkkkkkggs",
	"sgkddccddkgs",
	"sgkdcwccdkgs",
	"sgkddccddkgs",
	"sggkkkkkkggs",
	"ssssssssssss",
]

# Mochila de soporte vital PLSS.
const BACKPACK := [
	"wwwwwwwwww",
	"wggggggggw",
	"wgwwwwwwgw",
	"wgwddddwgw",
	"wgwwwwwwgw",
	"wggggggggw",
	"wwwwwwwwww",
	"wgrgwwgcgw",
	"wggggggggw",
	"wwwwwwwwww",
	"wdwwwwwwdw",
	"wwwwwwwwww",
]

# Pelota de golf (Apolo 14).
const GOLF_BALL := [
	".wwww.",
	"wwgwww",
	"wwwwgw",
	"wgwwww",
	"wwwgww",
	".wwww.",
]

# Casco de astronauta con visor dorado oscuro.
const HELMET := [
	"...wwwwww...",
	"..wwwwwwww..",
	".wwyyyyyyww.",
	"wwykkkkkkyww",
	"wwykkdkkkyww",
	"wwykkkkkkyww",
	"wwwyyyyyywww",
	"wwwwwwwwwwww",
	".gwwwwwwwwg.",
	"..bbbbbbbb..",
]

# Foto familiar (Apolo 16).
const PHOTO := [
	"nnnnnnnnnn",
	"nccccccccn",
	"ncwwccwwcn",
	"ncwwccwwcn",
	"ncggccggcn",
	"nggggggggn",
	"ngggyygggn",
	"nnnnnnnnnn",
]


## Devuelve las filas de un sprite por su nombre ("BOOT", "CAMERA", ...).
static func by_name(id: String) -> Array:
	match id:
		"BOOT":
			return BOOT
		"CAMERA":
			return CAMERA
		"BACKPACK":
			return BACKPACK
		"PHOTO":
			return PHOTO
		"HELMET":
			return HELMET
	return GOLF_BALL


## Convierte filas de caracteres en textura, añadiendo 1 px de contorno.
static func make(rows: Array) -> ImageTexture:
	var h := rows.size()
	var w := String(rows[0]).length()
	var img := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row := String(rows[y])
		for x in w:
			var ch := row[x]
			if PALETTE.has(ch):
				img.set_pixel(x + 1, y + 1, PALETTE[ch])
	# Contorno: cualquier píxel vacío con un vecino opaco se pinta oscuro.
	var src := img.duplicate() as Image
	for y in h + 2:
		for x in w + 2:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + o
				if n.x >= 0 and n.y >= 0 and n.x < w + 2 and n.y < h + 2 and src.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
	return ImageTexture.create_from_image(img)
