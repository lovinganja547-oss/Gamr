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
uniform float dirt = 0.0;          // 0 = propre, 1 = très sale
uniform float points_on = 0.0;
uniform float layer = 0.5;          // 0 = racine, 1 = pointe
uniform float fur_len = 0.012;      // longueur des poils (m)
uniform float density = 380.0;      // mèches par mètre
uniform float flow = 0.3;           // irrégularité du sens du poil (épis)
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
	// sens du poil : couché vers l'arrière, avec des épis qui varient le long du corps
	vec3 swirl = vec3(sin(VERTEX.y * 23.0 + VERTEX.z * 17.0), sin(VERTEX.z * 19.0 + VERTEX.x * 29.0), sin(VERTEX.x * 21.0 + VERTEX.y * 13.0));
	// les mèches partent droit puis retombent : la courbure augmente vers la pointe
	vec3 dir = normalize(NORMAL + (comb + swirl * flow) * layer * layer * 1.35);
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
		p += vec3(sin(lpos.y * 620.0 + lpos.x * 210.0), sin(lpos.z * 620.0 + lpos.y * 210.0), sin(lpos.x * 620.0 + lpos.z * 210.0)) * curl;
	}
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float h = hash(cell);
	float h2 = hash(cell + 7.31);
	float h3 = hash(cell + 3.17);
	// racine de la mèche décalée dans sa cellule : plus de grille visible
	float d = length(f - (vec3(0.5) + (vec3(h3, h2, h) - 0.5) * 0.46));
	// touffes : la longueur ondule lentement sur le corps
	float clump = sin(lpos.x * 38.0 + sin(lpos.y * 31.0) * 1.7) * sin(lpos.z * 35.0 + sin(lpos.x * 27.0) * 1.7);
	float height = clamp(0.5 + h * 0.5 + clump * 0.16, 0.25, 1.0);
	float t = layer / height;
	// de loin les mèches deviennent plus petites qu'un pixel : on les épaissit pour éviter le scintillement
	float fw = max(fwidth(p.x), max(fwidth(p.y), fwidth(p.z)));
	float radius = mix(0.6, 0.12, t * t) + clamp(fw * 0.55 - 0.2, 0.0, 0.5);
	if (t > 1.0 || d > radius) { discard; }
	vec4 m = COLOR;
	vec3 col = mix(c_main.rgb, c_second.rgb, clamp(m.r * pattern_on, 0.0, 1.0));
	col = mix(col, c_points.rgb, clamp(m.b * points_on, 0.0, 1.0));
	col = mix(col, c_white.rgb, clamp(m.g, 0.0, 1.0));
	// sous-poil sombre et dense, pointes plus claires et légèrement délavées
	float depth = pow(layer, 0.75);
	col *= mix(0.7, 1.16, depth) * mix(0.8, 1.0, m.a);
	col *= 0.9 + h2 * 0.2;
	col *= 1.0 + clump * 0.06;
	col = mix(col, col * 1.08 + vec3(0.03, 0.022, 0.01), smoothstep(0.7, 1.0, t));
	// le cœur de la mèche est plus lumineux que son bord
	col *= mix(1.05, 0.92, smoothstep(0.0, radius, d));
	float spots = smoothstep(0.15, 0.7, sin(lpos.x * 70.0 + sin(lpos.z * 55.0) * 2.0) * sin(lpos.y * 60.0 + sin(lpos.x * 45.0) * 2.0) + (0.4 - lpos.y * 1.2));
	col = mix(col, col * vec3(0.55, 0.45, 0.33), clamp(dirt * spots, 0.0, 0.85));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	// duvet éclairé à contre-jour sur le contour
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = col * fres * 0.3 * layer;
}
