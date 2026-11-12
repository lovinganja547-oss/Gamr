shader_type spatial;
// Sol peint : herbe (ou autre base), chemin et seconde matière fondus par un masque (R, G),
// ombres de contact peintes (B), variation de teinte à grande échelle, bords irréguliers.
uniform sampler2D tex_base : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_r : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_g : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mask : repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 mask_rect = vec4(-20.0, -20.0, 40.0, 40.0);
uniform float uv_base = 0.42;
uniform float uv_r = 0.5;
uniform float uv_g = 0.45;
uniform vec3 tint_base : source_color = vec3(1.0);
uniform vec3 tint_var : source_color = vec3(1.08, 1.02, 0.78);
uniform vec3 tint_r : source_color = vec3(1.0);
uniform vec3 tint_g : source_color = vec3(1.0);
uniform float macro_amount = 0.3;
uniform sampler2D tex_g2 : source_color, repeat_enable, filter_linear_mipmap;
uniform float g2_z = -9999.0;   // au nord de cette ligne, la matière verte devient tex_g2 (sable)
uniform vec3 tint_g2 : source_color = vec3(1.0);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	vec3 nz = texture(noise_tex, p * 0.031).rgb;
	vec3 nz2 = texture(noise_tex, p * 0.23 + vec2(0.31, 0.57)).rgb;
	vec2 muv = (p - mask_rect.xy) / mask_rect.zw;
	vec3 m = texture(mask, muv + (nz2.rg - 0.5) * 0.35 / mask_rect.zw).rgb;
	vec3 a = texture(tex_base, p * uv_base).rgb;
	vec3 a2 = texture(tex_base, p.yx * uv_base * 0.31 + vec2(0.5, 0.2)).rgb;
	a = mix(a, a2, 0.4) * tint_base;
	a *= mix(1.0 - macro_amount, 1.0 + macro_amount * 0.6, nz.r);
	a = mix(a, a * tint_var, smoothstep(0.5, 0.78, nz.g));
	vec3 r = texture(tex_r, p * uv_r).rgb * tint_r * mix(0.9, 1.08, nz.b);
	vec3 g = texture(tex_g, p * uv_g).rgb * tint_g * mix(0.9, 1.08, nz.b);
	if (g2_z > -9000.0) {
		vec3 g2 = texture(tex_g2, p * uv_g).rgb * tint_g2 * mix(0.9, 1.08, nz.b);
		g = mix(g, g2, smoothstep(g2_z + 1.5, g2_z - 1.5, wp.z + (nz2.r - 0.5) * 2.0));
	}
	float jr = (nz2.b - 0.5) * 0.4;
	float er = smoothstep(0.36, 0.64, m.r + jr * (1.0 - abs(m.r * 2.0 - 1.0)));
	float eg = smoothstep(0.36, 0.64, m.g + jr * (1.0 - abs(m.g * 2.0 - 1.0)));
	vec3 c = mix(a, g, eg);
	c = mix(c, r, er);
	c *= 1.0 - 0.16 * max(er * (1.0 - er), eg * (1.0 - eg)) * 4.0;
	c *= 1.0 - m.b * 0.5;
	ALBEDO = c;
	ROUGHNESS = 0.96;
	SPECULAR = 0.08;
}
