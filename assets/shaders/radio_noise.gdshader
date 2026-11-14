shader_type canvas_item;
// Ruido ligero + scanlines para la caja de diálogo cuando habla un rover por radio.
// intensity = 0 lo apaga.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float n = hash(cell + floor(TIME * 24.0));
	float line = mod(floor(FRAGCOORD.y), 2.0);
	float band = step(0.985, fract(SCREEN_UV.y * 3.0 - TIME * 0.7));  // banda de interferencia que baja
	float a = (n * 0.55 + line * 0.35 + band * 0.6) * intensity;
	COLOR = vec4(vec3(n * 0.8 + 0.2), a);
}
