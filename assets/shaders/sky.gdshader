shader_type sky;
// Ciel dégradé, soleil avec halo et nuages doux ombrés (sans animation : calculé une seule fois).
uniform vec3 top_color : source_color = vec3(0.24, 0.5, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.87, 0.97);
uniform vec3 ground_color : source_color = vec3(0.55, 0.66, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.78);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.78, 0.88);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float cloud_cover = 0.42;
uniform float cloud_scale = 0.11;
uniform vec2 cloud_offset = vec2(0.0);

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, ground_color, smoothstep(0.0, -0.1, h));
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	// halo large + voile chaud près de l'horizon côté soleil
	col += sun_color * pow(sd, 6.0) * 0.16;
	col = mix(col, mix(col, sun_color, 0.35), pow(sd, 3.0) * (1.0 - clamp(h * 2.5, 0.0, 1.0)) * 0.6);
	if (h > 0.015) {
		vec2 uv = d.xz / (h + 0.22) * cloud_scale + cloud_offset;
		float n = texture(noise_tex, uv).r * 0.62 + texture(noise_tex, uv * 2.6 + vec2(0.37, 0.11)).g * 0.28 + texture(noise_tex, uv * 6.5).b * 0.10;
		float edge0 = 1.0 - cloud_cover;
		float c = smoothstep(edge0 - 0.04, edge0 + 0.2, n);
		// ombrage : la densité un peu plus loin vers le soleil assombrit le dessous du nuage
		vec2 toward = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.02;
		float n2 = texture(noise_tex, uv + toward).r * 0.62 + texture(noise_tex, (uv + toward) * 2.6 + vec2(0.37, 0.11)).g * 0.28;
		float lit = clamp(0.55 + (n - n2) * 9.0 + (1.0 - c) * 0.5, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_color, lit);
		cc = mix(cc, cc + sun_color * 0.25, pow(sd, 4.0));
		float fade = smoothstep(0.015, 0.16, h);
		col = mix(col, cc, c * fade * 0.94);
	}
	col += sun_color * (smoothstep(0.9993, 0.9997, sd) * 1.6 + pow(sd, 180.0) * 0.5);
	COLOR = col;
}
