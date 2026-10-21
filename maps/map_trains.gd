class_name MapTrains
extends Node3D

## MapTrains - High-speed combat map featuring three sectioned team trains framing a triangle.
## The trains remain completely static framing the triangle arena.
## Every two minutes, the active triangle departs (moves away).
## After 30 seconds of transit, the next triangle map in the loop arrives.
## Any players remaining on the departing triangle die immediately, and their camera
## is directed to follow their team's train.

signal area_changed(new_area_id: int, area_name: String)
signal area_departed(departing_area_id: int, departing_area_name: String)
signal area_warning(time_left: float, next_area_name: String)

enum MapState {
	AT_MAP,
	IN_TRANSIT
}

const AREA_INTERVAL: float = 120.0 # 2 minutes per map
const TRANSIT_INTERVAL: float = 30.0 # 30 seconds between departure and next arrival

const AREA_NAMES: Array[String] = [
	"Crimson Canyon (Red)",
	"Verdant Valley (Green)",
	"Frostbite Pass (Blue)"
]

const AREA_DESCRIPTIONS: Array[String] = [
	"A sheer terracotta chasm with a roaring magma forge at its heart.",
	"An emerald jade grove crowned by an ancient mossy megalith.",
	"A frozen glacial summit pierced by glowing crystalline azure spires."
]

# Triangle Geometry Configuration (Equilateral triangle side = 36m, center at origin)
const TRIANGLE_SIDE: float = 36.0
const VERTEX_RADIUS: float = 20.7846 # 36 / sqrt(3)
const APOTHEM: float = 10.3923       # 36 / (2 * sqrt(3))

# Vertices of the outer equilateral triangle (Train centerlines):
# VA (North-West): (-18.0, 0, -10.3923)
# VB (North-East): (+18.0, 0, -10.3923)
# VC (South):      (  0.0, 0, +20.7846)
const VERTEX_NW: Vector3 = Vector3(-18.0, 0.0, -10.3923)
const VERTEX_NE: Vector3 = Vector3(18.0, 0.0, -10.3923)
const VERTEX_SOUTH: Vector3 = Vector3(0.0, 0.0, 20.7846)

# Inner Triangle Map Vertices (Docked platform framed by the trains):
# Apothem r = 8.6m, vertex radius = 17.2m
const MAP_NW: Vector3 = Vector3(-14.8956, 0.0, -8.6)
const MAP_NE: Vector3 = Vector3(14.8956, 0.0, -8.6)
const MAP_SOUTH: Vector3 = Vector3(0.0, 0.0, 17.2)

# Car Dimensions
const NUM_CARS_PER_TRAIN: int = 4
const CAR_LENGTH: float = 7.2
const CAR_WIDTH: float = 4.8
const CAR_HEIGHT: float = 0.8
const COUPLER_LENGTH: float = 1.0
const COUPLER_WIDTH: float = 2.4
const COUPLER_HEIGHT: float = 0.5

# Materials
var mat_train_floor: StandardMaterial3D = null
var mat_train_dark: StandardMaterial3D = null
var mat_train_metal: StandardMaterial3D = null
var mat_coupler: StandardMaterial3D = null

# Area cycle state
var current_state: MapState = MapState.AT_MAP
var area_order: Array[int] = [0, 1, 2]
var current_order_index: int = 0
var current_area_id: int = 0
var area_timer: float = AREA_INTERVAL
var transit_timer: float = TRANSIT_INTERVAL
var is_transitioning: bool = false
var has_sent_warning: bool = false

# Node references
var spawn_points_container: Node3D = null
var trains_container: Node3D = null
var areas_container: Node3D = null
var area_nodes: Array[Node3D] = []
var team_trains: Dictionary = {}

func _ready() -> void:
	_init_materials()
	_build_trains_structure()
	_build_spawn_points()
	_build_triangle_maps()
	_activate_initial_map()

func _init_materials() -> void:
	# Primary train platform: gray industrial steel plate
	mat_train_floor = StandardMaterial3D.new()
	mat_train_floor.albedo_color = Color(0.40, 0.43, 0.47, 1.0)
	mat_train_floor.metallic = 0.35
	mat_train_floor.roughness = 0.55

	# Dark metal chassis & bogies
	mat_train_dark = StandardMaterial3D.new()
	mat_train_dark.albedo_color = Color(0.18, 0.20, 0.23, 1.0)
	mat_train_dark.metallic = 0.6
	mat_train_dark.roughness = 0.45

	# Metallic couplers
	mat_coupler = StandardMaterial3D.new()
	mat_coupler.albedo_color = Color(0.28, 0.30, 0.33, 1.0)
	mat_coupler.metallic = 0.7
	mat_coupler.roughness = 0.35

