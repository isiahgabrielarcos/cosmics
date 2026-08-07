shader_type canvas_item;

// Sibling of glare_sweep.gdshader. Same sweeping band, same luminance mask —
// but the bright pixels actually GLOW rather than just being brightened.
//
// The difference is where the light ends up. glare_sweep adds light to a
// pixel based on that pixel's own brightness, so nothing ever escapes the
// shape. Here each fragment instead *gathers* brightness from the texels
// around it, which means a white pixel throws light onto its darker
// neighbours and out past the silhouette into the transparent padding. That
// spill is what reads as a glow.
//
// Two things follow from that, and both matter:
//
//   1. The halo has to raise ALPHA, not just colour. A fragment outside the
//      artwork has alpha 0, and adding colour to a fully transparent pixel is
//      invisible. So the gathered light contributes alpha of its own and the
//      result is composited manually.
//
//   2. The halo is clipped to the node's own rectangle. It can only draw
//      where the node draws. If a sprite is cropped tight to its art the glow
//      will cut off at the edge — give the texture a few px of transparent
//      padding, or scale the node up slightly, to give it room to bleed into.
//
// For genuine engine bloom on top of this, turn glow on in a WorldEnvironment
// and raise `hdr_boost` above 1.0 — that pushes the halo past white into HDR
// where the glow pass can find it. It looks good standalone without that.

// ── Look ─────────────────────────────────────────────────────────────────────
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Which pixels emit. Same meaning as glare_sweep's luma_threshold/softness.
uniform float luma_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float luma_softness : hint_range(0.01, 1.0) = 0.22;

// How far the light spreads, in texels of the source image. This is the knob
// that decides whether it reads as a sheen or a lamp.
uniform float glow_radius : hint_range(0.0, 64.0) = 10.0;

// Glow that is always on, and the extra the sweeping band adds as it passes.
// Set sweep_glow to 0 for a steady lamp; set base_glow to 0 to only glow
// while the band crosses.
uniform float base_glow : hint_range(0.0, 4.0) = 0.6;
uniform float sweep_glow : hint_range(0.0, 4.0) = 1.4;

// How much of the halo turns into opacity outside the artwork. Lower it if
// the glow looks like fog rather than light.
uniform float halo_opacity : hint_range(0.0, 2.0) = 0.85;

// Extra brightening applied to pixels that are already lit, so the source of
// the glow stays hotter than its halo.
uniform float core_boost : hint_range(0.0, 4.0) = 0.8;

// Push the result above 1.0 for a WorldEnvironment glow pass to pick up.
// 1.0 = no HDR, purely in-shader.
uniform float hdr_boost : hint_range(1.0, 8.0) = 1.0;

// ── Sweep (identical to glare_sweep) ─────────────────────────────────────────
uniform float angle_degrees : hint_range(-180.0, 180.0) = 35.0;
uniform float band_width : hint_range(0.01, 1.0) = 0.18;
uniform float band_sharpness : hint_range(0.5, 8.0) = 2.0;
uniform float period : hint_range(0.1, 20.0) = 4.0;
uniform float sweep_fraction : hint_range(0.05, 1.0) = 0.35;
uniform float phase_offset : hint_range(0.0, 20.0) = 0.0;
uniform bool screen_space = false;

// Gather pattern. 3 rings x 8 taps = 24 samples — enough for a smooth falloff
// without the cost of a real blur. Loop bounds must be compile-time constants.
const int RINGS = 3;
const int TAPS = 8;
// Offsets each ring's taps so the samples don't line up into visible spokes.
const float SPIRAL = 0.618;


// How much light a texel emits, given its already-sampled colour: luminance
// past the threshold, gated by alpha so transparent padding isn't read as
// "dark". Takes the sample rather than the sampler — passing TEXTURE into a
// function trips an engine assertion about custom samplers.
float emission_of(vec4 t) {
	float luma = dot(t.rgb, vec3(0.2126, 0.7152, 0.0722));
	return smoothstep(luma_threshold, luma_threshold + luma_softness, luma) * t.a;
}


void fragment() {
	vec4 base = COLOR;

	// ── Sweep band ───────────────────────────────────────────────────────────
	vec2 dir = vec2(cos(radians(angle_degrees)), sin(radians(angle_degrees)));
	vec2 suv = screen_space ? SCREEN_UV : UV;
	float half_extent = 0.5 * (abs(dir.x) + abs(dir.y));
	float proj = (dot(suv - vec2(0.5), dir) + half_extent) / (2.0 * half_extent);

	float t = fract((TIME + phase_offset) / period);
	float travel = t / sweep_fraction;
	float head = mix(-band_width, 1.0 + band_width, travel);
	float band = 1.0 - smoothstep(0.0, 1.0, abs(proj - head) / band_width);
	band = pow(band, band_sharpness);

	float strength = base_glow + sweep_glow * band;

	// ── Gather surrounding light ─────────────────────────────────────────────
	// Rings weighted so nearer samples count for more, which is what gives the
	// halo a falloff instead of a flat disc.
	float halo = 0.0;
	float weight_sum = 0.0;
	for (int r = 1; r <= RINGS; r++) {
		float ring = float(r) / float(RINGS);
		float radius = glow_radius * ring;
		float w = 1.0 - ring * 0.75;
		for (int i = 0; i < TAPS; i++) {
			float a = TAU * float(i) / float(TAPS) + float(r) * SPIRAL;
			vec2 offset = vec2(cos(a), sin(a)) * radius * TEXTURE_PIXEL_SIZE;
			halo += emission_of(texture(TEXTURE, UV + offset)) * w;
			weight_sum += w;
		}
	}
	halo /= max(weight_sum, 0.0001);

	// The fragment's own emission, kept separate so the source stays brighter
	// than what it throws.
	float core = emission_of(texture(TEXTURE, UV));

	// ── Composite ────────────────────────────────────────────────────────────
	// Worked in premultiplied space: light adds linearly there, and the halo
	// can raise alpha where the artwork has none.
	vec3 light = glow_color.rgb * hdr_boost * strength;
	vec3 added = light * (halo * halo_opacity + core * core_boost);

	float glow_alpha = clamp(halo * halo_opacity * strength, 0.0, 1.0);
	float out_alpha = clamp(max(base.a, glow_alpha), 0.0, 1.0);

	vec3 premul = base.rgb * base.a + added;
	COLOR = vec4(premul / max(out_alpha, 0.0001), out_alpha);
}
