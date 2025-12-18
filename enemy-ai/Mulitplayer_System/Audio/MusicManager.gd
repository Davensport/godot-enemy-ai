extends Node

@onready var _player_a = $MusicA
@onready var _player_b = $MusicB

var _active_player: AudioStreamPlayer = null
var _inactive_player: AudioStreamPlayer = null
var _tween: Tween

const FADE_TIME = 1.0 # Faster fade for combat feels snappier

# NEW: Dictionary to store song positions { "song_path": 12.5 }
var track_history = {} 

func _ready():
	_active_player = _player_a
	_inactive_player = _player_b

func play_track(new_stream_path: String):
	# ... (Existing load logic) ...
	var new_stream = load(new_stream_path)
	if not new_stream: return
	if _active_player.playing and _active_player.stream == new_stream: return

	# 1. SAVE POSITION OF CURRENT TRACK
	if _active_player.stream:
		var current_path = _active_player.stream.resource_path
		track_history[current_path] = _active_player.get_playback_position()

	# 2. SETUP NEW TRACK
	_inactive_player.stream = new_stream
	_inactive_player.volume_db = -80
	
	# NEW: CHECK IF WE HAVE A SAVED POSITION
	var start_time = 0.0
	if track_history.has(new_stream_path):
		start_time = track_history[new_stream_path]
	
	_inactive_player.play(start_time) # Start from saved spot!

	# 3. CROSSFADE (Same as before)
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.parallel().tween_property(_active_player, "volume_db", -80, FADE_TIME)
	_tween.parallel().tween_property(_inactive_player, "volume_db", 0, FADE_TIME)
	
	# Swap references
	var temp = _active_player
	_active_player = _inactive_player
	_inactive_player = temp
	
	_tween.tween_callback(_inactive_player.stop)

# --- HELPER FUNCTIONS ---
func play_explore_music():
	play_track("res://Mulitplayer_System/Audio/ES_Tomorrow - Hanna Lindgren.mp3")

func play_combat_music():
	play_track("res://Mulitplayer_System/Audio/ES_Carriers - Jon Sumner.mp3")
