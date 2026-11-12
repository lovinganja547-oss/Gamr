shader_type spatial;
// Feuillage sculpté : texture de feuilles en projection sur les trois axes, occlusion par sommet,
// teinte par instance, léger balancement au vent, dessus plus clair.
uniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float tex_scale = 1.1;
uniform float sway = 0.035;
uniform float top_light = 0.3;
varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = TIME * 1.25 + origin.x * 0.6 + origin.z * 0.8;
	float k = sway * (0.6 + VERTEX.y * 0.5);
	VERTEX.x += sin(ph + VERTEX.y * 1.7) * k;
	VERTEX.z += cos(ph * 0.8 + VERTEX.x * 1.3) * k * 0.7;
}

void fragment() {
	vec3 w = pow(abs(normalize(ln)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 t = texture(tex, lp.zy * tex_scale).rgb * w.x + texture(tex, lp.xz * tex_scale).rgb * w.y + texture(tex, lp.xy * tex_scale).rgb * w.z;
	vec3 c = COLOR.rgb * t * 1.25;
	c *= mix(1.0 - top_light, 1.0 + top_light * 0.6, smoothstep(-0.7, 0.9, ln.y * 0.6 + lp.y * 0.5));
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.04;
	BACKLIGHT = c * 0.35;
}
