shader_type canvas_item;
render_mode unshaded;

uniform vec2 outline[32];
uniform int count = 0;
uniform vec2 canvas_size = vec2(1672.0, 941.0);
uniform float feather = 9.0;
uniform float fort_level = 0.0;

#include "res://shaders/earth_sky_mask.gdshaderinc"

void fragment() {
	vec2 point = UV * canvas_size;
	float distance_to_edge = 10000.0;
	for (int index = 0; index < count; index++) {
		vec2 start = outline[index];
		vec2 end = outline[(index + 1) % count];
		if ((start.y <= 0.0 && end.y <= 0.0) || (start.x <= 0.0 && end.x <= 0.0)
				|| (start.x >= canvas_size.x && end.x >= canvas_size.x)
				|| (start.y >= canvas_size.y && end.y >= canvas_size.y)) {
			continue;
		}
		vec2 edge = end - start;
		float t = clamp(dot(point - start, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
		distance_to_edge = min(distance_to_edge, length(point - start - t * edge));
	}
	COLOR.a *= smoothstep(0.0, feather, distance_to_edge);
	COLOR.a *= 1.0 - earth_sky_mask(point, COLOR.rgb, fort_level);
}
