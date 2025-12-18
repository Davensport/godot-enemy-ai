class_name VoiceComponent
extends Node

# --- CONFIGURATION ---
@export var input: Node # We change type to Node so it's flexible, or keep as InputComponent
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
		
		# Try to connect to InputComponent if it exists
		if input and input.has_signal("on_voice_toggled"):
			input.on_voice_toggled.connect(_on_voice_toggled)
	
	# 2. SETUP PLAYBACK (Everyone)
	_setup_audio_player()

func _setup_audio_player():
	if not audio_player: return
	
	audio_player.play() # Play immediately so the stream is active
	_playback = audio_player.get_stream_playback()

func _process(_delta):
	# SECURITY CHECK: Only the owner captures mic
	if not is_multiplayer_authority(): return

	# --- NEW: FALLBACK INPUT LOGIC ---
	# If we don't have an InputComponent, check the key directly here.
	if input == null:
		if Input.is_action_just_pressed("push_to_talk"):
			_on_voice_toggled(true)
		elif Input.is_action_just_released("push_to_talk"):
			_on_voice_toggled(false)
	# ----------------------------------

	# CAPTURE LOGIC
	if _is_recording and _capture_effect:
		if _capture_effect.can_get_buffer(512):
			var buffer = _capture_effect.get_buffer(512)
			send_voice_data.rpc(buffer)
		
		# Prevent buffer overflow
		if _capture_effect.get_frames_available() > 2048:
			_capture_effect.get_buffer(_capture_effect.get_frames_available())

func _on_voice_toggled(is_talking: bool):
	_is_recording = is_talking
	if _capture_effect: 
		_capture_effect.clear_buffer()

@rpc("any_peer", "call_remote", "unreliable") 
func send_voice_data(data: PackedVector2Array):
	if _playback:
		_playback.push_buffer(data)
