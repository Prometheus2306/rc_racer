# RaceManager.gd
extends Node

# --- Race State ---
var current_lap = 1
var next_checkpoint_id = 0
var total_checkpoints = 0


func _ready():
	# Wait a frame to make sure all nodes are ready
	await get_tree().create_timer(0.1).timeout
	
	var checkpoints = get_tree().get_nodes_in_group("checkpoints")
	total_checkpoints = checkpoints.size()
	
	print("Race started! Total checkpoints: ", total_checkpoints)
	print("Next checkpoint is: 0")

	# Go through each checkpoint and connect its signal to our function
	for cp in checkpoints:
		cp.player_entered.connect(_on_checkpoint_entered)
		
	# NEW: Call the visibility update function at the start of the race.
	update_checkpoint_visibility()


# NEW: This function loops through all checkpoints and shows only the next one.
func update_checkpoint_visibility():
	# Get all nodes in the "checkpoints" group
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp.checkpoint_id == next_checkpoint_id:
			# If this checkpoint's ID matches the one we're looking for, show it.
			cp.show_visuals()
		else:
			# Otherwise, hide it.
			cp.hide_visuals()


func _on_checkpoint_entered(entered_id):
	# Check if the player hit the checkpoint we were expecting.
	if entered_id == next_checkpoint_id:
		print("Correct checkpoint hit: ", entered_id)
		
		# If this was the last checkpoint on the track...
		if entered_id == total_checkpoints - 1:
			#...the next one is the finish line (checkpoint 0) to complete the lap.
			next_checkpoint_id = 0
			current_lap += 1
			print("--- Lap ", current_lap, " completed! ---")
			# Re-enable all checkpoint colliders for the new lap
			for cp in get_tree().get_nodes_in_group("checkpoints"):
				cp.get_node("CollisionShape3D").disabled = false
		else:
			# If it wasn't the last one, just aim for the next one in the sequence.
			next_checkpoint_id += 1
			
		print("Next checkpoint is: ", next_checkpoint_id)
		
		# MODIFIED: Call the visibility update function every time we hit a checkpoint.
		update_checkpoint_visibility()


func _on_out_of_bounds_area_body_entered(body):
	# Check if it was the player who fell out of the world.
	if body.is_in_group("player"):
		print("Player is out of bounds! Respawning...")
		# Call a new respawn function on the car's script.
		body.respawn()
