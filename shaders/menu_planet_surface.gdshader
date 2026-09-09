shader_type canvas_item;

// Сфера с независимым дрейфом облаков, ночными городами и прозрачной атмосферой.
uniform sampler2D surface_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D weather_tex : repeat_enable, filter_linear_mipmap;
// Освещённость нарастает вместе с восходом; ночные огни сохраняют яркость.
uniform float daylight_exposure = 1.0;
uniform float city_light_power = 1.0;
uniform float city_light_threshold = 0.55;
uniform float seconds_per_turn = 960.0;
uniform vec3 light_dir = vec3(0.45, 0.85, -0.38);
uniform vec3 atmosphere_color = vec3(0.20, 0.52, 1.0);
uniform float planet_radius = 0.90;
uniform float axis_tilt = 0.45;
uniform vec2 sun_q = vec2(0.45, -0.88);

float hash_21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	return texture(weather_tex, p / vec2(36.0, 18.0)).r;
}
void fragment() {
	vec2 q = (UV * 2.0 - 1.0) / planet_radius;
	float radius = length(q);
	vec3 light = normalize(light_dir);
	float toward_sun = pow(max(0.0, dot(normalize(q + vec2(0.00001)), normalize(sun_q))), 5.0);
	vec4 result = vec4(0.0);
	if (radius <= 1.0) {
		float z = sqrt(max(0.0, 1.0 - dot(q,q)));
		vec3 normal = vec3(q.x, -q.y, z);
		float ct = cos(axis_tilt);
		float st = sin(axis_tilt);
		vec3 tilted = vec3(normal.x, normal.y * ct - normal.z * st, normal.y * st + normal.z * ct);
		float turn = TIME / seconds_per_turn;
		vec2 uv = vec2(0.5 - atan(tilted.x, tilted.z) / 6.2831853 - turn,
			0.5 - asin(clamp(tilted.y, -1.0, 1.0)) / 3.14159265);
		vec3 surface = textureLod(surface_tex, uv, (1.0 - z) * 1.5).rgb;
		float incidence = dot(normal, light);
		float day = smoothstep(-0.12, 0.65, incidence);
		// Огни плавно гаснут в сумерках и полностью выключены на освещённой суше.
		float night = 1.0 - smoothstep(-0.15, 0.08, incidence);
		vec3 color = surface * (0.025 + day * 0.48) * daylight_exposure;
		// Города закреплены на поверхности. Синяя вода и полярный лёд исключены.
		float land = (1.0 - smoothstep(0.015, 0.10, surface.b - surface.r * 0.65 - surface.g * 0.35));
		land *= 1.0 - smoothstep(0.65, 0.85, min(surface.r, min(surface.g, surface.b)));
		vec2 grid = uv * vec2(1440.0, 720.0);
		vec2 cell = floor(grid);
		vec2 jitter = vec2(hash_21(cell + 3.2), hash_21(cell + 7.8)) - 0.5;
		float distance = length(fract(grid) - 0.5 - jitter * 0.65);
		float urban_noise = noise(uv * vec2(540.0, 270.0));
		float cluster = smoothstep(0.30, 0.61, urban_noise);
		float roads = (1.0 - smoothstep(0.008, 0.025, abs(urban_noise - 0.52))) * cluster;
		float cities = (1.0 - smoothstep(0.02, max(0.16, fwidth(grid.x) * 0.5), distance)) * step(city_light_threshold, hash_21(cell));
		color += vec3(1.0, 0.65, 0.24) * (cities * cluster * 4.0 + roads * 0.09) * land * night * city_light_power;
		// Кучевые облака: раздельные округлые ячейки внутри погодных фронтов.
		vec2 weather = uv * vec2(108.0, 54.0) + vec2(turn * 1.8, 0.0);
		float front = noise(weather);
		float detail = noise(weather * 7.0 + vec2(4.1, 7.3));
		float fine = noise(weather * 23.0 + vec2(2.7, 6.1));
		float cumulus = smoothstep(0.53, 0.74, front * 0.46 + detail * 0.34 + fine * 0.20);
		// Перистые облака: тонкие вытянутые волокна с изгибом по широте.
		vec2 wisps = weather * vec2(3.8, 28.0);
		wisps.y += sin(weather.x * 1.6) * 2.6 + front * 4.0;
		float cirrus = smoothstep(0.48, 0.70, noise(wisps)) * smoothstep(0.35, 0.65, front) * 0.22;
		float cloud = clamp(cumulus + cirrus, 0.0, 0.93);
		float cloud_day = smoothstep(-0.38, 0.48, incidence);
		vec3 cloud_color = mix(vec3(0.045, 0.064, 0.085), vec3(0.95, 0.92, 0.86), cloud_day);
		cloud_color += vec3(0.23, 0.12, 0.045) * toward_sun * (1.0 - z);
		// Слабая тень с подветренной стороны подчёркивает объём кучевых облаков.
		float cloud_relief = detail - noise(weather * 7.0 + vec2(4.16, 7.35));
		cloud_color *= daylight_exposure;
		cloud_color *= clamp(0.90 + cloud_relief * 2.0, 0.70, 1.12);
		color = mix(color * (1.0 - cumulus * 0.18), cloud_color, cloud * 0.70);
		float air = pow(1.0 - z, 9.0);
		vec3 scattering = mix(vec3(0.10, 0.56, 1.0), vec3(0.88, 0.92, 1.0), toward_sun * 0.65);
		color = mix(color, scattering, air * 0.88);
		color += vec3(0.42, 0.78, 1.0) * exp(-abs(radius - 1.0) * 600.0) * 0.9;
		// Поверхность непрозрачна до самого края: прежнее затухание альфы
		// создавало чёрный зазор перед внешней атмосферой.
		result = vec4(color, 1.0);
	} else {
		// Плотность плавно убывает наружу: нет непрозрачной обводки диска.
		float height = radius - 1.0;
		float density = exp(-height * 185.0) * (1.0 - smoothstep(0.012, 0.035, height));
		vec3 glow = mix(vec3(0.34, 0.72, 1.0), vec3(0.82, 0.93, 1.0), toward_sun * 0.55);
		result = vec4(glow, density);
	}
	COLOR = result;
}
