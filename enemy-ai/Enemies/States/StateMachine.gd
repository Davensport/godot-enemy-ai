class_name StateMachine
extends Node

@export var initial_state: EnemyState

var current_state: EnemyState
var states: Dictionary = {}

func _ready():
	# Wait for the owner (Enemy) to be ready first
	await owner.ready
	
	# Auto-discover all children states
	for child in get_children():
		if child is EnemyState:
			states[child.name.to_lower()] = child
			child.enemy = owner # Pass reference to the Enemy
			child.stats = owner.stats # Pass reference to Stats
			child.transition_requested.connect(_on_transition_requested)

	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)

func _on_transition_requested(from: EnemyState, to_state_name: String):
	if from != current_state:
		return # Safety check
	
	var new_state = states.get(to_state_name.to_lower())
	if not new_state:
		push_error("State not found: " + to_state_name)
		return

	if current_state:
		current_state.exit()

	new_state.enter()
	current_state = new_state

# Add to StateMachine.gd
func force_change_state(new_state_name: String):
	var new_state = states.get(new_state_name.to_lower())
	if not new_state: return

	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state
