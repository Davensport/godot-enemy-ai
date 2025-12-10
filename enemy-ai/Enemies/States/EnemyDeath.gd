class_name EnemyDeath
extends EnemyState

func enter():
	enemy.play_animation(stats.anim_death)
	
	# 1. Stop all movement immediately
	enemy.velocity = Vector3.ZERO
	
	# 2. Disable Collision Logic
	# We delay this slightly to ensure the "Death" animation starts 
	# while they are still standing firmly on the floor.
	if enemy.collision_shape:
		enemy.collision_shape.set_deferred("disabled", true)
	
	# 3. Handle Logic
	if enemy.auto_respawn:
		_handle_respawn()
	else:
		_handle_despawn()

func physics_update(_delta):
	enemy.velocity = Vector3.ZERO

func _handle_despawn():
	# Wait for the animation to actually finish!
	# If this is 0.0, they sink instantly.
	await get_tree().create_timer(2.0).timeout 
	
	if enemy.visuals_container:
		var tween = create_tween()
		# Sinks them 2 meters down over 2 seconds
		tween.tween_property(enemy.visuals_container, "position:y", -2.0, 2.0).as_relative()
		await tween.finished
		
	enemy.queue_free()
func _handle_respawn():
	# Wait for the respawn timer
	await get_tree().create_timer(enemy.respawn_time).timeout
	
	# Reset Health
	enemy.health_component.reset_health()
	
	# Re-enable Collision
	if enemy.collision_shape:
		enemy.collision_shape.set_deferred("disabled", false)
		
	# Visual Reset (Optional: Maybe pop them back to spawn pos?)
	enemy.play_animation(stats.anim_idle)
	
	# Go back to Idle
	transition_requested.emit(self, "idle")
