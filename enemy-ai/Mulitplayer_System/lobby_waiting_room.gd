extends Node3D

# --- 3D RESOURCES ---
@onready var spawner = $MultiplayerSpawner
# Adjust path if needed!
@onready var lobby_character_scene = preload("res://Mulitplayer_System/LobbyCharacter.tscn")
@onready var podiums = [$Podium1, $Podium2, $Podium3, $Podium4]

# --- UI RESOURCES ---
@onready var color_picker = $CanvasLayer/UI/ColorPickerBtn
@onready var lobby_id_label = $CanvasLayer/LobbyCodeLabel
@onready var copy_button = $CanvasLayer/LobbyCodeLabel/CopyButton
@onready var start_game_button = $CanvasLayer/UI/StartGameButton 
@onready var ready_button = $CanvasLayer/UI/ReadyButton           

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

	Global.player_list_updated.connect(_refresh_display)

# --- PEER MANAGEMENT ---

func _init_host_ready_state():
	# Initialize the host as Not Ready
	ready_status[1] = false

func _on_peer_connected(id):
	# New players start as Not Ready
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
	
	# Cleanup
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			if not id in peers:
				child.queue_free()
	
	# Spawn / Update
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
		
		# --- UPDATE 3D VISUALS ---
		# Apply the checkmark immediately if they are already ready
		var is_ready = ready_status.get(id, false)
		if char_instance.has_method("set_ready_visuals"):
			char_instance.set_ready_visuals(is_ready)
		
		char_instance.position = podiums[index].position
		char_instance.rotation = podiums[index].rotation
		index += 1

func _refresh_display():
	if multiplayer.is_server():
		_spawn_lobby_players()

# --- COLOR LOGIC ---
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
#  READY SYSTEM LOGIC
# ==============================================================================

# 1. CLIENT CLICKS BUTTON
func _on_ready_button_pressed():
	_rpc_toggle_ready.rpc_id(1)

# 2. SERVER PROCESSES REQUEST
@rpc("any_peer", "call_local", "reliable")
func _rpc_toggle_ready():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var current_state = ready_status.get(sender_id, false)
	
	# Toggle state
	ready_status[sender_id] = !current_state
	
	# Send update to everyone
	_sync_ready_status.rpc(ready_status)
	
	# Check if game can start
	_check_can_start()

# 3. SERVER CHECKS ALL PLAYERS
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

# 4. CLIENTS UPDATE UI & 3D WORLD
@rpc("call_local", "reliable")
func _sync_ready_status(new_status):
	ready_status = new_status
	
	# A. Update My UI Button
	var my_id = multiplayer.get_unique_id()
	var am_i_ready = ready_status.get(my_id, false)
	
	if am_i_ready:
		ready_button.text = "READY! (Cancel)"
		ready_button.modulate = Color.GREEN 
	else:
		ready_button.text = "READY UP" 
		ready_button.modulate = Color.WHITE

	# B. Update 3D Characters (Show Checkmarks)
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
