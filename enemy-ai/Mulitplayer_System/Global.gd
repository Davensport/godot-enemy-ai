extends Node

# --- SIGNALS ---
signal lobby_joined(lobby_id)
signal player_list_updated

# --- CONFIGURATION ---
const LOBBY_NAME = "DAVENSPORT TEST"
const LOBBY_MODE = "CoOP"
const MAX_PLAYERS = 4

# --- SCENE PATHS ---
const LOBBY_MENU_SCENE = "res://Mulitplayer_System/LobbyWaitingRoom.tscn"
const GAME_SCENE = "res://scenes/main.tscn"

# --- RESOURCES ---
# Ensure this points to your ACTUAL Player.tscn
var multiplayer_scene = preload("res://Player/MainPlayerScn/Player.tscn")

# --- VARIABLES ---
var _hosted_lobby_id = 0
var steam_peer = SteamMultiplayerPeer.new()
var players_loaded = 0

# --- COLOR SYSTEM (Fixed) ---
# We use this to store colors so we can apply them during spawn
var player_colors = {} 

func _ready():
	Steam.steamInit()
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.persona_state_change.connect(_on_persona_change)

func _process(_delta):
	Steam.run_callbacks()

# ==============================================================================
# COLOR SYNC (NEW & CRITICAL)
# ==============================================================================
# This function allows Clients to tell the Host "I picked this color!"
@rpc("any_peer", "call_local", "reliable")
func register_player_color(new_color):
	var sender_id = multiplayer.get_remote_sender_id()
	player_colors[sender_id] = new_color
	# Optional: Print for debug
	print("Registered Color for Peer %s: %s" % [sender_id, new_color])

# ==============================================================================
# HOSTING / JOINING (Standard)
# ==============================================================================
func become_host() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_lobby_created(connect: int, lobby_id: int):
	if connect == 1:
		_hosted_lobby_id = lobby_id
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)
		
		var error = steam_peer.create_host(0)
		if error == OK:
			multiplayer.set_multiplayer_peer(steam_peer)
			call_deferred("_switch_to_lobby_menu")

func join_game(lobby_id: int):
	_hosted_lobby_id = lobby_id
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby: int, permissions: int, locked: bool, response: int):
	if response == 1:
		var owner_id = Steam.getLobbyOwner(lobby)
		if owner_id != Steam.getSteamID():
			connect_socket(owner_id)
		call_deferred("_switch_to_lobby_menu")
		lobby_joined.emit(lobby)

func _on_join_requested(lobby_id: int, friend_id: int):
	join_game(lobby_id)

func connect_socket(steam_id: int):
	var error = steam_peer.create_client(steam_id, 0)
	if error == OK:
		multiplayer.set_multiplayer_peer(steam_peer)

# ==============================================================================
# SCENE MANAGEMENT
# ==============================================================================
func _switch_to_lobby_menu():
	get_tree().change_scene_to_file(LOBBY_MENU_SCENE)

@rpc("call_local", "reliable")
func start_game():
	# Reset the loading counter when starting a new game
	players_loaded = 0
	
	var scene = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene

# ==============================================================================
# SPAWNING LOGIC (Fixed)
# ==============================================================================

@rpc("any_peer", "call_local", "reliable")
func player_loaded_level():
	if multiplayer.is_server():
		players_loaded += 1
		var total_players = multiplayer.get_peers().size() + 1
		
		if players_loaded >= total_players:
			server_spawn_players()

func server_spawn_players():
	var players_node = get_tree().current_scene.get_node_or_null("Players")
	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoint")
	
	if not players_node:
		print("Error: No 'Players' node found in level!")
		return

	var all_peer_ids = multiplayer.get_peers()
	all_peer_ids.append(1)
	
	var index = 0
	for id in all_peer_ids:
		# 1. Instantiate
		var player_instance = multiplayer_scene.instantiate()
		player_instance.name = str(id)
		
		# 2. APPLY COLOR (The Fix)
		# We use the correct variable name 'player_color' from RootController.gd
		if id in player_colors:
			# FIX: Variable name mismatch fixed here (was network_color)
			player_instance.player_color = player_colors[id]
		
		# 3. Add to Scene
		players_node.add_child(player_instance, true)
		
		# 4. Position
		var offset = Vector3(index * 2, 0, 0)
		if spawn_point:
			player_instance.global_position = spawn_point.global_position + offset
		else:
			player_instance.global_position = Vector3(0, 10, 0) + offset
			
		index += 1

# ==============================================================================
# HELPER FUNCTIONS
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
