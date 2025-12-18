class_name VoiceComponent
extends Node

# --- SIGNALS ---
signal on_talking(is_talking: bool) # NEW: Tells the UI to light up

# --- CONFIGURATION ---
@export var input: Node 
@export var audio_player: AudioStreamPlayer3D

const RECORD_BUS_NAME = "Record"
var _capture_effect: AudioEffectCapture
var _playback: AudioStreamGeneratorPlayback
var _is_recording: bool = false

# --- VISUAL STATE ---
var _speech_active: bool = false
var _speech_timer: float = 0.0
const SPEECH_DECAY: float = 0.2 # How long icon stays on after data stops

func _ready():
	# 1. SETUP MICROPHONE (Local Player Only)
	if is_multiplayer_authority():
		var idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
		if idx != -1:
			_capture_effect = AudioServer.get_bus_effect(idx, 0)
		else:
			printerr("VoiceComponent: 'Record' bus not found!")
		
		if input and input.has_signal("on_voice_toggled"):
			input.on_voice_toggled.connect(_on_voice_toggled)
	
	# 2. SETUP PLAYBACK
	_setup_audio_player()

func _setup_audio_player():
	if not audio_player: return
	if not audio_player.playing: audio_player.play() 
	if audio_player.stream is AudioStreamGenerator:
		_playback = audio_player.get_stream_playback()

func _process(delta):
	# --- VISUAL DECAY LOGIC ---
	if _speech_active:
		_speech_timer -= delta
		if _speech_timer <= 0:
			_speech_active = false
			on_talking.emit(false) # Turn icon OFF
	# ---------------------------

	if not is_multiplayer_authority(): return

	# FALLBACK INPUT
	if input == null:
		if Input.is_action_just_pressed("push_to_talk"): _on_voice_toggled(true)
		elif Input.is_action_just_released("push_to_talk"): _on_voice_toggled(false)
	
	# CAPTURE LOGIC
	if _is_recording and _capture_effect:
		if _capture_effect.can_get_buffer(256):
			var raw_buffer = _capture_effect.get_buffer(256)
			
			# --- LOCAL VISUAL FEEDBACK ---
			# If we successfully grabbed data, we are "talking"
			_refresh_talking_visual()
			# -----------------------------

			var mono_data = PackedFloat32Array()
			mono_data.resize(raw_buffer.size())
			for i in range(raw_buffer.size()):
				mono_data[i] = raw_buffer[i].x 
			
			send_voice_data.rpc(mono_data)
		
		if _capture_effect.get_frames_available() > 1024:
			_capture_effect.get_buffer(_capture_effect.get_frames_available())

func _on_voice_toggled(is_talking: bool):
	_is_recording = is_talking
	if _capture_effect: _capture_effect.clear_buffer()

# Helper to keep the icon lit
func _refresh_talking_visual():
	_speech_timer = SPEECH_DECAY
	if not _speech_active:
		_speech_active = true
		on_talking.emit(true) # Turn icon ON

@rpc("any_peer", "call_remote", "unreliable") 
func send_voice_data(data: PackedFloat32Array):
	if not _playback: return
	
	# --- REMOTE VISUAL FEEDBACK ---
	# If we received data, they are "talking"
	_refresh_talking_visual()
	# ------------------------------
	
	var stereo_buffer = PackedVector2Array()
	stereo_buffer.resize(data.size())
	for i in range(data.size()):
		var sample = data[i]
		stereo_buffer[i] = Vector2(sample, sample)
		
	_playback.push_buffer(stereo_buffer)
