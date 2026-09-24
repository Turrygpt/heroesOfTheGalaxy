// Граница нужна только для дальнего неба: ниже неё остаются горы и залив.
float earth_sky_horizon(float x) {
	if (x < 250.0) { return mix(131.0, 90.0, x / 250.0); }
	if (x < 450.0) { return mix(90.0, 75.0, (x - 250.0) / 200.0); }
	if (x < 650.0) { return mix(75.0, 78.0, (x - 450.0) / 200.0); }
	if (x < 850.0) { return mix(78.0, 69.0, (x - 650.0) / 200.0); }
	if (x < 1050.0) { return mix(69.0, 65.0, (x - 850.0) / 200.0); }
	if (x < 1200.0) { return mix(65.0, 44.0, (x - 1050.0) / 150.0); }
	if (x < 1350.0) { return mix(44.0, 12.0, (x - 1200.0) / 150.0); }
	if (x < 1450.0) { return mix(15.0, 8.0, (x - 1350.0) / 100.0); }
	if (x < 1550.0) { return mix(8.0, 22.0, (x - 1450.0) / 100.0); }
	return mix(22.0, 47.0, clamp((x - 1550.0) / 122.0, 0.0, 1.0));
}

float earth_sky_mask(vec2 point, vec3 color, float fort_stage) {
	float ridge = earth_sky_horizon(point.x);
	float height_mask = 1.0 - smoothstep(ridge - 10.0, ridge + 9.0, point.y);
	float blue = smoothstep(-0.018, 0.024, color.b - color.g);
	float green = smoothstep(-0.045, 0.012, color.g - color.r);
	float brightness = smoothstep(0.23, 0.40, max(max(color.r, color.g), color.b));
	float saturation = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
	float natural_color = 1.0 - smoothstep(0.47, 0.64, saturation);
	// Светящиеся обода защитного комплекса близки по цвету к небу.
	float ring_distance = length(vec2((point.x - 520.0) / 77.0, (point.y - 73.0) / 80.0));
	float ring = 1.0 - smoothstep(1.12, 1.25, ring_distance);
	float ring_protection = ring * step(0.5, fort_stage);
	return height_mask * blue * green * brightness * natural_color * (1.0 - ring_protection);
}
