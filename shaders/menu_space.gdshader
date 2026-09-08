shader_type canvas_item;

// Процедурный космос главного меню: тёплая пыль слева (за кольцом),
// холодный рукав справа-сверху и звёзды нескольких размеров.
// UV — нормализованный кадр, aspect берётся из SCREEN_PIXEL_SIZE,
// чтобы сетка звёзд не растягивалась на широком экране.

float hash_21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash_21(cell);
	float b = hash_21(cell + vec2(1.0, 0.0));
	float c = hash_21(cell + vec2(0.0, 1.0));
	float d = hash_21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 point) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int index = 0; index < 4; index++) {
		value += value_noise(point) * amplitude;
		point = point * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.48;
	}
	return value;
}

float star_layer(vec2 uv, float scale, float threshold, float time) {
	vec2 grid_uv = uv * scale;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;
	float n = hash_21(cell);
	if (n < threshold) {
		return 0.0;
	}
	vec2 offset = vec2(hash_21(cell + vec2(13.1, 0.0)), hash_21(cell + vec2(0.0, 47.2))) - 0.5;
	vec2 delta = local - offset * 0.55;
	float brightness = (n - threshold) / max(1.0 - threshold, 0.001);
	// Медленная небольшая пульсация: у каждой звезды свой темп и фаза.
	float pulse = 0.90 + 0.10 * sin(time * (0.35 + n * 0.55) + n * 40.0);
	float radius = mix(0.016, 0.055, brightness) * (0.96 + 0.04 * pulse);
	float core = smoothstep(radius, 0.0, length(delta)) * brightness * pulse;
	float spikes = 0.0;
	if (n > 0.985) {
		float arm = 1.0 - smoothstep(0.0, 0.42, abs(delta.x) * 18.0);
		float cross = 1.0 - smoothstep(0.0, 0.42, abs(delta.y) * 18.0);
		spikes = max(arm * (1.0 - abs(delta.y) * 3.4), cross * (1.0 - abs(delta.x) * 3.4));
		spikes = max(spikes, 0.0) * brightness * pulse * 0.55;
	}
	return core + spikes;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001);
	vec2 p = vec2(uv.x * aspect, uv.y);

	vec3 color = vec3(0.012, 0.027, 0.07);
	float warp = fbm(p * 2.0 + vec2(TIME * 0.004, 0.0));
	vec2 q = p + (warp - 0.5) * 0.22;

	float warm_n = fbm(q * 2.4 + vec2(3.1, 8.0));
	float cool_n = fbm(q * 2.8 + vec2(11.0, 2.4) + vec2(-TIME * 0.003, TIME * 0.002));
	float vein = fbm(q * 1.7 + vec2(6.4, 1.8));

	float warm_mask = smoothstep(0.48, 0.02, uv.x) * smoothstep(0.02, 0.18, uv.y) * smoothstep(0.88, 0.48, uv.y);
	float warm_body = smoothstep(0.42, 0.78, warm_n) * warm_mask;
	float warm_core = smoothstep(0.62, 0.90, warm_n) * warm_mask;

	float diag = uv.x * 0.62 + (1.0 - uv.y) * 0.58;
	float band = exp(-((diag - 0.82) * (diag - 0.82)) / 0.048) * smoothstep(0.38, 0.72, uv.x);
	float cool_body = smoothstep(0.48, 0.82, cool_n) * (0.22 + 0.78 * band);
	float cool_core = smoothstep(0.66, 0.92, cool_n) * band;
	float mid = smoothstep(0.55, 0.82, vein) * smoothstep(0.18, 0.45, uv.x) * smoothstep(0.72, 0.42, uv.x) * 0.28;

	color += warm_body * vec3(0.61, 0.267, 0.086) * 0.95;
	color += warm_core * vec3(0.816, 0.439, 0.165) * 0.62;
	color += cool_body * vec3(0.11, 0.227, 0.478) * 0.55;
	color += cool_core * vec3(0.659, 0.808, 0.949) * 0.38;
	color += mid * vec3(0.188, 0.118, 0.306);
	color += vec3(0.02, 0.024, 0.043) * fbm(p * 6.0);

	vec2 star_uv = vec2(uv.x * aspect, uv.y);
	float stars = 0.0;
	stars += star_layer(star_uv, 92.0, 0.88, TIME) * 0.55;
	stars += star_layer(star_uv + vec2(17.0, 9.0), 54.0, 0.93, TIME) * 0.85;
	stars += star_layer(star_uv + vec2(4.0, 28.0), 22.0, 0.975, TIME);
	color += vec3(0.86, 0.91, 1.0) * stars;

	COLOR = vec4(color, 1.0);
}
