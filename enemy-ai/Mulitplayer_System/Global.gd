extends Node

# --- SIGNALS ---
signal lobby_joined(lobby_id)
signal player_list_updated
signal customization_updated

# --- CONFIGURATION ---
const LOBBY_NAME = "DAVENSPORT TEST"
const LOBBY_MODE = "CoOP"
const MAX_PLAYERS = 4

# --- SCENE PATHS ---
const LOBBY_MENU_SCENE = "res://Mulitplayer_System/LobbyWaitingRoom.tscn"
const GAME_SCENE = "res://scenes/main.tscn"

# --- RESOURCES ---
var multiplayer_scene = preload("res://Player/MainPlayerScn/Player.tscn")

# --- VARIABLES ---
var _hosted_lobby_id = 0
var steam_peer = SteamMultiplayerPeer.new()
var players_loaded = 0

# --- GLOBAL STATE ---
var player_name: String = "Guest"
var is_loading_from_save: bool = false 

# --- CUSTOMIZATION DATA ---
var player_customization = {} 
var player_colors = {} 
var my_player_color = Color.WHITE

func _ready():
	Steam.steamInit()
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.persona_state_change.connect(_on_persona_change)
	
	# --- NEW: LISTEN FOR CONNECTIONS ---
	multiplayer.peer_connected.connect(_on_server_peer_connected)

func _process(_delta):
	Steam.run_callbacks()

# ==============================================================================
# SYNC LOGIC FOR LATE JOINERS (NEW)
# ==============================================================================
func _on_server_peer_connected(id):
	# If I am the server, I hold the "Truth" of what everyone looks like.
	# When a new player 'id' joins, I send them the current list.
	if multiplayer.is_server():
		_rpc_full_sync.rpc_id(id, player_customization)

@rpc("authority", "call_remote", "reliable")
func _rpc_full_sync(server_list: Dictionary):
	# Client receives the full list and updates their local data
	player_customization = server_list
	customization_updated.emit()

# ==============================================================================
# CUSTOMIZATION UPDATES
# ==============================================================================

# 1. CLIENT CALLS THIS
func update_customization(part_name: String, color: Variant):
	_server_receive_customization.rpc_id(1, part_name, color)

# 2. SERVER RECEIVES
@rpc("any_peer", "call_local", "reliable")
func _server_receive_customization(part_name: String, color: Variant):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	_broadcast_customization.rpc(sender_id, part_name, color)

# 3. BROADCAST TO EVERYONE
@rpc("call_local", "reliable")
func _broadcast_customization(player_id: int, part_name: String, color: Variant):
	if not player_customization.has(player_id):
		player_customization[player_id] = {
			"Tunic": null,
			"Skin": null, 
			"Hair": null
		}
	
	player_customization[player_id][part_name] = color
	
	# Legacy Support
	if part_name == "Tunic" and color != null:
		player_colors[player_id] = color
	
	customization_updated.emit()

# ==============================================================================
# HOSTING / JOINING
# ==============================================================================
func become_host() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_lobby_created(_connect: int, lobby_id: int):
	if _connect == 1:
		_hosted_lobby_id = lobby_id
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)
		
		var error = steam_peer.create_host(0)
		if error == OK:
			multiplayer.set_multiplayer_peer(steam_peer)
			call_deferred("_switch_to_lobby_menu")

func join_game(lobby_id: int):
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	if steam_peer:
		steam_peer.close()
	_hosted_lobby_id = lobby_id
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int):
	if response == 1:
		var owner_id = Steam.getLobbyOwner(lobby)
		if owner_id != Steam.getSteamID():
			connect_socket(owner_id)
		call_deferred("_switch_to_lobby_menu")
		lobby_joined.emit(lobby)

func _on_join_requested(lobby_id: int, _friend_id: int):
	join_game(lobby_id)

func connect_socket(steam_id: int):
	var error = steam_peer.create_client(steam_id, 0)
	if error == OK:
		multiplayer.set_multiplayer_peer(steam_peer)

func _switch_to_lobby_menu():
	get_tree().change_scene_to_file(LOBBY_MENU_SCENE)

@rpc("call_local", "reliable")
func start_game():
	players_loaded = 0
	var scene = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene

# ==============================================================================
# SPAWNING LOGIC
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
	if not players_node: return

	var all_peer_ids = multiplayer.get_peers()
	all_peer_ids.append(1)
	
	var index = 0
	for id in all_peer_ids:
		var player_instance = multiplayer_scene.instantiate()
		player_instance.name = str(id)
		
		if id in player_customization:
			if player_instance.has_method("apply_customization_data"):
				player_instance.apply_customization_data(player_customization[id])
			if "Tunic" in player_customization[id]:
				player_instance.player_color = player_customization[id]["Tunic"]
		elif id in player_colors:
			player_instance.player_color = player_colors[id]
		
		players_node.add_child(player_instance, true)
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
		members.append(Steam.getFriendPersonaName(member_steam_id))
	return members

func _on_lobby_chat_update(_lobby_id, _change_id, _making_change_id, _chat_state):
	player_list_updated.emit()

func _on_persona_change(_steam_id, _flag):
	player_list_updated.emit()
	
func leave_lobby():
	# 1. Clear the Multiplayer Peer (Disconnects Godot logic)
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	
	# 2. Close the Steam Peer (Disconnects Steam logic)
	if steam_peer:
		steam_peer.close()
	
	# 3. Leave the actual Steam Lobby (Clean cleanup)
	if _hosted_lobby_id != 0:
		Steam.leaveLobby(_hosted_lobby_id)
		_hosted_lobby_id = 0
	
	# 4. Clear local data
	player_customization.clear()
	player_colors.clear()
	players_loaded = 0
