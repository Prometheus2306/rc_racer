class_name RaceCheckpoint
extends Area3D

signal racer_entered(racer: RCCar, checkpoint_id: int)

@export var checkpoint_id: int = 0
@export var gate_width: float = 13.0
@export var is_finish_line: bool = false

var _guide_visual: Node3D


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	# Ensure generous trigger volume so jumping cars still register!
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var shape := BoxShape3D.new()
	shape.size = Vector3(gate_width, 8.0, 2.8)
	col.shape = shape
	col.position = Vector3(0.0, 3.5, 0.0)

	# Hide legacy placeholder mesh if present
	var legacy_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy_mesh != null:
		legacy_mesh.visible = false

	_build_gate_decor()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_gate_decor() -> void:
	var half_w := gate_width * 0.5
	if is_finish_line:
		# Classic Checkered Start/Finish Paper Archway!
		var mat_post := PaperStyle.make_paper_mat(
			Color(0.92, 0.24, 0.20), true, 0.025, 2, PaperStyle.PAPER_WHITE, 1.2
		)
		var mat_checker := PaperStyle.make_paper_mat(
			PaperStyle.INK_DARK, true, 0.025, 1, PaperStyle.PAPER_WHITE, 1.4
		)
		var mat_road_line := PaperStyle.make_paper_mat(
			PaperStyle.INK_DARK, false, 0.0, 1, PaperStyle.PAPER_WHITE, 1.5
		)

		for sx: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.28
			cyl.bottom_radius = 0.34
			cyl.height = 5.4
			post.mesh = cyl
			post.position = Vector3(sx * (half_w + 0.3), 2.7, 0.0)
			post.material_override = mat_post
			add_child(post)

		var banner := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(gate_width + 1.4, 1.25, 0.35)
		banner.mesh = b_mesh
		banner.position = Vector3(0.0, 5.1, 0.0)
		banner.material_override = mat_checker
		add_child(banner)

		var strip := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(gate_width, 0.05, 1.5)
		strip.mesh = s_mesh
		strip.position = Vector3(0.0, 0.03, 0.0)
		strip.material_override = mat_road_line
		add_child(strip)
	else:
		# Cute Paper Pennant Flags on left & right shoulders
		var mat_stick := PaperStyle.make_paper_mat(PaperStyle.CARDBOARD_DARK, true, 0.02)
		var mat_flag := PaperStyle.make_paper_mat(Color(1.0, 0.78, 0.16), true, 0.02)
		for sx: float in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.08
			pm.bottom_radius = 0.10
			pm.height = 2.4
			pole.mesh = pm
			pole.position = Vector3(sx * (half_w + 0.35), 1.2, 0.0)
			pole.material_override = mat_stick
			add_child(pole)

			var flag := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.75, 0.45, 0.08)
			flag.mesh = fm
			flag.position = Vector3(sx * (half_w - 0.05), 2.1, 0.0)
			flag.material_override = mat_flag
			add_child(flag)

	# Glowing translucent target strip on the ground for Player's next checkpoint
	_guide_visual = Node3D.new()
	add_child(_guide_visual)
	var glow := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(gate_width - 0.6, 0.12, 0.55)
	glow.mesh = gm
	glow.position = Vector3(0.0, 0.08, 0.0)
	var g_mat := StandardMaterial3D.new()
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g_mat.albedo_color = Color(1.0, 0.90, 0.20, 0.58)
	glow.material_override = g_mat
	_guide_visual.add_child(glow)


func _on_body_entered(body: Node3D) -> void:
	if body is RCCar:
		racer_entered.emit(body as RCCar, checkpoint_id)


func show_visuals() -> void:
	if _guide_visual != null:
		_guide_visual.visible = true


func hide_visuals() -> void:
	if _guide_visual != null:
		_guide_visual.visible = false
