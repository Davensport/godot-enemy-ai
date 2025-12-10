extends Node3D

func _ready():
	# Wait for the end of the frame to ensure the Scene Tree is fully built.
	# This prevents "Node not found" or "not inside tree" errors.
	call_deferred("_signal_readiness")

func _signal_readiness():
	# Tell the Global script (on the Host machine ID 1) that we are done loading.
	# We only send this signal ONCE.
	Global.player_loaded_level.rpc_id(1)
