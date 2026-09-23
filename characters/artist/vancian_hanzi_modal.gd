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

var deadzone_radius: float = 42.0
var outer_radius: float = 150.0
var option_radius: float = 44.0

var options: Array = []
var container: Control = null
var caster: Node = null

var selected_slot_index: int = 0
var current_stroke: Array[Vector2] = []
var all_strokes: Array = [] # Array of Array[Vector2]
var recognized_result: Dictionary = {}
var selected_top_left_element: String = ""
var feedback_text: String = ""
var feedback_color: Color = Color.WHITE

const CONFIDENCE_THRESHOLD: float = 0.75
const REQUIRED_STROKES: Dictionary = {
	"earth": 3,
	"water": 3,
	"fire": 4,
	"air": 4
}

# The four elements in required order: fire, water, earth, air
const TOP_LEFT_ELEMENTS: Array = [
	{
		"id": "fire",
		"hanzi": "火",
		"english": "Fire",
		"color": Color(0.95, 0.35, 0.15, 1.0)
	},
	{
		"id": "water",
		"hanzi": "水",
		"english": "Water",
		"color": Color(0.25, 0.65, 0.95, 1.0)
	},
	{
		"id": "earth",
		"hanzi": "土",
		"english": "Earth",
		"color": Color(0.85, 0.65, 0.25, 1.0)
	},
	{
		"id": "air",
		"hanzi": "风",
		"english": "Air",
		"color": Color(0.40, 0.85, 0.60, 1.0)
	}
]

const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.95, 0.35, 0.15, 1.0),
	"water": Color(0.25, 0.65, 0.95, 1.0),
	"air": Color(0.40, 0.85, 0.60, 1.0),
	"earth": Color(0.85, 0.65, 0.25, 1.0)
}

func _ensure_container() -> void:
	if container == null:
		layer = 100
		container = Control.new()
		container.name = "ModalContainer"
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(container)
		container.draw.connect(_on_container_draw)
		container.hide()

func _ready() -> void:
	_ensure_container()

func open(at_position: Vector2 = Vector2.ZERO, runtime_options: Array = []) -> void:
	_ensure_container()

	if caster and caster.has_method("get_vancian_modal_options"):
		options = caster.call("get_vancian_modal_options", "R")
	elif not runtime_options.is_empty():
		options = runtime_options.duplicate(true)
	elif options.is_empty():
		_setup_default_options()

	var vp_size = Vector2(1280, 720)
	if is_inside_tree() and get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	elif container:
		vp_size = container.get_viewport_rect().size

	if at_position == Vector2.ZERO or not Rect2(Vector2.ZERO, vp_size).has_point(at_position):
		at_position = vp_size * 0.5
	else:
		var margin = outer_radius + 20.0
		at_position.x = clampf(at_position.x, margin, maxf(margin, vp_size.x - margin))
		at_position.y = clampf(at_position.y, margin, maxf(margin, vp_size.y - margin))
	wheel_center = at_position

	current_state = State.WHEEL
	is_modal_open = true
	current_hovered_option = "cancel"
	all_strokes.clear()
	current_stroke.clear()
	recognized_result = {}
	selected_top_left_element = ""
	feedback_text = ""

	if container:
		container.show()
		container.queue_redraw()

func _setup_default_options() -> void:
	options = [
		{"id": "empty_0", "slot_index": 0, "label": "Slot 1\n[Blank]", "element": "", "is_empty": true},
		{"id": "empty_1", "slot_index": 1, "label": "Slot 2\n[Blank]", "element": "", "is_empty": true},
		{"id": "empty_2", "slot_index": 2, "label": "Slot 3\n[Blank]", "element": "", "is_empty": true},
		{"id": "empty_3", "slot_index": 3, "label": "Slot 4\n[Blank]", "element": "", "is_empty": true}
	]

func close_and_select() -> String:
	if not is_modal_open:
		return "cancel"

	if current_state == State.DRAWING:
		cancel_modal()
		return "cancel"

	# If hovering over an empty slot, don't cast; transition to drawing
	for opt in options:
		if str(opt.get("id", "")) == current_hovered_option:
			if opt.get("is_empty", false):
				selected_slot_index = int(opt.get("slot_index", 0))
				transition_to_drawing()
				return "drawing"
			break

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
	# Cardinal diamond layout: index 0: Top, index 1: Right, index 2: Bottom, index 3: Left
	var angle = -PI * 0.5 + (float(index) / float(total)) * TAU
	var offset_dist = (deadzone_radius + outer_radius) * 0.54
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
	elif dist > (outer_radius + 50.0):
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

		if min_opt_dist <= (option_radius + 28.0):
			current_hovered_option = best_opt
		else:
			current_hovered_option = "cancel"

	if prev_hover != current_hovered_option:
		container.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_modal_open or not container:
		return

	if event.is_action_pressed("ui_cancel"):
		cancel_modal()
		get_viewport().set_input_as_handled()
		return

	if current_state == State.WHEEL:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_modal()
			get_viewport().set_input_as_handled()
	elif current_state == State.DRAWING:
		_handle_drawing_input(event)

