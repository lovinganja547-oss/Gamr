shader_type spatial;
render_mode cull_disabled, world_vertex_coords, shadows_disabled;
// Touffes d'herbe et fleurs (cartes croisées) animées par le vent, éclairées comme le sol.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wind = 0.07;
uniform vec4 frame = vec4(0.0, 0.0, 1.0, 1.0);   // sous-image (planche de fleurs) ; z, w = taille
uniform float atlas = 1.0;                        // nombre de vignettes par côté
varying vec2 uv2;

void vertex() {
	float top = 1.0 - UV.y;
	float ph = TIME * 1.7 + VERTEX.x * 0.8 + VERTEX.z * 1.1;
	float gust = sin(TIME * 0.45 + VERTEX.x * 0.12 + VERTEX.z * 0.09) * 0.5 + 0.5;
	VERTEX.x += (sin(ph) * 0.6 + gust) * wind * top * top;
	VERTEX.z += cos(ph * 0.83) * wind * 0.5 * top * top;
	NORMAL = vec3(0.0, 1.0, 0.0);
	// vignette choisie par l'alpha de la couleur d'instance (0..1 -> index)
	float idx = floor(COLOR.a * atlas * atlas - 0.001);
	vec2 cell = vec2(mod(idx, atlas), floor(idx / atlas));
	uv2 = (UV + cell) / atlas;
}

void fragment() {
	vec4 t = texture(tex, uv2);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
