extends Control

# --- MENU PAGE REFERENCES ---
# Make sure these paths match your Scene Tree exactly!
@onready var menu_root = $MenuContainer/MenuRoot
@onready var menu_play_select = $MenuContainer/MenuPlaySelection
@onready var menu_host_setup = $MenuContainer/MenuHostSetup
@onready var menu_join_lobby = $MenuContainer/MenuJoinLobby
@onready var menu_settings = $MenuContainer/MenuSettings

# --- INPUT REFERENCES ---
@onready var lobby_id_input = $MenuContainer/MenuJoinLobby/LobbyIdInput

func _ready():
	# Start by showing only the main root menu
	_show_page(menu_root)

# --- HELPER FUNCTION: PAGE SWAPPER ---
func _show_page(target_page: Control):
	# 1. Hide ALL pages first
	menu_root.visible = false
	menu_play_select.visible = false
	menu_host_setup.visible = false
	menu_join_lobby.visible = false
	menu_settings.visible = false
	
	# 2. Show ONLY the one we want
	target_page.visible = true

# ==============================================================================
# 1. ROOT MENU SIGNALS
# ==============================================================================
func _on_btn_play_pressed():
	_show_page(menu_play_select)

func _on_btn_settings_pressed():
	_show_page(menu_settings)

func _on_btn_quit_pressed():
	get_tree().quit()

# ==============================================================================
# 2. PLAY SELECTION SIGNALS
# ==============================================================================
func _on_btn_host_pressed():
	_show_page(menu_host_setup)

func _on_btn_join_pressed():
	_show_page(menu_join_lobby)
	# Clear the text box so it's fresh for pasting
	if lobby_id_input:
		lobby_id_input.text = ""

func _on_btn_back_to_root_pressed():
	_show_page(menu_root)

# ==============================================================================
# 3. HOST SETUP SIGNALS
# ==============================================================================
func _on_btn_new_game_pressed():
	# Logic: Start a fresh lobby
	Global.is_loading_from_save = false
	Global.become_host()

func _on_btn_continue_pressed():
	# Logic: Load data (if you have a save system later)
	Global.is_loading_from_save = true
	Global.become_host()

func _on_btn_back_to_play_pressed():
	_show_page(menu_play_select)

# ==============================================================================
# 4. JOIN LOBBY SIGNALS
# ==============================================================================
func _on_btn_confirm_join_pressed():
	if not lobby_id_input: return
	
	var lobby_id_str = lobby_id_input.text.strip_edges()
	
	# Basic validation to ensure it's a number
	if lobby_id_str.is_valid_int():
		var lobby_id = lobby_id_str.to_int()
		Global.join_game(lobby_id)
	else:
		print("Invalid Lobby ID format!")
		# Optional: You could make the text red here to warn the user
		# lobby_id_input.modulate = Color.RED

func _on_btn_back_from_join_pressed():
	_show_page(menu_play_select)

# ==============================================================================
# 5. SETTINGS SIGNALS
# ==============================================================================
func _on_btn_settings_back_pressed():
	_show_page(menu_root)
