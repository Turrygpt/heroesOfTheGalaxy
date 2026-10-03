shader_type canvas_item;

uniform float source_horizon = 0.14;
uniform bool foreground = false;

void fragment() {
	// Высота горизонта одинакова у сменных панорам; грунт остаётся плоским.
	vec2 sample_uv = UV;
	sample_uv.y = UV.y < 0.28
		? UV.y * source_horizon / 0.28
		: source_horizon + (UV.y - 0.28) * (1.0 - source_horizon) / 0.72;
	vec4 tex = texture(TEXTURE, sample_uv);
	COLOR = vec4(tex.rgb, tex.a * (foreground ? smoothstep(0.32, 0.42, UV.y) : 1.0));
}
