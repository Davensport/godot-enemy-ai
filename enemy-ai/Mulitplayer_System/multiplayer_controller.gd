extends CharacterBody3D

# --- NODES ---
@onready var anim_player: AnimationPlayer = $"Mesh/Root Scene/AnimationPlayer"
@onready var camera: Node3D = $CameraRig/Camera3D
@onready var username_label = $Label3D
@export var network_color := Color.WHITE:
	set(value):
		network_color = value
		_apply_color_to_mesh()

# --- CONFIGURATION ---
@export var speed := 5.0
const JUMP_VELOCITY = 4.5

# --- STATE VARIABLES ---
var do_jump = false # Read by multiplayer_input.gd
var _is_on_floor = true

# --- NETWORK SETUP ---
@export var player_id := 1:
	set(id):
		player_id = id
		# We set the authority of the INPUT node to the specific player ID
		if has_node("InputSynchronizer"):
			$InputSynchronizer.set_multiplayer_authority(id)

func _enter_tree():
	# CRITICAL FIX FOR FROZEN MOVEMENT:
	# 1. The Body (Position/Physics) MUST be owned by the Server (1).
	set_multiplayer_authority(1)
	
	# 2. The Input (WASD) MUST be owned by the Player (Client).
	var client_id = name.to_int()
	if has_node("InputSynchronizer"):
		$InputSynchronizer.set_multiplayer_authority(client_id)

func _ready() -> void:
	# 1. Setup Camera for local player only
	if multiplayer.get_unique_id() == name.to_int():
		$CameraRig/Camera3D.make_current()

	# 2. Wait a moment to prevent RPC errors
	await get_tree().create_timer(0.5).timeout

	# 3. Handle Name Tags
	# We ask the "Owner" of the input who they are
	if name.to_int() == multiplayer.get_unique_id():
		_set_steam_name()
	else:
		request_name_info.rpc_id(name.to_int())
		
# APPLY COLOR
	if name.to_int() == multiplayer.get_unique_id():
		# I am the owner, so I grab the color I picked in the lobby
		network_color = Global.my_player_color
	
	# Note: Add 'network_color' to the Player's MultiplayerSynchronizer!

func _apply_color_to_mesh():
	var mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Wizard_001" # Adjust path
	var mat = mesh.get_active_material(0).duplicate()
	mat.albedo_color = network_color
	mesh.set_surface_override_material(0, mat)

# --- NAME SYNC LOGIC ---

func _set_steam_name():
	var my_name = Steam.getPersonaName()
	username_label.text = my_name
	set_network_name.rpc(my_name)

@rpc("any_peer", "call_remote", "reliable")
func request_name_info():
	var sender_id = multiplayer.get_remote_sender_id()
	set_network_name.rpc_id(sender_id, Steam.getPersonaName())

@rpc("any_peer", "call_local", "reliable")
func set_network_name(name_to_set: String):
	username_label.text = name_to_set

# --- PHYSICS & MOVEMENT ---

func _physics_process(delta: float) -> void:
	# 1. SERVER calculates the physics/movement
	if multiplayer.is_server():
		_apply_movement_front_input(delta)
		
	# 2. ALL PEERS run animations based on the Server's synced velocity
	_apply_animimations(delta)

func _apply_movement_front_input(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Check for Jump (set by the Input script via RPC)
	if do_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		do_jump = false

	# GET INPUTS FROM THE SYNCHRONIZER
	# Note: We access the 'input_direction' var from the input script
	var input_dir = %InputSynchronizer.input_direction
	var client_camera_yaw = %InputSynchronizer.camera_yaw
	
	var basis_to_use = Basis.from_euler(Vector3(0, client_camera_yaw, 0))
	var direction = (basis_to_use * Vector3(input_dir.x, 0, input_dir.y))
	
	direction = Vector3(direction.x, 0, direction.z).normalized() * input_dir.length()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	turn_to(direction)

func turn_to(direction: Vector3) -> void:
	if direction:
		var yaw := atan2(-direction.x, -direction.z)
		var target_rotation = lerp_angle(rotation.y, yaw, 0.25)
		rotation.y = target_rotation

func _apply_animimations(_delta):
	var current_speed := velocity.length()
	const RUN_SPEED := 3.5
	const BLEND_SPEED := 0.2
	
	if current_speed > RUN_SPEED:
		anim_player.play("CharacterArmature|Run", BLEND_SPEED)
	elif current_speed > 0.0:
		anim_player.play("CharacterArmature|Walk", BLEND_SPEED, lerp(0.5, 1.75, current_speed/RUN_SPEED))
	else:
		anim_player.play("CharacterArmature|Idle")
