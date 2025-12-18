extends Node

# --- AUDIO PLAYERS ---
# Make sure you have two AudioStreamPlayers as children named 'MusicA' and 'MusicB'
@onready var _player_a = $MusicA
@onready var _player_b = $MusicB

# --- SETTINGS ---
const FADE_TIME = 1.5  # Seconds to crossfade between tracks

# --- PLAYLIST (Define your paths here!) ---
# UPDATE THESE PATHS to match your actual files
const TRACK_MAIN_MENU = "res://Mulitplayer_System/Audio/ES_The Fairy Dance - Bonnie Grace.mp3"
const TRACK_EXPLORE = "res://Mulitplayer_System/Audio/ES_Tomorrow - Hanna Lindgren.mp3"
const TRACK_COMBAT = "res://Mulitplayer_System/Audio/ES_Carriers - Jon Sumner.mp3"

# --- INTERNAL STATE ---
var _active_player: AudioStreamPlayer = null
var _inactive_player: AudioStreamPlayer = null
var _tween: Tween

# Dictionary to remember where a song left off: { "path/to/song.mp3": 45.2 }
var track_history = {} 

func _ready():
	# Initialize our double-buffer players
	_active_player = _player_a
	_inactive_player = _player_b
	
	# Ensure volumes are reset
	_active_player.volume_db = 0
	_inactive_player.volume_db = -80

# --- PUBLIC HELPER FUNCTIONS ---
# Call these from anywhere! (e.g. MusicManager.play_combat_music())

func play_menu_music():
	play_track(TRACK_MAIN_MENU)

func play_explore_music():
	play_track(TRACK_EXPLORE)

func play_combat_music():
	play_track(TRACK_COMBAT)

func stop_music():
	if _tween: _tween.kill()
	_active_player.stop()
	_inactive_player.stop()

# --- CORE LOGIC (The Brains) ---
func play_track(new_stream_path: String):
	# 1. Load the file
	var new_stream = load(new_stream_path)
	if not new_stream:
		print("MusicManager Error: Could not load file at: ", new_stream_path)
		return

	# 2. If this song is already playing, do nothing
	if _active_player.playing and _active_player.stream == new_stream:
		return

	# 3. SAVE POSITION of the current song (so we can resume it later)
	if _active_player.playing and _active_player.stream:
		var current_path = _active_player.stream.resource_path
		track_history[current_path] = _active_player.get_playback_position()

	# 4. PREPARE THE NEW PLAYER
	_inactive_player.stream = new_stream
	_inactive_player.volume_db = -80 # Start silent
	
	# Check if we have a saved position for this new song
	var start_time = 0.0
	if track_history.has(new_stream_path):
		start_time = track_history[new_stream_path]
	
	_inactive_player.play(start_time)

	# 5. CROSSFADE ANIMATION
	if _tween: _tween.kill()
	_tween = create_tween()
	
	# Fade OUT active
	_tween.parallel().tween_property(_active_player, "volume_db", -80, FADE_TIME)
	# Fade IN inactive
	_tween.parallel().tween_property(_inactive_player, "volume_db", 0, FADE_TIME)
	
	# 6. SWAP REFERENCES
	var temp = _active_player
	_active_player = _inactive_player
	_inactive_player = temp
	
	# Stop the old player once the fade finishes to save CPU
	_tween.tween_callback(_inactive_player.stop)
