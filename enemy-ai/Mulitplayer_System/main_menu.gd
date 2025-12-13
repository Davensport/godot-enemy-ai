extends Control

# Reference the text box you just added
@onready var lobby_input = $Panel/VBoxContainer/LobbyInput 
@onready var steam_name_label: Label = $Panel/SteamNameLabel

func _ready():
	# Check if Steam is running
	if Steam.isSteamRunning():
		var name = Steam.getPersonaName()
		steam_name_label.text = "Logged in as: " + str(name)
	else:
		steam_name_label.text = "Steam not running (Debug Mode)"
		steam_name_label.modulate = Color.RED # Make it red to warn you!


func _on_host_button_pressed():
	Global.become_host()

# This is your existing "Join Game" button
func _on_join_button_pressed():
	# 1. Get the text from the box
	var lobby_id_text = lobby_input.text
	
	# 2. Basic validation (make sure it's not empty)
	if lobby_id_text == "":
		print("Error: Lobby ID is empty.")
		return

	# 3. Convert String -> Int and Join
	# Note: Steam IDs are large 64-bit integers, so we use int()
	var lobby_id = int(lobby_id_text)
	
	print("Joining Lobby ID: " + str(lobby_id))
	Global.join_game(lobby_id)

func _on_quit_button_pressed():
	get_tree().quit()
