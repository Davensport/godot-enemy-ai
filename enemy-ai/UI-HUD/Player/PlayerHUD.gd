extends CanvasLayer

# --- NODES ---
# IMPORTANT: Ensure your root Control node is renamed to "GameplayContainer"
@onready var gameplay_container = $GameplayContainer 

@onready var hp_bar = $GameplayContainer/MarginContainer/VBoxContainer/HPBar
@onready var speed_label = $GameplayContainer/MarginContainer/VBoxContainer/SpeedLabel
@onready var dmg_label = $GameplayContainer/MarginContainer/VBoxContainer/DamageLabel
@onready var kills_label = $GameplayContainer/MarginContainer/VBoxContainer/KillsLabel

# Death Screen Nodes
@onready var death_overlay = $DeathOverlay
@onready var respawn_btn = $DeathOverlay/CenterContainer/VBoxContainer/RespawnButton
@onready var anim_player = $AnimationPlayer

func _ready():
	
	# 1. Connect the respawn button locally
	respawn_btn.pressed.connect(_on_respawn_pressed)
	
	# 2. Listen for the GLOBAL death signal
	SignalBus.player_died.connect(_on_player_died)
	
	# 3. PLAY SPAWN ANIMATION
	# Since this script is brand new (just spawned), we start with the overlay 
	# visible (black) and fade it out to reveal the game.
	death_overlay.visible = true
	death_overlay.modulate.a = 1.0
	gameplay_container.visible = true
	
	# Ensure this animation exists: Fades DeathOverlay Alpha from 1 -> 0
	anim_player.play("fade_in_respawn")

func setup_ui(player: PlayerController):
	# Dependency Injection logic (Same as before)
	if player.health:
		player.health.on_health_changed.connect(update_health)
		update_health(player.health.current_health, player.health.max_health)
	
	if player.movement:
		player.movement.on_speed_changed.connect(update_speed)
		update_speed(player.movement.speed)

	if player.combat:
		player.combat.on_damage_multiplier_changed.connect(update_dmg)
		update_dmg(player.combat.damage_multiplier)
	if not SignalBus.enemy_died.is_connected(update_kills):
		SignalBus.enemy_died.connect(update_kills)
		update_kills(null)

# --- UPDATERS ---
func update_health(current, max_hp):
	hp_bar.max_value = max_hp
	hp_bar.value = current

func update_speed(new_speed):
	speed_label.text = "Speed: %.1f" % new_speed

func update_dmg(new_mult):
	dmg_label.text = "Dmg Mult: x%.1f" % new_mult

var TotalKills: float = 0
func update_kills(_enemy_node): 
	if (_enemy_node):
		TotalKills += 1
		kills_label.text = "Kills: %.0f" % TotalKills
	else: #should only run on setup
		kills_label.text = "Kills: 0"
# --- DEATH LOGIC ---

func _on_player_died():
	# 1. Unlock mouse so you can click
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 2. Force the overlay and button to be visible
	death_overlay.visible = true
	respawn_btn.visible = true # <--- ADD THIS LINE
	respawn_btn.disabled = false # <--- ADD THIS LINE
	
	# 3. Try to play the animation (if it exists)
	if anim_player.has_animation("fade_to_death"):
		anim_player.play("fade_to_death")
	else:
		# Fallback if animation is missing: make it black instantly
		death_overlay.modulate.a = 1.0

func _on_respawn_pressed():
	# Prevent double clicks
	respawn_btn.disabled = true
	
	# Emit signal. The PlayerSpawner is listening for this!
	SignalBus.respawn_requested.emit()
	
