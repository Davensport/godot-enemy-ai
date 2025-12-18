class_name VoiceComponent
extends Node

# --- CONFIGURATION ---
@export var input: Node # Flexible type to accept InputComponent or null
@export var audio_player: AudioStreamPlayer3D

const RECORD_BUS_NAME = "Record"
const VOICE_BUS_NAME = "VoIP"

var _capture_effect: AudioEffectCapture
var _playback: AudioStreamGeneratorPlayback
var _is_recording: bool = false

func _ready():
	# 1. SETUP MICROPHONE (Local Player Only)
	if is_multiplayer_authority():
		var idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
		if idx != -1:
			_capture_effect = AudioServer.get_bus_effect(idx, 0)
		else:
			printerr("VoiceComponent: 'Record' bus not found in Audio Layout!")
		
		# Connect to InputComponent if it exists
		if input and input.has_signal("on_voice_toggled"):
			input.on_voice_toggled.connect(_on_voice_toggled)
	
	# 2. SETUP PLAYBACK (Everyone)
	_setup_audio_player()

func _setup_audio_player():
	if not audio_player: return
	
	if not audio_player.playing:
		audio_player.play() 
	
	# We grab the stream playback so we can push data into it later
	if audio_player.stream is AudioStreamGenerator:
		_playback = audio_player.get_stream_playback()
	else:
		printerr("VoiceComponent: AudioPlayer stream is not an AudioStreamGenerator!")

func _process(_delta):
	# SECURITY CHECK: Only the owner captures mic
	if not is_multiplayer_authority(): return

	# --- FALLBACK INPUT LOGIC ---
	# If no InputComponent is attached (like in the Lobby), check keys directly.
	if input == null:
		if Input.is_action_just_pressed("push_to_talk"):
			_on_voice_toggled(true)
		elif Input.is_action_just_released("push_to_talk"):
			_on_voice_toggled(false)
	
	# --- CAPTURE LOGIC ---
	if _is_recording and _capture_effect:
		# OPTIMIZATION 1: Use a smaller buffer (256 frames)
		# At 22050Hz, 256 frames fits safely into a network packet.
		if _capture_effect.can_get_buffer(256):
			var raw_buffer = _capture_effect.get_buffer(256)
			
			# OPTIMIZATION 2: Convert Stereo to Mono
			# We only take the Left (X) channel to cut data size in half.
			var mono_data = PackedFloat32Array()
			mono_data.resize(raw_buffer.size())
			
			for i in range(raw_buffer.size()):
				mono_data[i] = raw_buffer[i].x 
			
			send_voice_data.rpc(mono_data)
		
		# Prevent internal buffer overflow by discarding old data
		if _capture_effect.get_frames_available() > 1024:
			_capture_effect.get_buffer(_capture_effect.get_frames_available())

func _on_voice_toggled(is_talking: bool):
	_is_recording = is_talking
	if _capture_effect: 
		_capture_effect.clear_buffer()

# We receive an Array of Floats (Mono) instead of Vector2s (Stereo)
@rpc("any_peer", "call_remote", "unreliable") 
func send_voice_data(data: PackedFloat32Array):
	if not _playback: return
	
	# --- RECONSTRUCTION ---
	# Turn the Mono float back into Stereo (Left/Right) for the speakers
	var stereo_buffer = PackedVector2Array()
	stereo_buffer.resize(data.size())
	
	for i in range(data.size()):
		var sample = data[i]
		stereo_buffer[i] = Vector2(sample, sample)
		
	_playback.push_buffer(stereo_buffer)
