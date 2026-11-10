extends Node3D

@export var target: Node3D
@export var follow_speed: float = 7.5
@export var track_limits: Rect2 = Rect2(-52.0, -36.0, 104.0, 72.0)

const CAMERA_MODES: Array[String] = [
	"Funk-Flitzer Klassik",
	"Papier-Isometrisch",
	"Diorama-Nah",
]

var camera_mode: int = 0
var showcase_mode: bool = true
var _showcase_angle: float = 0.0

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	apply_camera_mode(0)


func cycle_camera_mode() -> String:
	camera_mode = (camera_mode + 1) % CAMERA_MODES.size()
	apply_camera_mode(camera_mode)
	return CAMERA_MODES[camera_mode]


func apply_camera_mode(mode_idx: int) -> void:
	camera_mode = posmod(mode_idx, CAMERA_MODES.size())
	if cam == null:
		return

	var local_eye := Vector3(0.0, 27.5, 21.5)
	match camera_mode:
		0: # Funk-Flitzer Klassik (Elevated 3/4 bird's-eye tabletop perspective)
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 43.0
			local_eye = Vector3(0.0, 27.5, 21.5)
		1: # Papier-Isometrisch (Orthographic isometric diorama)
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 31.0
			local_eye = Vector3(19.0, 22.0, 19.0)
		2: # Diorama-Nah (Closer action tabletop angle)
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 47.0
			local_eye = Vector3(0.0, 17.5, 16.0)

	cam.transform = Transform3D(Basis.looking_at(-local_eye.normalized(), Vector3.UP), local_eye)


func _process(delta: float) -> void:
	if showcase_mode:
		_showcase_angle += delta * 0.28
		var focus := Vector3(cos(_showcase_angle) * 14.0, 0.0, 10.0 + sin(_showcase_angle * 0.8) * 10.0)
		global_position = global_position.lerp(focus, 3.0 * delta)
		return

	if not is_instance_valid(target):
		return

	var target_pos := target.global_position
	# Velocity look-ahead so player sees upcoming turns & hazards clearly!
	if target is CharacterBody3D:
		var v := (target as CharacterBody3D).velocity
		var lead := Vector3(v.x, 0.0, v.z) * 0.22
		if lead.length() > 6.0:
			lead = lead.normalized() * 6.0
		target_pos += lead

	target_pos.y = lerpf(global_position.y, maxf(target.global_position.y * 0.5, 0.0), 4.0 * delta)
	var smoothed := global_position.lerp(target_pos, follow_speed * delta)

	if track_limits.size.x > 1.0 and track_limits.size.y > 1.0:
		smoothed.x = clampf(smoothed.x, track_limits.position.x, track_limits.position.x + track_limits.size.x)
		smoothed.z = clampf(smoothed.z, track_limits.position.y, track_limits.position.y + track_limits.size.y)

	global_position = smoothed
