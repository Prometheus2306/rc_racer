class_name RCCar
extends CharacterBody3D

enum Powerup {
	NONE = 0,
	TURBO = 1,
	SHOCK = 2,
	SPRING = 3,
	OIL = 4,
}

# --- Configurable Properties ---
@export var racer_name: String = "Spieler"
@export var is_ai: bool = false
@export var vehicle_class: int = 0
@export var paint_index: int = 0
@export var car_number: int = 1

@export var speed: float = 23.5
@export var acceleration: float = 28.0
@export var turn_speed: float = 3.15
@export var friction: float = 14.0
@export var gravity: float = 26.0
@export var offroad_grip: float = 0.80
@export var car_mass: float = 1.0

@export_group("Penalties and Flips")
@export var wall_hit_vertical_launch: float = 4.8
@export var wall_hit_outward_force: float = 9.5
@export var air_flip_speed: float = 9.5
@export var auto_correct_speed: float = 9.0
@export var flip_cooldown: float = 1.1

# --- Race Progress State ---
var race_can_move: bool = false
var current_lap: int = 1
var next_checkpoint_id: int = 0
var checkpoints_passed: int = 0
var finished: bool = false
var finish_time: float = 0.0
var lap_start_time: float = 0.0
var best_lap_time: float = 9999.0
var race_rank: int = 1

# --- Power-Up & Status Timers ---
var held_powerup: Powerup = Powerup.NONE
var boost_timer: float = 0.0
var spinout_timer: float = 0.0
var shock_fx_timer: float = 0.0
var wall_bonk_cooldown: float = 0.0
var squash_scale: Vector3 = Vector3.ONE

# --- Flip & Safe Position ---
var last_safe_position: Vector3 = Vector3.ZERO
var last_safe_yaw: float = 0.0
var is_flipping: bool = false
var flip_cooldown_timer: float = 0.0
var was_on_floor: bool = true

# --- AI State ---
var waypoints: PackedVector3Array = PackedVector3Array()
var ai_wp_index: int = 0
var ai_lane_offset: float = 0.0
var ai_skill: float = 1.0
var _ai_stuck_timer: float = 0.0
var _ai_reverse_timer: float = 0.0
var _ai_powerup_delay: float = 0.0

# --- Visual Rig References ---
var _vis: Dictionary = {}
var _antenna_vel: Vector2 = Vector2.ZERO
var _antenna_rot: Vector2 = Vector2.ZERO
var sfx: SFXManager = null
var hazard_parent: Node3D = null

@onready var car_model: Node3D = $CarModel
@onready var landing_ray: RayCast3D = $RayCast3D


func _ready() -> void:
	add_to_group("racers")
	if not is_ai:
		add_to_group("player")
	else:
		if is_in_group("player"):
			remove_from_group("player")

	collision_layer = 1
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)

	apply_class_and_paint(vehicle_class, paint_index, car_number)
	last_safe_position = global_position
	last_safe_yaw = rotation.y


func apply_class_and_paint(cls_id: int, p_idx: int, num: int = 1) -> void:
	vehicle_class = posmod(cls_id, CarVisuals.VEHICLE_CLASSES.size())
	paint_index = posmod(p_idx, PaperStyle.CAR_PAINTS.size())
	car_number = num

	var info: Dictionary = CarVisuals.VEHICLE_CLASSES[vehicle_class]
	speed = float(info["top_speed"])
	acceleration = float(info["accel"])
	turn_speed = float(info["turn_speed"])
	offroad_grip = float(info["offroad_grip"])
	car_mass = float(info["mass"])

	if car_model != null:
		_vis = CarVisuals.build_car_visuals(car_model, vehicle_class, paint_index, car_number)


func reset_for_race(start_xform: Transform3D) -> void:
	global_transform = start_xform
	velocity = Vector3.ZERO
	last_safe_position = start_xform.origin
	last_safe_yaw = start_xform.basis.get_euler().y
	current_lap = 1
	next_checkpoint_id = 0
	checkpoints_passed = 0
	finished = false
	finish_time = 0.0
	lap_start_time = 0.0
	best_lap_time = 9999.0
	held_powerup = Powerup.NONE
	boost_timer = 0.0
	spinout_timer = 0.0
	shock_fx_timer = 0.0
	is_flipping = false
	squash_scale = Vector3.ONE
	ai_wp_index = _find_closest_waypoint_index()
	_ai_stuck_timer = 0.0
	_ai_reverse_timer = 0.0
	if car_model != null:
		car_model.rotation = Vector3.ZERO
		car_model.scale = Vector3.ONE


