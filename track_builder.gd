class_name TrackBuilder
extends RefCounted

const TRACK_INFO: Array[Dictionary] = [
	{
		"id": 0,
		"name": "Gartenkurs",
		"subtitle": "Sonniger Hinterhof, Holzbrücke & Froschteich",
		"sky_color": Color(0.62, 0.86, 0.99),
		"limits": Rect2(-52.0, -36.0, 104.0, 72.0),
	},
	{
		"id": 1,
		"name": "Sandkasten-Baustelle",
		"subtitle": "Holz-Sandkasten, Spielzeugkran & Sprunghügel",
		"sky_color": Color(0.98, 0.87, 0.68),
		"limits": Rect2(-54.0, -36.0, 108.0, 72.0),
	},
]


static func build_track(
	container: Node3D,
	track_id: int,
	checkpoint_scene: PackedScene
) -> Dictionary:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	var tid := posmod(track_id, TRACK_INFO.size())
	var control_pts: Array[Vector3] = []
	if tid == 0:
		control_pts = [
			Vector3(-18.0, 0.0, 24.0),
			Vector3(0.0, 0.0, 24.0),
			Vector3(20.0, 0.0, 24.0),
			Vector3(38.0, 0.0, 18.0),
			Vector3(42.0, 0.0, 0.0),
			Vector3(36.0, 0.3, -18.0),
			Vector3(20.0, 1.55, -24.0),
			Vector3(0.0, 1.75, -25.0),
			Vector3(-20.0, 1.55, -24.0),
			Vector3(-36.0, 0.2, -18.0),
			Vector3(-42.0, 0.0, -1.0),
			Vector3(-36.0, 0.0, 18.0),
		]
	else:
		control_pts = [
			Vector3(-20.0, 0.0, 24.0),
			Vector3(0.0, 0.0, 24.0),
			Vector3(22.0, 0.0, 24.0),
			Vector3(40.0, 0.0, 18.0),
			Vector3(43.0, 0.0, 0.0),
			Vector3(36.0, 0.0, -20.0),
			Vector3(18.0, 1.35, -24.0),
			Vector3(0.0, 0.15, -8.0),
			Vector3(-18.0, 1.35, -24.0),
			Vector3(-36.0, 0.0, -20.0),
			Vector3(-43.0, 0.0, 0.0),
			Vector3(-38.0, 0.0, 18.0),
		]

	var samples := _sample_closed_catmull(control_pts, 8) # 12 * 8 = 96 smooth stations
	var road_half_w := 5.8
	var rail_offset := 7.3

	# 1. Base Tabletop Lawn / Sandbox Floor (Off-road surface)
	_build_base_ground(container, tid)

	# 2. Continuous Paper-Cutout Road Ribbon + White Sticker Trim + Guard Curbs
	_build_road_and_curbs(container, samples, road_half_w, rail_offset, tid)

	# 3. Track-Specific Landmarks, Ramps, Pickups & Funk-Flitzer Hazards
	var sway_nodes: Array[Node3D] = []
	if tid == 0:
		_populate_garden_track(container, samples, sway_nodes)
	else:
		_populate_sandbox_track(container, samples, sway_nodes)

	# 4. Checkpoints (Station 8 = Start/Finish straight!)
	var cp_count := 6
	var start_station := 8
	var checkpoints: Array[RaceCheckpoint] = []
	for c_idx in range(cp_count):
		var st_i := (start_station + int(round(float(c_idx) * float(samples.size()) / float(cp_count)))) % samples.size()
		var pos: Vector3 = samples[st_i]
		var fwd: Vector3 = _station_forward(samples, st_i)

		var cp: RaceCheckpoint
		if checkpoint_scene != null:
			cp = checkpoint_scene.instantiate() as RaceCheckpoint
		else:
			cp = RaceCheckpoint.new()
		cp.checkpoint_id = c_idx
		cp.is_finish_line = (c_idx == 0)
		cp.gate_width = rail_offset * 2.0 - 0.4
		container.add_child(cp)
		cp.transform = _make_Basis_transform(pos, fwd)
		checkpoints.append(cp)

	# 5. Starting Grid (4 Staggered Slots right behind Start/Finish station 8)
	var start_transforms: Array[Transform3D] = []
	var grid_offsets: Array[Vector2] = [
		Vector2(-2.2, 3.8), # Slot 0 (Player / Pole)
		Vector2(2.2, 5.2),  # Slot 1
		Vector2(-2.2, 7.6), # Slot 2
		Vector2(2.2, 9.0),  # Slot 3
	]
	var sf_pos: Vector3 = samples[start_station]
	var sf_fwd: Vector3 = _station_forward(samples, start_station)
	var sf_right: Vector3 = sf_fwd.cross(Vector3.UP).normalized()
	for go in grid_offsets:
		var gp: Vector3 = sf_pos - sf_fwd * go.y + sf_right * go.x + Vector3(0.0, 0.72, 0.0)
		start_transforms.append(_make_Basis_transform(gp, sf_fwd))

	# 6. AI Waypoints (32 ordered points starting right after Start/Finish)
	var waypoints := PackedVector3Array()
	var step := 3
	for k in range(0, samples.size(), step):
		var idx := (start_station + k) % samples.size()
		waypoints.append(samples[idx] + Vector3(0.0, 0.35, 0.0))

	return {
		"checkpoints": checkpoints,
		"start_transforms": start_transforms,
		"waypoints": waypoints,
		"limits": TRACK_INFO[tid]["limits"],
		"sky_color": TRACK_INFO[tid]["sky_color"],
		"sway_nodes": sway_nodes,
	}


