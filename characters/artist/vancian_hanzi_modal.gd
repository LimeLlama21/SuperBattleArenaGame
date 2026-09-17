class_name VancianHanziModal
extends CanvasLayer

const HanziPointCloudRecognizer = preload("res://characters/artist/hanzi_point_cloud_recognizer.gd")

signal option_selected(choice: String)
signal cancelled()
signal spell_inscribed(slot_index: int, element: String)

enum State { WHEEL, DRAWING }
var current_state: State = State.WHEEL

var is_modal_open: bool = false
var wheel_center: Vector2 = Vector2.ZERO
var current_hovered_option: String = "cancel"

var deadzone_radius: float = 40.0
var outer_radius: float = 145.0
var option_radius: float = 38.0

var options: Array = []
var container: Control = null
var caster: Node = null

var selected_slot_index: int = 0
var current_stroke: Array[Vector2] = []
var all_strokes: Array = [] # Array of Array[Vector2]
var recognized_result: Dictionary = {}
var feedback_text: String = ""
var feedback_color: Color = Color(1, 1, 1, 1)

const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.95, 0.35, 0.15, 0.95),
	"water": Color(0.25, 0.65, 0.95, 0.95),
	"air": Color(0.45, 0.90, 0.65, 0.95),
	"earth": Color(0.85, 0.65, 0.25, 0.95)
}

const ELEMENT_HANZI: Dictionary = {
	"fire": "火",
	"water": "水",
	"air": "风",
	"earth": "土"
}

func _ready() -> void:
	layer = 100
	container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.draw.connect(_on_container_draw)
	container.hide()

func open(at_position: Vector2 = Vector2.ZERO, runtime_options: Array = []) -> void:
	if not runtime_options.is_empty():
		options = runtime_options.duplicate(true)
	elif options.is_empty():
		_setup_default_options()

	if at_position == Vector2.ZERO and container:
		at_position = container.get_viewport_rect().size * 0.5
	wheel_center = at_position

	current_state = State.WHEEL
	is_modal_open = true
	current_hovered_option = "cancel"
	all_strokes.clear()
	current_stroke.clear()
	recognized_result = {}
	feedback_text = ""

	if container:
		container.show()
		container.queue_redraw()

func _setup_default_options() -> void:
	options = [
		{"id": "slot_0:empty", "slot_index": 0, "label": "⚪ [Empty]", "is_empty": true},
		{"id": "slot_1:empty", "slot_index": 1, "label": "⚪ [Empty]", "is_empty": true},
		{"id": "slot_2:empty", "slot_index": 2, "label": "⚪ [Empty]", "is_empty": true},
		{"id": "slot_3:empty", "slot_index": 3, "label": "⚪ [Empty]", "is_empty": true}
	]

func close_and_select() -> String:
	if not is_modal_open:
		return "cancel"

	if current_state == State.DRAWING:
		# If user was in drawing mode and pressed to close/cancel
		cancel_modal()
		return "cancel"

	is_modal_open = false
	if container:
		container.hide()

	var final_choice = current_hovered_option
	if final_choice == "cancel":
		cancelled.emit()
	option_selected.emit(final_choice)
	return final_choice

func cancel_modal() -> void:
	if not is_modal_open:
		return
	is_modal_open = false
	if container:
		container.hide()
	current_hovered_option = "cancel"
	cancelled.emit()
	option_selected.emit("cancel")

func cancel_wheel() -> void:
	cancel_modal()

func cancel() -> void:
	cancel_modal()

func get_option_center(index: int, total: int) -> Vector2:
	if total <= 0:
		return wheel_center
	var angle = -PI * 0.5 + (float(index) / float(total)) * TAU
	var offset_dist = (deadzone_radius + outer_radius) * 0.52
	return wheel_center + Vector2(cos(angle), sin(angle)) * offset_dist

func _process(_delta: float) -> void:
	if not is_modal_open or not container:
		return

	if current_state == State.WHEEL:
		_process_wheel_hover()
	container.queue_redraw()

func _process_wheel_hover() -> void:
	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = mouse_pos - wheel_center
	var dist = to_mouse.length()

	var prev_hover = current_hovered_option
	if dist <= deadzone_radius:
		current_hovered_option = "cancel"
	elif dist > (outer_radius + 45.0):
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

