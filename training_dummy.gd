extends CharacterBody3D

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var team_id: int = 2
@export var character_name: String = "Training Dummy"

var is_dead: bool = false
var is_cc_immune: bool = false
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_percent: float = 0.0
var silence_timer: float = 0.0

var total_damage: float = 0.0
var last_hit_damage: float = 0.0
var combat_timer: float = 0.0
var dps: float = 0.0
var reset_stats_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO

@onready var info_label: Label3D = $InfoLabel
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	home_position = global_position
	current_health = max_health
	_update_label()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer < 0.0:
			stun_timer = 0.0

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer < 0.0:
			slow_timer = 0.0
			slow_percent = 0.0

	if silence_timer > 0.0:
		silence_timer -= delta
		if silence_timer < 0.0:
			silence_timer = 0.0

	if combat_timer > 0.0:
		combat_timer += delta
		dps = total_damage / max(1.0, combat_timer)
		reset_stats_timer -= delta
		if reset_stats_timer <= 0.0:
			combat_timer = 0.0
			total_damage = 0.0
			dps = 0.0

	# Smoothly return to home center position if knocked back
	if global_position.distance_to(home_position) > 0.1 and stun_timer <= 0.0:
		velocity = (home_position - global_position) * 4.0
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 15.0 * delta)

	move_and_slide()
	_update_label()

func take_damage(amount: float, attacker_id: int = 0, action_type: int = 0) -> void:
	if is_dead:
		return

	last_hit_damage = amount
	total_damage += amount
	if combat_timer == 0.0:
		combat_timer = 0.001
	reset_stats_timer = 4.5
	
	current_health = max(0.0, current_health - amount)

	# Hit flash effect
	if mesh_instance:
		var orig_mat = mesh_instance.get_surface_override_material(0)
		var flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1.0, 0.4, 0.4, 1.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.2, 0.2, 1.0)
		flash_mat.emission_energy_multiplier = 3.0
		mesh_instance.set_surface_override_material(0, flash_mat)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.set_surface_override_material(0, orig_mat)
		)

	# Spawn floating damage number via Main
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("display_damage_number"):
		main_node.display_damage_number(amount, global_position + Vector3(0, 0.5, 0), action_type)

	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Death shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Automatic Respawn after 0.6s
	get_tree().create_timer(0.6).timeout.connect(func():
		respawn()
	)

func respawn() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	current_health = max_health
	stun_timer = 0.0
	slow_timer = 0.0
	silence_timer = 0.0
	is_dead = false
	
	# Pop in animation
	scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_label()

func apply_stun(duration: float) -> void:
	if not is_dead:
		stun_timer = max(stun_timer, duration)

func apply_slow(duration: float, percent: float) -> void:
	if not is_dead:
		slow_timer = max(slow_timer, duration)
		slow_percent = max(slow_percent, percent)

func apply_silence(duration: float) -> void:
	if not respawn and not is_dead:
		silence_timer = max(silence_timer, duration)

func apply_knockback(impulse: Vector3) -> void:
	if not is_dead:
		velocity.x += impulse.x * 0.5
		velocity.z += impulse.z * 0.5
		velocity.y = max(velocity.y + impulse.y * 0.4, impulse.y * 0.4)

func set_opponent_visible(_vis: bool) -> void:
	pass

func _update_label() -> void:
	if not info_label:
		return
	
	var status_str = ""
	if stun_timer > 0.0:
		status_str += " [STUNNED: %.1fs]" % stun_timer
	if slow_timer > 0.0:
		status_str += " [SLOWED: %.0f%%]" % (slow_percent * 100.0)
	if silence_timer > 0.0:
		status_str += " [SILENCED: %.1fs]" % silence_timer

	var hp_pct = clamp(current_health / max_health, 0.0, 1.0)
	var hp_bar_len = 10
	var filled = int(round(hp_pct * hp_bar_len))
	var bar_str = "[" + "█".repeat(filled) + "░".repeat(hp_bar_len - filled) + "]"

	if total_damage > 0.0:
		info_label.text = "🎯 TRAINING DUMMY\n%s %.0f/%.0f HP (%.0f%%)%s\nLast: %.0f | DPS: %.1f | Total: %.0f" % [bar_str, current_health, max_health, hp_pct * 100.0, status_str, last_hit_damage, dps, total_damage]
	else:
		info_label.text = "🎯 TRAINING DUMMY\n%s %.0f/%.0f HP (%.0f%%)%s\nAttack to test damage & combos" % [bar_str, current_health, max_health, hp_pct * 100.0, status_str]

