extends Node3D

@onready var players_node = $Players
@export var player_scene: PackedScene 

func _ready():
	# 1. DISABLE THIS CONNECTION
	# The RootController now handles respawn logic internally.
	# If we leave this connected, it will double-fire and delete the player.
	# if SignalBus.has_signal("respawn_requested"):
	# 	SignalBus.respawn_requested.connect(_on_respawn_requested)

	# 2. THE HANDSHAKE (Keep this! This is good for initial joining)
	if multiplayer.is_server():
		_spawn_player(1)
	else:
		_register_player.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func _register_player(new_player_id):
	if multiplayer.is_server():
		_spawn_player(new_player_id)

func _spawn_player(id):
	if players_node.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	
	if has_node("SpawnPoint"):
		var random_x = randf_range(-3, 3)
		var random_z = randf_range(-3, 3)
		var offset = Vector3(random_x, 0, random_z)
		
		player.position = $SpawnPoint.position + offset
		player.rotation = $SpawnPoint.rotation
	else:
		player.position = Vector3(0, 10, 0) 

	player.set_multiplayer_authority(id)
	players_node.add_child(player)

# --- RESPAWN LOGIC (DISABLED) ---
# We comment this out so it doesn't fight with RootController.gd

# func _on_respawn_requested():
# 	respawn_me_on_server.rpc_id(1)

# @rpc("any_peer", "call_local")
# func respawn_me_on_server():
# 	# THIS WAS THE KILLER!
# 	# It was deleting the player node while we were trying to teleport it.
# 	pass
