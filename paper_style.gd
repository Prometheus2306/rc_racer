class_name PaperStyle
extends RefCounted

# --- Paper Mario Craft Color Palette ---
const INK_DARK := Color(0.14, 0.11, 0.10, 1.0)
const PAPER_WHITE := Color(0.99, 0.97, 0.93, 1.0)
const TAPE_CREAM := Color(0.96, 0.91, 0.78, 1.0)
const CARDBOARD_TAN := Color(0.81, 0.61, 0.39, 1.0)
const CARDBOARD_DARK := Color(0.63, 0.44, 0.26, 1.0)
const WOOD_PLANK := Color(0.85, 0.65, 0.42, 1.0)
const GRASS_LIGHT := Color(0.42, 0.80, 0.38, 1.0)
const GRASS_MID := Color(0.32, 0.71, 0.34, 1.0)
const GRASS_DARK := Color(0.22, 0.56, 0.28, 1.0)
const SAND_LIGHT := Color(0.95, 0.82, 0.50, 1.0)
const SAND_MID := Color(0.87, 0.70, 0.38, 1.0)
const ROAD_SLATE := Color(0.37, 0.39, 0.45, 1.0)
const ROAD_SAND := Color(0.76, 0.58, 0.38, 1.0)
const SKY_BLUE := Color(0.64, 0.86, 0.99, 1.0)

const CAR_PAINTS: Array[Dictionary] = [
	{"name": "Flitzer-Rot", "color": Color(0.93, 0.23, 0.20), "accent": Color(1.0, 0.88, 0.25)},
	{"name": "Wiesen-Grün", "color": Color(0.22, 0.74, 0.32), "accent": Color(0.98, 0.97, 0.92)},
	{"name": "Sonnen-Gelb", "color": Color(0.99, 0.78, 0.14), "accent": Color(0.90, 0.22, 0.18)},
	{"name": "Himmel-Blau", "color": Color(0.20, 0.55, 0.95), "accent": Color(1.0, 0.84, 0.20)},
	{"name": "Pfirsich-Pink", "color": Color(0.96, 0.43, 0.66), "accent": Color(0.99, 0.96, 0.88)},
	{"name": "Turbo-Orange", "color": Color(0.96, 0.48, 0.15), "accent": Color(0.18, 0.20, 0.26)},
]

static var _toon_shader: Shader = null
static var _outline_shader: Shader = null
static var _water_shader: Shader = null
static var _mat_cache: Dictionary = {}
static var _sticker_cache: Dictionary = {}


static func _ensure_shaders() -> void:
	if _toon_shader == null:
		_toon_shader = load("res://shaders/paper_toon.gdshader")
	if _outline_shader == null:
		_outline_shader = load("res://shaders/paper_outline.gdshader")
	if _water_shader == null:
		_water_shader = load("res://shaders/water_foil.gdshader")


static func make_paper_mat(
	color: Color,
	with_outline: bool = false,
	outline_width: float = 0.03,
	pattern_mode: int = 0,
	pattern_color: Color = PAPER_WHITE,
	pattern_scale: float = 1.5
) -> ShaderMaterial:
	_ensure_shaders()
	var key := "%s_%s_%.3f_%d_%s_%.2f" % [
		color.to_html(), str(with_outline), outline_width,
		pattern_mode, pattern_color.to_html(), pattern_scale
	]
	if _mat_cache.has(key):
		return _mat_cache[key]

	var mat := ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("pattern_mode", pattern_mode)
	mat.set_shader_parameter("pattern_color", pattern_color)
	mat.set_shader_parameter("pattern_scale", pattern_scale)

	if with_outline and _outline_shader != null:
		var out_mat := ShaderMaterial.new()
		out_mat.shader = _outline_shader
		out_mat.set_shader_parameter("outline_color", INK_DARK)
		out_mat.set_shader_parameter("outline_width", outline_width)
		mat.next_pass = out_mat

	_mat_cache[key] = mat
	return mat


static func make_water_mat() -> ShaderMaterial:
	_ensure_shaders()
	if _mat_cache.has("__water_foil__"):
		return _mat_cache["__water_foil__"]
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	_mat_cache["__water_foil__"] = mat
	return mat


# --- 2D SDF Helpers for Die-Cut Paper Mario Stickers ---
static func _sd_circle(p: Vector2, c: Vector2, r: float) -> float:
	return p.distance_to(c) - r


static func _sd_box(p: Vector2, c: Vector2, b: Vector2, radius: float = 0.0) -> float:
	var d := (p - c).abs() - b
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) - radius


