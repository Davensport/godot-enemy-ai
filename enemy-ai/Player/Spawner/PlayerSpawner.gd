class_name PlayerSpawner
extends Marker3D

@export_group("Assets")
@export var player_scene: PackedScene
@export var hud_scene: PackedScene

# We keep track of the HUD so we can delete the old one when respawning
var current_hud_instance: Node = null

func _ready():
	# Listen for the UI button request
	SignalBus.respawn_requested.connect(_on_respawn_requested)
	
	# Initial Spawn
	call_deferred("_spawn_player_and_ui")

func _spawn_player_and_ui():
	if not player_scene:
		push_error("PlayerSpawner: No Player Scene assigned!")
		return
		
	# Add Player to the Scene
	# EMIT THIS WITH THE INSTANCE:

	# --- 1. Instantiate the Player ---
	var player_instance = player_scene.instantiate()
	
	# Force name so enemies find it
	player_instance.name = "player"
	
	# Align Player with Spawner
	player_instance.global_transform = global_transform
	
	# Add Player to the Scene
	get_parent().add_child(player_instance)
	#SignalBus.player_spawned.emit(player_instance)
	SignalBus.player_spawned.emit()
	
	
	# Notify system (Optional, if you use this signal)
	# SignalBus.player_spawned.emit()
	
	# --- 2. Instantiate and Connect UI ---
	if hud_scene:
		var hud_instance = hud_scene.instantiate()
		current_hud_instance = hud_instance 
		
		# Add UI to the Scene
		get_tree().current_scene.add_child(hud_instance)
		
		# THE MAGIC: Wire them together
		if hud_instance.has_method("setup_ui"):
			hud_instance.setup_ui(player_instance)

# This function is now triggered by the UI Button via SignalBus
func _on_respawn_requested():
	print("Respawn requested. Resetting state...")
	
	# 1. DO NOT Delete the HUD
	# We want to keep the HUD, just hide the death screen (which the HUD script handles now).
	# if current_hud_instance ... -> DELETE THIS
		
	# 2. DO NOT Delete the Player
	# Our RootController handles the teleport and health reset.
	# var old_player = ... -> DELETE THIS
	# old_player.queue_free() -> DELETE THIS
	
	pass
	
	# 3. Wait a frame for deletion to finish, then spawn anew
	await get_tree().process_frame 
	_spawn_player_and_ui()
