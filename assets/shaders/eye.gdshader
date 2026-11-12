shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Œil vivant dessiné sur un seul globe : iris nuancé et strié, anneau sombre, pupille (ronde ou
// fendue pour le chat), blanc de l'œil dans les coins, deux reflets fixes, ombre de la paupière.
uniform vec3 iris_color : source_color = vec3(0.42, 0.26, 0.12);
uniform float iris_size = 0.80;      // rayon de l'iris sur le globe (0..1)
uniform float pupil_size = 0.36;
uniform float slit = 0.0;            // 1 = pupille verticale (chat)
uniform vec2 look = vec2(0.0);       // décalage du regard
varying vec3 lp;

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	vec2 uv = lp.xy - look * 0.25;
	float front = smoothstep(-0.1, 0.3, lp.z);
	float d = length(uv);
	float ang = atan(uv.y, uv.x);
	// blanc de l'œil (légèrement chaud, ombré vers les bords)
	vec3 col = vec3(0.96, 0.94, 0.90) * mix(0.7, 1.0, smoothstep(1.0, 0.75, d));
	// iris : plus clair au centre, stries radiales, anneau sombre sur le pourtour
	float streak = 0.5 + 0.5 * sin(ang * 26.0 + sin(d * 22.0) * 1.5);
	vec3 iris = mix(iris_color * 1.45, iris_color * 0.55, smoothstep(0.15, iris_size, d));
	iris *= 0.86 + 0.22 * streak;
	iris = mix(iris, iris_color * 0.18, smoothstep(iris_size * 0.84, iris_size, d));
	// éclat en croissant dans le bas de l'iris (lumière qui traverse)
	iris += iris_color * 0.55 * smoothstep(0.2, -0.6, uv.y / iris_size) * smoothstep(iris_size, iris_size * 0.4, d);
	col = mix(col, iris, smoothstep(iris_size + 0.02, iris_size - 0.02, d));
	// pupille
	vec2 pu = uv / vec2(mix(1.0, 0.36, slit), 1.0);
	float pd = length(pu);
	col = mix(col, vec3(0.015, 0.012, 0.02), smoothstep(pupil_size + 0.03, pupil_size - 0.03, pd));
	// ombre de la paupière supérieure
	col *= mix(1.0, 0.62, smoothstep(0.25, 0.95, uv.y));
	col *= front;
	// reflets
	float h1 = smoothstep(0.21, 0.15, length(lp.xy - vec2(0.27, 0.33)));
	float h2 = smoothstep(0.09, 0.05, length(lp.xy - vec2(-0.25, -0.27)));
	ALBEDO = col;
	EMISSION = vec3(1.0) * (h1 + h2 * 0.7) + col * 0.18;
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
}
