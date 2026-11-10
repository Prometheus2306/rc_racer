class_name TrackHazard
extends Area3D

enum Kind {
	BOOST_PAD,
	OIL_SLICK,
	HOPPING_FROG,
	GARDEN_GNOME,
}

@export var kind: Kind = Kind.BOOST_PAD
@export var boost_speed: float = 33.0
@export var boost_upward: float = 0.0
@export var patrol_offset: Vector3 = Vector3(3.5, 0.0, 0.0)
@export var patrol_speed: float = 2.0
@export var temporary_drop: bool = false

var owner_ignore: Node3D = null
var _ignore_timer: float = 0.85
var _life_timer: float = 18.0
var _base_pos: Vector3
var _t: float = 0.0
var _visual: Node3D


func _ready() -> void:
	_base_pos = position
	_t = randf() * TAU
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	_build_hazard()
	body_entered.connect(_on_body_entered)


func _build_hazard() -> void:
	var col := CollisionShape3D.new()
	_visual = Node3D.new()
	add_child(_visual)

	match kind:
		Kind.BOOST_PAD:
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.6, 0.9, 4.2)
			col.shape = bs
			col.position = Vector3(0.0, 0.4, 0.0)

			var pad := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.4, 0.08, 4.0)
			pad.mesh = bm
			pad.position = Vector3(0.0, 0.05, 0.0)
			pad.material_override = PaperStyle.make_paper_mat(
				Color(1.0, 0.42, 0.12), true, 0.02, 5, Color(1.0, 0.95, 0.25), 1.0
			)
			_visual.add_child(pad)

		Kind.OIL_SLICK:
			var cs := CylinderShape3D.new()
			cs.radius = 1.45
			cs.height = 0.6
			col.shape = cs
			col.position = Vector3(0.0, 0.3, 0.0)

			# Layered flat Paper Mario paint/oil splat blobs
			var mat_oil := PaperStyle.make_paper_mat(Color(0.36, 0.14, 0.52), true, 0.02)
			var blobs: Array[Vector4] = [
				Vector4(0.0, 0.0, 1.25, 0.05),
				Vector4(-0.65, 0.45, 0.65, 0.05),
				Vector4(0.72, -0.35, 0.58, 0.05),
				Vector4(0.25, 0.78, 0.48, 0.05),
			]
			for b: Vector4 in blobs:
				var mi := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = b.z
				cm.bottom_radius = b.z
				cm.height = b.w
				cm.radial_segments = 12
				mi.mesh = cm
				mi.position = Vector3(b.x, 0.04, b.y)
				mi.material_override = mat_oil
				_visual.add_child(mi)

		Kind.HOPPING_FROG:
			var fs := SphereShape3D.new()
			fs.radius = 1.05
			col.shape = fs
			col.position = Vector3(0.0, 0.85, 0.0)
			var frog := PaperStyle.make_standee("frog", 2.0, PaperStyle.GRASS_LIGHT, false)
			_visual.add_child(frog)

		Kind.GARDEN_GNOME:
			var gs := SphereShape3D.new()
			gs.radius = 1.05
			col.shape = gs
			col.position = Vector3(0.0, 0.95, 0.0)
			var gnome := PaperStyle.make_standee("gnome", 2.35, Color(0.20, 0.52, 0.92), true)
			_visual.add_child(gnome)

	add_child(col)


func _process(delta: float) -> void:
	_t += delta * patrol_speed
	if _ignore_timer > 0.0:
		_ignore_timer -= delta
	if temporary_drop:
		_life_timer -= delta
		if _life_timer <= 0.0:
			queue_free()
			return

	if kind == Kind.HOPPING_FROG:
		var s := sin(_t)
		var hop := absf(sin(_t * 2.0)) * 1.15
		position = _base_pos + patrol_offset * s + Vector3(0.0, hop, 0.0)
		_visual.rotation.z = sin(_t * 2.0) * 0.14
	elif kind == Kind.GARDEN_GNOME:
		var s := sin(_t)
		position = _base_pos + patrol_offset * s
		_visual.rotation.z = cos(_t * 2.0) * 0.16


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("racers"):
		return
	if body == owner_ignore and _ignore_timer > 0.0:
		return

	match kind:
		Kind.BOOST_PAD:
			if body.has_method("apply_boost_pad"):
				var fwd := -global_transform.basis.z.normalized()
				body.apply_boost_pad(fwd, boost_speed, boost_upward)
		Kind.OIL_SLICK:
			if body.has_method("trigger_spinout"):
				body.trigger_spinout(0.80)
				if temporary_drop:
					queue_free()
		Kind.HOPPING_FROG, Kind.GARDEN_GNOME:
			if body.has_method("apply_hazard_bonk"):
				body.apply_hazard_bonk(global_position)
