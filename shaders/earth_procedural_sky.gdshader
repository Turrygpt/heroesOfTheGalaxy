shader_type canvas_item;
render_mode unshaded;

float sky_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float sky_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = sky_hash(cell);
	float b = sky_hash(cell + vec2(1.0, 0.0));
	float c = sky_hash(cell + vec2(0.0, 1.0));
	float d = sky_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float sky_clouds(vec2 point) {
	float low = sky_noise(point);
	float middle = sky_noise(point * 2.03 + vec2(17.0, 9.0));
	float detail = sky_noise(point * 4.07 + vec2(41.0, 23.0));
	return low * 0.58 + middle * 0.29 + detail * 0.13;
}

void fragment() {
	vec2 point = UV * vec2(1672.0, 941.0);
	float height = clamp(point.y / 190.0, 0.0, 1.0);
	vec3 clear_sky = mix(vec3(0.38, 0.62, 0.84), vec3(0.80, 0.89, 0.94), height);
	float far_cloud = sky_clouds(vec2(point.x * 0.0028 - TIME * 0.010, point.y * 0.008 + 3.0));
	float near_cloud = sky_clouds(vec2(point.x * 0.0042 - TIME * 0.019 + 37.0, point.y * 0.013 + 8.0));
	float cloud = smoothstep(0.47, 0.66, far_cloud) * 0.53
		+ smoothstep(0.56, 0.73, near_cloud) * 0.14;
	cloud *= 1.0 - smoothstep(0.46, 0.87, height);
	// Длинная размытая гряда закрывает пустой участок над дальними горами.
	float bank_center = 39.0 + sin(point.x * 0.008 - TIME * 0.025) * 9.0;
	float bank_height = exp(-pow((point.y - bank_center) / 23.0, 2.0));
	float bank_width = smoothstep(630.0, 850.0, point.x) * (1.0 - smoothstep(1330.0, 1530.0, point.x));
	cloud += bank_height * bank_width * (0.11 + far_cloud * 0.25);
	vec3 color = mix(clear_sky, vec3(0.94, 0.97, 0.99), clamp(cloud, 0.0, 0.61));
	float haze = smoothstep(0.18, 0.86, height) * 0.38;
	color = mix(color, vec3(0.85, 0.91, 0.93), haze);
	COLOR = vec4(color, 1.0);
}
