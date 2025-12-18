extends EnemyState

@export var wander_radius: float = 6.0
@export var wander_wait_time: float = 2.0

var _wait_timer: float = 0.0
var _current_wander_target: Vector3 = Vector3.ZERO

func enter():
	# 1. PLAY ANIMATION
	# We use "Walk" or the move animation defined in stats
	enemy.play_animation(stats.anim_move)
	
	# 2. PICK INITIAL TARGET
	# Pick a random spot immediately so we don't stand still
	_pick_new_wander_target()

	# 3. MUSIC "CALM DOWN" CHECK
	# If we just gave up the chase, check if the music should stop.
	_check_if_battle_is_over()

func physics_update(delta):
	# 1. PLAYER DETECTION
	# If we see the player nearby, switch immediately to Chase
	if _can_see_player():
		transition_requested.emit(self, "chase")
		return

	# 2. WAIT LOGIC
	# If we are waiting at a destination...
	if _wait_timer > 0:
		_wait_timer -= delta
		enemy.velocity = Vector3.ZERO # Stop moving while waiting
		if enemy.has_method("play_animation"):
			enemy.play_animation("Idle") # Optional: Switch to idle anim while waiting
		
		# When timer ends, pick a new spot and resume walking
		if _wait_timer <= 0:
			_pick_new_wander_target()
			enemy.play_animation(stats.anim_move)
		return

	# 3. MOVEMENT LOGIC
	# Move towards the random target
	var dir = (_current_wander_target - enemy.global_position).normalized()
	enemy.velocity = dir * (stats.move_speed * 0.5) # Wander is usually slower (50% speed)
	
	enemy.rotate_smoothly(enemy.velocity, delta)
	
	# 4. REACHED DESTINATION?
	# If we are close enough to the random point, start waiting
	if enemy.global_position.distance_to(_current_wander_target) < 1.0:
		_wait_timer = wander_wait_time

# --- HELPER: PICK RANDOM SPOT ---
func _pick_new_wander_target():
	# Pick a random offset
	var random_x = randf_range(-wander_radius, wander_radius)
	var random_z = randf_range(-wander_radius, wander_radius)
	
	# Add to our "Home" position (so they don't wander off the map)
	# Assumes 'home_position' exists on DummyEnemy.gd (we added it earlier!)
	var center = enemy.home_position if "home_position" in enemy else enemy.global_position
	
	_current_wander_target = center + Vector3(random_x, 0, random_z)

# --- HELPER: CHECK FOR PLAYER ---
func _can_see_player():
	# 1. Is there a valid target?
	if not is_instance_valid(enemy.player_target):
		return false
		
	# 2. Is it within detection range?
	var dist = enemy.global_position.distance_to(enemy.player_target.global_position)
	if dist > stats.aggro_range:
		return false
		
	# 3. Can we actually see them? (Optional - relies on CombatComponent)
	if enemy.combat_component:
		return enemy.combat_component.has_line_of_sight()
	
	return true

# --- HELPER: MUSIC LOGIC ---
func _check_if_battle_is_over():
	# Get all active enemies
	var all_enemies = get_tree().get_nodes_in_group("active_enemies")
	var anyone_still_fighting = false
	
	for other_enemy in all_enemies:
		# Don't check 'self' (we know WE just gave up)
		if other_enemy == enemy: continue
		
		# Check their StateMachine
		var sm = other_enemy.get_node_or_null("StateMachine")
		if sm and sm.current_state:
			var state_name = sm.current_state.name.to_lower()
			
			# If anyone else is Chasing or Attacking, keep the music intense!
			if "chase" in state_name or "attack" in state_name:
				anyone_still_fighting = true
				break
	
	# If nobody else is fighting, we can finally relax.
	if not anyone_still_fighting:
		SignalBus.combat_status_changed.emit(false)
