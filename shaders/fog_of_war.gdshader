shader_type canvas_item;

// Чёрная маска полностью закрывает неизвестное, синяя полупрозрачная
// оставляет видимой память карты. Прозрачная маска — текущий обзор.
uniform sampler2D pattern_tex : filter_linear, repeat_enable;
uniform vec2 pattern_repeat = vec2(1.0, 1.0);

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	vec3 pattern = texture(pattern_tex, UV * pattern_repeat).rgb;
	float unexplored = clamp((mask.a - 0.52) / 0.48, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.08, 0.14, 0.22), pattern, unexplored), mask.a);
}
