extends SceneTree

const CrushScene = preload("res://characters/crush/crush.tscn")
const AsparsasScene = preload("res://characters/asparsas/asparsas.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	print("--- INSPECTING MELEE HITBOX & ATTACK EXECUTION ---")
	
	var characters = {
		"Crush": CrushScene,
		"Asparsas": AsparsasScene,
		"Reaper": preload("res://characters/reaper/reaper.tscn"),
		"Monkey": preload("res://characters/monkey/monkey.tscn")
	}
	
	for c_name in characters:
		print("\n================== TESTING ", c_name, " ==================")
		var p: BasePlayer = characters[c_name].instantiate()
		root.add_child(p)
		p.name = "1"
		if not p.is_node_ready():
			p._ready()
		p.global_position = Vector3(0, 0, 0)
		
		var lmb_ab = p.abilities.get("LMB")
		print(c_name, " LMB ability_id: ", lmb_ab.ability_id if lmb_ab else "null", " windup: ", lmb_ab.get_windup_time() if lmb_ab else 0, " hitbox: ", lmb_ab.hitbox)
		
		# Test LMB cast
		p.try_cast_ability("LMB")
		print("Spawned indicators under ", c_name, ":")
		for child in p.get_children():
			if "Telegraph" in child.name or "@Node3D@" in child.name:
				print("  Child under player: ", child.name, " pos: ", child.position, " rot: ", child.rotation)
		for child in root.get_children():
			if "Telegraph" in child.name or "@Node3D@" in child.name:
				print("  Child under root: ", child.name, " pos: ", child.position, " rot: ", child.rotation)
		
		# Clean up
		p.queue_free()
		await process_frame

	quit()
