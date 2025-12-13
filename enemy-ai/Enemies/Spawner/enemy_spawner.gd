class_name EnemySpawner
extends Marker3D

@export_group("Spawner Settings")
# List of enemies to spawn. Create "New SpawnDefinition" entries here.
@export var spawn_list: Array[SpawnDefinition] 

@export var spawn_interval: float = 4.0
@export var spawn_radius: float = 3.0
@export var max_active_enemies: int = 5

var current_enemy_count: int = 0
var spawn_timer: Timer

func _ready():
	# 1. SECURITY CHECK
	# Only the Server is allowed to spawn things.
	# The MultiplayerSpawner (which we will add next) will handle the Clients.
	if not multiplayer.is_server():
		return  # <--- Clients stop here!

	# 2. Existing Timer Code
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	randomize()
	call_deferred("_spawn_enemy")

func _on_spawn_timer_timeout():
	if current_enemy_count < max_active_enemies:
		_spawn_enemy()

func _spawn_enemy():
	# 1. Validation
	# CRITICAL FIX: Ensure the Spawner is still inside the Scene Tree (has a parent)
	# This prevents crashes during Level Unloads/Resets when the player dies.
	if not is_inside_tree() or not get_parent():
		return

	if spawn_list.is_empty():
		return

	# 2. Pick a random enemy based on weights
	var selected_spawn = _get_random_spawn_from_weights()
	if not selected_spawn or not selected_spawn.enemy_scene:
		return

	# 3. Instantiate
	var enemy_instance = selected_spawn.enemy_scene.instantiate()
	if not enemy_instance:
		return
	
	# --- NEW: Inject Stats Override ---
	# If the SpawnDefinition has specific stats (e.g., SkeletonStats), 
	# we assign them BEFORE adding the child. The DummyEnemy._ready() will use them.
	if selected_spawn.stats_override and "stats" in enemy_instance:
		enemy_instance.stats = selected_spawn.stats_override

	# 4. Calculate random position offset
	var random_x = randf_range(-spawn_radius, spawn_radius)
	var random_z = randf_range(-spawn_radius, spawn_radius)
	var spawn_pos = global_position + Vector3(random_x, 0, random_z)
	
	# 5. Add to scene
	get_parent().add_child(enemy_instance)
	enemy_instance.global_position = spawn_pos
	
	# 6. Track enemy count
	current_enemy_count += 1
	
	# 7. Listen for death to decrease count
	# NOTE: Ensure your path matches your scene structure!
	if enemy_instance.has_node("Components/HealthComponent"):
		enemy_instance.get_node("Components/HealthComponent").on_death.connect(_on_enemy_death)

func _on_enemy_death():
	current_enemy_count = max(0, current_enemy_count - 1)

# --- WEIGHTED RANDOM LOGIC ---
func _get_random_spawn_from_weights() -> SpawnDefinition:
	var total_weight = 0
	for item in spawn_list:
		total_weight += item.spawn_weight
	
	var random_value = randi_range(1, total_weight)
	var current_weight = 0
	
	for item in spawn_list:
		current_weight += item.spawn_weight
		if random_value <= current_weight:
			return item
	
	return spawn_list[0] # Fallback
