shader_type canvas_item;

// A band of light that sweeps across a canvas item and only lights up its
// bright pixels, so a static panel or sprite reads as a polished surface
// catching a reflection instead of a flat image.
//
// The band travels edge to edge once per `period`, taking `sweep_fraction` of
// it — the rest of the period is the gap before the next pass. Which pixels
// catch it is decided by luminance: everything at or below `luma_threshold`
// stays dark, so white trim flares while mid-tones only glint.
//
// Deliberately never references MODULATE: leaving it alone lets the renderer
// apply the node's modulate to the finished colour, so fading a panel out
// fades its glare with it.

uniform vec4 glare_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.9;

// Which pixels catch the light. `luma_softness` is the band above the
// threshold over which they fade in — widen it for a softer, dirtier shine.
uniform float luma_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float luma_softness : hint_range(0.01, 1.0) = 0.22;

// Sweep geometry. 0 degrees runs left to right, 90 bottom to top.
uniform float angle_degrees : hint_range(-180.0, 180.0) = 35.0;
uniform float band_width : hint_range(0.01, 1.0) = 0.18;
// Higher = a tighter, harder-edged streak. Lower = a broad wash.
uniform float band_sharpness : hint_range(0.5, 8.0) = 2.0;

uniform float period : hint_range(0.1, 20.0) = 4.0;
uniform float sweep_fraction : hint_range(0.05, 1.0) = 0.35;
// Stagger materials that share a screen so they don't all flash together.
uniform float phase_offset : hint_range(0.0, 20.0) = 0.0;

// Project the sweep across the whole screen instead of this item's own UV.
// Needed for NinePatchRect (9-slice warps UV at the margins) and Labels (UV
// is per-glyph), and it lets one pass travel across several nodes at once.
uniform bool screen_space = false;

void fragment() {
	vec4 base = COLOR;

	vec2 dir = vec2(cos(radians(angle_degrees)), sin(radians(angle_degrees)));
	vec2 uv = screen_space ? SCREEN_UV : UV;

	// Normalising by the projected half-extent keeps 0..1 spanning the item
	// whatever the angle, so band_width means the same thing in every
	// direction instead of shrinking on the diagonals.
	float half_extent = 0.5 * (abs(dir.x) + abs(dir.y));
	float proj = (dot(uv - vec2(0.5), dir) + half_extent) / (2.0 * half_extent);

	// Band starts just off one edge and finishes just off the other, so it
	// enters and leaves cleanly rather than popping in at full width.
	float t = fract((TIME + phase_offset) / period);
	float travel = t / sweep_fraction;
	float head = mix(-band_width, 1.0 + band_width, travel);
	float band = 1.0 - smoothstep(0.0, 1.0, abs(proj - head) / band_width);
	band = pow(band, band_sharpness);

	float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	float mask = smoothstep(luma_threshold, luma_threshold + luma_softness, luma);

	// base.a keeps the glare inside the artwork instead of bleeding into the
	// transparent padding around it.
	COLOR.rgb += glare_color.rgb * (band * mask * intensity * base.a);
}
