# checkpoint.gd
extends Area3D

# This is a signal we will send to the main race manager when the player enters.
signal player_entered(checkpoint_id)

# We can set the ID of each checkpoint in the editor.
@export var checkpoint_id = 0

func _on_body_entered(body):
	# This function is called automatically when a physics body enters the Area3D.
	# First, we check if the body that entered is the player.
	# We can do this by checking if it has the "RCCar" class name.
	if body.is_in_group("player"):
		# If it is the player, emit our custom signal and pass our ID.
		player_entered.emit(checkpoint_id)
		# Optional: Disable the checkpoint after it's been hit once per lap
		# to prevent re-triggering. We'll re-enable it later.
		$CollisionShape3D.disabled = true

# This function shows the visible part of the checkpoint.
func show_visuals():
	$MeshInstance3D.show()

# This function hides the visible part of the checkpoint.
func hide_visuals():
	$MeshInstance3D.hide()