static func _make_Basis_transform(pos: Vector3, fwd: Vector3) -> Transform3D:
	var f := Vector3(fwd.x, 0.0, fwd.z)
	if f.length_squared() < 0.0001:
		f = Vector3.FORWARD
	f = f.normalized()
	var r := f.cross(Vector3.UP).normalized()
	var b := Basis(r, Vector3.UP, -f)
	return Transform3D(b, pos)


static func _station_forward(samples: Array[Vector3], idx: int) -> Vector3:
	var nxt := samples[(idx + 1) % samples.size()]
	var prv := samples[(idx - 1 + samples.size()) % samples.size()]
	return (nxt - prv).normalized()


static func _sample_closed_catmull(pts: Array[Vector3], subdiv: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := pts.size()
	for i in range(n):
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in range(subdiv):
			var t := float(s) / float(subdiv)
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out.append(q)
	return out


static func _build_base_ground(container: Node3D, tid: int) -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "OffroadGround"
	ground_body.collision_layer = 2
	ground_body.collision_mask = 0
	ground_body.add_to_group("offroad_surface")
	container.add_child(ground_body)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(160.0, 2.0, 120.0)
	col.shape = bs
	col.position = Vector3(0.0, -1.02, 0.0)
	ground_body.add_child(col)

	var mesh_i := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(160.0, 0.4, 120.0)
	mesh_i.mesh = bm
	mesh_i.position = Vector3(0.0, -0.22, 0.0)
	if tid == 0:
		mesh_i.material_override = PaperStyle.make_paper_mat(
			PaperStyle.GRASS_MID, false, 0.0, 1, PaperStyle.GRASS_LIGHT, 0.12
		)
	else:
		mesh_i.material_override = PaperStyle.make_paper_mat(
			PaperStyle.SAND_LIGHT, false, 0.0, 3, PaperStyle.SAND_MID, 0.25
		)
	ground_body.add_child(mesh_i)


static func _build_road_and_curbs(
	container: Node3D,
	samples: Array[Vector3],
	half_w: float,
	rail_offset: float,
	tid: int
) -> void:
	var n := samples.size()

	# --- A. White Paper Cutout Backing Strip (slightly wider than road) ---
	var trim_st := SurfaceTool.new()
	trim_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n):
		var j := (i + 1) % n
		var p0 := samples[i] + Vector3(0.0, 0.015, 0.0)
		var p1 := samples[j] + Vector3(0.0, 0.015, 0.0)
		var r0 := _station_forward(samples, i).cross(Vector3.UP).normalized()
		var r1 := _station_forward(samples, j).cross(Vector3.UP).normalized()
		var w := half_w + 0.48
		_add_quad_up(trim_st, p0 - r0 * w, p1 - r1 * w, p1 + r1 * w, p0 + r0 * w, float(i) * 0.25, float(i + 1) * 0.25)
	trim_st.generate_normals()
	var trim_mi := MeshInstance3D.new()
	trim_mi.mesh = trim_st.commit()
	trim_mi.material_override = PaperStyle.make_paper_mat(PaperStyle.PAPER_WHITE, false)
	container.add_child(trim_mi)

	# --- B. Main Drivable Road Ribbon + Collision ---
	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_st := SurfaceTool.new()
	center_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(n):
		var j := (i + 1) % n
		var p0 := samples[i] + Vector3(0.0, 0.04, 0.0)
		var p1 := samples[j] + Vector3(0.0, 0.04, 0.0)
		var r0 := _station_forward(samples, i).cross(Vector3.UP).normalized()
		var r1 := _station_forward(samples, j).cross(Vector3.UP).normalized()

		_add_quad_up(
			road_st,
			p0 - r0 * half_w,
			p1 - r1 * half_w,
			p1 + r1 * half_w,
			p0 + r0 * half_w,
			float(i) * 0.35,
			float(i + 1) * 0.35
		)

		# Dashed masking-tape center stripe every other segment!
		if i % 2 == 0:
			var cw := 0.22
			var cp0 := p0 + Vector3(0.0, 0.018, 0.0)
			var cp1 := p1 + Vector3(0.0, 0.018, 0.0)
			_add_quad_up(center_st, cp0 - r0 * cw, cp1 - r1 * cw, cp1 + r1 * cw, cp0 + r0 * cw, 0.0, 1.0)

		# Support pillars under elevated bridge sections!
		if samples[i].y > 0.45 and i % 4 == 0:
			var h: float = samples[i].y + 0.2
			for sx: float in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.35
				cyl.bottom_radius = 0.40
				cyl.height = h
				post.mesh = cyl
				post.position = samples[i] + r0 * (sx * (half_w - 0.5)) - Vector3(0.0, h * 0.5, 0.0)
				post.material_override = PaperStyle.make_paper_mat(PaperStyle.CARDBOARD_DARK, true, 0.025)
				container.add_child(post)

	road_st.generate_normals()
	var road_mesh := road_st.commit()

	var road_body := StaticBody3D.new()
	road_body.name = "RoadSurface"
	road_body.collision_layer = 2
	road_body.collision_mask = 0
	road_body.add_to_group("road_surface")
	container.add_child(road_body)

	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road_mesh
	var road_col := PaperStyle.ROAD_SLATE if tid == 0 else PaperStyle.ROAD_SAND
	road_mi.material_override = PaperStyle.make_paper_mat(road_col, false, 0.0, 3, road_col.lightened(0.06), 0.5)
	road_body.add_child(road_mi)

	var road_shape_node := CollisionShape3D.new()
	road_shape_node.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(road_shape_node)

	center_st.generate_normals()
	var center_mi := MeshInstance3D.new()
	center_mi.mesh = center_st.commit()
	center_mi.material_override = PaperStyle.make_paper_mat(PaperStyle.TAPE_CREAM, false)
	container.add_child(center_mi)

	# --- C. Outer & Inner Striped Toy Guardrail Curbs (Layer 4 = Hard Walls) ---
	var wall_body := StaticBody3D.new()
	wall_body.name = "TrackCurbWalls"
	wall_body.collision_layer = 4
	wall_body.collision_mask = 0
	container.add_child(wall_body)

	var c_primary := Color(0.92, 0.23, 0.20) if tid == 0 else Color(0.98, 0.78, 0.14)
	var c_secondary := PaperStyle.PAPER_WHITE if tid == 0 else PaperStyle.INK_DARK
	var mat_curb_a := PaperStyle.make_paper_mat(c_primary, true, 0.024)
	var mat_curb_b := PaperStyle.make_paper_mat(c_secondary, true, 0.024)
	var mat_wood_rail := PaperStyle.make_paper_mat(PaperStyle.WOOD_PLANK, true, 0.026)

	for i in range(n):
		var j := (i + 1) % n
		var p0 := samples[i]
		var p1 := samples[j]
		var mid := (p0 + p1) * 0.5
		var seg_vec := p1 - p0
		var seg_len := seg_vec.length()
		var fwd := seg_vec.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var elevated := mid.y > 0.35
		var cur_off := (half_w + 0.45) if elevated else rail_offset
		var cur_h := 0.95 if elevated else 0.78

		for side: float in [-1.0, 1.0]:
			var w_pos: Vector3 = mid + right * (side * cur_off) + Vector3(0.0, cur_h * 0.5 - 0.05, 0.0)
			var xform: Transform3D = _make_Basis_transform(w_pos, fwd)
			# Align pitch if elevated slope
			var pitch := asin(clampf(fwd.y, -0.8, 0.8))
			xform.basis = xform.basis * Basis(Vector3.RIGHT, pitch)

			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.55, cur_h, seg_len + 0.18)
			mi.mesh = bm
			mi.transform = xform
			if elevated:
				mi.material_override = mat_wood_rail
			else:
				mi.material_override = mat_curb_a if (i % 2 == 0) else mat_curb_b
			wall_body.add_child(mi)

			var cs := CollisionShape3D.new()
			var bshape := BoxShape3D.new()
			bshape.size = Vector3(0.65, cur_h + 1.4, seg_len + 0.20)
			cs.shape = bshape
			cs.transform = xform
			wall_body.add_child(cs)