func transition_to_drawing() -> void:
	current_state = State.DRAWING
	all_strokes.clear()
	current_stroke.clear()
	recognized_result = {}
	selected_top_left_element = ""
	feedback_text = "Draw Hanzi on canvas (Auto-completes at 75% confidence on last stroke)"
	feedback_color = Color(0.85, 0.88, 0.95, 1.0)
	if container:
		container.queue_redraw()

func transition_to_wheel() -> void:
	current_state = State.WHEEL
	all_strokes.clear()
	current_stroke.clear()
	recognized_result = {}
	selected_top_left_element = ""
	feedback_text = ""
	if caster and caster.has_method("get_vancian_modal_options"):
		options = caster.call("get_vancian_modal_options", "R")
	if container:
		container.queue_redraw()

func _get_drawing_canvas_rect() -> Rect2:
	var vp_size = container.get_viewport_rect().size if container else Vector2(1280, 720)
	var canvas_size = Vector2(380, 380) # Blank white square
	var canvas_pos = (vp_size - canvas_size) * 0.5
	return Rect2(canvas_pos, canvas_size)

func _get_top_left_card_rect(index: int) -> Rect2:
	var card_w = 72.0
	var card_h = 82.0
	var start_x = 32.0
	var start_y = 36.0
	var spacing = 12.0
	return Rect2(start_x + float(index) * (card_w + spacing), start_y, card_w, card_h)

func _handle_drawing_input(event: InputEvent) -> void:
	var canvas_rect = _get_drawing_canvas_rect()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_modal()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Note: Manual card selection is disabled. Elemental cards are for reference and live match display only.
				# Check canvas drawing
				if canvas_rect.has_point(event.position):
					current_stroke = [event.position.clamp(canvas_rect.position, canvas_rect.end)]
					get_viewport().set_input_as_handled()
				else:
					# Check bottom action buttons
					_handle_canvas_button_clicks(event.position)
					get_viewport().set_input_as_handled()
			else:
				# Mouse released: finalize current stroke and evaluate
				if not current_stroke.is_empty():
					if current_stroke.size() == 1:
						current_stroke.append(current_stroke[0] + Vector2(1, 1))
					all_strokes.append(current_stroke.duplicate())
					current_stroke.clear()
					_evaluate_drawing()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not current_stroke.is_empty():
			current_stroke.append(event.position.clamp(canvas_rect.position, canvas_rect.end))
			get_viewport().set_input_as_handled()
		elif canvas_rect.has_point(event.position):
			current_stroke = [event.position.clamp(canvas_rect.position, canvas_rect.end)]
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_C:
			all_strokes.clear()
			current_stroke.clear()
			recognized_result = {}
			selected_top_left_element = ""
			feedback_text = "Canvas cleared."
			feedback_color = Color(0.8, 0.8, 0.8, 1.0)
			container.queue_redraw()

func _handle_canvas_button_clicks(click_pos: Vector2) -> void:
	var canvas_rect = _get_drawing_canvas_rect()

	var clear_rect = Rect2(canvas_rect.position.x + 40, canvas_rect.end.y + 16, 140, 38)
	var back_rect = Rect2(canvas_rect.position.x + 200, canvas_rect.end.y + 16, 140, 38)

	if clear_rect.has_point(click_pos):
		all_strokes.clear()
		current_stroke.clear()
		recognized_result = {}
		selected_top_left_element = ""
		feedback_text = "Canvas cleared."
		feedback_color = Color(0.8, 0.8, 0.8, 1.0)
		container.queue_redraw()
	elif back_rect.has_point(click_pos):
		cancel_modal()

