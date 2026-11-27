extends Window

# A small no-focus window that gives the human direct access to Jeremy's
# tricks, plus a live readout useful for spotting frozen/stuck states.

const MENU_SIZE := Vector2i(300, 430)

var pet: Node
var status_label: Label
var refresh_timer := 0.0


func _init(pet_node: Node) -> void:
	pet = pet_node
	title = "jeremy menu"
	size = MENU_SIZE
	borderless = true
	always_on_top = true

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = "jeremy // menu"
	heading.add_theme_font_size_override("font_size", 18)
	layout.add_child(heading)

	layout.add_child(HSeparator.new())

	_add_button(layout, "steal cursor", _on_steal_cursor_pressed)
	_add_button(layout, "chase cursor", _on_chase_cursor_pressed)
	_add_button(layout, "write note", _on_write_note_pressed)
	_add_button(layout, "say something", _on_say_pressed)
	_add_button(layout, "eat tab", _on_eat_tab_pressed)

	layout.add_child(HSeparator.new())

	var status_heading := Label.new()
	status_heading.text = "status"
	status_heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(status_heading)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(status_label)

	layout.add_child(HSeparator.new())
	_add_button(layout, "close", _on_close_pressed)


func _ready() -> void:
	set_flag(Window.FLAG_NO_FOCUS, true)
	set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	set_flag(Window.FLAG_BORDERLESS, true)
	refresh_status()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_status()
		refresh_timer = 0.25


func place_near(point: Vector2) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := Vector2(DisplayServer.screen_get_position(screen))
	var screen_size := Vector2(DisplayServer.screen_get_size(screen))

	var x := clampf(
		point.x + 16.0,
		screen_position.x + 8.0,
		screen_position.x + screen_size.x - float(size.x) - 8.0
	)
	var y := clampf(
		point.y + 16.0,
		screen_position.y + 8.0,
		screen_position.y + screen_size.y - float(size.y) - 8.0
	)

	position = Vector2i(roundi(x), roundi(y))


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func refresh_status() -> void:
	if status_label == null:
		return

	if not is_instance_valid(pet):
		status_label.text = "jeremy is gone."
		return

	var lines := [
		"state: " + _current_state(),
		"grounded: " + str(pet.get("grounded")),
		"airborne: " + str(pet.get("airborne")),
		"walking: " + str(pet.get("walking")),
		"dragging: " + str(pet.get("dragging")),
		"cursor chase: " + str(pet.get("cursor_chasing")),
		"cursor steal: " + str(pet.get("cursor_stealing")),
		"tabs today: " + str(pet.get("tabs_eaten")),
	]

	var velocity: Vector2 = pet.get("velocity")
	var desktop_position: Vector2 = pet.get("desktop_position")
	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	lines.append("velocity: %.0f, %.0f" % [velocity.x, velocity.y])
	lines.append("position: %.0f, %.0f" % [desktop_position.x, desktop_position.y])
	lines.append("mouse: %.0f, %.0f" % [mouse_position.x, mouse_position.y])
	lines.append("jump timer: %.1f" % float(pet.get("jump_timer")))
	lines.append("walk timer: %.1f" % float(pet.get("walk_timer")))
	lines.append("chatter timer: %.1f" % float(pet.get("chatter_timer")))
	lines.append("chase cooldown: %.1f" % float(pet.get("cursor_chase_cooldown")))

	var manager: Node = pet.get("notepad_manager")
	lines.append("notepads: " + ("on" if manager != null else "off"))

	status_label.text = "\n".join(lines)


func _current_state() -> String:
	if bool(pet.get("cursor_stealing")):
		return "cursor steal"
	if bool(pet.get("cursor_chasing")):
		return "cursor chase"
	if bool(pet.get("dragging")):
		return "dragged"
	if bool(pet.get("eating")):
		return "eating tab"
	if bool(pet.get("edge_hanging")):
		return "wall hang"
	if bool(pet.get("edge_peeking")):
		return "ceiling peek"
	if bool(pet.get("celebrating")):
		return "celebrating"
	if bool(pet.get("speaking")):
		return "talking"
	if bool(pet.get("walking")):
		return "walking"
	if bool(pet.get("airborne")):
		return "airborne"
	return "idle"


func _on_steal_cursor_pressed() -> void:
	if is_instance_valid(pet):
		pet.call("steal_cursor")


func _on_chase_cursor_pressed() -> void:
	if is_instance_valid(pet):
		pet.call("start_cursor_chase")


func _on_write_note_pressed() -> void:
	if not is_instance_valid(pet):
		return

	var manager: Node = pet.get("notepad_manager")
	if manager != null:
		manager.call("write_note")


func _on_say_pressed() -> void:
	if is_instance_valid(pet):
		pet.call("speak", "say_random_idle")


func _on_eat_tab_pressed() -> void:
	if is_instance_valid(pet):
		pet.call("steal_tab")


func _on_close_pressed() -> void:
	queue_free()
