extends Node

# --- SIGNALS ---
signal lobby_joined(lobby_id)
signal player_list_updated

# --- CONFIGURATION ---
const LOBBY_NAME = "DAVENSPORT TEST"
const LOBBY_MODE = "CoOP"
const MAX_PLAYERS = 4

# --- SCENE PATHS ---
# 1. The Waiting Room (From your previous message)
const LOBBY_MENU_SCENE = "res://Mulitplayer_System/LobbyWaitingRoom.tscn" 

# 2. The Actual Game Level (Updated path)
const GAME_SCENE = "res://scenes/main.tscn"

# --- RESOURCES ---
# Ensure this points to your player file
var multiplayer_scene = preload("res://Player/MainPlayerScn/Player.tscn")

# --- VARIABLES ---
var _hosted_lobby_id = 0
var steam_peer = SteamMultiplayerPeer.new()
var players_loaded = 0

var my_player_color = Color.WHITE
# Add this near your other variables
var player_colors = {} # A dictionary to store { PeerID : Color }

func _ready():
	Steam.steamInit()
	
	# Connect Critical Signals
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.persona_state_change.connect(_on_persona_change)

func _process(_delta):
	Steam.run_callbacks()

# ==============================================================================
# 1. HOSTING LOGIC
# ==============================================================================
func become_host() -> void:
	print("Starting Host...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_lobby_created(connect: int, lobby_id: int):
	if connect == 1:
		_hosted_lobby_id = lobby_id
		print("Created lobby: %s" % _hosted_lobby_id)
		
		# Set Lobby Data
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)
		
		# Initialize Host Network
		var error = steam_peer.create_host(0)
		if error == OK:
			multiplayer.set_multiplayer_peer(steam_peer)
			print("Host Network created.")
			call_deferred("_switch_to_lobby_menu")
		else:
			print("Failed to create host network: %s" % error)

# ==============================================================================
# 2. JOINING LOGIC
# ==============================================================================

# Triggered by Steam Invite
func _on_join_requested(lobby_id: int, friend_id: int):
	print("Received invite from Friend %s to Lobby %s" % [friend_id, lobby_id])
	join_game(lobby_id)

func join_game(lobby_id: int):
	print("Attempting to join lobby room: %s" % lobby_id)
	_hosted_lobby_id = lobby_id
	
	# Ask Steam to put us in the room. Wait for callback.
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby: int, permissions: int, locked: bool, response: int):
	print("Lobby Join Response: %s" % response)
	
	if response == 1:
		# Success! Check if we are a client
		var owner_id = Steam.getLobbyOwner(lobby)
		if owner_id != Steam.getSteamID():
			print("I am a client. Connecting socket to Owner: %s" % owner_id)
			connect_socket(owner_id)
		
		call_deferred("_switch_to_lobby_menu")
		lobby_joined.emit(lobby)
	else:
		print("Failed to join lobby. Error Code: %s" % response)

func connect_socket(steam_id: int):
	var error = steam_peer.create_client(steam_id, 0)
	if error == OK:
		print("Client socket connected!")
		multiplayer.set_multiplayer_peer(steam_peer)
	else:
		print("Error creating client socket: %s" % error)

# ==============================================================================
# 3. SCENE MANAGEMENT & GAME START
# ==============================================================================

func _switch_to_lobby_menu():
	get_tree().change_scene_to_file(LOBBY_MENU_SCENE)

# Make sure this has @rpc!
@rpc("call_local", "reliable")
func start_game():
	# Load the actual level
	var scene = load(GAME_SCENE).instantiate()
	
	# Switch the scene on the current device
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free() # Delete the Lobby
	get_tree().current_scene = scene

# ==============================================================================
# 4. SPAWNING LOGIC
# ==============================================================================

# Called by Main.gd on every client when the map finishes loading
@rpc("any_peer", "call_local", "reliable")
func player_loaded_level():
	if multiplayer.is_server():
		
		# --- SAFETY CHECK: Prevent double counting ---
		var total_players = multiplayer.get_peers().size() + 1
		if players_loaded >= total_players:
			return
		# ---------------------------------------------

		players_loaded += 1
		print("Player Loaded! Total: %s" % players_loaded)
		
		if players_loaded == total_players:
			print("All players loaded. Spawning characters!")
			server_spawn_players()

func server_spawn_players():
	var players_node = get_tree().current_scene.get_node("Players")
	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoint")
	
	if not players_node:
		printerr("CRITICAL: Could not find 'Players' node in the scene!")
		return

	var all_peer_ids = multiplayer.get_peers()
	all_peer_ids.append(1)
	
	# Create an index counter to calculate spacing
	var index = 0
	
	for id in all_peer_ids:
		var player_instance = multiplayer_scene.instantiate()
		player_instance.name = str(id)
		player_instance.player_id = id 
		
		# --- INSTANT COLOR FIX ---
		# Apply the color BEFORE adding to the tree so there is no delay/flash.
		if id in player_colors:
			player_instance.network_color = player_colors[id]
		
		# 1. Add to Tree FIRST
		players_node.add_child(player_instance, true)
		
		# 2. Calculate Offset (2 meters apart along X axis)
		var spawn_offset = Vector3(index * 2, 0, 0)
		
		# 3. Set Position SECOND
		if spawn_point:
			player_instance.global_position = spawn_point.global_position + spawn_offset
		else:
			player_instance.global_position = Vector3(0, 5, 0) + spawn_offset
			
		index += 1
# ==============================================================================
# 5. HELPER FUNCTIONS
# ==============================================================================
func get_lobby_members():
	var members = []
	var num_members = Steam.getNumLobbyMembers(_hosted_lobby_id)
	for i in range(num_members):
		var member_steam_id = Steam.getLobbyMemberByIndex(_hosted_lobby_id, i)
		var member_name = Steam.getFriendPersonaName(member_steam_id)
		members.append(member_name)
	return members

func _on_lobby_chat_update(_lobby_id, _change_id, _making_change_id, _chat_state):
	player_list_updated.emit()

func _on_persona_change(_steam_id, _flag):
	player_list_updated.emit()
