# CameraGimbal.gd
extends Node3D

# --- EXPORT VARIABLES ---
# We can set these from the Inspector in the editor.

# The node we want the camera to follow (our car).
@export var target: Node3D

# How quickly the camera catches up to the player. Higher is faster.
@export var follow_speed = 5.0

# The rectangular boundaries of our track. We will define this visually.
# The 'x' and 'y' of the Rect2's position map to the world's X and Z.
# The 'x' and 'y' of the Rect2's size map to the world's width and depth.
@export var track_limits: Rect2


func _process(delta):
	# If no target is set, do nothing.
	if not is_instance_valid(target):
		return

	# --- SMOOTH FOLLOW ---
	# We use lerp (linear interpolation) to smoothly move the camera's position
	# towards the target's position. This prevents jittery movement.
	var target_position = target.global_position
	self.global_position = self.global_position.lerp(target_position, follow_speed * delta)
	
	# --- CLAMPING LOGIC ---
	# Now, we make sure the smoothed position doesn't go outside our track limits.
	var new_pos = self.global_position
	
	# Clamp the X position
	new_pos.x = clamp(new_pos.x, track_limits.position.x, track_limits.position.x + track_limits.size.x)
	
	# Clamp the Z position (using the Rect2's 'y' properties for Z)
	new_pos.z = clamp(new_pos.z, track_limits.position.y, track_limits.position.y + track_limits.size.y)
	
	# Apply the final, clamped position.
	self.global_position = new_pos