func _input(event: InputEvent) -> void:
	if not is_modal_open or not container:
		return

	if event.is_action_pressed("ui_cancel"):
		if current_state == State.DRAWING:
			transition_to_wheel()
		else:
			cancel_modal()
		get_viewport().set_input_as_handled()
		return

	if current_state == State.WHEEL:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_wheel_click()
			get_viewport().set_input_as_handled()
	elif current_state == State.DRAWING:
		_handle_drawing_input(event)

func _handle_wheel_click() -> void:
	if current_hovered_option == "cancel":
		cancel_modal()
		return

	# Find matching option dictionary
	var selected_opt: Dictionary = {}
	for opt in options:
		if str(opt.get("id", "")) == current_hovered_option:
			selected_opt = opt
			break

	if selected_opt.is_empty():
		return

	var is_empty = selected_opt.get("is_empty", false)
	var slot_idx = int(selected_opt.get("slot_index", 0))

	if is_empty:
		# Empty slot -> Transition into Hanzi Calligraphy Drawing!
		selected_slot_index = slot_idx
		transition_to_drawing()
	else:
		# Prepared slot -> Select it and close modal to cast!
		is_modal_open = false
		if container:
			container.hide()
		option_selected.emit(current_hovered_option)

func transition_to_drawing() -> void:
	current_state = State.DRAWING
	all_strokes.clear()
	current_stroke.clear()
	recognized_result = {}
	feedback_text = "Draw Chinese character for spell: 火 (Fire), 水 (Water), 风 (Air), 土 (Earth)"
	feedback_color = Color(0.9, 0.9, 0.7, 1.0)
	if container:
		container.queue_redraw()

func transition_to_wheel() -> void:
	current_state = State.WHEEL
	all_strokes.clear()
	current_stroke.clear()
	if caster and caster.has_method("get_vancian_modal_options"):
		options = caster.call("get_vancian_modal_options", "R")
	if container:
		container.queue_redraw()

func _handle_drawing_input(event: InputEvent) -> void:
	var canvas_rect = _get_drawing_canvas_rect()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if canvas_rect.has_point(event.position):
				current_stroke = [event.position]
				get_viewport().set_input_as_handled()
			else:
				# Check button clicks
				_handle_canvas_button_clicks(event.position)
				get_viewport().set_input_as_handled()
		else:
			if not current_stroke.is_empty():
				all_strokes.append(current_stroke.duplicate())
				current_stroke.clear()
				_evaluate_drawing()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not current_stroke.is_empty():
			current_stroke.append(event.position)
			get_viewport().set_input_as_handled()
		elif canvas_rect.has_point(event.position):
			current_stroke = [event.position]
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_C: # Clear
			all_strokes.clear()
			current_stroke.clear()
			recognized_result = {}
			feedback_text = "Canvas cleared."
			container.queue_redraw()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE: # Confirm
			_confirm_inscription()

func _get_drawing_canvas_rect() -> Rect2:
	var vp_size = container.get_viewport_rect().size if container else Vector2(1280, 720)
	var canvas_size = Vector2(380, 380)
	var canvas_pos = (vp_size - canvas_size) * 0.5
	return Rect2(canvas_pos, canvas_size)

func _handle_canvas_button_clicks(click_pos: Vector2) -> void:
	var vp_size = container.get_viewport_rect().size if container else Vector2(1280, 720)
	var canvas_rect = _get_drawing_canvas_rect()

	# Inscribe button rect
	var inscribe_rect = Rect2(canvas_rect.position.x, canvas_rect.end.y + 16, 115, 38)
	# Clear button rect
	var clear_rect = Rect2(canvas_rect.position.x + 130, canvas_rect.end.y + 16, 115, 38)
	# Back to Wheel button rect
	var back_rect = Rect2(canvas_rect.position.x + 260, canvas_rect.end.y + 16, 120, 38)

	if inscribe_rect.has_point(click_pos):
		_confirm_inscription()
	elif clear_rect.has_point(click_pos):
		all_strokes.clear()
		current_stroke.clear()
		recognized_result = {}
		feedback_text = "Canvas cleared."
		container.queue_redraw()
	elif back_rect.has_point(click_pos):
		transition_to_wheel()

