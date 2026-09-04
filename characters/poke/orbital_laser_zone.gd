class_name OrbitalLaserZone
extends Node3D

@export var radius: float = 3.8 # Roughly 2.5x Crush's diameter (1.5m)
@export var initial_delay: float = 1.5
@export var strike_duration: float = 3.5
@export var initial_damage: float = 85.0
@export var dps: float = 35.0
@export var shooter_id: int = 0
@export var shooter_team: int = 0

var elapsed_time: float = 0.0
var has_struck: bool = false
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.2

@onready var telegraph_ring: MeshInstance3D = get_node_or_null("TelegraphRing")
@onready var laser_column: MeshInstance3D = get_node_or_null("LaserColumn")
@onready var core_beam: MeshInstance3D = get_node_or_null("CoreBeam")
@onready var ground_glow: MeshInstance3D = get_node_or_null("GroundGlow")
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready() -> void:
	_update_geometry()
	if laser_column: laser_column.visible = false
	if core_beam: core_beam.visible = false
	if ground_glow: ground_glow.visible = false
	if telegraph_ring: telegraph_ring.visible = true

func _update_geometry() -> void:
	if telegraph_ring and telegraph_ring.mesh is TorusMesh:
		telegraph_ring.mesh.outer_radius = radius
		telegraph_ring.mesh.inner_radius = max(0.1, radius - 0.18)
	
	if laser_column and laser_column.mesh is CylinderMesh:
		laser_column.mesh.top_radius = radius
		laser_column.mesh.bottom_radius = radius
		laser_column.mesh.height = 40.0
		laser_column.position = Vector3(0, 20.0, 0)
	
	if core_beam and core_beam.mesh is CylinderMesh:
		core_beam.mesh.top_radius = radius * 0.45
		core_beam.mesh.bottom_radius = radius * 0.45
		core_beam.mesh.height = 40.0
		core_beam.position = Vector3(0, 20.0, 0)

	if ground_glow and ground_glow.mesh is CylinderMesh:
		ground_glow.mesh.top_radius = radius
		ground_glow.mesh.bottom_radius = radius
		ground_glow.mesh.height = 0.25
		ground_glow.position = Vector3(0, 0.12, 0)

func _process(delta: float) -> void:
	elapsed_time += delta

	# Charging phase before strike
	if elapsed_time < initial_delay:
		var progress = elapsed_time / initial_delay
		if telegraph_ring:
			var pulse = 1.0 + sin(elapsed_time * 20.0) * 0.04
			telegraph_ring.scale = Vector3(pulse, 1.0, pulse)
		if omni_light:
			omni_light.light_energy = 1.0 + progress * 4.0
		return

	# Impact moment (at 1.5s)
	if not has_struck:
		has_struck = true
		_on_strike_impact()

	# Persistent burning beam phase
	var active_time = elapsed_time - initial_delay
	if active_time < strike_duration:
		# Visual rotation & flicker
		if laser_column:
			laser_column.rotation.y += delta * 3.0
		if core_beam:
			core_beam.rotation.y -= delta * 5.0
		if omni_light:
			omni_light.light_energy = 6.0 + sin(active_time * 30.0) * 2.0
		
		# Server tick continuous high DPS
		if is_server_authority():
			tick_timer += delta
			if tick_timer >= TICK_INTERVAL:
				tick_timer = 0.0
				_apply_dps_tick(TICK_INTERVAL)
	else:
		# Fade out and clean up
		_fade_and_free()

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _on_strike_impact() -> void:
	if telegraph_ring: telegraph_ring.visible = false
	if laser_column: laser_column.visible = true
	if core_beam: core_beam.visible = true
	if ground_glow: ground_glow.visible = true

	# Impact visual shockwave expansion
	var shockwave = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius * 1.3
	cyl.bottom_radius = radius * 1.3
	cyl.height = 0.4
	shockwave.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.95, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 6.0
	shockwave.material_override = mat
	shockwave.position = Vector3(0, 0.2, 0)
	add_child(shockwave)

	var tw = create_tween()
	tw.tween_property(shockwave, "scale", Vector3(1.35, 1.0, 1.35), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(shockwave.queue_free)

	# Server initial massive damage impact
	if is_server_authority():
		_apply_initial_blast()

func _apply_initial_blast() -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	for player in players_container.get_children():
		if player is Node3D and not player.get("is_dead"):
			var is_enemy = (player.name != str(shooter_id)) and (shooter_team == 0 or player.get("team_id") != shooter_team)
			if is_enemy:
				var to_p = player.global_position - global_position
				to_p.y = 0.0
				if to_p.length() <= radius:
					if player.has_method("take_damage"):
						player.take_damage(initial_damage, shooter_id, BasePlayer.ActionType.ABILITY)
					var shooter = players_container.get_node_or_null(str(shooter_id))
					if shooter and shooter.has_method("_on_character_damage_dealt"):
						shooter._on_character_damage_dealt(player, initial_damage, BasePlayer.ActionType.ABILITY)

func _apply_dps_tick(dt: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var tick_dmg = dps * dt
	for player in players_container.get_children():
		if player is Node3D and not player.get("is_dead"):
			var is_enemy = (player.name != str(shooter_id)) and (shooter_team == 0 or player.get("team_id") != shooter_team)
			if is_enemy:
				var to_p = player.global_position - global_position
				to_p.y = 0.0
				if to_p.length() <= radius:
					if player.has_method("take_damage"):
						player.take_damage(tick_dmg, shooter_id, BasePlayer.ActionType.ABILITY)
					var shooter = players_container.get_node_or_null(str(shooter_id))
					if shooter and shooter.has_method("_on_character_damage_dealt"):
						shooter._on_character_damage_dealt(player, tick_dmg, BasePlayer.ActionType.ABILITY)

func _fade_and_free() -> void:
	set_process(false)
	var tw = create_tween()
	if laser_column:
		tw.tween_property(laser_column, "scale", Vector3(0.01, 1.0, 0.01), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if core_beam:
		tw.parallel().tween_property(core_beam, "scale", Vector3(0.01, 1.0, 0.01), 0.3)
	if ground_glow:
		tw.parallel().tween_property(ground_glow, "scale", Vector3(0.01, 1.0, 0.01), 0.3)
	tw.tween_callback(queue_free)
