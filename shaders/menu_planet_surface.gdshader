shader_type canvas_item;

// Вращающаяся планета главного меню: surface_tex — equirectangular 2:1 карта.
// Диск планеты меньше UV, чтобы вокруг осталось место на атмосферу.
// Compatibility не умеет return в fragment — ветка через if.

uniform sampler2D surface_tex : repeat_enable, filter_linear_mipmap;
uniform float seconds_per_turn = 960.0;
uniform vec3 light_dir = vec3(0.12, 0.72, 0.55);
uniform vec3 atmosphere_color = vec3(0.38, 0.72, 1.0);
uniform float planet_radius = 0.90;

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
	for (int index = 0; index < 3; index++) {
		value += value_noise(point) * amplitude;
		point = point * 2.07 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 light_n = normalize(light_dir);
	vec4 out_color = vec4(0.0);

	if (r <= planet_radius) {
		vec2 q = p / planet_radius;
		float r2 = dot(q, q);
		float z = sqrt(max(0.0, 1.0 - r2));
		vec3 normal = normalize(vec3(q.x, -q.y, z));

		float turn = TIME / max(seconds_per_turn, 1.0);
		float longitude = 1.0 - (atan(normal.x, normal.z) / 6.28318530718 + 0.5 + turn);
		float latitude = 1.0 - (asin(clamp(normal.y, -1.0, 1.0)) / 3.14159265359 + 0.5);
		// Дальние точки диска (малый z, лимб) дальше от камеры — сильнее размытие.
		float farness = pow(1.0 - z, 1.15);
		vec2 surf_uv = vec2(longitude, latitude);
		float lod = farness * 4.2;
		vec2 blur = vec2(farness * 0.011, farness * 0.0055);
		vec3 surface = textureLod(surface_tex, surf_uv, lod).rgb * 0.40;
		surface += textureLod(surface_tex, surf_uv + vec2(blur.x, 0.0), lod).rgb * 0.15;
		surface += textureLod(surface_tex, surf_uv - vec2(blur.x, 0.0), lod).rgb * 0.15;
		surface += textureLod(surface_tex, surf_uv + vec2(0.0, blur.y), lod).rgb * 0.15;
		surface += textureLod(surface_tex, surf_uv - vec2(0.0, blur.y), lod).rgb * 0.15;

		float light = dot(normal, light_n);
		float day = smoothstep(-0.12, 0.55, light);
		float night = smoothstep(-0.55, 0.12, light);
		vec3 color = surface * (0.07 + 0.52 * day);
		color = mix(color * 0.18, color, night);

		vec2 cloud_uv = vec2(longitude * 7.0 + turn * 0.18, latitude * 3.6);
		float cloud_a = fbm(cloud_uv);
		float cloud_b = fbm(cloud_uv * 1.7 + vec2(4.2, -turn * 0.11));
		float bands = smoothstep(0.08, 0.22, latitude) * smoothstep(0.92, 0.78, latitude);
		float clouds = smoothstep(0.46, 0.74, cloud_a * 0.62 + cloud_b * 0.38) * bands;
		vec3 cloud_color = mix(vec3(0.42, 0.48, 0.55), vec3(0.70, 0.74, 0.80), cloud_b);

		// Оптическая толща: к лимбу смотрим сквозь больше воздуха.
		float air = pow(1.0 - z, 1.28);
		color = mix(color, cloud_color * (0.28 + 0.45 * day), clouds * (0.28 + 0.32 * day) * (1.0 - air * 0.85));
		vec3 haze = mix(atmosphere_color * 0.22, vec3(0.78, 0.90, 1.0), day * 0.55);
		haze = mix(haze, vec3(1.0, 0.72, 0.38), smoothstep(0.05, 0.55, light) * (1.0 - day) * 0.35);
		color = mix(color, haze, smoothstep(0.08, 0.92, air) * (0.55 + 0.28 * day));
		color = mix(color, vec3(dot(color, vec3(0.30, 0.50, 0.20))), air * 0.22);
		color += atmosphere_color * pow(air, 2.4) * (0.20 + 0.45 * day);

		out_color = vec4(color, 1.0);
	}

	float sun_facing = clamp(dot(normalize(vec3(p.x, -p.y, 0.35)), light_n), 0.0, 1.0);
	float dist_out = max(0.0, r - planet_radius);
	float corona = exp(-dist_out * 42.0);
	float halo_soft = exp(-dist_out * 16.0);
	float inside_fade = smoothstep(planet_radius * 0.97, planet_radius, r);
	vec3 corona_col = mix(atmosphere_color * 0.55, vec3(0.55, 0.82, 1.0), sun_facing);
	corona_col = mix(corona_col, vec3(1.0, 0.70, 0.32), sun_facing * (1.0 - sun_facing) * 1.4);
	float shell = (corona * 0.85 + halo_soft * 0.22) * mix(0.18, 1.0, 0.35 + 0.65 * sun_facing);
	shell *= mix(inside_fade, 1.0, step(planet_radius, r));
	out_color.rgb += corona_col * shell;
	out_color.a = max(out_color.a, shell * 0.72);

	COLOR = out_color;
}
