shader_type canvas_item;
render_mode unshaded;
uniform float fort_level = 0.0;

#include "res://shaders/earth_sky_mask.gdshaderinc"

void fragment() {
	vec2 point = UV * vec2(1672.0, 941.0);
	COLOR.a *= 1.0 - earth_sky_mask(point, COLOR.rgb, fort_level);
}
