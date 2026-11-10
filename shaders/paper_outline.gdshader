shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.14, 0.11, 0.10, 1.0);
uniform float outline_width : hint_range(0.0, 0.15) = 0.032;

void vertex() {
	// Push smooth/box normals slightly outward for crisp cartoon ink border
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
