shader_type canvas_item;
render_mode unshaded;
uniform vec2 outline[32];
uniform int count = 0;
uniform vec2 canvas_size = vec2(1881.0, 836.0);
uniform float feather = 9.0;
void fragment() {
    vec2 p = UV * canvas_size;
    float distance_to_edge = 10000.0;
    for (int i = 0; i < count; i++) {
        vec2 a = outline[i];
        vec2 b = outline[(i + 1) % count];
        if ((a.y <= 0.0 && b.y <= 0.0) || (a.x <= 0.0 && b.x <= 0.0) || (a.x >= canvas_size.x && b.x >= canvas_size.x) || (a.y >= canvas_size.y && b.y >= canvas_size.y)) { continue; }
        vec2 edge = b - a;
        float t = clamp(dot(p - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
        distance_to_edge = min(distance_to_edge, length(p - a - t * edge));
    }
    COLOR.a *= smoothstep(0.0, feather, distance_to_edge);
}
