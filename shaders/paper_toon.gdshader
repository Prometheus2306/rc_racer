shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(0.92, 0.25, 0.22, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float paper_grain : hint_range(0.0, 0.25) = 0.055;
uniform float grain_scale = 32.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec4 shadow_tint : source_color = vec4(0.46, 0.43, 0.56, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.88;
uniform int pattern_mode = 0; // 0=solid, 1=checkers, 2=stripes, 3=cardboard_ribs, 4=stitching, 5=boost_chevrons
uniform vec4 pattern_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pattern_scale = 1.5;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_tex) {
		vec4 t = texture(albedo_tex, UV);
		base = mix(base, t.rgb, t.a);
	}

	if (pattern_mode == 1) {
		// Checkered finish line / curb pattern
		vec2 c = floor(world_pos.xz * pattern_scale);
		float chk = mod(c.x + c.y, 2.0);
		base = mix(base, pattern_color.rgb, chk);
	} else if (pattern_mode == 2) {
		// Red/white or yellow/black curb stripes
		float s = step(0.5, fract((world_pos.x + world_pos.z) * pattern_scale));
		base = mix(base, pattern_color.rgb, s);
	} else if (pattern_mode == 3) {
		// Corrugated cardboard subtle ribs
		float rib = sin((world_pos.x * 0.7 + world_pos.z * 0.7 + world_pos.y * 2.2) * pattern_scale * 6.28318) * 0.5 + 0.5;
		base *= mix(0.92, 1.06, rib);
	} else if (pattern_mode == 4) {
		// Stitched paper edge dashes on UV border
		vec2 d_edge = min(UV, 1.0 - UV);
		float edge_dist = min(d_edge.x, d_edge.y);
		float on_stitch_line = smoothstep(0.06, 0.045, edge_dist) * smoothstep(0.02, 0.032, edge_dist);
		float dash = step(0.45, fract((UV.x + UV.y) * pattern_scale * 8.0));
		base = mix(base, pattern_color.rgb, on_stitch_line * dash * 0.85);
	} else if (pattern_mode == 5) {
		// Animated boost pad chevrons along local UV
		float chev = fract(UV.y * 3.0 - TIME * 2.8 + abs(UV.x - 0.5) * 1.8);
		float stripe = smoothstep(0.35, 0.42, chev) * (1.0 - smoothstep(0.68, 0.75, chev));
		base = mix(base, pattern_color.rgb, stripe);
	}

	// Construction paper fiber texture
	vec2 gp = world_pos.xz * grain_scale + vec2(world_pos.y * grain_scale * 0.7);
	float n = value_noise(gp) * 0.65 + value_noise(gp * 2.3) * 0.35;
	base *= 1.0 + (n - 0.5) * paper_grain * 2.0;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = clamp(base + vec3(fresnel * rim_strength * 0.2), 0.0, 1.0);
	ROUGHNESS = roughness_val;
	SPECULAR = 0.12;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float stepped = smoothstep(-0.06, 0.05, ndotl) * 0.75 + smoothstep(0.45, 0.55, ndotl) * 0.25;
	float lit = clamp(stepped * ATTENUATION, 0.0, 1.0);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.04, 1.02, 0.99), lit);
	DIFFUSE_LIGHT += shade * (LIGHT_COLOR / PI);
}
