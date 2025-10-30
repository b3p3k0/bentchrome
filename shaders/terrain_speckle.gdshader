shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 speckle_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scale : hint_range(2.0, 256.0) = 8.0;

float hash(vec2 p) {
    const vec2 k = vec2(127.1, 311.7);
    return fract(sin(dot(p, k)) * 43758.5453);
}

void fragment() {
    vec2 coord = FRAGCOORD.xy / scale;
    float base_noise = hash(floor(coord));
    float selector = hash(floor(coord) + 37.0);
    float speck = step(1.0 - density, base_noise);
    float signed = selector < 0.5 ? -1.0 : 1.0;
    float blend = speck * signed * intensity;
    vec3 target = speckle_color.rgb;
    vec3 color = base_color.rgb + blend * (target - base_color.rgb);
    COLOR = vec4(clamp(color, 0.0, 1.0), base_color.a);
}