static func _add_quad_up(
	st: SurfaceTool,
	l0: Vector3,
	l1: Vector3,
	r1: Vector3,
	r0: Vector3,
	v0: float,
	v1: float
) -> void:
	# Clockwise viewed from +Y -> +Y upward normal in Godot 4!
	st.set_uv(Vector2(0.0, v0))
	st.add_vertex(l0)
	st.set_uv(Vector2(0.0, v1))
	st.add_vertex(l1)
	st.set_uv(Vector2(1.0, v1))
	st.add_vertex(r1)

	st.set_uv(Vector2(0.0, v0))
	st.add_vertex(l0)
	st.set_uv(Vector2(1.0, v1))
	st.add_vertex(r1)
	st.set_uv(Vector2(1.0, v0))
	st.add_vertex(r0)


# --- Track 0: Gartenkurs (Backyard Garden, Foil Frog Pond, Jump Ramp, Gnomes & Frogs) ---
static func _populate_garden_track(container: Node3D, samples: Array[Vector3], sway_nodes: Array[Node3D]) -> void:
	# 1. Shiny Crinkled Blue Foil Frog Pond beneath the North Wooden Bridge!
	var pond := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 15.5
	pm.bottom_radius = 15.5
	pm.height = 0.10
	pm.radial_segments = 28
	pond.mesh = pm
	pond.scale = Vector3(1.45, 1.0, 0.85)
	pond.position = Vector3(0.0, 0.03, -24.5)
	pond.material_override = PaperStyle.make_water_mat()
	container.add_child(pond)

	# Paper Lily Pads on the Frog Pond
	var mat_lily := PaperStyle.make_paper_mat(PaperStyle.GRASS_LIGHT, true, 0.02)
	for lp: Vector3 in [Vector3(-12.0, 0.10, -19.0), Vector3(11.0, 0.10, -19.5), Vector3(4.0, 0.10, -30.5), Vector3(-7.0, 0.10, -31.0)]:
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.4
		cm.bottom_radius = 1.4
		cm.height = 0.06
		pad.mesh = cm
		pad.position = lp
		pad.material_override = mat_lily
		container.add_child(pad)

	# 2. Folded-Cardboard Jump Ramp + Boost Pad on South Straight (around x = 15, z = 24)
	_place_jump_ramp(container, Vector3(15.5, 0.04, 24.0), Vector3(1.0, 0.0, 0.0), 5.6, 4.6, 1.05)

	# Extra Boost Pad exiting West turn!
	_place_boost_pad(container, samples[88], _station_forward(samples, 88), 32.0, 0.0)

	# 3. Power-Up Pickups (3 across South/East, 3 across Bridge/West!)
	for st: int in [22, 24, 54, 56, 76]:
		var p_pos: Vector3 = samples[st]
		var r_vec: Vector3 = _station_forward(samples, st).cross(Vector3.UP).normalized()
		var offset: float = -2.2 if (st % 4 == 0) else 2.2
		var pu := PowerupPickup.new()
		pu.position = p_pos + r_vec * offset
		container.add_child(pu)

	# 4. Hopping Paper Frog (at West Bridge Exit, station 68) & Garden Gnome (West Straight, station 80)
	var frog_st := 70
	var frog := TrackHazard.new()
	frog.kind = TrackHazard.Kind.HOPPING_FROG
	frog.position = samples[frog_st]
	frog.patrol_offset = _station_forward(samples, frog_st).cross(Vector3.UP).normalized() * 3.8
	frog.patrol_speed = 2.1
	container.add_child(frog)

	var gnome_st := 82
	var gnome := TrackHazard.new()
	gnome.kind = TrackHazard.Kind.GARDEN_GNOME
	gnome.position = samples[gnome_st]
	gnome.patrol_offset = _station_forward(samples, gnome_st).cross(Vector3.UP).normalized() * 3.6
	gnome.patrol_speed = 1.7
	container.add_child(gnome)

	# 5. Tiered Corrugated Cardboard Hills + Hanging Sky Clouds + Die-Cut Trees & Flowers!
	_place_cardboard_hill(container, Vector3(0.0, 0.0, 0.0), Vector3(22.0, 2.2, 12.0), PaperStyle.GRASS_LIGHT)
	_place_cardboard_hill(container, Vector3(2.0, 2.2, -1.0), Vector3(12.0, 2.0, 6.5), PaperStyle.CARDBOARD_TAN)
	_place_cardboard_hill(container, Vector3(-56.0, 0.0, -28.0), Vector3(18.0, 4.5, 18.0), PaperStyle.GRASS_DARK)
	_place_cardboard_hill(container, Vector3(56.0, 0.0, -26.0), Vector3(20.0, 5.0, 16.0), PaperStyle.CARDBOARD_TAN)
	_place_cardboard_hill(container, Vector3(55.0, 0.0, 28.0), Vector3(16.0, 3.8, 14.0), PaperStyle.GRASS_LIGHT)

	var tree_spots: Array[Vector3] = [
		Vector3(-12.0, 0.0, 2.0), Vector3(12.0, 0.0, 3.0), Vector3(0.0, 4.2, -1.0),
		Vector3(-24.0, 0.0, 6.0), Vector3(24.0, 0.0, 6.0), Vector3(-24.0, 0.0, -6.0), Vector3(24.0, 0.0, -6.0),
		Vector3(-52.0, 0.0, 8.0), Vector3(-50.0, 0.0, -10.0), Vector3(52.0, 0.0, 8.0), Vector3(52.0, 0.0, -8.0),
		Vector3(-28.0, 0.0, 35.0), Vector3(0.0, 0.0, 36.0), Vector3(28.0, 0.0, 35.0),
	]
	for idx in range(tree_spots.size()):
		var kind := "tree_round" if (idx % 2 == 0) else "tree_pine"
		var tint := PaperStyle.GRASS_LIGHT if (idx % 3 == 0) else PaperStyle.GRASS_DARK
		var t_node := PaperStyle.make_standee(kind, randf_range(4.4, 6.0), tint, true)
		t_node.position = tree_spots[idx]
		container.add_child(t_node)
		sway_nodes.append(t_node)

	var flower_colors: Array[Color] = [Color(0.98, 0.36, 0.52), Color(1.0, 0.82, 0.18), Color(0.42, 0.72, 1.0), Color(0.98, 0.54, 0.20)]
	var flower_spots: Array[Vector3] = [
		Vector3(-8.0, 2.2, 4.0), Vector3(8.0, 2.2, 4.0), Vector3(-18.0, 0.0, 12.0),
		Vector3(18.0, 0.0, 12.0), Vector3(32.0, 0.0, 32.0), Vector3(-34.0, 0.0, 32.0),
		Vector3(-16.0, 0.0, 34.0), Vector3(14.0, 0.0, 34.0),
	]
	for f_i in range(flower_spots.size()):
		var fl := PaperStyle.make_standee("flower", 2.1, flower_colors[f_i % flower_colors.size()], false)
		fl.position = flower_spots[f_i]
		container.add_child(fl)
		sway_nodes.append(fl)

	# Static cheering spectator gnomes safely on the infield hill!
	for gx: float in [-4.5, 4.5]:
		var spec := PaperStyle.make_standee("gnome", 2.4, Color(0.22, 0.72, 0.38), true)
		spec.position = Vector3(gx, 2.2, 4.8)
		container.add_child(spec)
		sway_nodes.append(spec)

	_place_hanging_clouds(container, sway_nodes)


