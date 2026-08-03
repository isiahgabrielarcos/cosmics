shader_type sky;

// Wraps the level-selection skybox in a colour gradient plus a star field,
// both layered additively over black so the world environment itself stays
// black and only these two textures light it up.

uniform sampler2D gradient_tex : source_color, filter_linear;
uniform sampler2D stars_tex : source_color, filter_linear, repeat_enable;

uniform float gradient_strength : hint_range(0.0, 2.0) = 0.55;
uniform float stars_strength : hint_range(0.0, 2.0) = 0.9;
uniform float stars_tiling : hint_range(1.0, 8.0) = 2.0;
// Pushes the gradient toward the horizon so it reads as a landscape band
// rather than a flat wash over the whole dome.
uniform float horizon_bias : hint_range(0.1, 4.0) = 1.35;

void sky() {
	vec3 d = normalize(EYEDIR);

	// Equirectangular projection: x wraps the full 360 degrees around the
	// horizon, y runs pole to pole.
	float u = atan(d.x, d.z) / (2.0 * PI) + 0.5;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;

	vec3 gradient = texture(gradient_tex, vec2(u, pow(v, horizon_bias))).rgb;
	vec3 stars = texture(stars_tex, vec2(u, v) * stars_tiling).rgb;

	COLOR = gradient * gradient_strength + stars * stars_strength;
}