func _physics_process(delta: float) -> void:
	if flip_cooldown_timer > 0.0:
		flip_cooldown_timer -= delta
	if wall_bonk_cooldown > 0.0:
		wall_bonk_cooldown -= delta
	if boost_timer > 0.0:
		boost_timer -= delta
	if shock_fx_timer > 0.0:
		shock_fx_timer -= delta

	var on_floor_now := is_on_floor()

	# Landing squash & stretch!
	if on_floor_now and not was_on_floor and velocity.y < -3.0:
		squash_scale = Vector3(1.20, 0.74, 1.16)
	was_on_floor = on_floor_now

	# --- Gravity ---
	if not on_floor_now:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.4

	# --- Gather Throttle, Steer, Drift & Powerup Input ---
	var throttle := 0.0
	var steer := 0.0
	var drifting := false

	if race_can_move:
		if is_ai or finished:
			var ai_cmd := _compute_ai_controls(delta)
			throttle = ai_cmd.x
			steer = ai_cmd.y
			drifting = absf(steer) > 0.72 and throttle > 0.5
		else:
			if Input.is_action_pressed("move_forward"):
				throttle += 1.0
			if Input.is_action_pressed("move_backward"):
				throttle -= 1.0
			if Input.is_action_pressed("steer_left"):
				steer += 1.0
			if Input.is_action_pressed("steer_right"):
				steer -= 1.0
			drifting = Input.is_action_pressed("drift")
			if Input.is_action_just_pressed("use_powerup"):
				activate_powerup()
			if Input.is_action_just_pressed("respawn"):
				respawn()

	# --- Spinout Override (Oil Slick / Electro-Shock) ---
	if spinout_timer > 0.0:
		spinout_timer -= delta
		throttle *= 0.2
		steer = 0.0

	# --- Surface Grip Check (Road vs Offroad Grass) ---
	var surface_mult := 1.0
	if on_floor_now and landing_ray != null and landing_ray.is_colliding():
		var col_obj := landing_ray.get_collider()
		if col_obj != null and col_obj.is_in_group("offroad_surface"):
			surface_mult = offroad_grip

	# --- Horizontal RC Vehicle Physics (Decoupled from Y!) ---
	var fwd_3d := -global_transform.basis.z
	var fwd_2d := Vector2(fwd_3d.x, fwd_3d.z).normalized()
	var right_2d := Vector2(-fwd_2d.y, fwd_2d.x)
	var horiz := Vector2(velocity.x, velocity.z)
	var fwd_speed := horiz.dot(fwd_2d)
	var side_speed := horiz.dot(right_2d)

	# Steering (scales smoothly with movement; reverses naturally when backing up)
	if horiz.length() > 0.35 and spinout_timer <= 0.0:
		var rev_sign := -1.0 if fwd_speed < -0.6 else 1.0
		var speed_factor := clampf(horiz.length() / 7.0, 0.35, 1.0)
		var drift_turn_bonus := 1.25 if drifting else 1.0
		rotate_y(steer * turn_speed * drift_turn_bonus * speed_factor * rev_sign * delta)

	# Recompute basis after rotation
	fwd_3d = -global_transform.basis.z
	fwd_2d = Vector2(fwd_3d.x, fwd_3d.z).normalized()
	right_2d = Vector2(-fwd_2d.y, fwd_2d.x)

	var max_spd := speed * surface_mult
	if boost_timer > 0.0:
		max_spd = speed * 1.45
		throttle = maxf(throttle, 1.0)

	if is_ai:
		max_spd *= ai_skill

	var target_fwd := 0.0
	if throttle > 0.0:
		target_fwd = max_spd * throttle
	elif throttle < 0.0:
		target_fwd = max_spd * 0.52 * throttle

	if absf(throttle) > 0.01:
		var acc := acceleration * (1.45 if boost_timer > 0.0 else 1.0)
		fwd_speed = move_toward(fwd_speed, target_fwd, acc * delta)
	else:
		fwd_speed = move_toward(fwd_speed, 0.0, friction * delta)

	# Lateral tire grip (allows controllable arcade drift!)
	var lat_grip := 4.5 if drifting else 11.5
	if not on_floor_now:
		lat_grip = 2.0
	side_speed = move_toward(side_speed, 0.0, lat_grip * delta * 3.0)

	horiz = fwd_2d * fwd_speed + right_2d * side_speed
	velocity.x = horiz.x
	velocity.z = horiz.y

	# Safe spot tracking when cleanly on road
	if on_floor_now and surface_mult >= 0.99 and spinout_timer <= 0.0:
		last_safe_position = global_position
		last_safe_yaw = rotation.y

	move_and_slide()

	# --- Wall Bonk & Car-to-Car Bump Detection ---
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		var n := col.get_normal()

		# Rival RC car bump!
		if collider is RCCar:
			var other := collider as RCCar
			var push_dir := (global_position - other.global_position)
			push_dir.y = 0.0
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()
				var push_strength := 5.5 / maxf(car_mass, 0.5)
				velocity += push_dir * push_strength
				other.velocity -= push_dir * (5.5 / maxf(other.car_mass, 0.5))

		# Hard wall collision (layer 4 -> bit index 3)
		elif collider is CollisionObject3D and (collider as CollisionObject3D).get_collision_layer_value(3):
			if n.dot(Vector3.UP) < 0.55 and wall_bonk_cooldown <= 0.0:
				var head_on := -fwd_3d.dot(n)
				if head_on > 0.55 and horiz.length() > 11.0:
					var launch_dir := (n + Vector3.UP * 0.45).normalized()
					velocity = launch_dir * wall_hit_outward_force
					velocity.y = wall_hit_vertical_launch
					wall_bonk_cooldown = 0.35
					squash_scale = Vector3(1.25, 1.15, 0.72)
					if not is_ai and sfx != null:
						sfx.play("bonk")
					break

	_update_visual_animations(delta, on_floor_now, fwd_speed, steer, drifting)

	if not is_ai and sfx != null:
		sfx.update_motor(absf(fwd_speed) / maxf(speed, 1.0), not on_floor_now, boost_timer > 0.0, race_can_move)


