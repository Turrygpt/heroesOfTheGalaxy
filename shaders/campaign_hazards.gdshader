// Размытая визуальная маска облаков; проходимость хранится отдельно в карте.
shader_type canvas_item;
render_mode unshaded;

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(noise_hash(i), noise_hash(i + vec2(1.0, 0.0)), f.x),
		mix(noise_hash(i + vec2(0.0, 1.0)), noise_hash(i + vec2(1.0)), f.x), f.y);
}
// Палитра меняется по крупным областям, а не раскрашивает каждую клетку.
vec3 nebula_palette(vec2 uv) {
	float north = smoothstep(0.25, 0.72, uv.x - uv.y * 0.22);
	float south = smoothstep(0.35, 0.85, uv.y);
	vec3 violet = vec3(0.43, 0.24, 0.57);
	vec3 teal = vec3(0.40, 0.29, 0.64);
	vec3 copper = vec3(0.58, 0.23, 0.42);
	return mix(mix(violet, teal, north), copper, south * (1.0 - north * 0.6));
}
// Вторая маска: по каналу на сектор со своей композицией (см.
// campaign_terrain_renderer.gd:BIOME_CHANNELS). Без неё - чёрная, то есть
// обычная палитра карты; авторская миссия так и работает.
uniform sampler2D biome_mask : hint_default_black;
void fragment() {
	vec2 p = UV * 90.0;
	vec2 flow = vec2(TIME * 0.018, -TIME * 0.011);
	vec2 drift = vec2(cloud_noise(p * 0.24), cloud_noise(p * 0.24 + 31.7)) - 0.5;
	// Извилистая кромка и лёгкие языки газа поверх доступных клеток.
	vec3 mask = texture(TEXTURE, UV + drift * 0.012).rgb;
	vec2 biome = texture(biome_mask, UV + drift * 0.012).rg;
	float ice = clamp(biome.r * 1.7, 0.0, 1.0);
	float toxic = clamp(biome.g * 1.7, 0.0, 1.0);
	float n = cloud_noise(p + drift * 2.0 + flow) * 0.55 + cloud_noise(p * 2.1 - flow * 0.7) * 0.3 + cloud_noise(p * 4.3) * 0.15;
	vec3 dust = mix(vec3(0.035, 0.045, 0.07), vec3(0.18, 0.23, 0.30), n);
	vec3 radiation = nebula_palette(UV) * (0.35 + n * 0.85);
	vec3 gas = mix(vec3(0.07, 0.23, 0.38), vec3(0.24, 0.67, 0.83), n);
	dust = mix(dust, mix(vec3(0.05, 0.08, 0.13), vec3(0.30, 0.44, 0.58), n), ice);
	radiation = mix(radiation, mix(vec3(0.09, 0.24, 0.42), vec3(0.50, 0.76, 0.98), n), ice);
	gas = mix(gas, mix(vec3(0.08, 0.28, 0.48), vec3(0.46, 0.82, 1.00), n), ice);
	dust = mix(dust, mix(vec3(0.06, 0.07, 0.03), vec3(0.24, 0.27, 0.10), n), toxic);
	radiation = mix(radiation, mix(vec3(0.11, 0.16, 0.03), vec3(0.42, 0.54, 0.14), n), toxic);
	gas = mix(gas, mix(vec3(0.09, 0.15, 0.03), vec3(0.38, 0.54, 0.13), n), toxic);
	mask.b *= 1.35;
	float total = mask.r + mask.g + mask.b;
	vec3 color = (dust * mask.r + radiation * mask.g + gas * mask.b) / max(total, 0.001);
	// Полупрозрачные проходы сохраняют газовую дымку вместо чёрного выреза.
	float density = pow(clamp(total, 0.0, 1.0), 0.8);
	COLOR = vec4(color, density * (0.53 + n * 0.42));
}