# --- Track 1: Sandkasten-Baustelle (Wooden Sandbox, Toy Blocks, Camel Ramp & Oil Hazards) ---
static func _populate_sandbox_track(container: Node3D, samples: Array[Vector3], sway_nodes: Array[Node3D]) -> void:
	# Giant Wooden Sandbox Frame around the whole diorama!
	var mat_timber := PaperStyle.make_paper_mat(PaperStyle.WOOD_PLANK, true, 0.03, 3, PaperStyle.CARDBOARD_TAN, 0.4)
	var frame_bars: Array = [
		[Vector3(0.0, 1.2, 40.0), Vector3(120.0, 2.6, 3.0)],
		[Vector3(0.0, 1.2, -40.0), Vector3(120.0, 2.6, 3.0)],
		[Vector3(-58.5, 1.2, 0.0), Vector3(3.0, 2.6, 83.0)],
		[Vector3(58.5, 1.2, 0.0), Vector3(3.0, 2.6, 83.0)],
	]
	for fb: Array in frame_bars:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = fb[1] as Vector3
		mi.mesh = bm
		mi.position = fb[0] as Vector3
		mi.material_override = mat_timber
		container.add_child(mi)

	# Toy Building Blocks & Cardboard Crane in Infield!
	var block_cols: Array[Color] = [Color(0.94, 0.25, 0.22), Color(0.22, 0.56, 0.95), Color(0.99, 0.78, 0.14), Color(0.26, 0.76, 0.38)]
	var block_defs: Array = [
		[Vector3(-14.0, 1.6, 8.0), Vector3(3.2, 3.2, 3.2), 0],
		[Vector3(-10.4, 1.6, 8.0), Vector3(3.2, 3.2, 3.2), 1],
		[Vector3(-12.2, 4.8, 8.0), Vector3(3.2, 3.2, 3.2), 2],
		[Vector3(14.0, 2.0, 8.0), Vector3(4.0, 4.0, 4.0), 2],
		[Vector3(14.0, 6.5, 8.0), Vector3(2.2, 5.0, 2.2), 0],
		[Vector3(18.5, 8.4, 8.0), Vector3(11.0, 1.1, 1.2), 2], # Toy Crane Boom!
	]
	for bd: Array in block_defs:
		var bi := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = bd[1] as Vector3
		bi.mesh = bmesh
		bi.position = bd[0] as Vector3
		bi.material_override = PaperStyle.make_paper_mat(block_cols[int(bd[2])], true, 0.03)
		container.add_child(bi)

	# Folded Jump Ramp on South Straight + Boost Pads!
	_place_jump_ramp(container, Vector3(16.0, 0.04, 24.0), Vector3(1.0, 0.0, 0.0), 5.6, 4.6, 1.15)
	_place_boost_pad(container, samples[36], _station_forward(samples, 36), 33.0, 0.0)
	_place_boost_pad(container, samples[86], _station_forward(samples, 86), 33.0, 0.0)

	# Pre-placed Paint/Oil Hazards & Gnome Construction Foremen!
	for oil_st: int in [32, 74]:
		var oil := TrackHazard.new()
		oil.kind = TrackHazard.Kind.OIL_SLICK
		var r_dir: Vector3 = _station_forward(samples, oil_st).cross(Vector3.UP).normalized()
		oil.position = samples[oil_st] + r_dir * 2.2
		container.add_child(oil)

	var foreman := TrackHazard.new()
	foreman.kind = TrackHazard.Kind.GARDEN_GNOME
	foreman.position = samples[60]
	foreman.patrol_offset = _station_forward(samples, 60).cross(Vector3.UP).normalized() * 3.5
	foreman.patrol_speed = 1.9
	container.add_child(foreman)

	# Power-Up Pickups
	for st: int in [20, 44, 56, 78, 90]:
		var pu := PowerupPickup.new()
		var r_dir: Vector3 = _station_forward(samples, st).cross(Vector3.UP).normalized()
		pu.position = samples[st] + r_dir * (-2.0 if st % 4 == 0 else 2.0)
		container.add_child(pu)

	# Potted Paper Cacti / Bushes around sandbox corners
	for spot: Vector3 in [Vector3(-48.0, 0.0, 30.0), Vector3(48.0, 0.0, 30.0), Vector3(-48.0, 0.0, -30.0), Vector3(48.0, 0.0, -30.0), Vector3(0.0, 0.0, 34.0)]:
		var b := PaperStyle.make_standee("bush", 3.4, PaperStyle.GRASS_LIGHT, true)
		b.position = spot
		container.add_child(b)
		sway_nodes.append(b)

	_place_hanging_clouds(container, sway_nodes)