func _evaluate_drawing() -> void:
	if all_strokes.is_empty():
		return

	var result = HanziPointCloudRecognizer.recognize(all_strokes)
	recognized_result = result
	var elem = str(result.get("element", ""))
	var hanzi = str(result.get("hanzi", ""))
	var score = float(result.get("score", 0.0))

	if elem != "" and score >= 0.40:
		feedback_text = "Recognized: %s [%s] (Confidence: %d%%)" % [hanzi, elem.capitalize(), int(score * 100)]
		feedback_color = ELEMENT_COLORS.get(elem, Color.WHITE)
	else:
		feedback_text = "Strokes ambiguous. Try 火 (Fire), 水 (Water), 风 (Air), or 土 (Earth)."
		feedback_color = Color(0.9, 0.4, 0.4, 1.0)
	container.queue_redraw()

func _confirm_inscription() -> void:
	if recognized_result.is_empty():
		_evaluate_drawing()

	var elem = str(recognized_result.get("element", ""))
	var score = float(recognized_result.get("score", 0.0))

	if elem != "" and score >= 0.35:
		# Success! Inscribe spell into caster slot
		if caster and "vancian_slots" in caster and caster.vancian_slots.size() > selected_slot_index:
			caster.vancian_slots[selected_slot_index] = elem

		spell_inscribed.emit(selected_slot_index, elem)

		# Close modal with "inscribed" choice so caster applies 1.0s cooldown
		is_modal_open = false
		if container:
			container.hide()
		option_selected.emit("inscribed:%d:%s" % [selected_slot_index, elem])
	else:
		feedback_text = "Draw a clearer character before inscribing!"
		feedback_color = Color(1.0, 0.3, 0.3, 1.0)
		container.queue_redraw()

func _on_container_draw() -> void:
	if not is_modal_open or not container:
		return

	var font: Font = null
	if container.has_theme_font("font"):
		font = container.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font

	if current_state == State.WHEEL:
		_draw_wheel_state(font)
	elif current_state == State.DRAWING:
		_draw_drawing_state(font)