# -------------------------------------------------------------------------
# 1. STATIC TRAIN PLATFORMS FRAMING THE TRIANGLE
# -------------------------------------------------------------------------
func _build_trains_structure() -> void:
	trains_container = Node3D.new()
	trains_container.name = "Trains"
	add_child(trains_container)

	# Build 3 Trains:
	# Train 3 (North): Team 3's train, connecting NW to NE (along X axis at Z = -APOTHEM)
	var train3 = _create_train_edge("Train3_Team3", Color(0.25, 0.85, 0.45))
	train3.position = Vector3(0.0, 0.0, -APOTHEM)
	train3.rotation.y = 0.0
	trains_container.add_child(train3)

	# Train 1 (West): Team 1's train, connecting South to NW
	# Center is at (-9.0, 0, 5.196) and rotated +30 degrees
	var train1 = _create_train_edge("Train1_Team1", Color(0.25, 0.60, 0.98))
	train1.position = Vector3(-9.0, 0.0, APOTHEM * 0.5)
	train1.rotation.y = deg_to_rad(30.0)
	trains_container.add_child(train1)

	# Train 2 (East): Team 2's train, connecting NE to South
	# Center is at (+9.0, 0, 5.196) and rotated -30 degrees
	var train2 = _create_train_edge("Train2_Team2", Color(0.95, 0.35, 0.25))
	train2.position = Vector3(9.0, 0.0, APOTHEM * 0.5)
	train2.rotation.y = deg_to_rad(-30.0)
	trains_container.add_child(train2)

	# Store references for team lookup
	team_trains[1] = train1
	team_trains[2] = train2
	team_trains[3] = train3

	# Corner Junctions: Platforms bridging the ends of trains into a continuous circuit
	_create_corner_junction("Corner_NW", VERTEX_NW)
	_create_corner_junction("Corner_NE", VERTEX_NE)
	_create_corner_junction("Corner_South", VERTEX_SOUTH)

	# Small walkway gangways extending slightly inwards from trains to ensure smooth stepping onto triangle
	_create_train_gangway("Gangway_Train3", Vector3(0.0, 0.0, -APOTHEM + 2.4 + 0.6), Vector3(12.0, CAR_HEIGHT, 1.4))
	_create_train_gangway_rotated("Gangway_Train1", Vector3(-9.0, 0.0, APOTHEM * 0.5) + Vector3(0.6 * sin(deg_to_rad(30.0)), 0.0, -0.6 * cos(deg_to_rad(30.0))), deg_to_rad(30.0), Vector3(12.0, CAR_HEIGHT, 1.4))
	_create_train_gangway_rotated("Gangway_Train2", Vector3(9.0, 0.0, APOTHEM * 0.5) + Vector3(-0.6 * sin(deg_to_rad(-30.0)), 0.0, -0.6 * cos(deg_to_rad(-30.0))), deg_to_rad(-30.0), Vector3(12.0, CAR_HEIGHT, 1.4))

func _create_train_edge(train_name: String, team_accent_color: Color) -> Node3D:
	var edge = Node3D.new()
	edge.name = train_name

	var team_accent_mat = StandardMaterial3D.new()
	team_accent_mat.albedo_color = team_accent_color
	team_accent_mat.emission_enabled = true
	team_accent_mat.emission = team_accent_color * 0.45

	var total_span = (NUM_CARS_PER_TRAIN * CAR_LENGTH) + ((NUM_CARS_PER_TRAIN - 1) * COUPLER_LENGTH)
	var start_x = -total_span * 0.5 + (CAR_LENGTH * 0.5)

	for i in range(NUM_CARS_PER_TRAIN):
		var car_x = start_x + (i * (CAR_LENGTH + COUPLER_LENGTH))
		var car = _create_train_car(i + 1, Vector3(car_x, 0.0, 0.0), team_accent_mat, i == 0 or i == NUM_CARS_PER_TRAIN - 1)
		edge.add_child(car)

		if i < NUM_CARS_PER_TRAIN - 1:
			var coupler_x = car_x + (CAR_LENGTH * 0.5) + (COUPLER_LENGTH * 0.5)
			var coupler = _create_coupler(i + 1, Vector3(coupler_x, 0.0, 0.0))
			edge.add_child(coupler)

	return edge

