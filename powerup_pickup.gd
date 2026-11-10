class_name PowerupPickup
extends Area3D

@export var respawn_time: float = 5.5

var _active: bool = true
var _timer: float = 0.0
var _visual_pivot: Node3D
var _ring_mesh: MeshInstance3D
var _time_accum: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.45
	col.shape = sph
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	# Ground shadow/target ring so top-down alignment is effortless
	_ring_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.05
	cyl.height = 0.05
	_ring_mesh.mesh = cyl
	_ring_mesh.position = Vector3(0.0, 0.04, 0.0)
	_ring_mesh.material_override = PaperStyle.make_paper_mat(Color(1.0, 0.88, 0.28), true, 0.02)
	add_child(_ring_mesh)

	_visual_pivot = Node3D.new()
	_visual_pivot.position = Vector3(0.0, 1.15, 0.0)
	add_child(_visual_pivot)

	var sprite := Sprite3D.new()
	var tex := PaperStyle.get_sticker_texture("power_mystery", Color(1.0, 0.56, 0.14))
	sprite.texture = tex
	sprite.pixel_size = 1.65 / float(tex.get_height())
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.shaded = false
	_visual_pivot.add_child(sprite)

	body_entered.connect(_on_body_entered)
	_time_accum = randf() * TAU


func _process(delta: float) -> void:
	_time_accum += delta
	if _active:
		_visual_pivot.rotation.y += delta * 2.4
		_visual_pivot.position.y = 1.15 + sin(_time_accum * 3.2) * 0.20
		_visual_pivot.scale = _visual_pivot.scale.lerp(Vector3.ONE, delta * 10.0)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_active = true
			_visual_pivot.visible = true
			_ring_mesh.visible = true
			_visual_pivot.scale = Vector3(0.05, 1.4, 0.05)


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.is_in_group("racers") and body.has_method("collect_powerup"):
		if body.collect_powerup():
			_active = false
			_timer = respawn_time
			_visual_pivot.visible = false
			_ring_mesh.visible = false