func _evaluate_drawing() -> void:
	if all_strokes.is_empty():
		return

	var canvas_rect = _get_drawing_canvas_rect()
	var result = HanziPointCloudRecognizer.recognize(all_strokes, canvas_rect)
	recognized_result = result
	var elem = str(result.get("element", ""))
	var hanzi = str(result.get("hanzi", ""))
	var score = float(result.get("score", 0.0))
	var stroke_count = all_strokes.size()

	if elem != "" and score >= 0.05:
		selected_top_left_element = elem
		var english_name = elem.capitalize()
		var pct = int(score * 100)
		var target_strokes = int(REQUIRED_STROKES.get(elem, 4))

		# Auto-complete inscription after last stroke is finished if confidence >= 75%
		if stroke_count >= target_strokes and score >= CONFIDENCE_THRESHOLD:
			_auto_complete_inscription(elem, hanzi, score)
			return

		if stroke_count >= target_strokes:
			feedback_text = "Final stroke %d/%d done: %s [%s] (%d%% match) — Below 75%% threshold! Redraw or Clear (C)." % [stroke_count, target_strokes, hanzi, english_name, pct]
			feedback_color = Color(1.0, 0.65, 0.35, 1.0)
		else:
			feedback_text = "Stroke %d/%d: %s [%s] (%d%% match) — Draw next stroke" % [stroke_count, target_strokes, hanzi, english_name, pct]
			feedback_color = ELEMENT_COLORS.get(elem, Color.WHITE)
	else:
		selected_top_left_element = ""
		feedback_text = "Stroke %d: Drawing in progress... Draw 火 (Fire), 水 (Water), 土 (Earth), or 风 (Air)" % stroke_count
		feedback_color = Color(0.95, 0.75, 0.45, 1.0)
	container.queue_redraw()

