extends Node3D

# --- 3D RESOURCES ---
@onready var spawner = $MultiplayerSpawner
# Make sure this path points to your dummy character! 
# (It might be "res://Mulitplayer_System/LobbyCharacter.tscn" if you moved it)
@onready var lobby_character_scene = preload("res://Mulitplayer_System/LobbyCharacter.tscn")
@onready var podiums = [$Podium1, $Podium2, $Podium3, $Podium4]

# --- UI RESOURCES ---
@onready var color_picker = $CanvasLayer/UI/ColorPickerBtn
@onready var lobby_id_label = $LobbyCodeLabel
@onready var copy_button = $LobbyCodeLabel/CopyButton

func _ready():
	# 1. Update the Lobby ID Text
	lobby_id_label.text = "Lobby ID: " + str(Global._hosted_lobby_id)
	
	# 2. Hide "Start Game" button if I am not the host
	if not multiplayer.is_server():
		$CanvasLayer/UI/StartGameButton.visible = false
	
	# 3. Spawn Mannequins (Host Only)
	if multiplayer.is_server():
		_spawn_lobby_players()
		
		# Listen for connections to update the podiums
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 4. Listen for Steam updates (Backups for name/color changes)
	Global.player_list_updated.connect(_refresh_display)

# --- HELPER FUNCTIONS ---
func _on_peer_connected(_id):
	_spawn_lobby_players()

func _on_peer_disconnected(_id):
	_spawn_lobby_players()

# ==============================================================================
# 3D MANNEQUIN LOGIC
# ==============================================================================
func _spawn_lobby_players():
	var peers = multiplayer.get_peers()
	peers.append(1) # Add Host
	
	# 1. CLEANUP: Remove players who left
	for child in get_children():
		if child.name.is_valid_int():
			var id = child.name.to_int()
			if not id in peers:
				child.queue_free()
	
	# 2. UPDATE / SPAWN
	var index = 0
	for id in peers:
		if index >= podiums.size(): break
		
		var char_instance
		
		# SMART CHECK: Does this player already exist?
		if has_node(str(id)):
			char_instance = get_node(str(id))
		else:
			# No? Create them.
			char_instance = lobby_character_scene.instantiate()
			char_instance.name = str(id)
			
			# Host sets their own name immediately
			if id == multiplayer.get_unique_id():
				char_instance.player_name = Steam.getPersonaName()
			
			# Apply Saved Color (If they picked one earlier)
			if id in Global.player_colors:
				char_instance.player_color = Global.player_colors[id]
			
			add_child(char_instance, true)
		
		# Always update position
		char_instance.position = podiums[index].position
		char_instance.rotation = podiums[index].rotation
		
		index += 1

func _refresh_display():
	if multiplayer.is_server():
		_spawn_lobby_players()

# ==============================================================================
# COLOR PICKER LOGIC (THE CRITICAL UPDATE)
# ==============================================================================
func _on_color_picker_btn_color_changed(color):
	Global.my_player_color = color
	
	# 1. Update the visual dummy in the lobby
	var my_id = multiplayer.get_unique_id()
	if has_node(str(my_id)):
		var my_char = get_node(str(my_id))
		
		if multiplayer.is_server():
			my_char.set_color_on_server(color)
		else:
			my_char.set_color_on_server.rpc_id(1, color)

	# 2. SEND TO SERVER GLOBAL LIST (The Fix!)
	# This ensures the Host remembers your color when the level loads.
	Global.register_player_color.rpc(color)


# ==============================================================================
# UI BUTTON LOGIC
# ==============================================================================

# 1. COPY LOBBY ID
func _on_copy_button_pressed():
	DisplayServer.clipboard_set(str(Global._hosted_lobby_id))
	
	var original_text = copy_button.text
	copy_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_button.text = original_text

# 2. INVITE FRIENDS
func _on_invite_friends_pressed():
	Steam.activateGameOverlayInviteDialog(Global._hosted_lobby_id)

# 3. START GAME
func _on_start_game_pressed():
	# Only the host can start the game
	if multiplayer.is_server():
		Global.start_game.rpc()
