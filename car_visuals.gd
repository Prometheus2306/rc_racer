class_name CarVisuals
extends RefCounted

const VEHICLE_CLASSES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "Flitzer-Buggy",
		"tagline": "Ausgewogen & wendig",
		"top_speed": 23.5,
		"accel": 28.0,
		"turn_speed": 3.15,
		"offroad_grip": 0.80,
		"mass": 1.0,
	},
	{
		"id": 1,
		"name": "Monster-Truck",
		"tagline": "Stark im Gras & Rammen",
		"top_speed": 22.2,
		"accel": 25.0,
		"turn_speed": 2.85,
		"offroad_grip": 0.97,
		"mass": 1.35,
	},
	{
		"id": 2,
		"name": "Baja-Käfer",
		"tagline": "Top-Antritt & enge Kurven",
		"top_speed": 23.0,
		"accel": 32.0,
		"turn_speed": 3.45,
		"offroad_grip": 0.84,
		"mass": 0.92,
	},
	{
		"id": 3,
		"name": "Stadion-Truck",
		"tagline": "Höchstes Tempo & Turbo",
		"top_speed": 24.8,
		"accel": 26.5,
		"turn_speed": 2.95,
		"offroad_grip": 0.82,
		"mass": 1.12,
	},
]


static func build_car_visuals(
	parent: Node3D,
	class_id: int,
	paint_idx: int,
	car_number: int = 1
) -> Dictionary:
	for c in parent.get_children():
		c.queue_free()

	var p_info: Dictionary = PaperStyle.CAR_PAINTS[posmod(paint_idx, PaperStyle.CAR_PAINTS.size())]
	var main_col: Color = p_info["color"]
	var accent_col: Color = p_info["accent"]

	var mat_body := PaperStyle.make_paper_mat(main_col, true, 0.032)
	var mat_accent := PaperStyle.make_paper_mat(accent_col, true, 0.024)
	var mat_white := PaperStyle.make_paper_mat(PaperStyle.PAPER_WHITE, true, 0.022)
	var mat_dark := PaperStyle.make_paper_mat( Color(0.20, 0.21, 0.25), true, 0.025)
	var mat_glass := PaperStyle.make_paper_mat(Color(0.68, 0.88, 0.99), true, 0.020)
	var mat_light := PaperStyle.make_paper_mat(Color(1.0, 0.95, 0.55), false)

	var root := Node3D.new()
	root.name = "VisualRoot"
	parent.add_child(root)

	# White die-cut paper base trim around chassis (gives unmistakable Paper Mario toy look!)
	var base_trim := _box(Vector3(1.36, 0.08, 2.22), mat_white, Vector3(0.0, -0.14, 0.0))
	root.add_child(base_trim)

	var body_node := Node3D.new()
	body_node.name = "BodyShell"
	root.add_child(body_node)

	var wheel_radius := 0.36
	var wheel_width := 0.28
	var wheel_x := 0.74
	var wheel_y := -0.18
	var wheel_z_front := -0.68
	var wheel_z_back := 0.68

	match posmod(class_id, 4):
		0: # --- FLITZER-BUGGY ---
			# Sleek wedge chassis + cockpit + big RC rear wing!
			body_node.add_child(_box(Vector3(1.12, 0.28, 1.95), mat_body, Vector3(0.0, 0.02, 0.05)))
			var nose := _box(Vector3(0.92, 0.20, 0.75), mat_accent, Vector3(0.0, -0.02, -0.72))
			nose.rotation_degrees.x = 10.0
			body_node.add_child(nose)
			var cabin := _box(Vector3(0.84, 0.34, 0.82), mat_glass, Vector3(0.0, 0.28, 0.02))
			body_node.add_child(cabin)
			# Rear wing struts + airfoil
			body_node.add_child(_box(Vector3(0.10, 0.42, 0.14), mat_dark, Vector3(-0.42, 0.34, 0.86)))
			body_node.add_child(_box(Vector3(0.10, 0.42, 0.14), mat_dark, Vector3(0.42, 0.34, 0.86)))
			var wing := _box(Vector3(1.38, 0.10, 0.38), mat_accent, Vector3(0.0, 0.56, 0.90))
			wing.rotation_degrees.x = -12.0
			body_node.add_child(wing)

		1: # --- MONSTER-TRUCK ---
			wheel_radius = 0.48
			wheel_width = 0.38
			wheel_x = 0.84
			wheel_y = -0.10
			# High lifted pickup body
			body_node.add_child(_box(Vector3(1.24, 0.38, 2.02), mat_body, Vector3(0.0, 0.22, 0.0)))
			body_node.add_child(_box(Vector3(1.26, 0.12, 2.04), mat_accent, Vector3(0.0, 0.08, 0.0)))
			var cab := _box(Vector3(1.12, 0.42, 0.92), mat_body, Vector3(0.0, 0.56, -0.10))
			body_node.add_child(cab)
			body_node.add_child(_box(Vector3(1.15, 0.26, 0.82), mat_glass, Vector3(0.0, 0.56, -0.12)))
			# Roof light bar
			body_node.add_child(_box(Vector3(0.80, 0.12, 0.14), mat_light, Vector3(0.0, 0.82, -0.32)))

		2: # --- BAJA-KÄFER (Beetle) ---
			wheel_radius = 0.37
			wheel_x = 0.72
			# Cute rounded beetle base + dome!
			body_node.add_child(_box(Vector3(1.18, 0.28, 1.92), mat_body, Vector3(0.0, 0.02, 0.0)))
			var dome := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.58
			sph.height = 0.88
			sph.radial_segments = 16
			sph.rings = 8
			dome.mesh = sph
			dome.scale = Vector3(1.0, 0.85, 1.32)
			dome.position = Vector3(0.0, 0.22, 0.06)
			dome.material_override = mat_body
			body_node.add_child(dome)
			# Windshield band
			body_node.add_child(_box(Vector3(0.92, 0.24, 0.52), mat_glass, Vector3(0.0, 0.32, -0.28)))
			# Racing center stripe
			body_node.add_child(_box(Vector3(0.28, 0.06, 1.94), mat_accent, Vector3(0.0, 0.18, 0.0)))
			# Stinger exhaust
			var pipe := _cyl(0.09, 0.46, mat_dark, Vector3(0.0, 0.12, 1.04))
			pipe.rotation_degrees.x = 70.0
			body_node.add_child(pipe)

		_: # --- STADIUM-TRUCK ---
			wheel_radius = 0.38
			wheel_width = 0.32
			wheel_x = 0.78
			# Wide flared trophy truck
			body_node.add_child(_box(Vector3(1.34, 0.32, 2.08), mat_body, Vector3(0.0, 0.06, 0.0)))
			body_node.add_child(_box(Vector3(1.38, 0.10, 2.10), mat_accent, Vector3(0.0, -0.02, 0.0)))
			var st_cab := _box(Vector3(1.08, 0.32, 0.88), mat_glass, Vector3(0.0, 0.34, -0.04))
			body_node.add_child(st_cab)
			var roof := _box(Vector3(1.04, 0.08, 0.82), mat_body, Vector3(0.0, 0.50, -0.02))
			body_node.add_child(roof)
			# Hood scoop
			body_node.add_child(_box(Vector3(0.46, 0.14, 0.48), mat_accent, Vector3(0.0, 0.24, -0.68)))

	# Headlights (front = -Z)
	body_node.add_child(_box(Vector3(0.22, 0.14, 0.08), mat_light, Vector3(-0.38, 0.08, -1.02)))
	body_node.add_child(_box(Vector3(0.22, 0.14, 0.08), mat_light, Vector3(0.38, 0.08, -1.02)))

	# Number sticker plate on roof/hood
	var roof_heights: Array[float] = [0.47, 0.79, 0.62, 0.56]
	var badge_y: float = roof_heights[posmod(class_id, 4)]
	var badge := _box(Vector3(0.46, 0.03, 0.46), mat_white, Vector3(0.0, badge_y, -0.06))
	body_node.add_child(badge)
	var num_lbl := Label3D.new()
	num_lbl.text = str(car_number)
	num_lbl.font_size = 48
	num_lbl.pixel_size = 0.008
	num_lbl.modulate = PaperStyle.INK_DARK
	num_lbl.outline_size = 6
	num_lbl.outline_modulate = PaperStyle.PAPER_WHITE
	num_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	num_lbl.position = badge.position + Vector3(0.0, 0.03, 0.0)
	body_node.add_child(num_lbl)

	# --- Springy RC Radio Antenna (Signature Funk-Flitzer detail!) ---
	var antenna_pivot := Node3D.new()
	antenna_pivot.name = "AntennaPivot"
	antenna_pivot.position = Vector3(-0.36, 0.22, 0.78)
	body_node.add_child(antenna_pivot)

	var wire := _cyl(0.028, 1.35, mat_dark, Vector3(0.0, 0.67, 0.0))
	antenna_pivot.add_child(wire)

	var tip_ball := MeshInstance3D.new()
	var tip_sph := SphereMesh.new()
	tip_sph.radius = 0.11
	tip_sph.height = 0.22
	tip_ball.mesh = tip_sph
	tip_ball.position = Vector3(0.0, 1.36, 0.0)
	tip_ball.material_override = mat_accent
	antenna_pivot.add_child(tip_ball)

	# --- 4 Spinning + Front-Steering Paper-Craft Wheels ---
	var steer_pivots: Array[Node3D] = []
	var spin_pivots: Array[Node3D] = []
	var wheel_coords: Array[Vector3] = [
		Vector3(-wheel_x, wheel_y, wheel_z_front), # FL
		Vector3(wheel_x, wheel_y, wheel_z_front),  # FR
		Vector3(-wheel_x, wheel_y, wheel_z_back),  # RL
		Vector3(wheel_x, wheel_y, wheel_z_back),   # RR
	]
	for i in range(4):
		var st_piv := Node3D.new()
		st_piv.position = wheel_coords[i]
		root.add_child(st_piv)
		if i < 2:
			steer_pivots.append(st_piv)

		var sp_piv := Node3D.new()
		st_piv.add_child(sp_piv)
		spin_pivots.append(sp_piv)

		var tire := _cyl(wheel_radius, wheel_width, mat_dark, Vector3.ZERO)
		tire.rotation_degrees.z = 90.0
		sp_piv.add_child(tire)

		var hub := _cyl(wheel_radius * 0.56, wheel_width + 0.04, mat_white, Vector3.ZERO)
		hub.rotation_degrees.z = 90.0
		sp_piv.add_child(hub)

		# Spoke bar so wheel spin is clearly visible from top-down camera!
		var spoke := _box(Vector3(wheel_width + 0.06, wheel_radius * 0.95, 0.10), mat_accent, Vector3.ZERO)
		sp_piv.add_child(spoke)

	# --- Paper Confetti / Drift Dust Puff Particles ---
	var dust := CPUParticles3D.new()
	dust.name = "DriftDust"
	dust.position = Vector3(0.0, -0.25, 0.95)
	dust.emitting = false
	dust.amount = 18
	dust.lifetime = 0.45
	dust.explosiveness = 0.1
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.22, 0.22, 0.22)
	p_mesh.material = mat_white
	dust.mesh = p_mesh
	dust.direction = Vector3(0.0, 0.45, 1.0)
	dust.spread = 35.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 4.5
	dust.gravity = Vector3(0.0, -3.0, 0.0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	root.add_child(dust)

	# --- Turbo Boost Flame Cone ---
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.34
	cone.height = 0.95
	flame.mesh = cone
	flame.rotation_degrees.x = -90.0
	flame.position = Vector3(0.0, 0.05, 1.42)
	flame.material_override = PaperStyle.make_paper_mat(Color(1.0, 0.62, 0.10), true, 0.02)
	flame.visible = false
	body_node.add_child(flame)

	# --- Electro-Shock Visual Ring ---
	var shock_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.25
	torus.outer_radius = 1.50
	torus.rings = 16
	torus.ring_segments = 12
	shock_ring.mesh = torus
	shock_ring.position = Vector3(0.0, 0.20, 0.0)
	shock_ring.material_override = PaperStyle.make_paper_mat(Color(0.28, 0.88, 1.0), true, 0.02)
	shock_ring.visible = false
	root.add_child(shock_ring)

	return {
		"root": root,
		"body": body_node,
		"steer_pivots": steer_pivots,
		"spin_pivots": spin_pivots,
		"antenna": antenna_pivot,
		"dust": dust,
		"flame": flame,
		"shock_ring": shock_ring,
		"wheel_radius": wheel_radius,
	}


static func _box(sz: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi


static func _cyl(rad: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rad
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	return mi