func _create_train_car(car_index: int, pos: Vector3, accent_mat: StandardMaterial3D, is_end_car: bool) -> StaticBody3D:
	var car = StaticBody3D.new()
	car.name = "TrainCar_%d" % car_index
	car.position = pos
	car.collision_layer = 1 # Ground layer (walkable)
	car.collision_mask = 0

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(CAR_LENGTH, CAR_HEIGHT, CAR_WIDTH)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, -CAR_HEIGHT * 0.5, 0.0)
	car.add_child(col_shape)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(CAR_LENGTH, CAR_HEIGHT, CAR_WIDTH)
	box_mesh.material = mat_train_floor
	mesh_inst.mesh = box_mesh
	mesh_inst.position = col_shape.position
	car.add_child(mesh_inst)

	# Bogies & Wheels under the deck (aesthetic)
	var bogie_mesh = BoxMesh.new()
	bogie_mesh.size = Vector3(1.6, 0.6, CAR_WIDTH * 0.85)
	bogie_mesh.material = mat_train_dark

	for bx in [-CAR_LENGTH * 0.3, CAR_LENGTH * 0.3]:
		var bogie = MeshInstance3D.new()
		bogie.mesh = bogie_mesh
		bogie.position = Vector3(bx, -CAR_HEIGHT - 0.3, 0.0)
		car.add_child(bogie)

	# Team Accent Trim along inner edge facing the triangle
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(CAR_LENGTH * 0.95, 0.08, 0.25)
	trim_mesh.material = accent_mat
	var trim = MeshInstance3D.new()
	trim.mesh = trim_mesh
	trim.position = Vector3(0.0, 0.04, CAR_WIDTH * 0.45)
	car.add_child(trim)

	if is_end_car:
		var plow_mesh = BoxMesh.new()
		plow_mesh.size = Vector3(0.6, 0.6, CAR_WIDTH * 0.9)
		plow_mesh.material = mat_train_dark
		var plow = MeshInstance3D.new()
		plow.mesh = plow_mesh
		var dir_sign = 1.0 if pos.x > 0 else -1.0
		plow.position = Vector3(dir_sign * (CAR_LENGTH * 0.5 - 0.2), -0.5, 0.0)
		car.add_child(plow)

	return car

func _create_coupler(idx: int, pos: Vector3) -> StaticBody3D:
	var coupler = StaticBody3D.new()
	coupler.name = "Coupler_%d" % idx
	coupler.position = pos
	coupler.collision_layer = 1
	coupler.collision_mask = 0

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(COUPLER_LENGTH, COUPLER_HEIGHT, COUPLER_WIDTH)
	col.shape = box_shape
	col.position = Vector3(0.0, -COUPLER_HEIGHT * 0.5, 0.0)
	coupler.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_shape.size
	box_mesh.material = mat_coupler
	mesh_inst.mesh = box_mesh
	mesh_inst.position = col.position
	coupler.add_child(mesh_inst)

	return coupler

func _create_corner_junction(j_name: String, pos: Vector3) -> StaticBody3D:
	var junction = StaticBody3D.new()
	junction.name = j_name
	junction.position = pos
	junction.collision_layer = 1
	junction.collision_mask = 0

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(5.5, CAR_HEIGHT, 5.5)
	col.shape = box_shape
	col.position = Vector3(0.0, -CAR_HEIGHT * 0.5, 0.0)
	junction.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_shape.size
	box_mesh.material = mat_train_floor
	mesh_inst.mesh = box_mesh
	mesh_inst.position = col.position
	junction.add_child(mesh_inst)

	var support = MeshInstance3D.new()
	var s_mesh = BoxMesh.new()
	s_mesh.size = Vector3(3.2, 0.8, 3.2)
	s_mesh.material = mat_train_dark
	support.mesh = s_mesh
	support.position = Vector3(0.0, -CAR_HEIGHT - 0.4, 0.0)
	junction.add_child(support)

	trains_container.add_child(junction)
	return junction

