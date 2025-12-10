extends Node3D

@onready var players_node = $Players
@export var player_scene: PackedScene 

func _ready():
	# 1. Listen for Respawn requests
	if SignalBus.has_signal("respawn_requested"):
		SignalBus.respawn_requested.connect(_on_respawn_requested)

	# 2. THE HANDSHAKE (Fixes "Client in Floor")
	# We do NOT spawn players immediately.
	# We wait for the level to fully load, then tell the server "I'm Ready!"
	if multiplayer.is_server():
		# Host is always ready immediately
		_spawn_player(1)
	else:
		# Client tells the server they are ready to receive their body
		_register_player.rpc_id(1, multiplayer.get_unique_id())

# This RPC runs on the Server when the Client finishes loading
@rpc("any_peer", "call_local", "reliable")
func _register_player(new_player_id):
	if multiplayer.is_server():
		# The server receives the signal and safe-spawns the player
		_spawn_player(new_player_id)

func _spawn_player(id):
	# Prevent duplicates
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

# --- RESPAWN LOGIC (Fixes the Error) ---
func _on_respawn_requested():
	respawn_me_on_server.rpc_id(1)

@rpc("any_peer", "call_local")
func respawn_me_on_server():
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 1. Handle the Old Body
	var existing_player = players_node.get_node_or_null(str(sender_id))
	if existing_player:
		# We delete the old body
		existing_player.queue_free()
		
		# FIX: We WAIT one frame for Godot to fully delete it.
		# This prevents the "Name Taken" error without breaking the Spawner.
		await get_tree().process_frame
		
	# 2. Spawn new body
	_spawn_player(sender_id)