static func _sd_segment(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
	return (pa - ba * h).length() - r


static func _sd_triangle_up(p: Vector2, center: Vector2, half_w: float, half_h: float) -> float:
	# Upright isosceles triangle centered at center (tip at center.y - half_h, base at center.y + half_h)
	var q := p - center
	var ax := absf(q.x)
	# Normalized slope from tip (0, -half_h) to base corner (half_w, half_h)
	var t := clampf((q.y + half_h) / maxf(2.0 * half_h, 0.001), 0.0, 1.0)
	var half_span := half_w * t
	var dx := ax - half_span
	var dy := maxf(-half_h - q.y, q.y - half_h)
	if dx <= 0.0 and dy <= 0.0:
		return maxf(dx * 0.85, dy)
	return Vector2(maxf(dx * 0.85, 0.0), maxf(dy, 0.0)).length()


static func get_sticker_texture(kind: String, primary: Color = GRASS_LIGHT) -> ImageTexture:
	var key := "%s_%s" % [kind, primary.to_html()]
	if _sticker_cache.has(key):
		return _sticker_cache[key]

	var sz := 88
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)

	for py in range(sz):
		var uy := (float(py) / float(sz - 1)) * 2.0 - 1.0
		for px in range(sz):
			var ux := (float(px) / float(sz - 1)) * 2.0 - 1.0
			var p := Vector2(ux, uy)
			var col := _eval_sticker_pixel(kind, p, primary)
			img.set_pixel(px, py, col)

	var tex := ImageTexture.create_from_image(img)
	_sticker_cache[key] = tex
	return tex


