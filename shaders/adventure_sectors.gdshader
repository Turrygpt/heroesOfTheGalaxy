// Цветовая карта биомов непрерывна; плотные берега и газ берутся из геометрии.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D palette : source_color, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 80.0;
	vec2 drift = vec2(noise(p * 0.25), noise(p * 0.25 + 23.8)) - 0.5;
	float n = noise(p + drift * 3.0 + vec2(TIME * 0.012, 0.0)) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
	vec3 mask = texture(TEXTURE, UV + drift * 0.004).rgb;
	vec3 tint = texture(palette, UV).rgb;
	vec3 dust = tint * (0.25 + n * 0.7);
	vec3 gas = mix(vec3(0.12, 0.31, 0.5), vec3(0.38, 0.77, 0.85), n);
	float gas_ratio = clamp(mask.b * 1.8, 0.0, 1.0);
	vec3 color = mix(dust, gas, gas_ratio);
	float ambient = smoothstep(0.4, 0.8, n) * 0.18;
	float opacity = clamp(mask.r * 0.82 + mask.b * 0.8 + ambient, 0.0, 0.88);
	COLOR = vec4(color, opacity);
}
