// Shader « pelage » original : couleurs par masques de sommets, mèches fines,
// occlusion ambiante pré-calculée, éclairage enveloppant et liseré doux.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 c_main : source_color = vec4(0.9, 0.75, 0.5, 1.0);
uniform vec4 c_second : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform vec4 c_white : source_color = vec4(0.98, 0.96, 0.93, 1.0);
uniform vec4 c_points : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform float pattern_on = 1.0;
uniform float dirt = 0.0;          // 0 = propre, 1 = très sale
uniform float points_on = 0.0;
uniform float fur_strength = 1.0;
uniform float under = 0.0;         // 1 = recouvert de couches de poils (sous-poil assombri)
uniform float density = 380.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec4 m = COLOR;
	vec3 col = mix(c_main.rgb, c_second.rgb, clamp(m.r * pattern_on, 0.0, 1.0));
	col = mix(col, c_points.rgb, clamp(m.b * points_on, 0.0, 1.0));
	col = mix(col, c_white.rgb, clamp(m.g, 0.0, 1.0));
	// mèches fines : grain par cellule + longues stries qui suivent le corps
	vec3 cp = lpos * density * 0.75;
	vec3 cell = floor(cp);
	float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float s1 = sin(lpos.x * 160.0 + sin(lpos.y * 90.0) * 2.0) * sin(lpos.y * 150.0 + sin(lpos.z * 110.0) * 2.0);
	float s2 = sin(lpos.z * 240.0 + lpos.x * 70.0 + sin(lpos.y * 130.0) * 1.5);
	float clump = sin(lpos.x * 38.0 + sin(lpos.y * 31.0) * 1.7) * sin(lpos.z * 35.0 + sin(lpos.x * 27.0) * 1.7);
	float grain = (s1 * 0.06 + s2 * 0.04) * fur_strength + (h - 0.5) * 0.14 * (1.0 - under * 0.5) + clump * 0.05;
	col *= 1.0 + grain;
	col *= mix(1.0, 0.74, under);
	float spots = smoothstep(0.15, 0.7, sin(lpos.x * 70.0 + sin(lpos.z * 55.0) * 2.0) * sin(lpos.y * 60.0 + sin(lpos.x * 45.0) * 2.0) + (0.4 - lpos.y * 1.2));
	col = mix(col, col * vec3(0.55, 0.45, 0.33), clamp(dirt * spots, 0.0, 0.85));
	col *= mix(0.86, 1.0, m.a);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	RIM = 0.35;
	RIM_TINT = 0.7;
	// le relief des mèches accroche la lumière
	NORMAL = normalize(NORMAL + (vec3(s1, s2, h - 0.5) * 0.12 * fur_strength) * (1.0 - under));
}