func _create_train_gangway(g_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var gangway = StaticBody3D.new()
	gangway.name = g_name
	gangway.position = pos
	gangway.collision_layer = 1
	gangway.collision_mask = 0

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = Vector3(0.0, -size.y * 0.5, 0.0)
	gangway.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = size
	box_m.material = mat_coupler
	mesh_inst.mesh = box_m
	mesh_inst.position = col.position
	gangway.add_child(mesh_inst)

	trains_container.add_child(gangway)
	return gangway

func _create_train_gangway_rotated(g_name: String, pos: Vector3, rot_y: float, size: Vector3) -> StaticBody3D:
	var g = _create_train_gangway(g_name, pos, size)
	g.rotation.y = rot_y
	return g

func get_train_for_team(team: int) -> Node3D:
	if team_trains.has(team):
		return team_trains[team]
	return team_trains.get(1, null)

# -------------------------------------------------------------------------
# 2. SPAWN POINTS ON TRAINS
# -------------------------------------------------------------------------
func _build_spawn_points() -> void:
	spawn_points_container = Node3D.new()
	spawn_points_container.name = "SpawnPoints"
	add_child(spawn_points_container)

	# Team 3 Spawns on Train 3 (North)
	var t3_spawns = Node3D.new()
	t3_spawns.name = "Team3_Spawns"
	spawn_points_container.add_child(t3_spawns)
	_add_spawn_marker(t3_spawns, "Spawn1", Vector3(-6.0, 0.1, -APOTHEM))
	_add_spawn_marker(t3_spawns, "Spawn2", Vector3(0.0, 0.1, -APOTHEM))
	_add_spawn_marker(t3_spawns, "Spawn3", Vector3(6.0, 0.1, -APOTHEM))

	# Team 1 Spawns on Train 1 (West - rotated +30 deg)
	var t1_spawns = Node3D.new()
	t1_spawns.name = "Team1_Spawns"
	spawn_points_container.add_child(t1_spawns)
	_add_spawn_marker(t1_spawns, "Spawn1", Vector3(-9.0, 0.1, APOTHEM * 0.5) + Vector3(-6.0 * cos(deg_to_rad(30.0)), 0.0, 6.0 * sin(deg_to_rad(30.0))))
	_add_spawn_marker(t1_spawns, "Spawn2", Vector3(-9.0, 0.1, APOTHEM * 0.5))
	_add_spawn_marker(t1_spawns, "Spawn3", Vector3(-9.0, 0.1, APOTHEM * 0.5) + Vector3(6.0 * cos(deg_to_rad(30.0)), 0.0, -6.0 * sin(deg_to_rad(30.0))))

	# Team 2 Spawns on Train 2 (East - rotated -30 deg)
	var t2_spawns = Node3D.new()
	t2_spawns.name = "Team2_Spawns"
	spawn_points_container.add_child(t2_spawns)
	_add_spawn_marker(t2_spawns, "Spawn1", Vector3(9.0, 0.1, APOTHEM * 0.5) + Vector3(6.0 * cos(deg_to_rad(-30.0)), 0.0, -6.0 * sin(deg_to_rad(-30.0))))
	_add_spawn_marker(t2_spawns, "Spawn2", Vector3(9.0, 0.1, APOTHEM * 0.5))
	_add_spawn_marker(t2_spawns, "Spawn3", Vector3(9.0, 0.1, APOTHEM * 0.5) + Vector3(-6.0 * cos(deg_to_rad(-30.0)), 0.0, 6.0 * sin(deg_to_rad(-30.0))))

func _add_spawn_marker(parent: Node3D, m_name: String, pos: Vector3) -> Marker3D:
	var marker = Marker3D.new()
	marker.name = m_name
	marker.position = pos
	parent.add_child(marker)
	return marker

# -------------------------------------------------------------------------
# 3. THREE MAPS OF DIFFERENT COLORS (TRIANGLES THAT DOCK INSIDE THE TRAINS)
# -------------------------------------------------------------------------
func _build_triangle_maps() -> void:
	areas_container = Node3D.new()
	areas_container.name = "EnvironmentAreas"
	add_child(areas_container)

	area_nodes.clear()

	# Map 0: Crimson Canyon (Red)
	var red_map = _create_triangle_map_node(
		0,
		"TriangleMap_Red",
		Color(0.82, 0.22, 0.18), # Terracotta / Crimson platform
		Color(1.0, 0.35, 0.15),  # Glowing red/orange trim
		Color(0.24, 0.12, 0.10), # Dark basalt secondary
		"RedForge"
	)
	areas_container.add_child(red_map)
	area_nodes.append(red_map)

	# Map 1: Verdant Valley (Green)
	var green_map = _create_triangle_map_node(
		1,
		"TriangleMap_Green",
		Color(0.20, 0.68, 0.30), # Emerald jade green platform
		Color(0.30, 1.0, 0.50),  # Glowing mint/emerald trim
		Color(0.14, 0.28, 0.16), # Deep forest rock secondary
		"GreenMonolith"
	)
	areas_container.add_child(green_map)
	area_nodes.append(green_map)

	# Map 2: Frostbite Pass (Blue)
	var blue_map = _create_triangle_map_node(
		2,
		"TriangleMap_Blue",
		Color(0.18, 0.48, 0.90), # Cobalt / Sapphire blue platform
		Color(0.35, 0.85, 1.0),  # Glowing cyan/azure trim
		Color(0.12, 0.22, 0.36), # Deep ice rock secondary
		"BlueCrystal"
	)
	areas_container.add_child(blue_map)
	area_nodes.append(blue_map)

## Creates a complete triangular map of a specific color theme
func _create_triangle_map_node(map_id: int, node_name: String, primary_color: Color, trim_color: Color, secondary_color: Color, monument_type: String) -> Node3D:
	var map_root = Node3D.new()
	map_root.name = node_name
	map_root.set_meta("map_id", map_id)

	# 1. Main Walkable Triangular Platform (AnimatableBody3D on Layer 1)
	var floor_body = AnimatableBody3D.new()
	floor_body.name = "TriangleFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	map_root.add_child(floor_body)

	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = primary_color
	floor_mat.roughness = 0.6
	floor_mat.metallic = 0.25

	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = trim_color
	trim_mat.emission_enabled = true
	trim_mat.emission = trim_color * 0.7

	var sec_mat = StandardMaterial3D.new()
	sec_mat.albedo_color = secondary_color
	sec_mat.roughness = 0.85

	# Create triangular prism mesh & collision
	var prism_mesh = _generate_triangular_prism_mesh(MAP_NW, MAP_NE, MAP_SOUTH, 1.0, floor_mat)
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "FloorMesh"
	mesh_inst.mesh = prism_mesh
	floor_body.add_child(mesh_inst)

	var col_shape = CollisionShape3D.new()
	var poly_shape = ConvexPolygonShape3D.new()
	poly_shape.points = PackedVector3Array([
		Vector3(MAP_NW.x, 0.0, MAP_NW.z),
		Vector3(MAP_NE.x, 0.0, MAP_NE.z),
		Vector3(MAP_SOUTH.x, 0.0, MAP_SOUTH.z),
		Vector3(MAP_NW.x, -1.0, MAP_NW.z),
		Vector3(MAP_NE.x, -1.0, MAP_NE.z),
		Vector3(MAP_SOUTH.x, -1.0, MAP_SOUTH.z)
	])
	col_shape.shape = poly_shape
	floor_body.add_child(col_shape)

	# 2. Glowing perimeter neon trim framing the 3 edges
	_add_edge_trim(floor_body, MAP_NW, MAP_NE, trim_mat)
	_add_edge_trim(floor_body, MAP_NE, MAP_SOUTH, trim_mat)
	_add_edge_trim(floor_body, MAP_SOUTH, MAP_NW, trim_mat)

	# 3. Departure Zone Area3D (detects any players on the triangle map)
	var departure_zone = Area3D.new()
	departure_zone.name = "DepartureZone"
	departure_zone.collision_layer = 0
	departure_zone.collision_mask = 2 # Player physics layer
	var dep_col = CollisionShape3D.new()
	var dep_poly = ConvexPolygonShape3D.new()
	dep_poly.points = PackedVector3Array([
		Vector3(MAP_NW.x, -0.5, MAP_NW.z),
		Vector3(MAP_NE.x, -0.5, MAP_NE.z),
		Vector3(MAP_SOUTH.x, -0.5, MAP_SOUTH.z),
		Vector3(MAP_NW.x, 8.0, MAP_NW.z),
		Vector3(MAP_NE.x, 8.0, MAP_NE.z),
		Vector3(MAP_SOUTH.x, 8.0, MAP_SOUTH.z)
	])
	dep_col.shape = dep_poly
	departure_zone.add_child(dep_col)
	map_root.add_child(departure_zone)

	# 4. Central Monument themed by color
	_build_center_monument(map_root, monument_type, trim_mat, sec_mat)

	# 5. Three Tactical Cover Pillars (Layer 3 - Wall/Obstacle)
	_build_tactical_cover_pillars(map_root, trim_mat, sec_mat)

	return map_root

func _generate_triangular_prism_mesh(v0: Vector3, v1: Vector3, v2: Vector3, height: float, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	# Top face (Y = 0)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(v0.x, 0.0, v0.z))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(v1.x, 0.0, v1.z))
	st.set_uv(Vector2(0.5, 1)); st.add_vertex(Vector3(v2.x, 0.0, v2.z))

	# Bottom face (Y = -height)
	st.set_normal(Vector3.DOWN)
	st.set_uv(Vector2(0.5, 1)); st.add_vertex(Vector3(v2.x, -height, v2.z))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(v1.x, -height, v1.z))
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(v0.x, -height, v0.z))

	# Side quads (each quad = 2 triangles)
	_add_quad_to_surface(st, Vector3(v0.x, 0.0, v0.z), Vector3(v1.x, 0.0, v1.z), Vector3(v1.x, -height, v1.z), Vector3(v0.x, -height, v0.z))
	_add_quad_to_surface(st, Vector3(v1.x, 0.0, v1.z), Vector3(v2.x, 0.0, v2.z), Vector3(v2.x, -height, v2.z), Vector3(v1.x, -height, v1.z))
	_add_quad_to_surface(st, Vector3(v2.x, 0.0, v2.z), Vector3(v0.x, 0.0, v0.z), Vector3(v0.x, -height, v0.z), Vector3(v2.x, -height, v2.z))

	st.generate_normals()
	return st.commit()

