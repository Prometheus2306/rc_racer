# rc_car.gd

extends CharacterBody3D

# --- Car Properties ---
@export var speed = 10.0
@export var acceleration = 5.0
@export var turn_speed = 2.5
@export var friction = 3.0
@export var gravity = 9.8

# --- NEW: Penalty & Flip Properties ---
@export_group("Penalties and Flips")
# The upward force applied when hitting a wall.
@export var wall_hit_vertical_launch = 6.0
# NEW: The explosive outward force from a wall hit.
@export var wall_hit_outward_force = 10.0
# How fast the car flips in the air.
@export var air_flip_speed = 10.0
# How quickly the car rights itself before landing.
@export var auto_correct_speed = 5.0
# Cooldown in seconds between random air flips.
@export var flip_cooldown = 1.5

# NEW: This will store the last known valid position on the track.
var last_safe_position: Vector3
# --- Internal State Variables ---
# We'll use these to manage the new states.
var is_flipping = false
var flip_cooldown_timer = 0.0
# A reference to the car's visual model.
@onready var car_model = $CarModel
# A reference to the landing-detection raycast.
@onready var landing_ray = $RayCast3D


func _physics_process(delta):
	
	print("Is on floor? ", is_on_floor())
	
	# Update the flip cooldown timer.
	if flip_cooldown_timer > 0:
		flip_cooldown_timer -= delta

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Input Handling ---
	var input_dir = 0.0
	if Input.is_action_pressed("move_forward"):
		input_dir += 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir -= 1.0

	var turn_dir = 0.0
	if Input.is_action_pressed("steer_right"):
		turn_dir += 1.0
	if Input.is_action_pressed("steer_left"):
		turn_dir -= 1.0

	# --- Steering ---
	if velocity.length() > 0.1:
		rotate_y(turn_dir * turn_speed * delta)

	# --- Acceleration and Friction ---
	var forward_vector = -global_transform.basis.z
	if input_dir != 0:
		velocity = velocity.move_toward(forward_vector * speed * input_dir, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

	# --- Execute Movement ---
	move_and_slide()

	# --- NEW: Wall Collision Detection ---
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider().get_collision_layer_value(2):
			# The dot product tells us how aligned the surface is with "UP".
			# If it's a floor (close to 1.0), we ignore it.
			# If it's a wall (close to 0.0), we launch.
			if collision.get_normal().dot(Vector3.UP) < 0.9:
				# --- ALL YOUR LAUNCH LOGIC GOES INSIDE THIS NEW IF-STATEMENT ---
				var launch_direction = (collision.get_normal() + Vector3.UP).normalized()
				velocity = launch_direction * wall_hit_outward_force
				velocity.y += wall_hit_vertical_launch 
				print("Wall hit! Launched away.")
				break # Break is now inside the new if
			
	# --- NEW: Air Flip and Self-Righting Logic ---
	if not is_on_floor():
		# If we are airborne...
		if is_flipping:
			# ...and currently in a flip, keep rotating the visual model.
			car_model.rotate_x(air_flip_speed * delta)
		elif flip_cooldown_timer <= 0:
			# ...and the cooldown is ready, start a new flip!
			is_flipping = true
			flip_cooldown_timer = flip_cooldown
			
		# THE IMPORTANT PART: Self-righting before landing.
		# If the raycast can see the ground, it's time to straighten out.
		if landing_ray.is_colliding():
			is_flipping = false # Stop the random flip rotation.
			# Smoothly interpolate the car model's rotation back to zero (upright).
			car_model.rotation = car_model.rotation.lerp(Vector3.ZERO, auto_correct_speed * delta)
	else:
		# When we are safely on the floor...
		is_flipping = false
		# ...snap the rotation perfectly to upright, just in case.
		car_model.rotation = Vector3.ZERO


# ... (inside _ready() function, or add one if you don't have it) ...
func _ready():
	# Store our starting position as the first safe position.
	last_safe_position = self.global_position

# This function is called every second by the Timer node.
func _on_timer_timeout():
	# We need to get the track boundaries from the camera script.
	var camera_gimbal = get_node_or_null("/root/World/CameraGimbal")
	if not camera_gimbal: return

	var track_limits: Rect2 = camera_gimbal.track_limits
	var current_pos_2d = Vector2(self.global_position.x, self.global_position.z)

	# If the car is on the floor AND inside the track boundaries...
	if is_on_floor() and track_limits.has_point(current_pos_2d):
		# ...it's a safe spot. Save the position.
		last_safe_position = self.global_position
		# print("Safe position updated to: ", last_safe_position) # Uncomment for debugging

func respawn():
	# Stop all movement.
	velocity = Vector3.ZERO

	# Reset any flipping visuals and state.
	is_flipping = false
	car_model.rotation = Vector3.ZERO

	# Instantly move the car back to its last known safe position.
	self.global_position = last_safe_position
