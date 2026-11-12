shader_type spatial;
render_mode cull_back, shadows_disabled;
// Eau stylisée : deux nappes de bruit qui défilent, reflets scintillants, écume sur le bord.
uniform vec3 shallow : source_color = vec3(0.42, 0.78, 0.88);
uniform vec3 deep : source_color = vec3(0.16, 0.46, 0.72);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 center = vec2(0.0);
uniform float radius = 0.0;        // > 0 : plan d'eau rond, écume sur le pourtour
uniform float shore_z = -9999.0;   // rivage (mer au nord) : écume près de cette ligne
uniform float scale = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz * scale;
	float t = TIME;
	float n1 = texture(noise_tex, p * 0.07 + t * vec2(0.012, 0.008)).r;
	float n2 = texture(noise_tex, p * 0.17 - t * vec2(0.01, 0.014)).g;
	float w = n1 * 0.6 + n2 * 0.4;
	vec3 c = mix(deep, shallow, smoothstep(0.3, 0.75, w));
	float sp = texture(noise_tex, p * 0.55 + t * vec2(0.03, -0.02)).b * (0.55 + 0.45 * n2);
	c += smoothstep(0.66, 0.74, sp) * 0.22;
	float foam = 0.0;
	if (radius > 0.0) {
		float d = radius - distance(wp.xz, center);
		foam = smoothstep(0.34, 0.0, d + (n2 - 0.5) * 0.3 + sin(t * 1.4 + n1 * 12.0) * 0.05);
		c = mix(c, shallow * 1.1, smoothstep(1.2, 0.2, d) * 0.5);
	}
	if (shore_z > -9000.0) {
		float d2 = shore_z - wp.z;
		float wave = sin(t * 0.9 + wp.x * 0.35 + n1 * 5.0) * 0.5 + 0.5;
		foam = max(foam, smoothstep(0.9 + wave * 0.8, 0.0, d2 + (n2 - 0.5) * 0.8));
		foam = max(foam, smoothstep(0.12, 0.0, abs(d2 - 2.6 - wave * 1.4 + (n2 - 0.5) * 1.2)) * 0.6);
		c = mix(c, shallow * 1.12, smoothstep(7.0, 0.5, d2) * 0.6);
	}
	c = mix(c, foam_color, clamp(foam, 0.0, 1.0) * 0.9);
	ALBEDO = c;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