func _add_quad_to_surface(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> void:
	st.set_uv(Vector2(0, 0)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p3)

	st.set_uv(Vector2(0, 0)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p3)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p4)

func _add_edge_trim(parent: Node3D, p1: Vector3, p2: Vector3, trim_mat: Material) -> void:
	var trim_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	var dir = p2 - p1
	var length = dir.length()
	b_mesh.size = Vector3(length, 0.12, 0.3)
	b_mesh.material = trim_mat
	trim_mesh.mesh = b_mesh
	trim_mesh.position = (p1 + p2) * 0.5 + Vector3(0.0, 0.06, 0.0)
	trim_mesh.rotation.y = atan2(dir.x, dir.z) + deg_to_rad(90.0)
	parent.add_child(trim_mesh)

func _build_center_monument(parent: Node3D, monument_type: String, trim_mat: Material, sec_mat: Material) -> void:
	var monument = StaticBody3D.new()
	monument.name = "CenterMonument"
	monument.position = Vector3(0.0, 0.0, 0.0)
	monument.collision_layer = 4 # Layer 3 (bit 3 = 4) Wall / Obstacle
	monument.collision_mask = 0

	var col = CollisionShape3D.new()
	var box_col = BoxShape3D.new()
	box_col.size = Vector3(3.6, 5.0, 3.6)
	col.shape = box_col
	col.position = Vector3(0.0, 2.5, 0.0)
	monument.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	if monument_type == "BlueCrystal":
		var p_mesh = PrismMesh.new()
		p_mesh.size = Vector3(3.8, 6.5, 3.8)
		p_mesh.material = trim_mat
		mesh_inst.mesh = p_mesh
		mesh_inst.position = Vector3(0.0, 3.25, 0.0)
	elif monument_type == "GreenMonolith":
		var c_mesh = CylinderMesh.new()
		c_mesh.top_radius = 1.8
		c_mesh.bottom_radius = 2.2
		c_mesh.height = 5.5
		c_mesh.radial_segments = 8
		c_mesh.material = sec_mat
		mesh_inst.mesh = c_mesh
		mesh_inst.position = Vector3(0.0, 2.75, 0.0)
	else: # RedForge
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(3.6, 4.8, 3.6)
		b_mesh.material = sec_mat
		mesh_inst.mesh = b_mesh
		mesh_inst.position = Vector3(0.0, 2.4, 0.0)

	monument.add_child(mesh_inst)

	# Emissive spire or beacon cap
	var beacon = MeshInstance3D.new()
	var b_cap = BoxMesh.new()
	b_cap.size = Vector3(1.4, 1.4, 1.4)
	b_cap.material = trim_mat
	beacon.mesh = b_cap
	beacon.position = Vector3(0.0, 5.2, 0.0)
	monument.add_child(beacon)

	parent.add_child(monument)

