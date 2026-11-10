shader_type spatial;
render_mode specular_toon;

uniform vec4 shallow_color : source_color = vec4(0.32, 0.76, 0.95, 1.0);
uniform vec4 deep_color : source_color = vec4(0.16, 0.52, 0.84, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.98, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 1.6 + TIME * 2.2) * 0.025 + cos(wpos.z * 1.9 - TIME * 1.8) * 0.025;
}

void fragment() {
	float wave1 = sin(wpos.x * 2.1 + TIME * 2.0 + cos(wpos.z * 1.7)) * 0.5 + 0.5;
	float wave2 = cos(wpos.z * 2.6 - TIME * 1.6 + sin(wpos.x * 1.9)) * 0.5 + 0.5;
	float mix_v = smoothstep(0.25, 0.75, (wave1 + wave2) * 0.5);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, mix_v);

	// Paper-cutout white sparkle bands
	float sparkle = step(0.86, (wave1 * wave2));
	// Shoreline foam near UV border
	vec2 edge_d = min(UV, 1.0 - UV);
	float border = 1.0 - smoothstep(0.03, 0.075 + 0.015 * sin(TIME * 3.0 + wpos.x * 3.0), min(edge_d.x, edge_d.y));
	col = mix(col, foam_color.rgb, clamp(sparkle * 0.75 + border, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.45;
}