static func _place_jump_ramp(
	container: Node3D,
	pos: Vector3,
	fwd: Vector3,
	width: float,
	length: float,
	height: float
) -> void:
	# Wedge prism mesh + exact trimesh collision so cars glide up and launch into a flip!
	var hw := width * 0.5
	var hl := length * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Local space: approach at +Z (back), high lip at -Z (front = -Z in Godot!)
	var bl := Vector3(-hw, 0.0, hl)
	var br := Vector3(hw, 0.0, hl)
	var fl_bot := Vector3(-hw, 0.0, -hl)
	var fr_bot := Vector3(hw, 0.0, -hl)
	var fl_top := Vector3(-hw, height, -hl)
	var fr_top := Vector3(hw, height, -hl)

	# Top sloped deck (bl -> fl_top -> fr_top -> br)
	_add_quad_up(st, bl, fl_top, fr_top, br, 0.0, 1.0)
	# Front drop face (-Z)
	_add_quad_up(st, fl_top, fl_bot, fr_bot, fr_top, 0.0, 1.0)
	# Left side triangle
	st.set_uv(Vector2(0, 0)); st.add_vertex(bl)
	st.set_uv(Vector2(0, 1)); st.add_vertex(fl_bot)
	st.set_uv(Vector2(1, 1)); st.add_vertex(fl_top)
	# Right side triangle
	st.set_uv(Vector2(0, 0)); st.add_vertex(br)
	st.set_uv(Vector2(1, 1)); st.add_vertex(fr_top)
	st.set_uv(Vector2(0, 1)); st.add_vertex(fr_bot)

	st.generate_normals()
	var wedge_mesh := st.commit()

	var ramp_body := StaticBody3D.new()
	ramp_body.name = "PaperJumpRamp"
	ramp_body.collision_layer = 2
	ramp_body.collision_mask = 0
	ramp_body.add_to_group("road_surface")
	container.add_child(ramp_body)
	ramp_body.transform = _make_Basis_transform(pos, fwd)

	var mi := MeshInstance3D.new()
	mi.mesh = wedge_mesh
	mi.material_override = PaperStyle.make_paper_mat(
		Color(1.0, 0.52, 0.14), true, 0.025, 5, Color(1.0, 0.94, 0.24), 1.0
	)
	ramp_body.add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = wedge_mesh.create_trimesh_shape()
	ramp_body.add_child(cs)

	# Add boost trigger right on the ramp lip for awesome Funk-Flitzer airtime!
	var pad := TrackHazard.new()
	pad.kind = TrackHazard.Kind.BOOST_PAD
	pad.boost_speed = 31.0
	pad.boost_upward = 8.2
	container.add_child(pad)
	pad.transform = _make_Basis_transform(pos + fwd.normalized() * (hl * 0.4) + Vector3(0.0, height * 0.5, 0.0), fwd)


