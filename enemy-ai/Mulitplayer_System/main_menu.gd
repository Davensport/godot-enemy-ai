extends Control

# --- MENU PAGE REFERENCES ---
@onready var menu_root = $MenuContainer/MenuRoot
@onready var menu_play_select = $MenuContainer/MenuPlaySelection
@onready var menu_host_setup = $MenuContainer/MenuHostSetup
@onready var menu_join_lobby = $MenuContainer/MenuJoinLobby
@onready var menu_settings = $MenuContainer/MenuSettings

# --- INPUT REFERENCES ---
@onready var lobby_id_input = $MenuContainer/MenuJoinLobby/LobbyIdInput
@onready var steam_name_label: Label = $MenuContainer/SteamNameLabel

# --- SETTINGS UI REFERENCES ---
@onready var fullscreen_check = $MenuContainer/MenuSettings/SettingsContent/VideoRow/FullScreenCheck
# NEW: Reference to the ProgressBar instead of the Slider
@onready var master_volume_progress = $MenuContainer/MenuSettings/SettingsContent/AudioRow/MasterVolumeProgress

# --- AUDIO STATE ---
var master_bus_index: int
var is_dragging_volume: bool = false # Tracks if player is holding mouse down on the bar

func _ready():
	# 1. SETUP STEAM NAME
	var current_name = Global.player_name
	if Steam.isSteamRunning():
		current_name = Steam.getPersonaName()
	
	if steam_name_label:
		steam_name_label.text = "Logged in as: " + current_name

	# 2. SETUP AUDIO INDEX
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# 3. SYNC UI WITH CURRENT SETTINGS
	# Sync Fullscreen Checkbox
	var current_mode = DisplayServer.window_get_mode()
	if fullscreen_check:
		fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Sync Volume Bar (Convert DB to 0-100%)
	var current_db = AudioServer.get_bus_volume_db(master_bus_index)
	if master_volume_progress:
		# db_to_linear returns 0.0 to 1.0, so we multiply by 100 for the progress bar
		master_volume_progress.value = db_to_linear(current_db) * 100.0

	# 4. SHOW ROOT PAGE
	_show_page(menu_root)
	
	# START THE MUSIC
	MusicManager.play_menu_music()

# --- HELPER FUNCTION: PAGE SWAPPER ---
func _show_page(target_page: Control):
	menu_root.visible = false
	menu_play_select.visible = false
	menu_host_setup.visible = false
	menu_join_lobby.visible = false
	menu_settings.visible = false
	
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
	if lobby_id_input:
		lobby_id_input.text = ""

func _on_btn_back_to_root_pressed():
	_show_page(menu_root)

# ==============================================================================
# 3. HOST SETUP SIGNALS
# ==============================================================================
func _on_btn_new_game_pressed():
	Global.is_loading_from_save = false
	Global.become_host()

func _on_btn_continue_pressed():
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
	
	if lobby_id_str.is_valid_int():
		var lobby_id = lobby_id_str.to_int()
		Global.join_game(lobby_id)
	else:
		print("Invalid Lobby ID format!")

func _on_btn_back_from_join_pressed():
	_show_page(menu_play_select)

# ==============================================================================
# 5. SETTINGS SIGNALS
# ==============================================================================
func _on_btn_settings_back_pressed():
	_show_page(menu_root)

func _on_fullscreen_check_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# --- VOLUME BAR INPUT HANDLER ---
# Connect the 'gui_input' signal from MasterVolumeProgress to this function!
func _on_master_volume_progress_gui_input(event):
	if not master_volume_progress: return

	# 1. Handle Click Start/End
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_volume = event.pressed
			# Update immediately on click down
			if is_dragging_volume:
				_update_volume_from_mouse_pos(event.position.x)
				
	# 2. Handle Dragging
	elif event is InputEventMouseMotion and is_dragging_volume:
		_update_volume_from_mouse_pos(event.position.x)

# Helper to calculate volume based on mouse position
func _update_volume_from_mouse_pos(local_mouse_x):
	var width = master_volume_progress.size.x
	if width == 0: return
	
	# Calculate ratio (0.0 to 1.0)
	var ratio = clamp(local_mouse_x / width, 0.0, 1.0)
	
	# Update UI (0 to 100)
	master_volume_progress.value = ratio * 100.0
	
	# Update Audio (Linear to DB)
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(ratio))
	
	# Mute if silent
	AudioServer.set_bus_mute(master_bus_index, ratio < 0.01)