func _build_tactical_cover_pillars(parent: Node3D, trim_mat: Material, sec_mat: Material) -> void:
	# 3 cover pillars placed symmetrically along angles towards the 3 vertices
	var angles = [deg_to_rad(90.0), deg_to_rad(210.0), deg_to_rad(330.0)]
	var dist = 5.8
	for i in range(3):
		var angle = angles[i]
		var pos = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var pillar = StaticBody3D.new()
		pillar.name = "CoverPillar_%d" % (i + 1)
		pillar.position = pos
		pillar.collision_layer = 4 # Layer 3 Wall
		pillar.collision_mask = 0

		var col = CollisionShape3D.new()
		var b_shape = BoxShape3D.new()
		b_shape.size = Vector3(1.6, 2.2, 1.6)
		col.shape = b_shape
		col.position = Vector3(0.0, 1.1, 0.0)
		pillar.add_child(col)

		var mesh = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(1.6, 2.2, 1.6)
		b_mesh.material = sec_mat
		mesh.mesh = b_mesh
		mesh.position = col.position
		pillar.add_child(mesh)

		var accent = MeshInstance3D.new()
		var a_mesh = BoxMesh.new()
		a_mesh.size = Vector3(1.7, 0.2, 1.7)
		a_mesh.material = trim_mat
		accent.mesh = a_mesh
		accent.position = Vector3(0.0, 1.8, 0.0)
		pillar.add_child(accent)

		parent.add_child(pillar)

# -------------------------------------------------------------------------
# 4. INITIALIZATION & DYNAMIC CYCLING
# -------------------------------------------------------------------------
func _activate_initial_map() -> void:
	current_area_id = area_order[current_order_index]
	current_state = MapState.AT_MAP
	area_timer = AREA_INTERVAL
	transit_timer = TRANSIT_INTERVAL
	is_transitioning = false
	has_sent_warning = false

	for i in range(area_nodes.size()):
		var n = area_nodes[i]
		var is_active = (i == current_area_id)
		n.visible = is_active
		n.position = Vector3.ZERO
		n.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

