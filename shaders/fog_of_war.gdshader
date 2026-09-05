shader_type canvas_item;

// Второй слой тумана войны глобальной карты (см. fog_overlay.gd).
// TEXTURE - встроенный сэмплер, куда draw_texture_rect кладёт 64x64 маску
// открытых клеток (см. space_strategy_map.gd:_reveal_around): альфа=1 там,
// где клетка ещё не исследована, 0 - там, где уже видели. Читаем только её
// альфу, а цвет берём из pattern_tex - декоративной бесшовной текстуры
// "неизведанного космоса" (см. fog_space_pattern.gd), которая тайлится
// независимо от маски через pattern_repeat.
uniform sampler2D pattern_tex : filter_linear, repeat_enable;
uniform vec2 pattern_repeat = vec2(1.0, 1.0);

void fragment() {
	float covered = texture(TEXTURE, UV).a;
	vec3 pattern = texture(pattern_tex, UV * pattern_repeat).rgb;
	COLOR = vec4(pattern, covered);
}
