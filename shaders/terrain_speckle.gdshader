shader_type canvas_item;
// Procedural speckle in WORLD space (screen-space FRAGCOORD swims with the
// camera). shimmer > 0 animates speck brightness — water sparkle.

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 speckle_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scale : hint_range(2.0, 256.0) = 8.0;
uniform float shimmer : hint_range(0.0, 4.0) = 0.0;

// Weather is opt-in per material. The rings are world-anchored, sparse, and
// purely cosmetic; RainSquall owns the streaks while wet terrain owns splashes.
uniform bool rain_ripples = false;
uniform float rain_ripple_strength : hint_range(0.0, 0.25) = 0.0;

// Opt-in relief for DriveableHill. Ordinary terrain materials leave this off
// and remain byte-for-byte equivalent in the fragment path below.
uniform bool relief_enabled = false;
uniform vec2 relief_summit_half = vec2(448.0);
uniform float relief_grade_half = 120.0;
uniform float relief_strength : hint_range(0.0, 0.4) = 0.22;
uniform float relief_projection : hint_range(1.0, 2.0) = 1.55;
uniform float relief_slope_darkening : hint_range(0.0, 0.2) = 0.06;
uniform vec2 relief_light_dir = vec2(-0.70710678, -0.70710678);
uniform float relief_crest : hint_range(0.0, 0.2) = 0.10;
uniform float relief_crest_width : hint_range(1.0, 64.0) = 18.0;
uniform float relief_foot : hint_range(0.0, 0.2) = 0.12;
uniform float relief_foot_width : hint_range(1.0, 64.0) = 20.0;

varying vec2 world_pos;
varying vec2 local_pos;

float hash(vec2 p) {
    const vec2 k = vec2(127.1, 311.7);
    return fract(sin(dot(p, k)) * 43758.5453);
}

void vertex() {
    local_pos = VERTEX;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 speckle_at(vec2 sample_pos) {
    vec2 cell = floor(sample_pos / scale);
    float base_noise = hash(cell);
    float selector = hash(cell + 37.0);
    float speck = step(1.0 - density, base_noise);
    float dir = selector < 0.5 ? -1.0 : 1.0;
    float wobble = 1.0;
    if (shimmer > 0.0) {
        wobble = 0.5 + 0.5 * sin(TIME * shimmer + hash(cell + 91.0) * 6.28318);
    }
    float blend = speck * dir * intensity * wobble;
    return clamp(base_color.rgb + blend * (speckle_color.rgb - base_color.rgb), 0.0, 1.0);
}

void fragment() {
    vec3 color = speckle_at(world_pos);
    if (relief_enabled) {
        vec2 outside = max(abs(local_pos) - relief_summit_half, vec2(0.0));
        // On cardinal faces one component grows to grade_half. On a clipped
        // corner their SUM does, so this is one continuous eight-face metric.
        float slope_dist = outside.x + outside.y;
        float slope_t = clamp(slope_dist / max(relief_grade_half, 0.001), 0.0, 1.0);
        if (slope_dist > 0.001) {
            vec2 downhill = normalize(sign(local_pos) * outside);
            vec2 projected_pos = world_pos
                + downhill * slope_dist * (relief_projection - 1.0);
            color = mix(color, speckle_at(projected_pos), smoothstep(0.0, 1.0, slope_t));
            color *= 1.0 - relief_slope_darkening * smoothstep(0.0, 1.0, slope_t);

            float directional = dot(downhill, normalize(relief_light_dir));
            color *= 1.0 + directional * relief_strength * slope_t;

            float crest_band = 1.0 - smoothstep(0.0, relief_crest_width, slope_dist);
            float foot_band = smoothstep(max(relief_grade_half - relief_foot_width, 0.0),
                relief_grade_half, slope_dist);
            color += vec3(relief_crest * crest_band);
            color *= 1.0 - relief_foot * foot_band;
        }
    }
	if (rain_ripples) {
		vec2 rain_cell = floor(world_pos / 96.0);
		vec2 jitter = vec2(hash(rain_cell + 17.0), hash(rain_cell + 53.0));
		vec2 center = (rain_cell + jitter) * 96.0;
		float phase = fract(TIME * 0.72 + hash(rain_cell + 113.0));
		float radius = phase * 38.0;
		float dist = length(world_pos - center);
		float ring = 1.0 - smoothstep(1.2, 3.8, abs(dist - radius));
		color += vec3(0.32, 0.42, 0.52) * ring * (1.0 - phase) * rain_ripple_strength;
	}
    COLOR = vec4(clamp(color, 0.0, 1.0), base_color.a);
}