func set_area_sequence(sequence: Array) -> void:
	area_order.clear()
	for s in sequence:
		area_order.append(int(s))
	current_order_index = 0
	current_area_id = area_order[0]
	current_state = MapState.AT_MAP
	area_timer = AREA_INTERVAL
	transit_timer = TRANSIT_INTERVAL
	is_transitioning = false
	has_sent_warning = false
	_activate_initial_map()

func _process(delta: float) -> void:
	if is_transitioning:
		return

	if current_state == MapState.AT_MAP:
		area_timer -= delta
		if area_timer <= 10.0 and not has_sent_warning:
			has_sent_warning = true
			var next_idx = (current_order_index + 1) % area_order.size()
			var next_id = area_order[next_idx]
			area_warning.emit(area_timer, AREA_NAMES[next_id])

		if area_timer <= 0.0:
			area_timer = 0.0
			depart_current_triangle()
	elif current_state == MapState.IN_TRANSIT:
		transit_timer -= delta
		if transit_timer <= 0.0:
			transit_timer = 0.0
			current_order_index = (current_order_index + 1) % area_order.size()
			var next_area_id = area_order[current_order_index]
			arrive_at_triangle(next_area_id)

# -------------------------------------------------------------------------
# 5. DEPARTURE, ARRIVAL, AND ELIMINATION CONTRACT
# -------------------------------------------------------------------------
## Departs the active triangle map: kills players remaining on it and slides it away
func depart_current_triangle() -> void:
	if is_transitioning or current_state == MapState.IN_TRANSIT:
		return

	is_transitioning = true
	current_state = MapState.IN_TRANSIT
	transit_timer = TRANSIT_INTERVAL
	has_sent_warning = false

	# 1. Immediately eliminate any players remaining on the triangle map!
	eliminate_abandoned_players()

	# 2. Smoothly slide departing triangle away along +Z into the distance
	var departing_map = area_nodes[current_area_id] if current_area_id < area_nodes.size() else null
	if departing_map:
		var departing_id = current_area_id
		var departing_name = AREA_NAMES[departing_id]
		area_departed.emit(departing_id, departing_name)

		var tween = create_tween()
		tween.tween_property(departing_map, "position:z", 160.0, 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			if is_instance_valid(departing_map):
				departing_map.visible = false
				departing_map.process_mode = Node.PROCESS_MODE_DISABLED
				departing_map.position = Vector3(0.0, 0.0, -160.0)
			is_transitioning = false
		)
	else:
		is_transitioning = false

## Arrives at the next triangle in the loop: glides the new colored triangle into the trains frame
func arrive_at_triangle(new_area_id: int) -> void:
	if new_area_id < 0 or new_area_id >= area_nodes.size():
		return

	is_transitioning = true
	current_area_id = new_area_id
	current_state = MapState.AT_MAP
	area_timer = AREA_INTERVAL
	has_sent_warning = false

	var arriving_map = area_nodes[new_area_id]
	arriving_map.visible = true
	arriving_map.process_mode = Node.PROCESS_MODE_INHERIT
	arriving_map.position = Vector3(0.0, 0.0, -160.0)

	var tween = create_tween()
	tween.tween_property(arriving_map, "position:z", 0.0, 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		is_transitioning = false
		area_changed.emit(current_area_id, AREA_NAMES[current_area_id])
	)

## Compatibility helper for test suites and manual triggers
func advance_to_next_area() -> void:
	if current_state == MapState.AT_MAP:
		depart_current_triangle()
	else:
		current_order_index = (current_order_index + 1) % area_order.size()
		arrive_at_triangle(area_order[current_order_index])

## Compatibility helper for transitioning directly
func transition_to_area(new_area_id: int) -> void:
	arrive_at_triangle(new_area_id)

# -------------------------------------------------------------------------
# 6. PLAYER ELIMINATION & CAMERA DIRECTION TO TEAM TRAIN
# -------------------------------------------------------------------------
## Finds all living players on the triangle map, eliminates them, and directs their camera to their train
func eliminate_abandoned_players() -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		players_container = find_child("Players", true, false)
	if not players_container:
		# Search the tree for any living player nodes
		_eliminate_players_in_subtree(get_tree().root)
		return

	for child in players_container.get_children():
		if child is Node3D and not child.get("is_dead"):
			if is_player_on_triangle(child):
				_execute_abandoned_player(child)

func _eliminate_players_in_subtree(node: Node) -> void:
	if node is Node3D and node.has_method("die") and not node.get("is_dead"):
		if is_player_on_triangle(node):
			_execute_abandoned_player(node)
	for c in node.get_children():
		_eliminate_players_in_subtree(c)

