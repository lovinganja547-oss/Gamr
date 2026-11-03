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

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec4 m = COLOR;
	vec3 col = mix(c_main.rgb, c_second.rgb, clamp(m.r * pattern_on, 0.0, 1.0));
	col = mix(col, c_points.rgb, clamp(m.b * points_on, 0.0, 1.0));
	col = mix(col, c_white.rgb, clamp(m.g, 0.0, 1.0));
	float s1 = sin(lpos.x * 160.0 + sin(lpos.y * 90.0) * 2.0) * sin(lpos.y * 150.0 + sin(lpos.z * 110.0) * 2.0);
	float s2 = sin(lpos.z * 240.0 + lpos.x * 70.0);
	col *= 1.0 + (s1 * 0.05 + s2 * 0.025) * fur_strength;
	float spots = smoothstep(0.15, 0.7, sin(lpos.x * 70.0 + sin(lpos.z * 55.0) * 2.0) * sin(lpos.y * 60.0 + sin(lpos.x * 45.0) * 2.0) + (0.4 - lpos.y * 1.2));
	col = mix(col, col * vec3(0.55, 0.45, 0.33), clamp(dirt * spots, 0.0, 0.85));
	col *= mix(0.86, 1.0, m.a);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	RIM = 0.2;
	RIM_TINT = 0.6;
}