func _update_visual_animations(delta: float, on_floor_now: bool, fwd_speed: float, steer: float, drifting: bool) -> void:
	if car_model == null:
		return

	# Air flips & raycast landing self-righting
	if not on_floor_now:
		if is_flipping:
			car_model.rotate_x(-air_flip_speed * delta)
		elif flip_cooldown_timer <= 0.0 and velocity.y > 6.5:
			is_flipping = true
			flip_cooldown_timer = flip_cooldown

		if landing_ray != null and landing_ray.is_colliding() and velocity.y < 0.0:
			is_flipping = false
			car_model.rotation = car_model.rotation.lerp(Vector3.ZERO, auto_correct_speed * delta)
	else:
		is_flipping = false
		car_model.rotation.x = lerpf(car_model.rotation.x, 0.0, 12.0 * delta)
		car_model.rotation.z = lerpf(car_model.rotation.z, steer * 0.10, 10.0 * delta)
		if spinout_timer > 0.0:
			car_model.rotation.y += TAU * 2.2 * delta
		else:
			car_model.rotation.y = lerpf(car_model.rotation.y, 0.0, 12.0 * delta)

	squash_scale = squash_scale.lerp(Vector3.ONE, 9.0 * delta)
	car_model.scale = squash_scale

	if _vis.is_empty():
		return

	# Wheel steering & rolling
	var w_rad: float = float(_vis.get("wheel_radius", 0.36))
	var spin_pivots: Array = _vis.get("spin_pivots", [])
	for sp in spin_pivots:
		(sp as Node3D).rotate_x(-(fwd_speed / maxf(w_rad, 0.1)) * delta)

	var steer_pivots: Array = _vis.get("steer_pivots", [])
	for st in steer_pivots:
		(st as Node3D).rotation.y = lerpf((st as Node3D).rotation.y, steer * 0.42, 14.0 * delta)

	# Springy RC antenna wobble!
	var ant: Node3D = _vis.get("antenna", null)
	if ant != null:
		var target_bend := Vector2(
			clampf(-fwd_speed * 0.025, -0.45, 0.35),
			clampf(-steer * 0.35, -0.45, 0.45)
		)
		_antenna_vel += (target_bend - _antenna_rot) * 95.0 * delta
		_antenna_vel *= exp(-6.5 * delta)
		_antenna_rot += _antenna_vel * delta
		ant.rotation.x = _antenna_rot.x
		ant.rotation.z = _antenna_rot.y

	# Drift / Boost dust particles & flame
	var dust: CPUParticles3D = _vis.get("dust", null)
	if dust != null:
		dust.emitting = on_floor_now and ((drifting and absf(fwd_speed) > 8.0) or boost_timer > 0.0 or spinout_timer > 0.0)

	var flame: MeshInstance3D = _vis.get("flame", null)
	if flame != null:
		flame.visible = boost_timer > 0.0
		if flame.visible:
			var f_s := randf_range(0.82, 1.28)
			flame.scale = Vector3(f_s, f_s, f_s)

	var s_ring: MeshInstance3D = _vis.get("shock_ring", null)
	if s_ring != null:
		s_ring.visible = shock_fx_timer > 0.0
		if s_ring.visible:
			s_ring.rotate_y(delta * 8.0)


