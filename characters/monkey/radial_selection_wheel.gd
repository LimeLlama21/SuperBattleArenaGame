class_name RadialSelectionWheel
extends CanvasLayer

signal option_selected(option_name: String)
signal cancelled()

var is_wheel_open: bool = false
var wheel_center: Vector2 = Vector2.ZERO
var current_hovered_option: String = "cancel"

var deadzone_radius: float = 38.0
var outer_radius: float = 135.0
var option_radius: float = 38.0

const DEFAULT_OPTIONS: Array = [
	{
		"id": "tree",
		"label": "🌲 TREE",
		"color": Color(0.12, 0.60, 0.28, 0.95),
		"inactive_color": Color(0.12, 0.28, 0.16, 0.70),
		"arc_color": Color(0.35, 1.0, 0.55, 1.0)
	},
	{
		"id": "rock",
		"label": "🪨 ROCK",
		"color": Color(0.70, 0.48, 0.20, 0.95),
		"inactive_color": Color(0.28, 0.22, 0.16, 0.70),
		"arc_color": Color(1.0, 0.80, 0.30, 1.0)
	}
]

var options: Array = []
var container: Control = null

func _ready() -> void:
	layer = 100
	container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.draw.connect(_on_container_draw)
	container.hide()
	if options.is_empty():
		setup_options(DEFAULT_OPTIONS)

func setup_options(new_options: Array) -> void:
	options.clear()
	for opt in new_options:
		if opt is Dictionary:
			options.append(opt.duplicate(true))
		elif opt is String:
			options.append({"id": opt, "label": opt.capitalize()})
	if options.is_empty():
		options = DEFAULT_OPTIONS.duplicate(true)

func open(at_position: Vector2 = Vector2.ZERO, runtime_options: Array = []) -> void:
	if not runtime_options.is_empty():
		setup_options(runtime_options)
	elif options.is_empty():
		setup_options(DEFAULT_OPTIONS)

	if at_position == Vector2.ZERO and container:
		at_position = container.get_viewport_rect().size * 0.5
	wheel_center = at_position
	is_wheel_open = true
	current_hovered_option = "cancel"
	if container:
		container.show()
		container.queue_redraw()

func close_and_select() -> String:
	if not is_wheel_open:
		return "cancel"
	is_wheel_open = false
	if container:
		container.hide()
	var final_choice = current_hovered_option
	if final_choice == "cancel":
		cancelled.emit()
	option_selected.emit(final_choice)
	return final_choice

func cancel_wheel() -> void:
	if not is_wheel_open:
		return
	is_wheel_open = false
	if container:
		container.hide()
	current_hovered_option = "cancel"
	cancelled.emit()
	option_selected.emit("cancel")

func get_option_center(index: int, total: int) -> Vector2:
	if total <= 0:
		return wheel_center
	var angle = -PI * 0.5 + (float(index) / float(total)) * TAU
	var offset_dist = (deadzone_radius + outer_radius) * 0.52
	return wheel_center + Vector2(cos(angle), sin(angle)) * offset_dist

func _process(_delta: float) -> void:
	if not is_wheel_open or not container:
		return

	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = mouse_pos - wheel_center
	var dist = to_mouse.length()

	var prev_hover = current_hovered_option
	if dist <= deadzone_radius:
		current_hovered_option = "cancel"
	elif dist > (outer_radius + 40.0):
		current_hovered_option = "cancel"
	else:
		var best_opt = "cancel"
		var min_opt_dist = 999999.0
		var num_opts = options.size()
		for i in range(num_opts):
			var opt_c = get_option_center(i, num_opts)
			var d = mouse_pos.distance_to(opt_c)
			if d < min_opt_dist:
				min_opt_dist = d
				best_opt = str(options[i].get("id", "cancel"))
		if min_opt_dist <= (option_radius + 24.0):
			current_hovered_option = best_opt
		else:
			current_hovered_option = "cancel"

	if prev_hover != current_hovered_option:
		container.queue_redraw()
	else:
		container.queue_redraw()

func _on_container_draw() -> void:
	if not is_wheel_open or not container:
		return

	var font: Font = null
	if container.has_theme_font("font"):
		font = container.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font

	# Background outer circle
	container.draw_circle(wheel_center, outer_radius, Color(0.06, 0.07, 0.10, 0.88))
	container.draw_arc(wheel_center, outer_radius, 0, TAU, 64, Color(0.95, 0.80, 0.20, 0.65), 3.0)

	# Connecting Line from Center to Cursor
	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = (mouse_pos - wheel_center)
	if to_mouse.length() > 5.0:
		var line_end = wheel_center + to_mouse.limit_length(outer_radius)
		container.draw_line(wheel_center, line_end, Color(1, 1, 1, 0.45), 2.5)

	# Center Cancel circle ('✕')
	var cancel_active = (current_hovered_option == "cancel")
	var cancel_col = Color(0.85, 0.22, 0.22, 0.95) if cancel_active else Color(0.24, 0.25, 0.30, 0.75)
	container.draw_circle(wheel_center, deadzone_radius, cancel_col)
	container.draw_arc(wheel_center, deadzone_radius, 0, TAU, 32, Color(1, 1, 1, 0.9) if cancel_active else Color(0.5, 0.5, 0.5, 0.4), 2.5 if cancel_active else 1.5)

	if font:
		container.draw_string(font, wheel_center + Vector2(-8, 9), "✕", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(1, 1, 1, 1))

	# Draw options around wheel
	var num_opts = options.size()
	for i in range(num_opts):
		var opt = options[i]
		var opt_id = str(opt.get("id", ""))
		var opt_label = str(opt.get("label", opt_id.capitalize()))
		var is_active = (current_hovered_option == opt_id)
		var opt_center = get_option_center(i, num_opts)

		var base_col = opt.get("color", Color(0.25, 0.45, 0.85, 0.95))
		var inactive_col = opt.get("inactive_color", Color(base_col.r * 0.4, base_col.g * 0.4, base_col.b * 0.4, 0.70))
		var arc_col = opt.get("arc_color", Color(base_col.r * 1.3, base_col.g * 1.3, base_col.b * 1.3, 1.0))

		var bg_col = base_col if is_active else inactive_col
		container.draw_circle(opt_center, option_radius, bg_col)
		container.draw_arc(opt_center, option_radius, 0, TAU, 32, arc_col if is_active else Color(0.5, 0.5, 0.5, 0.4), 3.5 if is_active else 1.5)

		if font:
			# Center text horizontally & vertically
			var string_size = font.get_string_size(opt_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
			var text_pos = opt_center + Vector2(-string_size.x * 0.5, string_size.y * 0.3)
			var text_col = Color(1, 1, 1, 1) if is_active else Color(0.9, 0.9, 0.9, 0.8)
			container.draw_string(font, text_pos, opt_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_col)
