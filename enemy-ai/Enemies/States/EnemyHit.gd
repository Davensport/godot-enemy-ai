class_name EnemyHit
extends EnemyState

var stun_duration: float = 0.5

func enter():
	enemy.velocity = Vector3.ZERO
	
	# Fix: Ensure we actually have a hit animation, otherwise just wait
	if "anim_hit" in stats and stats.anim_hit != "":
		enemy.play_animation(stats.anim_hit)
	
	# Fix: Use a timer node or a simpler await safety check
	# (Prevents crashes if the enemy dies while waiting)
	await get_tree().create_timer(stun_duration).timeout
	
	# SAFETY: Check if we are still the active state before transitioning
	# If the enemy died during the stun, we don't want to force them back to idle.
	if enemy.state_machine.current_state == self:
		if enemy.player_target and is_instance_valid(enemy.player_target):
			transition_requested.emit(self, "chase")
		else:
			transition_requested.emit(self, "idle")

func physics_update(delta):
	# Apply Gravity while stunned
	if not stats.is_flying and not enemy.is_on_floor():
		enemy.velocity.y -= enemy.gravity * delta
	
	# Fix: Force zero horizontal velocity so they don't slide while flinching
	enemy.velocity.x = 0
	enemy.velocity.z = 0
