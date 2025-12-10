extends Node3D

@onready var players_node = $Players
@export var player_scene: PackedScene 

func _ready():
	# 1. Listen for Respawn requests (from our previous step)
	if SignalBus.has_signal("respawn_requested"):
		SignalBus.respawn_requested.connect(_on_respawn_requested)

	# 2. THE HANDSHAKE
	# We do NOT spawn players immediately in _ready().
	# Instead, we tell the server: "I have finished loading the level!"
	if multiplayer.is_server():
		# Host is always ready immediately, so they register themselves
		_register_player.rpc(1)
	else:
		# Client tells the server they are ready
		_register_player.rpc_id(1, multiplayer.get_unique_id())

# This function runs on the Server when a client finishes loading
@rpc("any_peer", "call_local", "reliable")
func _register_player(new_player_id):
	if multiplayer.is_server():
		# The server receives the ID and NOW spawns the player
		_spawn_player(new_player_id)

func _spawn_player(id):
	# Check if player already exists (to prevent double spawns)
	if players_node.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	
	if has_node("SpawnPoint"):
		player.position = $SpawnPoint.position
		player.rotation = $SpawnPoint.rotation
	else:
		player.position = Vector3(0, 10, 0) 

	player.set_multiplayer_authority(id)
	players_node.add_child(player)

# --- RESPAWN LOGIC (Kept from before) ---
func _on_respawn_requested():
	respawn_me_on_server.rpc_id(1)

@rpc("any_peer", "call_local")
func respawn_me_on_server():
	var sender_id = multiplayer.get_remote_sender_id()
	
	var existing_player = players_node.get_node_or_null(str(sender_id))
	if existing_player:
		existing_player.name = str(sender_id) + "_dying"
		existing_player.queue_free()
		
	_spawn_player(sender_id)