func _execute_abandoned_player(player: Node3D) -> void:
	# 1. Direct camera to follow their team's train
	var team_id = player.get("team_id") if "team_id" in player else 1
	var team_train = get_train_for_team(team_id)
	if player.has_method("direct_camera_to_train") and team_train:
		player.direct_camera_to_train(team_train)

	if player.has_method("sync_direct_camera_to_train") and player.has_method("is_multiplayer_match") and player.is_multiplayer_match():
		player.sync_direct_camera_to_train.rpc(team_id)

	# 2. Kill the abandoned player
	if player.has_method("die"):
		player.die()

## Checks whether a player is on the triangle map (and not safe on a train platform)
func is_player_on_triangle(player: Node3D) -> bool:
	if not is_instance_valid(player):
		return false

	var global_pos = player.global_position

	# If the player is on any train platform or corner junction, they are safe!
	if _is_position_on_any_train(global_pos):
		return false

	# 1. Check if the player is touching a floor belonging to the current triangle map
	if player.has_method("is_on_floor") and player.is_on_floor():
		if player.has_method("get_floor_collider"):
			var col = player.get_floor_collider()
			if is_instance_valid(col):
				var curr_map = area_nodes[current_area_id] if current_area_id < area_nodes.size() else null
				if curr_map and (col == curr_map or curr_map.is_ancestor_of(col)):
					return true

	# 2. Check the DepartureZone Area3D of the active triangle map
	var active_map = area_nodes[current_area_id] if current_area_id < area_nodes.size() else null
	if active_map:
		var zone = active_map.get_node_or_null("DepartureZone") as Area3D
		if zone and zone.overlaps_body(player):
			return true

	# 3. Geometric point-in-triangle check for the inner docked map
	if is_point_in_triangle_map(global_pos):
		return true

	return false

## Mathematical 2D point-in-equilateral-triangle test for docked map platform
func is_point_in_triangle_map(pos: Vector3) -> bool:
	if pos.y < -2.0 or pos.y > 8.0:
		return false
	var x = pos.x
	var z = pos.z

	# MAP_NW: (-14.8956, -8.6)
	# MAP_NE: (14.8956, -8.6)
	# MAP_SOUTH: (0.0, 17.2)
	var cp1 = 29.7912 * (z + 8.6)
	var cp2 = -14.8956 * (z + 8.6) - 25.8 * (x - 14.8956)
	var cp3 = -14.8956 * (z - 17.2) + 25.8 * x

	var has_neg = (cp1 < -0.01) or (cp2 < -0.01) or (cp3 < -0.01)
	var has_pos = (cp1 > 0.01) or (cp2 > 0.01) or (cp3 > 0.01)
	return not (has_neg and has_pos)

## Verifies if a given world position is on any of the 3 static trains or 3 corner platforms
func _is_position_on_any_train(pos: Vector3) -> bool:
	# Train 3 (North): X in [-18.0, 18.0], Z in [-APOTHEM - 2.8, -APOTHEM + 2.8]
	if pos.x >= -19.0 and pos.x <= 19.0 and pos.z >= -APOTHEM - 3.2 and pos.z <= -APOTHEM + 3.2:
		return true

	# Corner NW: (-18, -10.4), Corner NE: (18, -10.4), Corner South: (0, 20.8)
	if pos.distance_to(VERTEX_NW) <= 3.8:
		return true
	if pos.distance_to(VERTEX_NE) <= 3.8:
		return true
	if pos.distance_to(VERTEX_SOUTH) <= 3.8:
		return true

	# Train 1 (West): Center at (-9.0, 5.196), line from South to NW
	var d1 = _dist_to_segment_2d(Vector2(pos.x, pos.z), Vector2(VERTEX_SOUTH.x, VERTEX_SOUTH.z), Vector2(VERTEX_NW.x, VERTEX_NW.z))
	if d1 <= (CAR_WIDTH * 0.5) + 0.6:
		return true

	# Train 2 (East): Center at (9.0, 5.196), line from South to NE
	var d2 = _dist_to_segment_2d(Vector2(pos.x, pos.z), Vector2(VERTEX_SOUTH.x, VERTEX_SOUTH.z), Vector2(VERTEX_NE.x, VERTEX_NE.z))
	if d2 <= (CAR_WIDTH * 0.5) + 0.6:
		return true

	return false

func _dist_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ap = p - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return ap.length()
	var t = clamp(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj = a + ab * t
	return (p - proj).length()

func get_current_area_name() -> String:
	if current_area_id >= 0 and current_area_id < AREA_NAMES.size():
		return AREA_NAMES[current_area_id]
	return "Crimson Canyon (Red)"

func get_current_area_description() -> String:
	if current_area_id >= 0 and current_area_id < AREA_DESCRIPTIONS.size():
		return AREA_DESCRIPTIONS[current_area_id]
	return ""

func get_time_remaining() -> float:
	if current_state == MapState.AT_MAP:
		return area_timer
	return transit_timer

func get_current_area_id() -> int:
	return current_area_id
