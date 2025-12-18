class_name VoiceComponent
extends Node

# --- CONFIGURATION ---
@export var input: InputComponent
@export var audio_player: AudioStreamPlayer3D # Reference to a 3D player for spatial sound

# The name of the bus we created in Phase 1
const RECORD_BUS_NAME = "Record"
const VOICE_BUS_NAME = "VoIP"

# --- INTERNAL VARIABLES ---
var _capture_effect: AudioEffectCapture
var _playback: AudioStreamGeneratorPlayback
var _is_recording: bool = false

func _ready():
	# 1. SETUP MICROPHONE (Local Player Only)
	if is_multiplayer_authority():
		# Initialize the microphone input
		var idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
		_capture_effect = AudioServer.get_bus_effect(idx, 0) # Index 0 is the Capture effect
		
		# Connect to Input Manager
		if input:
			input.on_voice_toggled.connect(_on_voice_toggled)
	
	# 2. SETUP PLAYBACK (Everyone)
	_setup_audio_player()

func _setup_audio_player():
	if not audio_player:
		return
		
	# Create a generator. This acts as a buffer we can push raw audio bytes into.
	var generator = AudioStreamGenerator.new()
	generator.buffer_length = 0.1 # Keep buffer small for low latency
	
	audio_player.stream = generator
	audio_player.bus = VOICE_BUS_NAME
	audio_player.unit_size = 15.0 # How far the voice carries in 3D space
	audio_player.play()
	
	# Get the playback object so we can push data to it later
	_playback = audio_player.get_stream_playback()

# --- CAPTURE LOOP (Local Player) ---
func _process(_delta):
	if not is_multiplayer_authority(): return
	if not _is_recording: return
	
	_process_mic_input()

func _process_mic_input():
	if not _capture_effect: return
	
	# Check if we have enough frames to send
	if _capture_effect.can_get_buffer(512):
		var buffer = _capture_effect.get_buffer(512)
		# Send this buffer to everyone else
		send_voice_data.rpc(buffer)
	
	# Clear any excess to prevent lag buildup
	if _capture_effect.get_frames_available() > 2048:
		_capture_effect.get_buffer(_capture_effect.get_frames_available())

func _on_voice_toggled(is_talking: bool):
	_is_recording = is_talking
	# Clears old buffer when starting to talk so we don't send "old" audio
	if _capture_effect: 
		_capture_effect.clear_buffer()

# --- NETWORK ---

# This function runs on ALL clients except the sender
@rpc("any_peer", "call_remote", "unreliable") 
func send_voice_data(data: PackedVector2Array):
	if not _playback: return
	
	# Push the received audio data into the stream
	# 'push_buffer' automatically handles the audio mixing
	_playback.push_buffer(data)
