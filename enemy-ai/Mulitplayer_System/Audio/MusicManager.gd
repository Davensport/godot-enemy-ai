extends Node

@onready var menu_music = $MenuMusic


func play_menu_music():
	# CRITICAL: Only play if it's not already playing!
	if not menu_music.playing:
		menu_music.play()

func stop_menu_music():
	menu_music.stop()