# --- Power-Up Collection & Activation ---
func collect_powerup() -> bool:
	if held_powerup != Powerup.NONE:
		return false
	# Weight powerups slightly by race position so trailing cars get exciting catchup items!
	var pool: Array[Powerup] = [Powerup.TURBO, Powerup.SHOCK, Powerup.SPRING, Powerup.OIL]
	if race_rank >= 3:
		pool.append(Powerup.TURBO)
		pool.append(Powerup.SHOCK)
	else:
		pool.append(Powerup.OIL)
		pool.append(Powerup.SPRING)
	held_powerup = pool[randi() % pool.size()]
	_ai_powerup_delay = randf_range(0.8, 2.6)
	if not is_ai and sfx != null:
		sfx.play("pickup")
	return true


func activate_powerup() -> void:
	if held_powerup == Powerup.NONE:
		return
	var used := held_powerup
	held_powerup = Powerup.NONE

	match used:
		Powerup.TURBO:
			boost_timer = 2.05 if vehicle_class == 3 else 1.65
			var fwd := -global_transform.basis.z.normalized()
			velocity.x = fwd.x * speed * 1.42
			velocity.z = fwd.z * speed * 1.42
			squash_scale = Vector3(0.84, 0.92, 1.28)
			if sfx != null and not is_ai:
				sfx.play("turbo")

		Powerup.SHOCK:
			shock_fx_timer = 0.55
			if sfx != null and not is_ai:
				sfx.play("zap")
			for node in get_tree().get_nodes_in_group("racers"):
				if node != self and node is RCCar:
					var rival := node as RCCar
					if rival.global_position.distance_to(global_position) <= 13.0:
						rival.trigger_spinout(1.05)
						rival.shock_fx_timer = 0.65
						rival.velocity.y = 5.5

		Powerup.SPRING:
			velocity.y = 14.5
			var fwd_s := -global_transform.basis.z.normalized()
			velocity += fwd_s * 6.0
			is_flipping = true
			squash_scale = Vector3(0.80, 1.35, 0.85)
			if sfx != null and not is_ai:
				sfx.play("spring")

		Powerup.OIL:
			var oil := TrackHazard.new()
			oil.kind = TrackHazard.Kind.OIL_SLICK
			oil.temporary_drop = true
			oil.owner_ignore = self
			var drop_pos := global_position + global_transform.basis.z.normalized() * 2.2
			drop_pos.y = maxf(global_position.y - 0.35, 0.02)
			oil.position = drop_pos
			var target_parent: Node = hazard_parent if is_instance_valid(hazard_parent) else get_parent()
			target_parent.add_child(oil)
			if sfx != null and not is_ai:
				sfx.play("oil")