func _draw_wheel_state(font: Font) -> void:
	# Background outer circle
	container.draw_circle(wheel_center, outer_radius, Color(0.06, 0.08, 0.10, 0.90))
	container.draw_arc(wheel_center, outer_radius, 0, TAU, 64, Color(0.85, 0.72, 0.28, 0.75), 3.0)

	# Connecting line to cursor
	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = (mouse_pos - wheel_center)
	if to_mouse.length() > 5.0:
		var line_end = wheel_center + to_mouse.limit_length(outer_radius)
		container.draw_line(wheel_center, line_end, Color(1, 1, 1, 0.40), 2.0)

	# Center cancel circle
	var cancel_active = (current_hovered_option == "cancel")
	var cancel_col = Color(0.85, 0.22, 0.22, 0.95) if cancel_active else Color(0.24, 0.25, 0.30, 0.75)
	container.draw_circle(wheel_center, deadzone_radius, cancel_col)
	container.draw_arc(wheel_center, deadzone_radius, 0, TAU, 32, Color(1, 1, 1, 0.9) if cancel_active else Color(0.5, 0.5, 0.5, 0.4), 2.5 if cancel_active else 1.5)

	if font:
		container.draw_string(font, wheel_center + Vector2(-8, 9), "✕", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, 1))

	# Draw 4 Vancian slots
	var num_opts = options.size()
	for i in range(num_opts):
		var opt = options[i]
		var opt_id = str(opt.get("id", ""))
		var opt_label = str(opt.get("label", "Slot"))
		var is_empty = opt.get("is_empty", false)
		var is_active = (current_hovered_option == opt_id)
		var opt_center = get_option_center(i, num_opts)

		var bg_col = Color(0.18, 0.20, 0.25, 0.85)
		var border_col = Color(0.5, 0.5, 0.5, 0.5)

		if not is_empty:
			var elem_col = opt.get("color", Color(0.8, 0.6, 0.2, 0.9))
			bg_col = elem_col if is_active else Color(elem_col.r * 0.45, elem_col.g * 0.45, elem_col.b * 0.45, 0.75)
			border_col = Color(elem_col.r * 1.2, elem_col.g * 1.2, elem_col.b * 1.2, 1.0) if is_active else Color(0.6, 0.6, 0.6, 0.5)
		else:
			if is_active:
				bg_col = Color(0.35, 0.38, 0.45, 0.95)
				border_col = Color(0.95, 0.85, 0.35, 1.0)

		container.draw_circle(opt_center, option_radius, bg_col)
		container.draw_arc(opt_center, option_radius, 0, TAU, 32, border_col, 3.0 if is_active else 1.5)

		if font:
			var string_size = font.get_string_size(opt_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			var text_pos = opt_center + Vector2(-string_size.x * 0.5, string_size.y * 0.3)
			var text_col = Color(1, 1, 1, 1) if is_active else Color(0.85, 0.85, 0.85, 0.8)
			container.draw_string(font, text_pos, opt_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, text_col)

func _draw_drawing_state(font: Font) -> void:
	var canvas_rect = _get_drawing_canvas_rect()

	# Dark translucent backdrop covering screen
	var vp_rect = container.get_viewport_rect()
	container.draw_rect(vp_rect, Color(0, 0, 0, 0.65))

	# Talisman / Parchment canvas
	container.draw_rect(canvas_rect, Color(0.10, 0.11, 0.14, 0.95))
	container.draw_rect(canvas_rect, Color(0.85, 0.72, 0.28, 0.90), false, 3.0)

	# Decorative inner border
	var inner_rect = canvas_rect.grow(-8.0)
	container.draw_rect(inner_rect, Color(0.40, 0.35, 0.20, 0.50), false, 1.5)

	# Reference guides banner at top of canvas
	var title = "VANCIAN TALISMAN SCRIBING - SLOT %d" % (selected_slot_index + 1)
	if font:
		var title_sz = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - title_sz.x) * 0.5, canvas_rect.position.y - 45), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(0.95, 0.85, 0.40))

		# Reference Hanzi guide symbols
		var guide_text = "Available:  火 [Fire]    水 [Water]    风 [Air]    土 [Earth]"
		var guide_sz = font.get_string_size(guide_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - guide_sz.x) * 0.5, canvas_rect.position.y - 20), guide_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.8, 0.85, 0.90))

	# Draw recorded strokes (golden ink calligraphy trail)
	var ink_color = Color(0.98, 0.86, 0.35, 0.95)
	for stroke in all_strokes:
		if stroke.size() > 1:
			var pts: PackedVector2Array = PackedVector2Array()
			for p in stroke:
				pts.append(p)
			container.draw_polyline(pts, ink_color, 6.0, true)
		elif stroke.size() == 1:
			container.draw_circle(stroke[0], 3.5, ink_color)

	# Draw current in-progress stroke
	if current_stroke.size() > 1:
		var curr_pts: PackedVector2Array = PackedVector2Array()
		for p in current_stroke:
			curr_pts.append(p)
		container.draw_polyline(curr_pts, Color(1.0, 0.95, 0.65, 1.0), 6.5, true)
	elif current_stroke.size() == 1:
		container.draw_circle(current_stroke[0], 4.0, Color(1.0, 0.95, 0.65, 1.0))

	# Buttons under canvas: Inscribe, Clear, Back
	var inscribe_rect = Rect2(canvas_rect.position.x, canvas_rect.end.y + 16, 115, 38)
	var clear_rect = Rect2(canvas_rect.position.x + 130, canvas_rect.end.y + 16, 115, 38)
	var back_rect = Rect2(canvas_rect.position.x + 260, canvas_rect.end.y + 16, 120, 38)

	container.draw_rect(inscribe_rect, Color(0.18, 0.55, 0.28, 0.90))
	container.draw_rect(inscribe_rect, Color(0.35, 0.95, 0.50), false, 2.0)

	container.draw_rect(clear_rect, Color(0.45, 0.25, 0.25, 0.90))
	container.draw_rect(clear_rect, Color(0.85, 0.45, 0.45), false, 2.0)

	container.draw_rect(back_rect, Color(0.25, 0.28, 0.35, 0.90))
	container.draw_rect(back_rect, Color(0.65, 0.70, 0.85), false, 2.0)

	if font:
		container.draw_string(font, inscribe_rect.position + Vector2(16, 24), "✍️ Inscribe", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		container.draw_string(font, clear_rect.position + Vector2(24, 24), "🗑️ Clear", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		container.draw_string(font, back_rect.position + Vector2(20, 24), "↩️ Wheel", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

		# Feedback / Recognition result below buttons
		if not feedback_text.is_empty():
			var fb_sz = font.get_string_size(feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - fb_sz.x) * 0.5, canvas_rect.end.y + 75), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, feedback_color)
