extends MultiplayerSynchronizer

# Link to the parent CharacterBody3D
@onready var player = $".."

# --- SYNCED VARIABLES ---
# Ensure these two are checked in the Replication Tab!
var input_direction := Vector2.ZERO
var camera_yaw := 0.0

func _ready() -> void:
	# CRITICAL OPTIMIZATION:
	# Only the player who owns this character (the local human) should run this code.
	# The Server and other players will receive the data via the Synchronizer,
	# so they don't need to run _process functions to calculate inputs.
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	# 1. Get WASD Input
	input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 2. Get Camera Rotation (Yaw only)
	# This allows the character to move relative to where the camera is looking
	if player.camera:
		camera_yaw = player.camera.global_rotation.y

func _process(_delta: float) -> void:
	# Handle Jump Input
	if Input.is_action_just_pressed("ui_accept"):
		jump.rpc()

# --- RPC FUNCTIONS ---
@rpc("call_local")
func jump():
	# Only the Server (who owns the Body physics) is allowed to set 'do_jump'.
	if multiplayer.is_server():
		# We check is_on_floor() here on the server to prevent air-jumping cheats
		if player.is_on_floor():
			player.do_jump = true
