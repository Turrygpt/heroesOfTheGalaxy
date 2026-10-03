shader_type canvas_item;

// Дальний рельеф и площадка плавно сходятся без горизонтального шва.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * smoothstep(0.18, 0.32, UV.y));
}