static func _place_boost_pad(container: Node3D, pos: Vector3, fwd: Vector3, spd: float, up: float) -> void:
	var pad := TrackHazard.new()
	pad.kind = TrackHazard.Kind.BOOST_PAD
	pad.boost_speed = spd
	pad.boost_upward = up
	container.add_child(pad)
	pad.transform = _make_Basis_transform(pos + Vector3(0.0, 0.05, 0.0), fwd)


static func _place_cardboard_hill(container: Node3D, pos: Vector3, sz: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos + Vector3(0.0, sz.y * 0.5, 0.0)
	mi.material_override = PaperStyle.make_paper_mat(col, true, 0.035, 4, PaperStyle.PAPER_WHITE, 1.2)
	container.add_child(mi)


static func _place_hanging_clouds(container: Node3D, sway_nodes: Array[Node3D]) -> void:
	var mat_string := PaperStyle.make_paper_mat(PaperStyle.TAPE_CREAM, false)
	var cloud_positions: Array[Vector3] = [
		Vector3(-34.0, 14.5, -32.0),
		Vector3(0.0, 15.5, -35.0),
		Vector3(34.0, 14.0, -30.0),
		Vector3(-46.0, 13.5, 4.0),
		Vector3(46.0, 14.2, 6.0),
	]
	for cp in cloud_positions:
		var c_node := PaperStyle.make_standee("cloud", 5.2, PaperStyle.PAPER_WHITE, false)
		c_node.position = cp
		container.add_child(c_node)
		sway_nodes.append(c_node)

		# Visible hanging craft string above each cloud!
		var thread := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 12.0
		thread.mesh = cm
		thread.position = Vector3(0.0, 8.2, 0.0)
		thread.material_override = mat_string
		c_node.add_child(thread)
