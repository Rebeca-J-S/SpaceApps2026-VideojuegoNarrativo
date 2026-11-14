shader_type canvas_item;
// Overlay retro: scanlines + viñeta. Se aplica a un ColorRect a pantalla completa
// (mouse_filter = Ignore) colocado al final del árbol de la escena.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	// Con stretch mode "viewport" FRAGCOORD está en la resolución base (640x360),
	// así que cada línea alterna exactamente un píxel de arte.
	float line = mod(floor(FRAGCOORD.y), 2.0);
	vec2 uv = SCREEN_UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.8, length(uv * vec2(1.0, 0.85)));
	float a = line * scanline_strength + vig * vignette_strength;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 1.0));
}
