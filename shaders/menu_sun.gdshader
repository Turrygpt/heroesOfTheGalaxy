shader_type canvas_item;
render_mode blend_add;

// Увеличенное солнце скрывается за сферой; оптическое свечение остаётся поверх неё.
// Пока диск скрыт, край чуть просвечивает через атмосферу планеты.
uniform float emergence = 0.0;
uniform vec2 sun_uv = vec2(0.45, 0.62);
uniform vec2 planet_center_uv = vec2(0.08, 2.79);
uniform float planet_radius_height = 2.25;
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 planet_delta = (UV - planet_center_uv) * vec2(aspect, 1.0);
	float horizon = length(planet_delta) - planet_radius_height;
	float visible_disc = smoothstep(-SCREEN_PIXEL_SIZE.y, SCREEN_PIXEL_SIZE.y, horizon);
	float behind_disc = 1.0 - visible_disc;
	float atmospheric_window = smoothstep(-0.020, 0.010, horizon) * smoothstep(0.080, 0.000, abs(horizon));
	// Половинные координаты увеличивают все элементы вспышки ровно вдвое.
	vec2 p = (UV - sun_uv) * vec2(aspect, 1.0) * 0.5;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float core = exp(-d * d / 0.000045) * visible_disc;
	float refracted_core = exp(-d * d / 0.000075) * behind_disc * atmospheric_window * 0.18;
	float halo = exp(-d * 36.0);
	float rays = pow(abs(cos(angle * 9.0 + 0.3)), 10.0) * exp(-d * 27.0) * smoothstep(0.004, 0.018, d);
	float streak = exp(-abs(p.y) * 800.0) * exp(-abs(p.x) * 12.0);
	vec2 from_center = UV - vec2(0.5, 0.5);
	vec2 lens_axis = sun_uv - vec2(0.5, 0.5);
	float lens_power = mix(0.10, 0.62, emergence);
	float ghost_a = exp(-dot(from_center + lens_axis * 0.55, from_center + lens_axis * 0.55) * 190.0);
	float ghost_b = exp(-dot(from_center + lens_axis * 1.10, from_center + lens_axis * 1.10) * 420.0);
	float ghost_c = exp(-dot(from_center - lens_axis * 0.72, from_center - lens_axis * 0.72) * 780.0);
	float flare_line = exp(-abs(UV.y - sun_uv.y) * 950.0) * exp(-abs(UV.x - sun_uv.x) * 2.8);
	float dawn_bloom = exp(-d * 18.0) * atmospheric_window;
	vec3 color = vec3(1.0, 0.96, 0.80) * core * 2.0;
	color += vec3(1.0, 0.66, 0.28) * refracted_core * mix(0.45, 1.0, emergence);
	color += vec3(1.0, 0.55, 0.17) * halo * mix(0.18, 0.95, emergence);
	color += vec3(1.0, 0.74, 0.39) * rays * mix(0.025, 0.19, emergence) * mix(0.12, 1.0, visible_disc);
	color += vec3(0.65, 0.81, 1.0) * streak * mix(0.03, 0.26, emergence);
	color += vec3(1.0, 0.58, 0.18) * dawn_bloom * 0.28;
	color += vec3(0.74, 0.92, 1.0) * flare_line * lens_power * 0.16;
	color += vec3(0.50, 0.76, 1.0) * ghost_a * lens_power * 0.11;
	color += vec3(1.0, 0.68, 0.24) * ghost_b * lens_power * 0.07;
	color += vec3(0.72, 0.92, 1.0) * ghost_c * lens_power * 0.045;
	COLOR = vec4(color, 1.0);
}
