shader_type canvas_item;

// Тёмный кант отделяет прозрачный силуэт героя от детальной панорамы города.
// Ширина задана в пикселях исходного портрета: после уменьшения это даёт
// аккуратную линию примерно в один экранный пиксель.
uniform vec4 outline_color : source_color = vec4(0.025, 0.055, 0.075, 0.96);
uniform float outline_width : hint_range(1.0, 12.0) = 7.0;
uniform vec3 portrait_light = vec3(1.08, 1.04, 1.0);
// В узкой карточке показываем верхние 37% вертикального портрета: лицо,
// шею и плечи. Это почти точно совпадает с пропорциями рамки 1.8:1 и поэтому
// не растягивает черты лица.
uniform float crop_height : hint_range(0.25, 1.0) = 0.37;
uniform float crop_top : hint_range(0.0, 0.3) = 0.0;

void fragment() {
	vec2 portrait_uv = vec2(UV.x, crop_top + UV.y * crop_height);
	vec4 portrait = texture(TEXTURE, portrait_uv);
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_width;
	float around = 0.0;
	around = max(around, texture(TEXTURE, portrait_uv + vec2(step_size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, portrait_uv - vec2(step_size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, portrait_uv + vec2(0.0, step_size.y)).a);
	around = max(around, texture(TEXTURE, portrait_uv - vec2(0.0, step_size.y)).a);
	around = max(around, texture(TEXTURE, portrait_uv + step_size).a);
	around = max(around, texture(TEXTURE, portrait_uv - step_size).a);
	around = max(around, texture(TEXTURE, portrait_uv + vec2(step_size.x, -step_size.y)).a);
	around = max(around, texture(TEXTURE, portrait_uv + vec2(-step_size.x, step_size.y)).a);

	float outline_alpha = max(around - portrait.a, 0.0) * outline_color.a;
	portrait.rgb *= portrait_light;
	COLOR = portrait + vec4(outline_color.rgb, outline_alpha) * (1.0 - portrait.a);
}
