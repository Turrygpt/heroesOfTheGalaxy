// Объёмный амбиент: мягкие края, неоднородная пыль и медленное течение газа.
shader_type canvas_item;
uniform vec4 gas_color : source_color = vec4(0.3, 0.5, 0.8, 1.0);
uniform vec4 accent_color : source_color = vec4(0.5, 0.3, 0.7, 1.0);
uniform float seed_offset = 0.0;
uniform float density = 0.6;
uniform float stretch = 1.0;
uniform float angle = 0.0;
uniform vec2 cloud_size = vec2(100.0);
varying vec2 cloud_uv;
void vertex() { cloud_uv = VERTEX / cloud_size; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + vec2(17.1,9.2); a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = cloud_uv * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.42, 1.0, length(uv));
	vec2 p = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * uv;
	p *= vec2(3.0, 3.0 * stretch);
	p += vec2(seed_offset, TIME * 0.008);
	vec2 warp = vec2(fbm(p + 7.3), fbm(p - 3.8));
	float cloud = fbm(p + warp * 3.5);
	float filaments = smoothstep(0.36, 0.8, cloud);
	vec3 col = mix(gas_color.rgb * 0.18, gas_color.rgb, filaments);
	col = mix(col, accent_color.rgb, smoothstep(0.55, 0.85, cloud) * 0.5);
	COLOR = vec4(col, edge * density * smoothstep(0.18, 0.72, cloud));
}
