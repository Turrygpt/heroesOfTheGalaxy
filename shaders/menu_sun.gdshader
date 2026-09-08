shader_type canvas_item;
render_mode blend_add;

// Увеличенное солнце скрывается за сферой; оптическое свечение остаётся поверх неё.
// Пока диск скрыт, над горизонтом остаётся лишь слабое зарево.
uniform float emergence = 0.0;
uniform vec2 sun_uv = vec2(0.45, 0.62);
uniform vec2 planet_center_uv = vec2(0.08, 2.79);
uniform float planet_radius_height = 2.25;
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 planet_delta = (UV - planet_center_uv) * vec2(aspect, 1.0);
	float horizon = length(planet_delta) - planet_radius_height;
	float visible_disc = smoothstep(-SCREEN_PIXEL_SIZE.y, SCREEN_PIXEL_SIZE.y, horizon);
	// Половинные координаты увеличивают все элементы вспышки ровно вдвое.
	vec2 p = (UV - sun_uv) * vec2(aspect, 1.0) * 0.5;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float core = exp(-d * d / 0.000045) * visible_disc;
	float halo = exp(-d * 36.0);
	float rays = pow(abs(cos(angle * 9.0 + 0.3)), 10.0) * exp(-d * 27.0) * smoothstep(0.004, 0.018, d);
	float streak = exp(-abs(p.y) * 800.0) * exp(-abs(p.x) * 12.0);
	vec3 color = vec3(1.0, 0.96, 0.80) * core * 2.0;
	color += vec3(1.0, 0.55, 0.17) * halo * mix(0.18, 0.95, emergence);
	color += vec3(1.0, 0.74, 0.39) * rays * mix(0.025, 0.19, emergence) * mix(0.12, 1.0, visible_disc);
	color += vec3(0.65, 0.81, 1.0) * streak * mix(0.03, 0.26, emergence);
	COLOR = vec4(color, 1.0);
}