static func _eval_sticker_pixel(kind: String, p: Vector2, primary: Color) -> Color:
	var d := 10.0
	var fill := primary

	match kind:
		"tree_round":
			var d_trunk := _sd_box(p, Vector2(0.0, 0.46), Vector2(0.13, 0.30), 0.03)
			var d_c1 := _sd_circle(p, Vector2(0.0, -0.18), 0.42)
			var d_c2 := _sd_circle(p, Vector2(-0.26, 0.04), 0.30)
			var d_c3 := _sd_circle(p, Vector2(0.26, 0.04), 0.30)
			var d_canopy := minf(d_c1, minf(d_c2, d_c3))
			d = minf(d_trunk, d_canopy)
			if d_canopy <= d_trunk:
				fill = primary.lightened(0.08) if p.y < -0.15 else primary
				# Cute Paper Mario leaf highlight dots
				if _sd_circle(p, Vector2(-0.14, -0.30), 0.08) < 0.0:
					fill = primary.lightened(0.26)
			else:
				fill = Color(0.58, 0.38, 0.22)

		"tree_pine":
			var d_trunk := _sd_box(p, Vector2(0.0, 0.56), Vector2(0.12, 0.20), 0.02)
			var t1 := _sd_triangle_up(p, Vector2(0.0, -0.36), 0.36, 0.28)
			var t2 := _sd_triangle_up(p, Vector2(0.0, -0.06), 0.48, 0.30)
			var t3 := _sd_triangle_up(p, Vector2(0.0, 0.24), 0.58, 0.28)
			var d_foliage := minf(t1, minf(t2, t3))
			d = minf(d_trunk, d_foliage)
			if d_foliage <= d_trunk:
				if t1 < 0.02:
					fill = primary.lightened(0.14)
				elif t2 < 0.02:
					fill = primary
				else:
					fill = primary.darkened(0.10)
			else:
				fill = Color(0.55, 0.36, 0.20)

		"bush":
			var b1 := _sd_circle(p, Vector2(0.0, 0.10), 0.38)
			var b2 := _sd_circle(p, Vector2(-0.34, 0.24), 0.28)
			var b3 := _sd_circle(p, Vector2(0.34, 0.24), 0.28)
			var flat_cut := p.y - 0.48
			d = maxf(minf(b1, minf(b2, b3)), -flat_cut - 1.0)
			if p.y > 0.50:
				d = maxf(d, p.y - 0.50)
			fill = primary.lightened(0.10) if p.y < 0.08 else primary
			if _sd_circle(p, Vector2(-0.20, 0.16), 0.06) < 0.0 or _sd_circle(p, Vector2(0.22, 0.22), 0.06) < 0.0 or _sd_circle(p, Vector2(0.04, -0.04), 0.06) < 0.0:
				fill = Color(0.95, 0.30, 0.32)

		"flower":
			var stem := _sd_box(p, Vector2(0.0, 0.38), Vector2(0.06, 0.34), 0.02)
			var center_d := _sd_circle(p, Vector2(0.0, -0.14), 0.18)
			var petals := 10.0
			for i in range(6):
				var ang := float(i) * TAU / 6.0
				var pc := Vector2(cos(ang), sin(ang)) * 0.24 + Vector2(0.0, -0.14)
				petals = minf(petals, _sd_circle(p, pc, 0.15))
			d = minf(stem, minf(center_d, petals))
			if center_d < 0.0:
				fill = Color(1.0, 0.84, 0.16)
				# Happy little Paper Mario eyes!
				if _sd_circle(p, Vector2(-0.05, -0.16), 0.028) < 0.0 or _sd_circle(p, Vector2(0.05, -0.16), 0.028) < 0.0:
					fill = INK_DARK
			elif petals <= stem:
				fill = primary
			else:
				fill = GRASS_MID

		"cloud":
			var c1 := _sd_circle(p, Vector2(0.0, 0.02), 0.34)
			var c2 := _sd_circle(p, Vector2(-0.32, 0.12), 0.25)
			var c3 := _sd_circle(p, Vector2(0.32, 0.12), 0.25)
			var base_b := _sd_box(p, Vector2(0.0, 0.18), Vector2(0.34, 0.16), 0.06)
			d = minf(minf(c1, c2), minf(c3, base_b))
			fill = Color(0.99, 0.99, 1.0)
			if p.y > 0.20:
				fill = Color(0.89, 0.94, 0.99)
			if _sd_circle(p, Vector2(-0.09, 0.04), 0.035) < 0.0 or _sd_circle(p, Vector2(0.09, 0.04), 0.035) < 0.0:
				fill = INK_DARK
			if _sd_circle(p, Vector2(-0.18, 0.11), 0.045) < 0.0 or _sd_circle(p, Vector2(0.18, 0.11), 0.045) < 0.0:
				fill = Color(0.99, 0.68, 0.72)

		"gnome":
			# Classic Funk-Flitzer backyard garden gnome!
			var hat := _sd_triangle_up(p, Vector2(0.0, -0.34), 0.30, 0.34)
			var face := _sd_circle(p, Vector2(0.0, 0.06), 0.22)
			var beard := _sd_triangle_up(Vector2(p.x, -p.y + 0.44), Vector2(0.0, 0.18), 0.26, 0.24)
			var coat := _sd_box(p, Vector2(0.0, 0.46), Vector2(0.26, 0.24), 0.08)
			d = minf(minf(hat, face), minf(beard, coat))
			if hat <= 0.01:
				fill = Color(0.92, 0.20, 0.18) # Red pointy gnome hat!
			elif beard <= 0.01 and p.y > 0.08:
				fill = PAPER_WHITE
			elif face <= 0.01:
				fill = Color(0.99, 0.82, 0.68)
				if _sd_circle(p, Vector2(0.0, 0.08), 0.065) < 0.0:
					fill = Color(0.96, 0.56, 0.48) # Round nose
				elif _sd_circle(p, Vector2(-0.08, 0.0), 0.03) < 0.0 or _sd_circle(p, Vector2(0.08, 0.0), 0.03) < 0.0:
					fill = INK_DARK
			else:
				fill = primary # Tunic coat

		"frog":
			# Classic Funk-Flitzer Frog Pond hazard!
			var body := _sd_circle(p * Vector2(0.85, 1.1), Vector2(0.0, 0.18), 0.34)
			var eye_l := _sd_circle(p, Vector2(-0.20, -0.16), 0.14)
			var eye_r := _sd_circle(p, Vector2(0.20, -0.16), 0.14)
			d = minf(body, minf(eye_l, eye_r))
			fill = Color(0.30, 0.80, 0.34)
			if _sd_circle(p, Vector2(0.0, 0.28), 0.20) < 0.0:
				fill = Color(0.88, 0.96, 0.64) # Belly
			if _sd_circle(p, Vector2(-0.20, -0.16), 0.09) < 0.0 or _sd_circle(p, Vector2(0.20, -0.16), 0.09) < 0.0:
				fill = PAPER_WHITE
			if _sd_circle(p, Vector2(-0.20, -0.16), 0.045) < 0.0 or _sd_circle(p, Vector2(0.20, -0.16), 0.045) < 0.0:
				fill = INK_DARK

		"power_turbo":
			# Lightning bolt badge!
			var s1 := _sd_segment(p, Vector2(0.14, -0.52), Vector2(-0.18, 0.02), 0.11)
			var s2 := _sd_segment(p, Vector2(-0.18, 0.02), Vector2(0.16, -0.02), 0.10)
			var s3 := _sd_segment(p, Vector2(0.16, -0.02), Vector2(-0.14, 0.54), 0.11)
			d = minf(s1, minf(s2, s3))
			fill = Color(1.0, 0.84, 0.12) if p.y < 0.0 else Color(0.98, 0.52, 0.12)

		"power_shock":
			var orb := _sd_circle(p, Vector2.ZERO, 0.38)
			var r1 := _sd_segment(p, Vector2(-0.52, 0.0), Vector2(0.52, 0.0), 0.06)
			var r2 := _sd_segment(p, Vector2(0.0, -0.52), Vector2(0.0, 0.52), 0.06)
			d = minf(orb, minf(r1, r2))
			fill = Color(0.28, 0.82, 1.0)
			if _sd_circle(p, Vector2(-0.10, -0.10), 0.12) < 0.0:
				fill = PAPER_WHITE

		"power_spring":
			var c_top := _sd_box(p, Vector2(0.0, -0.36), Vector2(0.32, 0.08), 0.04)
			var c_mid := _sd_box(p, Vector2(0.0, 0.0), Vector2(0.28, 0.08), 0.04)
			var c_bot := _sd_box(p, Vector2(0.0, 0.36), Vector2(0.32, 0.08), 0.04)
			var diag1 := _sd_segment(p, Vector2(-0.26, -0.32), Vector2(0.26, 0.0), 0.06)
			var diag2 := _sd_segment(p, Vector2(0.26, 0.0), Vector2(-0.26, 0.32), 0.06)
			d = minf(minf(c_top, c_mid), minf(c_bot, minf(diag1, diag2)))
			fill = Color(0.32, 0.88, 0.42)

		"power_oil":
			var b_main := _sd_circle(p, Vector2(0.0, 0.08), 0.30)
			var b_l := _sd_circle(p, Vector2(-0.28, 0.18), 0.17)
			var b_r := _sd_circle(p, Vector2(0.26, -0.06), 0.18)
			var b_t := _sd_circle(p, Vector2(-0.10, -0.24), 0.15)
			d = minf(minf(b_main, b_l), minf(b_r, b_t))
			fill = Color(0.56, 0.22, 0.78)
			if _sd_circle(p, Vector2(-0.08, -0.02), 0.09) < 0.0:
				fill = Color(0.84, 0.56, 0.98)

		"power_mystery":
			# Floating Paper Star / Badge!
			var box_d := _sd_box(p, Vector2.ZERO, Vector2(0.42, 0.42), 0.12)
			d = box_d
			fill = primary
			# Question mark / star dot inside
			var q_top := absf(_sd_circle(p, Vector2(0.0, -0.12), 0.14)) - 0.055
			if p.x < -0.02 and p.y > -0.08:
				q_top = 10.0
			var q_stem := _sd_segment(p, Vector2(0.08, -0.02), Vector2(0.0, 0.10), 0.055)
			var q_dot := _sd_circle(p, Vector2(0.0, 0.26), 0.065)
			if minf(q_top, minf(q_stem, q_dot)) < 0.0:
				fill = PAPER_WHITE

		_:
			d = _sd_circle(p, Vector2.ZERO, 0.45)
			fill = primary

	# --- Paper Mario Die-Cut Sticker Border Evaluation ---
	# 1. Inside shape
	if d <= 0.0:
		return fill
	# 2. Crisp dark ink inner outline
	if d <= 0.045:
		return INK_DARK
	# 3. Thick white paper die-cut margin
	if d <= 0.145:
		return PAPER_WHITE
	# 4. Crisp outer cardstock edge with anti-aliased falloff
	if d <= 0.185:
		var a := 1.0 - smoothstep(0.155, 0.185, d)
		return Color(0.20, 0.16, 0.14, a)

	return Color(0.0, 0.0, 0.0, 0.0)


# Creates an upright 3D Paper Mario die-cut standee on a little cardboard base tab!
static func make_standee(
	kind: String,
	world_height: float = 3.0,
	tint: Color = GRASS_LIGHT,
	with_base_tab: bool = true
) -> Node3D:
	var root := Node3D.new()
	root.name = "Standee_" + kind

	var tex := get_sticker_texture(kind, tint)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = world_height / float(tex.get_height())
	sprite.position = Vector3(0.0, world_height * 0.46, 0.0)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(sprite)

	if with_base_tab:
		var base_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(world_height * 0.42, 0.08, world_height * 0.24)
		base_mesh.mesh = box
		base_mesh.position = Vector3(0.0, 0.04, 0.0)
		base_mesh.material_override = make_paper_mat(CARDBOARD_TAN, false)
		root.add_child(base_mesh)

	return root
