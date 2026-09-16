shader_type canvas_item;
// Портреты персонажей нарисованы на чёрном фоне БЕЗ альфы, а китель адмирала
// по яркости почти совпадает с этим фоном (замер: фон ~6, китель ~9 из 255),
// поэтому вырезать фон по яркости нельзя — срежет самого героя. Вместо этого
// гасим края кадра, чтобы чёрная подложка растворялась в затемнённой карте,
// а не висела прямоугольником.
uniform float side_softness : hint_range(0.0, 0.5) = 0.22;
uniform float top_softness : hint_range(0.0, 0.5) = 0.14;
uniform float bottom_softness : hint_range(0.0, 0.6) = 0.30;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fade_x = smoothstep(0.0, side_softness, UV.x) * smoothstep(0.0, side_softness, 1.0 - UV.x);
	float fade_y = smoothstep(0.0, top_softness, UV.y) * smoothstep(0.0, bottom_softness, 1.0 - UV.y);
	COLOR = vec4(tex.rgb, tex.a * fade_x * fade_y * COLOR.a);
}
