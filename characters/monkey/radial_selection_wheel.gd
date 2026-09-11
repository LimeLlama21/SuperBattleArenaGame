class_name RadialSelectionWheel
extends CanvasLayer

signal option_selected(option_name: String)

var is_wheel_open: bool = false
var wheel_center: Vector2 = Vector2.ZERO
var current_hovered_option: String = "cancel"

const DEADZONE_RADIUS: float = 38.0
const OUTER_RADIUS: float = 135.0
const TREE_OFFSET_Y: float = -78.0
const ROCK_OFFSET_Y: float = 78.0
const OPTION_RADIUS: float = 38.0

var container: Control = null

func _ready() -> void:
	layer = 100
	container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.draw.connect(_on_container_draw)
	container.hide()

func open(at_position: Vector2 = Vector2.ZERO) -> void:
	if at_position == Vector2.ZERO:
		at_position = container.get_viewport_rect().size * 0.5
	wheel_center = at_position
	is_wheel_open = true
	current_hovered_option = "cancel"
	container.show()
	container.queue_redraw()

func close_and_select() -> String:
	if not is_wheel_open:
		return "cancel"
	is_wheel_open = false
	container.hide()
	var final_choice = current_hovered_option
	option_selected.emit(final_choice)
	return final_choice

func cancel_wheel() -> void:
	if not is_wheel_open:
		return
	is_wheel_open = false
	container.hide()
	option_selected.emit("cancel")

func _process(_delta: float) -> void:
	if not is_wheel_open:
		return
	
	var mouse_pos = container.get_global_mouse_position()
	var dist_tree = mouse_pos.distance_to(wheel_center + Vector2(0, TREE_OFFSET_Y))
	var dist_rock = mouse_pos.distance_to(wheel_center + Vector2(0, ROCK_OFFSET_Y))
	
	var prev_hover = current_hovered_option
	if dist_tree <= (OPTION_RADIUS + 12.0):
		current_hovered_option = "tree"
	elif dist_rock <= (OPTION_RADIUS + 12.0):
		current_hovered_option = "rock"
	else:
		current_hovered_option = "cancel"
	
	if prev_hover != current_hovered_option:
		container.queue_redraw()
	else:
		# Keep line to mouse updated
		container.queue_redraw()

func _on_container_draw() -> void:
	if not is_wheel_open:
		return
	
	var font: Font = null
	if container.has_theme_font("font"):
		font = container.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	
	# Background outer circle
	container.draw_circle(wheel_center, OUTER_RADIUS, Color(0.06, 0.07, 0.10, 0.88))
	container.draw_arc(wheel_center, OUTER_RADIUS, 0, TAU, 64, Color(0.95, 0.80, 0.20, 0.65), 3.0)
	
	# Connecting Line from Center to Cursor
	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = (mouse_pos - wheel_center)
	if to_mouse.length() > 5.0:
		var line_end = wheel_center + to_mouse.limit_length(OUTER_RADIUS)
		container.draw_line(wheel_center, line_end, Color(1, 1, 1, 0.45), 2.5)

	# Center Cancel circle ('✕')
	var cancel_active = (current_hovered_option == "cancel")
	var cancel_col = Color(0.85, 0.22, 0.22, 0.95) if cancel_active else Color(0.24, 0.25, 0.30, 0.75)
	container.draw_circle(wheel_center, DEADZONE_RADIUS, cancel_col)
	container.draw_arc(wheel_center, DEADZONE_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.9) if cancel_active else Color(0.5, 0.5, 0.5, 0.4), 2.5 if cancel_active else 1.5)
	
	if font:
		container.draw_string(font, wheel_center + Vector2(-8, 9), "✕", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(1, 1, 1, 1))

	# Top Sector: TREE (0, TREE_OFFSET_Y)
	var tree_active = (current_hovered_option == "tree")
	var tree_center = wheel_center + Vector2(0, TREE_OFFSET_Y)
	var tree_bg_col = Color(0.12, 0.60, 0.28, 0.95) if tree_active else Color(0.12, 0.28, 0.16, 0.70)
	container.draw_circle(tree_center, OPTION_RADIUS, tree_bg_col)
	container.draw_arc(tree_center, OPTION_RADIUS, 0, TAU, 32, Color(0.35, 1.0, 0.55, 1.0) if tree_active else Color(0.2, 0.6, 0.3, 0.5), 3.5 if tree_active else 1.5)
	
	if font:
		container.draw_string(font, tree_center + Vector2(-28, -2), "🌲 TREE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 1, 1, 1) if tree_active else Color(0.85, 0.95, 0.85, 0.8))

	# Bottom Sector: ROCK (0, ROCK_OFFSET_Y)
	var rock_active = (current_hovered_option == "rock")
	var rock_center = wheel_center + Vector2(0, ROCK_OFFSET_Y)
	var rock_bg_col = Color(0.70, 0.48, 0.20, 0.95) if rock_active else Color(0.28, 0.22, 0.16, 0.70)
	container.draw_circle(rock_center, OPTION_RADIUS, rock_bg_col)
	container.draw_arc(rock_center, OPTION_RADIUS, 0, TAU, 32, Color(1.0, 0.80, 0.30, 1.0) if rock_active else Color(0.6, 0.45, 0.3, 0.5), 3.5 if rock_active else 1.5)
	
	if font:
		container.draw_string(font, rock_center + Vector2(-28, 6), "🪨 ROCK", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 1, 1, 1) if rock_active else Color(0.95, 0.90, 0.85, 0.8))
