extends Node3D

# --- 3D RESOURCES ---
@onready var spawner = $MultiplayerSpawner
@onready var lobby_character_scene = preload("res://Mulitplayer_System/LobbyCharacter.tscn")
@onready var podiums = [$Podium1, $Podium2, $Podium3, $Podium4]
@onready var main_camera = $Camera3D # Needed for the floating UI calculation

# --- UI RESOURCES ---
@onready var lobby_id_label = $CanvasLayer/LobbyCodeLabel
@onready var copy_button = $CanvasLayer/LobbyCodeLabel/CopyButton
@onready var start_game_button = $CanvasLayer/UI/StartGameButton 
@onready var ready_button = $CanvasLayer/UI/ReadyButton
@onready var customizer_ui: Control = $CanvasLayer/UI/LobbyCustomizer


# --- STATE ---
var ready_status: Dictionary = {} # Stores { peer_id : true/false }

func _ready():
	lobby_id_label.text = "Lobby ID: " + str(Global._hosted_lobby_id)
	
	# 1. SETUP BUTTONS INITIAL STATE
	if multiplayer.is_server():
		start_game_button.visible = true
		start_game_button.disabled = true # Locked until everyone is ready
		ready_button.visible = true       # Host also needs to ready up!
	else:
		start_game_button.visible = false
		ready_button.visible = true

	# 2. SPAWN LOGIC
	if multiplayer.is_server():
		_init_host_ready_state()
		_spawn_lobby_players()
		
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Listen for Global updates (Customization & List changes)
	Global.player_list_updated.connect(_refresh_display)
	Global.customization_updated.connect(_refresh_display)

# --- PEER MANAGEMENT ---

func _init_host_ready_state():
	ready_status[1] = false

func _on_peer_connected(id):
	ready_status[id] = false
	_spawn_lobby_players()
	_sync_ready_status.rpc(ready_status) 
	_check_can_start()

func _on_peer_disconnected(id):
	if ready_status.has(id):
		ready_status.erase(id)
	
	_spawn_lobby_players()
	_check_can_start()

# --- MANNEQUIN LOGIC ---
func _spawn_lobby_players():
	var peers = multiplayer.get_peers()
	peers.append(1) # Add Host
	
	# Cleanup old nodes
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			if not id in peers:
				child.queue_free()
	
	# Spawn / Update Loop
	var index = 0
	for id in peers:
		if index >= podiums.size(): break
		
		var char_instance
		if has_node(str(id)):
			char_instance = get_node(str(id))
		else:
			char_instance = lobby_character_scene.instantiate()
			char_instance.name = str(id)
			
			# Set Name (Host does it immediately, Clients via RPC inside Character script)
			if id == multiplayer.get_unique_id():
				char_instance.player_name = Steam.getPersonaName()
				
			add_child(char_instance, true)
		
		# A. APPLY CUSTOMIZATION
		# We check the Global dictionary for this player's data
		if id in Global.player_customization:
			if char_instance.has_method("apply_customization_data"):
				char_instance.apply_customization_data(Global.player_customization[id])
		
		# B. APPLY READY VISUALS
		var is_ready = ready_status.get(id, false)
		if char_instance.has_method("set_ready_visuals"):
			char_instance.set_ready_visuals(is_ready)
		
		# C. SETUP FLOATING UI (Local Player Only)
		if id == multiplayer.get_unique_id():
			# This connects the floating UI to OUR character so it follows our feet
			if customizer_ui:
				customizer_ui.visible = true
				customizer_ui.target_player_node = char_instance
				customizer_ui.main_camera = main_camera
		
		# D. POSITIONING
		char_instance.position = podiums[index].position
		char_instance.rotation = podiums[index].rotation
		index += 1

func _refresh_display():
	if multiplayer.is_server():
		_spawn_lobby_players()

# ==============================================================================
#  READY SYSTEM LOGIC
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
	
	# Update My UI Button
	var my_id = multiplayer.get_unique_id()
	var am_i_ready = ready_status.get(my_id, false)
	
	if am_i_ready:
		ready_button.text = "READY! (Cancel)"
		ready_button.modulate = Color.GREEN 
	else:
		ready_button.text = "READY UP" 
		ready_button.modulate = Color.WHITE

	# Update 3D Characters (Show Checkmarks)
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			var is_peer_ready = ready_status.get(id, false)
			
			if child.has_method("set_ready_visuals"):
				child.set_ready_visuals(is_peer_ready)

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
