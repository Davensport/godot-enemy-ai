class_name EnemyAttack
extends EnemyState

var strafe_dir: int = 1
var attack_timer: float = 0.0

func enter():
	# Fix 1: Randomize direction to prevent predictable movement
	strafe_dir = 1 if randf() > 0.5 else -1
	attack_timer = 0.0 

func physics_update(delta):
	# Fix 2: SAFETY CHECK - If player is gone, stop EVERYTHING and return immediately
	if not is_instance_valid(enemy.player_target):
		transition_requested.emit(self, "idle")
		return

	# Update Timer
	if attack_timer > 0:
		attack_timer -= delta
		_strafe_behavior(delta)
	else:
		_attack_behavior(delta)
	
	# Fix 3: Double-check safety before calculating distance at the end
	if is_instance_valid(enemy.player_target):
		var distance = enemy.global_position.distance_to(enemy.player_target.global_position)
		# Hysteresis: Only go back to chase if player moves significantly out of range
		if distance > stats.attack_range + 1.0: 
			transition_requested.emit(self, "chase")

func _strafe_behavior(delta):
	# Safe access because we checked validity in physics_update
	var dir_to_player = (enemy.player_target.global_position - enemy.global_position).normalized()
	var right_vec = dir_to_player.cross(Vector3.UP).normalized()
	var strafe_vel = right_vec * strafe_dir * (stats.move_speed * 0.25)
	
	enemy.velocity.x = move_toward(enemy.velocity.x, strafe_vel.x, stats.acceleration * delta)
	enemy.velocity.z = move_toward(enemy.velocity.z, strafe_vel.z, stats.acceleration * delta)
	enemy.rotate_smoothly(dir_to_player, delta)

	# Fix 4: Randomly switch direction occasionally to prevent getting stuck on walls
	if randf() < 0.02:
		strafe_dir *= -1

func _attack_behavior(_delta):
	# Fix 5: HARD STOP. Prevent sliding while shooting.
	enemy.velocity = Vector3.ZERO 
	
	enemy.play_animation(stats.anim_attack)
	enemy.combat_component.try_attack()
	
	attack_timer = stats.attack_rate
	strafe_dir *= -1