func apply_boost_pad(dir: Vector3, pad_speed: float, upward: float) -> void:
	boost_timer = maxf(boost_timer, 0.85)
	velocity.x = dir.x * pad_speed
	velocity.z = dir.z * pad_speed
	if upward > 0.1:
		velocity.y = maxf(velocity.y, upward)
	squash_scale = Vector3(0.85, 0.92, 1.24)
	if not is_ai and sfx != null:
		sfx.play("turbo", 1.15, -8.0)


func trigger_spinout(duration: float) -> void:
	if boost_timer > 0.4:
		return # Turbo shields against minor spinouts!
	spinout_timer = maxf(spinout_timer, duration)
	if not is_ai and sfx != null:
		sfx.play("bonk", 1.25)


func apply_hazard_bonk(hazard_pos: Vector3) -> void:
	if wall_bonk_cooldown > 0.0:
		return
	wall_bonk_cooldown = 0.45
	var away := (global_position - hazard_pos)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	away = away.normalized()
	velocity = away * 10.0 + Vector3.UP * 6.5
	squash_scale = Vector3(1.25, 0.72, 1.25)
	if not is_ai and sfx != null:
		sfx.play("bonk", 0.95)


func respawn() -> void:
	velocity = Vector3.ZERO
	is_flipping = false
	spinout_timer = 0.0
	if car_model != null:
		car_model.rotation = Vector3.ZERO
	global_position = last_safe_position + Vector3(0.0, 0.85, 0.0)
	rotation.y = last_safe_yaw


# --- AI Waypoint Navigation ---
func _find_closest_waypoint_index() -> int:
	if waypoints.is_empty():
		return 0
	var best_i := 0
	var best_d := INF
	for i in range(waypoints.size()):
		var d := global_position.distance_squared_to(waypoints[i])
		if d < best_d:
			best_d = d
			best_i = i
	return (best_i + 1) % waypoints.size()


func _compute_ai_controls(delta: float) -> Vector2:
	if waypoints.is_empty():
		return Vector2.ZERO

	var wp_count := waypoints.size()
	var target_wp := waypoints[ai_wp_index % wp_count]
	var next_wp := waypoints[(ai_wp_index + 1) % wp_count]
	var seg_dir := (next_wp - target_wp)
	seg_dir.y = 0.0
	if seg_dir.length_squared() > 0.01:
		seg_dir = seg_dir.normalized()
	var seg_right := Vector3(-seg_dir.z, 0.0, seg_dir.x)
	var aim_point := target_wp + seg_right * ai_lane_offset

	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length() < 6.2:
		ai_wp_index = (ai_wp_index + 1) % wp_count
		target_wp = waypoints[ai_wp_index]
		to_aim = target_wp - global_position
		to_aim.y = 0.0

	# Stuck recovery
	var horiz_spd := Vector2(velocity.x, velocity.z).length()
	if horiz_spd < 2.2 and is_on_floor():
		_ai_stuck_timer += delta
		if _ai_stuck_timer > 1.1:
			_ai_reverse_timer = 0.65
		if _ai_stuck_timer > 3.2:
			_ai_stuck_timer = 0.0
			global_position = target_wp + Vector3(0.0, 1.0, 0.0)
			var flat_next := Vector3(next_wp.x, global_position.y, next_wp.z)
			if global_position.distance_squared_to(flat_next) > 0.05:
				look_at(flat_next, Vector3.UP)
			velocity = Vector3.ZERO
	else:
		_ai_stuck_timer = 0.0

	if _ai_reverse_timer > 0.0:
		_ai_reverse_timer -= delta
		return Vector2(-0.85, 0.9)

	# Compute signed angle to aim_point
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var desired := to_aim.normalized()
	var cross_y := fwd.cross(desired).y
	var dot_f := fwd.dot(desired)
	var angle_err := atan2(cross_y, dot_f)

	var steer_cmd := clampf(angle_err * 2.4, -1.0, 1.0)
	var throttle_cmd := 1.0
	if absf(angle_err) > 0.85:
		throttle_cmd = 0.58
	elif absf(angle_err) > 0.45:
		throttle_cmd = 0.82

	if finished:
		throttle_cmd *= 0.65

	# AI Powerup Usage
	if held_powerup != Powerup.NONE and not finished:
		_ai_powerup_delay -= delta
		if _ai_powerup_delay <= 0.0:
			activate_powerup()

	return Vector2(throttle_cmd, steer_cmd)
