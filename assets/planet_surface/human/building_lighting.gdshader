shader_type canvas_item;

uniform float fog_amount : hint_range(0.0, 0.4) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);

	// Солнце находится справа сверху: левая и нижняя части здания холоднее и темнее.
	float away_from_light = clamp((1.0 - UV.x) * 0.62 + UV.y * 0.38, 0.0, 1.0);
	float self_shadow = smoothstep(0.18, 0.95, away_from_light) * 0.22;
	vec3 shadow_tint = vec3(0.62, 0.73, 0.86);
	source.rgb *= mix(vec3(1.0), shadow_tint, self_shadow);

	// Очень слабый холодный блик на стороне, обращённой к солнцу.
	float sunlight = smoothstep(0.48, 1.0, UV.x * (1.0 - UV.y));
	source.rgb += vec3(0.045, 0.055, 0.065) * sunlight * source.a;

	// Чем выше здание на панораме, тем сильнее оно растворяется в воздушной перспективе.
	vec3 atmospheric_color = vec3(0.61, 0.76, 0.86);
	source.rgb = mix(source.rgb, atmospheric_color, fog_amount * source.a);
	source.a *= 1.0 - fog_amount * 0.16;
	COLOR = source * COLOR;
}
