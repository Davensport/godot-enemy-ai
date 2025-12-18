extends Node3D

@onready var players_node = $Players
@export var player_scene: PackedScene 

func _ready():
	# 1. CONNECT COMBAT SIGNAL
	# We listen to the SignalBus to know when enemies are aggro'd
	if SignalBus.has_signal("combat_status_changed"):
		SignalBus.combat_status_changed.connect(_on_combat_status_changed)
	else:
		push_warning("SignalBus is missing 'combat_status_changed' - Music will not switch.")

	# 2. START DEFAULT MUSIC
	# We just ask for the "mode" now, no file paths needed here!
	MusicManager.play_explore_music()
	
	# 3. MULTIPLAYER HANDSHAKE
	if multiplayer.is_server():
		_spawn_player(1)
	else:
		_register_player.rpc_id(1, multiplayer.get_unique_id())

# --- MUSIC SWITCHING LOGIC ---
func _on_combat_status_changed(is_in_combat: bool):
	# Debug print so you can verify the signal is arriving
	# print("LevelManager: Switching Music. Combat Mode: ", is_in_combat)
	
	if is_in_combat:
		MusicManager.play_combat_music()
	else:
		MusicManager.play_explore_music()

# --- PLAYER SPAWNING LOGIC (Unchanged) ---
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
