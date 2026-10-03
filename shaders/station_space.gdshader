shader_type canvas_item;

// Спокойный фон для чтения силуэта станции, без ярких туманностей.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pixel = UV / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(pixel / 86.0);
	vec2 point = fract(pixel / 86.0);
	vec2 center = vec2(hash(cell), hash(cell + 19.0)) * 0.8 + 0.1;
	float star = (1.0 - smoothstep(0.003, 0.018, length(point - center))) * step(0.64, hash(cell + 7.0));
	float glow = exp(-4.0 * dot((UV - vec2(0.53, 0.5)) * vec2(1.1, 1.0), (UV - vec2(0.53, 0.5)) * vec2(1.1, 1.0)));
	vec3 color = mix(vec3(0.014, 0.026, 0.045), vec3(0.04, 0.075, 0.105), glow);
	COLOR = vec4(color + vec3(0.24, 0.31, 0.38) * star, 1.0);
}
