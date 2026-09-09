shader_type canvas_item;
render_mode blend_add;

// Лёгкий пост-эффект для нарисованных варп-кораблей: свечение и хроматический край.
void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float energy = max(max(base.r, base.g), base.b) * base.a;
	vec2 center = UV - vec2(0.5);
	float rim = smoothstep(0.18, 0.72, length(center));
	vec3 split = vec3(base.r + energy * rim * 0.18, base.g, base.b + energy * rim * 0.28);
	vec3 glow = split + vec3(0.20, 0.55, 1.0) * energy * 0.20;
	COLOR = vec4(glow, base.a);
}
