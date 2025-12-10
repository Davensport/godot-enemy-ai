extends Node3D

@onready var players_node = $Players
@export var player_scene: PackedScene 

func _ready():
	# 1. Listen for the Respawn Signal
	# (We check if the signal exists just to be safe so it doesn't crash)
	if SignalBus.has_signal("respawn_requested"):
		SignalBus.respawn_requested.connect(_on_respawn_requested)
	else:
		print("ERROR: 'respawn_requested' signal missing in SignalBus!")

	# 2. Spawn Initial Players
	if multiplayer.is_server():
		spawn_players()

func spawn_players():
	_spawn_player(1)
	for id in multiplayer.get_peers():
		_spawn_player(id)

func _spawn_player(id):
	var player = player_scene.instantiate()
	player.name = str(id)
	
	if has_node("SpawnPoint"):
		player.position = $SpawnPoint.position
		player.rotation = $SpawnPoint.rotation
	else:
		player.position = Vector3(0, 10, 0) 

	player.set_multiplayer_authority(id)
	players_node.add_child(player)

# --- RESPAWN LOGIC ---
func _on_respawn_requested():
	# Ask the server to respawn us
	respawn_me_on_server.rpc_id(1)

@rpc("any_peer", "call_local")
func respawn_me_on_server():
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 1. Handle the Old Body
	var existing_player = players_node.get_node_or_null(str(sender_id))
	if existing_player:
		# --- CRITICAL FIX START ---
		# We rename the old player to "garbage" INSTANTLY.
		# This frees up the ID (e.g., "1") so the new player can take it immediately.
		existing_player.name = str(sender_id) + "_dying"
		existing_player.queue_free()
		# --- CRITICAL FIX END ---
		
	# 2. Spawn new body
	_spawn_player(sender_id)
