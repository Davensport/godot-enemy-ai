extends Node3D

@onready var players_node = $Players
"res://Player/MainPlayerScn/Player.tscn" # Drag his player scene here in the Inspector!
@export var player_scene: PackedScene 

func _ready():
	# Only the Host (Server) spawns players. 
	# The MultiplayerSpawner will copy them to the clients automatically.
	if multiplayer.is_server():
		spawn_players()

func spawn_players():
	# 1. Spawn the Host (You)
	_spawn_player(1)
	
	# 2. Spawn the Clients (Your friends)
	for id in multiplayer.get_peers():
		_spawn_player(id)

func _spawn_player(id):
	var player = player_scene.instantiate()
	player.name = str(id)
	
	# --- SPAWN LOCATION ---
	# If you have a Marker3D named "SpawnPoint", we use it.
	# Otherwise, we default to 0, 10, 0 (Sky drop) to avoid falling through floor.
	if has_node("SpawnPoint"):
		player.position = $SpawnPoint.position
		player.rotation = $SpawnPoint.rotation
	else:
		player.position = Vector3(0, 10, 0) 

	# THIS IS CRITICAL: Assign authority so inputs work!
	player.set_multiplayer_authority(id)
	
	players_node.add_child(player)