func _auto_complete_inscription(elem: String, hanzi: String, score: float) -> void:
	var english_name = elem.capitalize()
	var pct = int(score * 100)
	feedback_text = "Auto-completed %s [%s] (%d%% match)! Slot %d prepared." % [hanzi, english_name, pct, selected_slot_index + 1]
	feedback_color = ELEMENT_COLORS.get(elem, Color(0.35, 0.95, 0.50))

	# Store spell into caster slot
	if caster and "vancian_slots" in caster and caster.vancian_slots.size() > selected_slot_index:
		caster.vancian_slots[selected_slot_index] = elem

	spell_inscribed.emit(selected_slot_index, elem)

	# Exit canvas completely and return to normal gameplay state
	is_modal_open = false
	current_state = State.WHEEL
	if container:
		container.hide()
	option_selected.emit("inscribed:%d:%s" % [selected_slot_index, elem])


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
	# Translucent backdrop
	var vp_rect = container.get_viewport_rect()
	container.draw_rect(vp_rect, Color(0, 0, 0, 0.55))

	# Radial outer disc & ring
	container.draw_circle(wheel_center, outer_radius, Color(0.07, 0.09, 0.12, 0.92))
	container.draw_arc(wheel_center, outer_radius, 0, TAU, 64, Color(0.90, 0.78, 0.32, 0.80), 3.0)

	# Connecting line from center to mouse
	var mouse_pos = container.get_global_mouse_position()
	var to_mouse = (mouse_pos - wheel_center)
	if to_mouse.length() > 5.0:
		var line_end = wheel_center + to_mouse.limit_length(outer_radius)
		container.draw_line(wheel_center, line_end, Color(1, 1, 1, 0.40), 2.0)

	# Center cancel circle
	var cancel_active = (current_hovered_option == "cancel")
	var cancel_col = Color(0.85, 0.22, 0.22, 0.95) if cancel_active else Color(0.24, 0.26, 0.32, 0.80)
	container.draw_circle(wheel_center, deadzone_radius, cancel_col)
	container.draw_arc(wheel_center, deadzone_radius, 0, TAU, 32, Color(1, 1, 1, 0.9) if cancel_active else Color(0.5, 0.5, 0.5, 0.4), 2.5 if cancel_active else 1.5)

	if font:
		container.draw_string(font, wheel_center + Vector2(-8, 8), "✕", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
		var cancel_txt = "CANCEL" if cancel_active else "CLOSE"
		var c_sz = font.get_string_size(cancel_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		container.draw_string(font, wheel_center + Vector2(-c_sz.x * 0.5, 26), cancel_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.9, 0.9, 0.8))

	# Draw 4 slots
	var num_opts = options.size()
	for i in range(num_opts):
		var opt = options[i]
		var opt_id = str(opt.get("id", ""))
		var is_empty = opt.get("is_empty", false)
		var is_active = (current_hovered_option == opt_id)
		var opt_center = get_option_center(i, num_opts)

		var bg_col = Color(0.18, 0.20, 0.26, 0.88)
		var border_col = Color(0.55, 0.60, 0.70, 0.60)

		if not is_empty:
			# Filled slot with stored spell
			var elem_col = opt.get("color", Color(0.85, 0.65, 0.25, 0.95))
			if is_active:
				bg_col = elem_col
				border_col = Color(1.0, 1.0, 1.0, 1.0)
			else:
				bg_col = Color(elem_col.r * 0.40, elem_col.g * 0.40, elem_col.b * 0.40, 0.85)
				border_col = Color(elem_col.r * 1.1, elem_col.g * 1.1, elem_col.b * 1.1, 0.9)
		else:
			# Blank slot
			if is_active:
				bg_col = Color(0.30, 0.35, 0.45, 0.95)
				border_col = Color(0.95, 0.85, 0.35, 1.0)

		container.draw_circle(opt_center, option_radius, bg_col)
		container.draw_arc(opt_center, option_radius, 0, TAU, 32, border_col, 3.5 if is_active else 1.8)

		if font:
			if is_empty:
				# Blank slot representation
				var line1 = "Slot %d" % (i + 1)
				var line2 = "+ DRAW" if is_active else "[Blank]"
				var s1 = font.get_string_size(line1, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
				var s2 = font.get_string_size(line2, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
				var text_col = Color(1.0, 0.95, 0.5) if is_active else Color(0.75, 0.80, 0.85, 0.85)
				container.draw_string(font, opt_center + Vector2(-s1.x * 0.5, -4), line1, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, text_col)
				container.draw_string(font, opt_center + Vector2(-s2.x * 0.5, 14), line2, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 1, 1) if is_active else Color(0.6, 0.65, 0.75, 0.7))
			else:
				# Filled slot representation
				var hanzi_txt = str(opt.get("hanzi", "✦"))
				var name_txt = str(opt.get("name", "Spell"))
				var action_txt = "⚡ CAST" if is_active else name_txt
				var s_hanzi = font.get_string_size(hanzi_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
				var s_act = font.get_string_size(action_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
				container.draw_string(font, opt_center + Vector2(-s_hanzi.x * 0.5, -3), hanzi_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
				container.draw_string(font, opt_center + Vector2(-s_act.x * 0.5, 15), action_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 1) if is_active else Color(0.9, 0.9, 0.9, 0.85))

	# Titles & Guidance around wheel
	if font:
		var title = "INK ALCHEMY — RADIAL WHEEL"
		var t_sz = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		container.draw_string(font, Vector2(wheel_center.x - t_sz.x * 0.5, wheel_center.y - outer_radius - 28), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.95, 0.85, 0.40))

		var hint = "Release R to Select • Center or RMB to Cancel"
		var h_sz = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		container.draw_string(font, Vector2(wheel_center.x - h_sz.x * 0.5, wheel_center.y + outer_radius + 38), hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.85, 0.90, 0.95))

func _draw_drawing_state(font: Font) -> void:
	var vp_size = container.get_viewport_rect().size if container else Vector2(1280, 720)
	var canvas_rect = _get_drawing_canvas_rect()

	# Dark translucent backdrop covering screen
	container.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.04, 0.05, 0.08, 0.78))

	# ==========================================
	# TOP LEFT: Four Elements (fire, water, earth, air)
	# with English translation of Hanzi under them
	# ==========================================
	var mouse_pos = container.get_global_mouse_position()

	if font:
		container.draw_string(font, Vector2(32, 24), "ELEMENTAL TALISMANS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.80, 0.90))

	for i in range(TOP_LEFT_ELEMENTS.size()):
		var elem_info = TOP_LEFT_ELEMENTS[i]
		var card_rect = _get_top_left_card_rect(i)
		var is_card_recognized = (selected_top_left_element == elem_info["id"])

		# Card Background
		var card_bg = Color(0.20, 0.24, 0.32, 0.95) if is_card_recognized else Color(0.12, 0.14, 0.18, 0.92)
		container.draw_rect(card_rect, card_bg)

		# Card Border in element color (glows when recognized)
		var elem_col = elem_info["color"]
		var border_w = 3.5 if is_card_recognized else 1.5
		var border_c = elem_col if is_card_recognized else Color(elem_col.r * 0.7, elem_col.g * 0.7, elem_col.b * 0.7, 0.6)
		container.draw_rect(card_rect, border_c, false, border_w)

		if font:
			# Hanzi Character at top
			var hanzi_str = elem_info["hanzi"]
			var h_sz = font.get_string_size(hanzi_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
			var h_pos = Vector2(card_rect.position.x + (card_rect.size.x - h_sz.x) * 0.5, card_rect.position.y + 32)
			container.draw_string(font, h_pos, hanzi_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, elem_col)

			# English Translation directly under the Hanzi
			var eng_str = elem_info["english"]
			var e_sz = font.get_string_size(eng_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
			var e_pos = Vector2(card_rect.position.x + (card_rect.size.x - e_sz.x) * 0.5, card_rect.position.y + 50)
			container.draw_string(font, e_pos, eng_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.92, 0.94, 0.98, 1.0))

			# Live Match Percentage under the English translation
			var cand_list = recognized_result.get("candidates", [])
			var cand_score = 0.0
			for cand in cand_list:
				if cand.get("element") == elem_info["id"]:
					cand_score = float(cand.get("score", 0.0))
					break
			if cand_score >= 0.05:
				var score_str = "%d%%" % int(cand_score * 100)
				var s_sz = font.get_string_size(score_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
				var s_pos = Vector2(card_rect.position.x + (card_rect.size.x - s_sz.x) * 0.5, card_rect.position.y + 68)
				var s_col = elem_col if is_card_recognized else Color(0.70, 0.75, 0.85, 0.75)
				container.draw_string(font, s_pos, score_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, s_col)

	# ==========================================
	# CENTER: Blank Canvas (A White Square)
	# ==========================================
	# Pure white square canvas
	container.draw_rect(canvas_rect, Color(1.0, 1.0, 1.0, 1.0))
	# Subtle outer border
	container.draw_rect(canvas_rect, Color(0.22, 0.25, 0.32, 0.90), false, 2.5)

	# Canvas Header
	if font:
		var draw_title = "DRAW SPELL TALISMAN — SLOT %d" % (selected_slot_index + 1)
		var dt_sz = font.get_string_size(draw_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - dt_sz.x) * 0.5, canvas_rect.position.y - 38), draw_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.95, 0.85, 0.40))

		var draw_hint = "Auto-completes at 75% confidence when final stroke is drawn"
		var dh_sz = font.get_string_size(draw_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - dh_sz.x) * 0.5, canvas_rect.position.y - 16), draw_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.78, 0.82, 0.90))

	# Draw recorded strokes on the white canvas with dark calligraphy ink
	var ink_color = Color(0.08, 0.08, 0.10, 0.95)
	for stroke in all_strokes:
		if stroke.size() > 1:
			var pts: PackedVector2Array = PackedVector2Array()
			for p in stroke:
				pts.append(p)
			container.draw_polyline(pts, ink_color, 6.0, true)
		elif stroke.size() == 1:
			container.draw_circle(stroke[0], 3.5, ink_color)

	# Draw in-progress stroke
	if current_stroke.size() > 1:
		var curr_pts: PackedVector2Array = PackedVector2Array()
		for p in current_stroke:
			curr_pts.append(p)
		container.draw_polyline(curr_pts, Color(0.12, 0.12, 0.16, 0.90), 6.0, true)
	elif current_stroke.size() == 1:
		container.draw_circle(current_stroke[0], 4.0, Color(0.12, 0.12, 0.16, 0.90))

	# Action Buttons below canvas: Clear, Wheel (Inscribe button removed; auto-completes on final stroke >= 75%)
	var clear_rect = Rect2(canvas_rect.position.x + 40, canvas_rect.end.y + 16, 140, 38)
	var back_rect = Rect2(canvas_rect.position.x + 200, canvas_rect.end.y + 16, 140, 38)

	container.draw_rect(clear_rect, Color(0.48, 0.22, 0.22, 0.92))
	container.draw_rect(clear_rect, Color(0.85, 0.45, 0.45), false, 2.0)

	container.draw_rect(back_rect, Color(0.24, 0.28, 0.36, 0.92))
	container.draw_rect(back_rect, Color(0.65, 0.72, 0.88), false, 2.0)

	if font:
		var clr_txt = "🗑️ Clear (C)"
		var clr_sz = font.get_string_size(clr_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		container.draw_string(font, Vector2(clear_rect.position.x + (clear_rect.size.x - clr_sz.x) * 0.5, clear_rect.position.y + 24), clr_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

		var back_txt = "↩️ Exit (RMB)"
		var back_sz = font.get_string_size(back_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		container.draw_string(font, Vector2(back_rect.position.x + (back_rect.size.x - back_sz.x) * 0.5, back_rect.position.y + 24), back_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

		# Recognition / guidance message below buttons
		if not feedback_text.is_empty():
			var fb_sz = font.get_string_size(feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			container.draw_string(font, Vector2(canvas_rect.position.x + (canvas_rect.size.x - fb_sz.x) * 0.5, canvas_rect.end.y + 76), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, feedback_color)
