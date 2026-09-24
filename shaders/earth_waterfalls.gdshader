shader_type canvas_item;
render_mode unshaded;

// Параметры в пикселях исходной панорамы 1672 × 941.
uniform vec4 waterfall_tops[7];
uniform vec4 waterfall_bottoms[7];

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 point = UV * vec2(1672.0, 941.0);
	vec3 source = texture(TEXTURE, UV).rgb;
	// Голубоватая вода пропускает блики, серые скалы и дорога их гасят.
	float water_color = smoothstep(0.012, 0.075, source.b - source.r);
	float water_light = smoothstep(0.14, 0.35, dot(source, vec3(0.299, 0.587, 0.114)));
	float water_surface = water_color * water_light;
	float opacity = 0.0;
	float spray = 0.0;
	for (int index = 0; index < 7; index++) {
		vec4 top = waterfall_tops[index];
		vec4 bottom = waterfall_bottoms[index];
		float progress = (point.y - top.y) / (bottom.y - top.y);
		if (progress < -0.06 || progress > 1.045) {
			continue;
		}
		float center = mix(top.x, bottom.x, clamp(progress, 0.0, 1.0));
		float half_width = mix(top.z, bottom.z, clamp(progress, 0.0, 1.0));
		float across = point.x - center;
		float edge = 1.0 - smoothstep(half_width - 4.0, half_width, abs(across));
		float length_mask = smoothstep(-0.01, 0.08, progress) * (1.0 - smoothstep(0.89, 1.0, progress));
		float mask = edge * length_mask * water_surface;
		float phase = TIME * bottom.w;
		// Узкие струи извиваются; светлые участки бегут вниз по течению.
		float strand = pow(0.5 + 0.5 * sin(across * 0.89 + sin(point.y * 0.08 - phase * 2.5) * 0.8), 6.0);
		float glint = pow(max(0.0, sin(point.y * 0.30 - phase * 8.0 + across * 0.13)), 5.0);
		float turbulence = hash21(floor(vec2(point.x * 0.42, point.y * 0.18 - phase * 5.0)));
		float flow = strand * (0.16 + glint * 0.38) + glint * turbulence * 0.09;
		opacity += mask * top.w * flow;
		// Внизу струя разбивается на мелкие движущиеся капли.
		float mist_zone = smoothstep(0.82, 0.98, progress) * (1.0 - smoothstep(1.0, 1.045, progress));
		float mist_width = 1.0 - smoothstep(half_width * 0.65, half_width * 1.05, abs(across));
		vec2 drop_cell = floor(vec2(point.x * 0.35, point.y * 0.35 - phase * 4.0));
		float drop = step(0.91, hash21(drop_cell));
		spray += mist_zone * mist_width * drop * top.w * water_surface * 0.05;
	}
	COLOR = vec4(0.81, 0.93, 1.0, clamp(opacity + spray, 0.0, 0.45));
}
