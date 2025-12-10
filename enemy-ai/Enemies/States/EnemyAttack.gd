class_name EnemyAttack
extends EnemyState

var strafe_dir: int = 1
var attack_timer: float = 0.0
var is_attacking: bool = false 

func enter():
	strafe_dir = 1 if randf() > 0.5 else -1
	attack_timer = 0.0 

func physics_update(delta):
	# 1. SAFETY CHECK
	if not is_instance_valid(enemy.player_target):
		transition_requested.emit(self, "idle")
		return

	if is_attacking:
		return

	# Update Timer
	if attack_timer > 0:
		attack_timer -= delta
		_strafe_behavior(delta)
	else:
		_attack_behavior(delta)
	
	# Distance Check (Only runs if NOT attacking)
	if is_instance_valid(enemy.player_target):
		var distance = enemy.global_position.distance_to(enemy.player_target.global_position)
		if distance > stats.attack_range + 1.0: 
			transition_requested.emit(self, "chase")

func _strafe_behavior(delta):
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
	# Stop moving completely
	enemy.velocity = Vector3.ZERO 
	
	# Lock the state
	is_attacking = true
	
	enemy.play_animation(stats.anim_attack)
	enemy.combat_component.try_attack()
	
	attack_timer = stats.attack_rate
	strafe_dir *= -1
	
	# Wait for the animation to finish (roughly)
	# You can tune this number (e.g. 0.5, 0.8) to match your animation length
	await get_tree().create_timer(0.6).timeout
	
	# Unlock
	is_attacking = false
