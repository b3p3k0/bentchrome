shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 speckle_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scale : hint_range(4.0, 128.0) = 32.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 coord = FRAGCOORD.xy / scale;
    float h = hash(floor(coord));
    float mask = step(1.0 - density, h) * intensity;
    vec3 mixed = mix(base_color.rgb, speckle_color.rgb, mask);
    COLOR = vec4(mixed, base_color.a);
}
