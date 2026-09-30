shader_type canvas_item;
// Slo Mo's shop after hours: the room sits at a low ambient, the overhead
// fixtures pool warm light below themselves, and the player's phone
// flashlight picks out one station. Everything is in 1280x720 canvas pixels.

const int MAX_LAMPS = 4;

uniform vec2 canvas_size = vec2(1280.0, 720.0);
uniform float ambient : hint_range(0.0, 1.0) = 0.25;
// Flashlight: center + radii of the beam ellipse.
uniform vec4 beam = vec4(640.0, 360.0, 160.0, 160.0);
uniform float beam_strength : hint_range(0.0, 1.0) = 1.0;
uniform float beam_gain = 1.2;
uniform vec3 beam_tint : source_color = vec3(0.91, 0.94, 1.0);
uniform float beam_tint_amount : hint_range(0.0, 1.0) = 0.10;
// Fixtures: xy = the fixture, zw = the radii of the pool it throws.
uniform vec4 lamps[MAX_LAMPS];
uniform int lamp_count = 0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.82, 0.55);
uniform float lamp_strength = 0.45;
uniform float lamp_halo = 0.22;
uniform float lamp_halo_radius = 70.0;

float falloff(vec2 point, vec2 center, vec2 radii) {
	float d = length((point - center) / max(radii, vec2(1.0)));
	float f = 1.0 - smoothstep(0.0, 1.0, d);
	return f * f;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 point = UV * canvas_size;

	vec3 room_light = vec3(ambient);
	vec3 halo = vec3(0.0);
	for (int i = 0; i < MAX_LAMPS; i++) {
		if (i >= lamp_count) {
			break;
		}
		vec4 lamp = lamps[i];
		// The pool hangs a little below the fixture: light falls, it doesn't rise.
		vec2 pool_center = lamp.xy + vec2(0.0, lamp.w * 0.45);
		room_light += lamp_color * lamp_strength * falloff(point, pool_center, lamp.zw);
		halo += lamp_color * lamp_halo * falloff(point, lamp.xy, vec2(lamp_halo_radius));
	}
	vec3 room = source.rgb * room_light;

	float d = length((point - beam.xy) / max(beam.zw, vec2(1.0)));
	float core = 1.0 - smoothstep(0.72, 1.08, d);
	float spill = 0.30 * (1.0 - smoothstep(1.0, 1.9, d));
	float lit_amount = clamp(core + spill, 0.0, 1.0) * beam_strength;
	vec3 lit = mix(source.rgb * beam_gain, beam_tint, beam_tint_amount);

	COLOR = vec4(mix(room, lit, lit_amount) + halo, source.a);
}
