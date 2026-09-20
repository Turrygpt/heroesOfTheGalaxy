shader_type canvas_item;
uniform float haze = 0.0;
void fragment() {
    vec4 pixel = COLOR;
    pixel.rgb = mix(pixel.rgb, vec3(0.68, 0.76, 0.75), haze);
    COLOR = pixel;
}
