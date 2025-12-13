extends Node3D

# --- 3D RESOURCES ---
@onready var spawner = $MultiplayerSpawner
@onready var lobby_character_scene = preload("res://Mulitplayer_System/LobbyCharacter.tscn")
@onready var podiums = [$Podium1, $Podium2, $Podium3, $Podium4]

# --- UI RESOURCES ---
@onready var color_picker = $CanvasLayer/UI/ColorPickerBtn
@onready var lobby_id_label = $CanvasLayer/LobbyCodeLabel
@onready var copy_button = $CanvasLayer/LobbyCodeLabel/CopyButton
@onready var start_game_button = $CanvasLayer/UI/StartGameButton # Make sure name matches!
@onready var ready_button = $CanvasLayer/UI/ReadyButton           # <--- NEW BUTTON

# --- STATE ---
var ready_status: Dictionary = {} # Stores { peer_id : true/false }

func _ready():
	lobby_id_label.text = "Lobby ID: " + str(Global._hosted_lobby_id)
	
	# 1. SETUP BUTTONS
	if multiplayer.is_server():
		start_game_button.visible = true
		start_game_button.disabled = true # Default to locked until everyone is ready
		ready_button.visible = true       # Host also needs to ready up!
	else:
		start_game_button.visible = false
		ready_button.visible = true

	# 2. Spawn Mannequins (Host Only)
	if multiplayer.is_server():
		_init_host_ready_state() # Set host to false initially
		_spawn_lobby_players()
		
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	Global.player_list_updated.connect(_refresh_display)

# --- PEER MANAGEMENT ---

func _init_host_ready_state():
	# Initialize the host in the dictionary
	ready_status[1] = false

func _on_peer_connected(id):
	# When a new player joins, mark them as NOT ready
	ready_status[id] = false
	_spawn_lobby_players()
	_sync_ready_status.rpc(ready_status) # Update everyone's UI
	_check_can_start()

func _on_peer_disconnected(id):
	# If they leave, remove them from the check so they don't block the game
	if ready_status.has(id):
		ready_status.erase(id)
	
	_spawn_lobby_players()
	_check_can_start()

# --- MANNEQUIN LOGIC (Unchanged mostly) ---
func _spawn_lobby_players():
	var peers = multiplayer.get_peers()
	peers.append(1)
	
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			if not id in peers:
				child.queue_free()
	
	var index = 0
	for id in peers:
		if index >= podiums.size(): break
		
		var char_instance
		if has_node(str(id)):
			char_instance = get_node(str(id))
		else:
			char_instance = lobby_character_scene.instantiate()
			char_instance.name = str(id)
			if id == multiplayer.get_unique_id():
				char_instance.player_name = Steam.getPersonaName()
			if id in Global.player_colors:
				char_instance.player_color = Global.player_colors[id]
			add_child(char_instance, true)
		
		# --- NEW: VISUAL FEEDBACK ON MANNEQUINS ---
		# If your LobbyCharacter has a Label3D or some indicator, update it here!
		# Example:
		# if ready_status.get(id, false):
		# 	char_instance.set_ready_visuals(true) 
		
		char_instance.position = podiums[index].position
		char_instance.rotation = podiums[index].rotation
		index += 1

func _refresh_display():
	if multiplayer.is_server():
		_spawn_lobby_players()

# --- COLOR LOGIC (Unchanged) ---
func _on_color_picker_btn_color_changed(color):
	Global.my_player_color = color
	var my_id = multiplayer.get_unique_id()
	if has_node(str(my_id)):
		var my_char = get_node(str(my_id))
		if multiplayer.is_server():
			my_char.set_color_on_server(color)
		else:
			my_char.set_color_on_server.rpc_id(1, color)
	Global.register_player_color.rpc(color)

# ==============================================================================
#  READY SYSTEM LOGIC (NEW)
# ==============================================================================

# 1. Button Pressed (Client Side)
func _on_ready_button_pressed():
	# Tell the server we clicked the button
	_rpc_toggle_ready.rpc_id(1)

# 2. Server processes the request
@rpc("any_peer", "call_local", "reliable")
func _rpc_toggle_ready():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Flip the boolean (True -> False, or False -> True)
	var current_state = ready_status.get(sender_id, false)
	ready_status[sender_id] = !current_state
	
	# Send the new list to everyone so they can update their UI icons
	_sync_ready_status.rpc(ready_status)
	
	# Check if we can start the game now
	_check_can_start()

# 3. Server checks if everyone is green
func _check_can_start():
	var all_ready = true
	
	# Loop through all connected peers (plus host)
	for id in ready_status:
		if ready_status[id] == false:
			all_ready = false
			break
			
	# Update the Host's Start Button
	start_game_button.disabled = not all_ready
	
	# Optional: Change button color based on state
	if all_ready:
		start_game_button.modulate = Color.GREEN
		start_game_button.text = "START GAME"
	else:
		start_game_button.modulate = Color.GRAY
		start_game_button.text = "Waiting for players..."

# 4. Clients receive the update to change their own UI
@rpc("call_local", "reliable")
func _sync_ready_status(new_status):
	ready_status = new_status
	
	# Update MY button look
	var my_id = multiplayer.get_unique_id()
	var am_i_ready = ready_status.get(my_id, false)
	
	if am_i_ready:
		ready_button.text = "Not Ready"
		ready_button.modulate = Color.RED # Click to cancel
	else:
		ready_button.text = "Ready!"
		ready_button.modulate = Color.GREEN # Click to ready up

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
