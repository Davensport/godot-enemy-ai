extends Node3D

# --- 3D RESOURCES ---
@onready var spawner = $MultiplayerSpawner
@onready var lobby_character_scene = preload("res://Mulitplayer_System/LobbyCharacter.tscn")
@onready var podiums = [$Podium1, $Podium2, $Podium3, $Podium4]
@onready var main_camera = $Camera3D 

# --- UI RESOURCES ---
@onready var lobby_id_label = $CanvasLayer/LobbyCodeLabel
@onready var copy_button = $CanvasLayer/LobbyCodeLabel/CopyButton
@onready var start_game_button = $CanvasLayer/UI/StartGameButton 
@onready var ready_button = $CanvasLayer/UI/ReadyButton
# Make sure you instantiated this scene in the CanvasLayer!
@onready var customizer_ui = $CanvasLayer/LobbyCustomizer 

# --- STATE ---
var ready_status: Dictionary = {}

func _ready():
	lobby_id_label.text = "Lobby ID: " + str(Global._hosted_lobby_id)
	
	if multiplayer.is_server():
		start_game_button.visible = true
		start_game_button.disabled = true
		ready_button.visible = true
		
		_init_host_ready_state()
		_update_lobby_nodes()
		
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else:
		start_game_button.visible = false
		ready_button.visible = true
		
		# CLIENT: We might have joined AFTER the spawn happened. Check immediately.
		_update_lobby_nodes()

	# --- FIX: LISTEN FOR SPAWNS ---
	# This ensures that AS SOON AS the node appears, we attach the UI.
	spawner.spawned.connect(_on_spawner_spawned)

	# Listen for Global updates
	Global.player_list_updated.connect(_refresh_display)
	Global.customization_updated.connect(_refresh_display)


func _on_spawner_spawned(_node):
	# The spawner just created a character. Update visuals immediately!
	_update_lobby_nodes()


# --- PEER MANAGEMENT ---

func _init_host_ready_state():
	ready_status[1] = false

func _on_peer_connected(id):
	ready_status[id] = false
	_sync_ready_status.rpc(ready_status) 
	_update_lobby_nodes()
	_check_can_start()

func _on_peer_disconnected(id):
	if ready_status.has(id):
		ready_status.erase(id)
	_update_lobby_nodes()
	_check_can_start()

# ==============================================================================
#  CORE LOBBY LOGIC
# ==============================================================================
func _update_lobby_nodes():
	# 1. SERVER ONLY: MANAGE SPAWNING
	if multiplayer.is_server():
		var peers = multiplayer.get_peers()
		peers.append(1) 
		
		for child in get_children():
			if child.name.is_valid_int():
				var id = child.name.to_int()
				if not id in peers:
					child.queue_free()
		
		for id in peers:
			if not has_node(str(id)):
				var char_instance = lobby_character_scene.instantiate()
				char_instance.name = str(id)
				if id == multiplayer.get_unique_id():
					char_instance.player_name = Steam.getPersonaName()
				add_child(char_instance, true)

	# 2. EVERYONE: UPDATE VISUALS
	var index = 0
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			
			# A. Position
			if index < podiums.size():
				child.position = podiums[index].position
				
				# --- OLD: RELIED ON PODIUM ROTATION ---
				# child.rotation = podiums[index].rotation
				
				# --- NEW: FORCE THEM TO FACE FORWARD ---
				# This forces Rotation Y to 0 (or 180).
				# Try Vector3.ZERO first. If they face backwards, change it to Vector3(0, PI, 0).
				child.rotation = Vector3.ZERO
			
			# B. Apply Global Customization
			if id in Global.player_customization:
				if child.has_method("apply_customization_data"):
					child.apply_customization_data(Global.player_customization[id])
			
			# C. Ready Checkmarks
			var is_ready = ready_status.get(id, false)
			if child.has_method("set_ready_visuals"):
				child.set_ready_visuals(is_ready)
			
			# D. ATTACH UI (The Fix)
			# Only attach if this is MY character
			if id == multiplayer.get_unique_id():
				if customizer_ui:
					customizer_ui.visible = true
					customizer_ui.target_player_node = child
					customizer_ui.main_camera = main_camera
			
			index += 1

func _refresh_display():
	_update_lobby_nodes()

# ==============================================================================
#  READY SYSTEM
# ==============================================================================

func _on_ready_button_pressed():
	_rpc_toggle_ready.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _rpc_toggle_ready():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	var current_state = ready_status.get(sender_id, false)
	ready_status[sender_id] = !current_state
	_sync_ready_status.rpc(ready_status)
	_check_can_start()

func _check_can_start():
	var all_ready = true
	for id in ready_status:
		if ready_status[id] == false:
			all_ready = false
			break
	start_game_button.disabled = not all_ready
	if all_ready:
		start_game_button.modulate = Color.GREEN
		start_game_button.text = "START GAME"
	else:
		start_game_button.modulate = Color.GRAY
		start_game_button.text = "Waiting..."

@rpc("call_local", "reliable")
func _sync_ready_status(new_status):
	ready_status = new_status
	var my_id = multiplayer.get_unique_id()
	var am_i_ready = ready_status.get(my_id, false)
	
	if am_i_ready:
		ready_button.text = "READY! (Cancel)"
		ready_button.modulate = Color.GREEN 
	else:
		ready_button.text = "READY UP" 
		ready_button.modulate = Color.WHITE
	_update_lobby_nodes()

# ==============================================================================
# UI BUTTON LOGIC
# ==============================================================================
func _on_copy_button_pressed():
	DisplayServer.clipboard_set(str(Global._hosted_lobby_id))
	var original_text = copy_button.text
	copy_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_button.text = original_text

func _on_invite_friends_pressed():
	Steam.activateGameOverlayInviteDialog(Global._hosted_lobby_id)

func _on_start_game_pressed():
	if multiplayer.is_server():
		Global.start_game.rpc()
