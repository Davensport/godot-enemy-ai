extends Label3D

# Adjust this path if your VoiceComponent is named differently
@onready var voice_component = $"../VoiceComponent" 

func _ready():
	visible = false # Start hidden
	if voice_component:
		voice_component.on_talking.connect(_update_visibility)

func _update_visibility(is_talking):
	visible = is_talking
