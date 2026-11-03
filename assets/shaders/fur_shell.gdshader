// Poils par couches (« shell fur ») : chaque couche est le maillage gonflé le long
// des normales ; un motif de mèches en espace objet découpe les poils (alpha scissor),
// plus fins et plus clairs vers la pointe. Compatible GL Compatibility.
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled, depth_draw_opaque;

uniform vec4 c_main : source_color = vec4(0.9, 0.75, 0.5, 1.0);
uniform vec4 c_second : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform vec4 c_white : source_color = vec4(0.98, 0.96, 0.93, 1.0);
uniform vec4 c_points : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform float pattern_on = 1.0;
uniform float points_on = 0.0;
uniform float layer = 0.5;          // 0 = racine, 1 = pointe
uniform float fur_len = 0.012;      // longueur des poils (m)
uniform float density = 380.0;      // mèches par mètre
uniform float curl = 0.0;           // poils bouclés (caniche)
uniform vec3 comb = vec3(0.0, -0.35, -0.45); // poils couchés (gravité / vers l'arrière)
uniform vec3 hole_a = vec3(100.0);  // zones sans poils (yeux, truffe), repère local
uniform vec3 hole_b = vec3(100.0);
uniform vec3 hole_c = vec3(100.0);
uniform float hole_r = 0.0;

varying vec3 lpos;
varying float len_k;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	float k = 1.0;
	if (hole_r > 0.0) {
		float d = min(min(distance(VERTEX, hole_a), distance(VERTEX, hole_b)), distance(VERTEX, hole_c));
		k = smoothstep(hole_r * 0.95, hole_r * 1.35, d);
	}
	len_k = k;
	vec3 dir = normalize(NORMAL + comb * layer);
	lpos = VERTEX;
	VERTEX += dir * fur_len * layer * k;
}

void fragment() {
	if (len_k < 0.05) { discard; }
	if (hole_r > 0.0) {
		float dh = min(min(distance(lpos, hole_a), distance(lpos, hole_b)), distance(lpos, hole_c));
		if (dh < hole_r) { discard; }
	}
	vec3 p = lpos * density;
	if (curl > 0.0) {
		p += vec3(sin(lpos.y * 900.0), sin(lpos.z * 900.0), sin(lpos.x * 900.0)) * curl;
	}
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash(cell);
	float h2 = hash(cell + 7.31);
	// chaque mèche a sa propre hauteur ; le poil s'affine vers la pointe
	float height = 0.45 + h * 0.55;
	float radius = (1.0 - layer / height) * 0.7 + 0.08;
	if (layer > height || length(f.xy + (h2 - 0.5) * 0.2) > radius) { discard; }
	vec4 m = COLOR;
	vec3 col = mix(c_main.rgb, c_second.rgb, clamp(m.r * pattern_on, 0.0, 1.0));
	col = mix(col, c_points.rgb, clamp(m.b * points_on, 0.0, 1.0));
	col = mix(col, c_white.rgb, clamp(m.g, 0.0, 1.0));
	col *= mix(0.82, 1.06, layer) * mix(0.75, 1.0, m.a) * (0.92 + h2 * 0.16);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
