shader_type canvas_item;
// Две локальные туманности на чистом звёздном фоне, без полос через весь экран.
uniform sampler2D nebula_tex : repeat_enable, filter_linear_mipmap;
float hash_21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float nebula(vec2 local, vec2 offset) {
	float broad = texture(nebula_tex, local * vec2(0.14, 0.28) + offset).r;
	float detail = texture(nebula_tex, local * vec2(0.44, 0.88) + offset + broad * 0.08).r;
	float envelope = exp(-dot(local, local) * 2.2);
	return envelope * smoothstep(0.30, 0.72, broad * 0.65 + detail * 0.35);
}
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = UV * vec2(aspect, 1.0);
	vec2 left = (p - vec2(0.16 * aspect, 0.35)) / vec2(0.32, 0.23);
	vec2 right = (p - vec2(0.78 * aspect, 0.28)) / vec2(0.30, 0.20);
	left = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * left;
	right = mat2(vec2(0.87, -0.50), vec2(0.50, 0.87)) * right;
	vec3 color = vec3(0.002, 0.005, 0.012);
	color += vec3(0.22, 0.12, 0.28) * nebula(left, vec2(0.12, 0.32));
	color += vec3(0.07, 0.23, 0.39) * nebula(right, vec2(0.63, 0.17));
	// У каждой звезды своя фаза; мерцание меняет яркость лишь на 6%.
	vec2 grid = p * 95.0;
	vec2 cell = floor(grid);
	float n = hash_21(cell);
	vec2 offset = vec2(hash_21(cell + 13.1), hash_21(cell + 47.2)) - 0.5;
	vec2 delta = fract(grid) - 0.5 - offset * 0.70;
	float radius = max(mix(0.025, 0.065, n), fwidth(grid.x) * 0.55);
	float star = exp(-dot(delta, delta) / (radius * radius)) * step(0.935, n);
	float twinkle = 0.94 + 0.06 * sin(TIME * (0.45 + n * 0.55) + n * 91.0);
	vec3 tint = mix(vec3(0.61, 0.78, 1.0), vec3(1.0, 0.90, 0.76), hash_21(cell + 8.7));
	color += tint * star * mix(0.26, 0.95, hash_21(cell + 6.4)) * twinkle;
	COLOR = vec4(color, 1.0);
}
