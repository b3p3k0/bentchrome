shader_type canvas_item;
// Procedural speckle in WORLD space (screen-space FRAGCOORD swims with the
// camera). shimmer > 0 animates speck brightness — water sparkle.

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 speckle_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scale : hint_range(2.0, 256.0) = 8.0;
uniform float shimmer : hint_range(0.0, 4.0) = 0.0;

varying vec2 world_pos;

float hash(vec2 p) {
    const vec2 k = vec2(127.1, 311.7);
    return fract(sin(dot(p, k)) * 43758.5453);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec2 cell = floor(world_pos / scale);
    float base_noise = hash(cell);
    float selector = hash(cell + 37.0);
    float speck = step(1.0 - density, base_noise);
    float dir = selector < 0.5 ? -1.0 : 1.0;
    float wobble = 1.0;
    if (shimmer > 0.0) {
        wobble = 0.5 + 0.5 * sin(TIME * shimmer + hash(cell + 91.0) * 6.28318);
    }
    float blend = speck * dir * intensity * wobble;
    vec3 color = base_color.rgb + blend * (speckle_color.rgb - base_color.rgb);
    COLOR = vec4(clamp(color, 0.0, 1.0), base_color.a);
}
