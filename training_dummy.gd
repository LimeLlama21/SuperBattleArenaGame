class_name TrainingDummy
extends BasePlayer

var total_damage: float = 0.0
var last_hit_damage: float = 0.0
var combat_timer: float = 0.0
var dps: float = 0.0
var reset_stats_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO

@onready var info_label: Label3D = get_node_or_null("InfoLabel")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _setup_character_kit() -> void:
	character_name = "Training Dummy"
	display_name = "Training Dummy"
	team_id = 2
	max_health = 10000.0
	current_health = 10000.0
	max_move_speed = 0.0
	home_position = global_position
	_update_label()

func _process_character_kit(delta: float) -> void:
	if is_dead:
		return

	if combat_timer > 0.0:
		combat_timer += delta
		dps = total_damage / max(1.0, combat_timer)
		reset_stats_timer -= delta
		if reset_stats_timer <= 0.0:
			combat_timer = 0.0
			total_damage = 0.0
			dps = 0.0
			current_health = max_health

	# Smoothly return to home center position if knocked back
	if global_position.distance_to(home_position) > 0.1 and not is_stunned() and velocity.length() < 1.0 and is_on_floor():
		var return_vel = (home_position - global_position) * 4.0
		velocity.x = return_vel.x
		velocity.z = return_vel.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	_update_label()

func _on_damage_taken_hook(amount: float, _attacker_id: int, action_type: int) -> void:
	if is_dead:
		return

	last_hit_damage = amount
	total_damage += amount
	if combat_timer == 0.0:
		combat_timer = 0.001
	reset_stats_timer = 4.5

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

func die() -> void:
	if is_dead:
		return
	super.die()
	
	# Death shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func respawn() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	current_health = max_health
	current_shield = 0.0
	cleanse_cc()
	is_dead = false
	visible = true
	
	# Pop in animation
	scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_label()

func _update_label() -> void:
	if not info_label:
		return
	
	var status_str = ""
	if is_stunned():
		status_str += " [STUNNED: %.1fs]" % stun_timer
	if is_rooted():
		status_str += " [ROOTED: %.1fs]" % root_timer
	if is_grounded():
		status_str += " [GROUNDED: %.1fs]" % grounded_timer
	if is_crippled():
		status_str += " [CRIPPLED: %.1fs]" % cripple_timer
	if is_slowed():
		status_str += " [SLOWED: %.0f%%]" % (slow_percent * 100.0)
	if is_silenced():
		status_str += " [SILENCED: %.1fs]" % silence_timer

	var hp_pct = clamp(current_health / max_health, 0.0, 1.0)
	var hp_bar_len = 10
	var filled = int(round(hp_pct * hp_bar_len))
	var bar_str = "[" + "█".repeat(filled) + "░".repeat(hp_bar_len - filled) + "]"

	if total_damage > 0.0:
		info_label.text = "🎯 TRAINING DUMMY\n%s %.0f/%.0f HP (%.0f%%)%s\nLast: %.0f | DPS: %.1f | Total: %.0f" % [bar_str, current_health, max_health, hp_pct * 100.0, status_str, last_hit_damage, dps, total_damage]
	else:
		info_label.text = "🎯 TRAINING DUMMY\n%s %.0f/%.0f HP (%.0f%%)%s\nAttack to test damage & combos" % [bar_str, current_health, max_health, hp_pct * 100.0, status_str]
