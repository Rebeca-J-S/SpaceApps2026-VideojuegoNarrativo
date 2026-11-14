shader_type canvas_item;
// Planeta pixel art que rota: proyecta una textura de ruido (mapa equirectangular)
// sobre una esfera, pixela el resultado y posteriza la luz en bandas.
// Se aplica a un ColorRect cuadrado (ver scripts/fx/pixel_planet.gd).

uniform sampler2D surface : filter_nearest, repeat_enable;
uniform float pixels = 72.0;          // resolución del disco en "píxeles de arte"
uniform float spin = 0.0;             // rotación (vueltas), la actualiza el script
uniform vec3 light_dir = vec3(-0.55, -0.45, 0.7);
uniform float light_bands = 5.0;
uniform vec4 shadow_color : source_color = vec4(0.03, 0.03, 0.06, 1.0);
uniform float polar_caps = 0.0;       // Marte: casquetes polares
uniform vec4 cap_color : source_color = vec4(0.93, 0.92, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.55, 0.35, 0.0); // atmósfera (alfa = intensidad)

void fragment() {
	vec2 uv = (floor(UV * pixels) + 0.5) / pixels;
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	vec3 n = vec3(p.x, p.y, sqrt(1.0 - d * d));
	float u = atan(n.x, n.z) / TAU + spin;
	float v = asin(n.y) / PI + 0.5;
	vec3 col = texture(surface, vec2(u, v)).rgb;

	if (polar_caps > 0.0 && abs(n.y) > 1.0 - polar_caps) {
		col = cap_color.rgb;
	}

	float light = dot(n, normalize(light_dir));
	float s = clamp(light * 1.15 + 0.1, 0.0, 1.0);
	s = floor(s * light_bands + 0.5) / light_bands;
	col = mix(shadow_color.rgb, col, s);

	if (rim_color.a > 0.0) {
		float rim = floor(smoothstep(0.8, 1.0, d) * 3.0) / 3.0;
		col = mix(col, rim_color.rgb, rim * rim_color.a * max(s, 0.3));
	}
	COLOR = vec4(col, 1.0);
}
