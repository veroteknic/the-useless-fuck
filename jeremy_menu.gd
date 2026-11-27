extends Window

const PixelUIScript = preload("res://pixel_ui.gd")

# A small no-focus window that gives the human direct access to Jeremy's
# tricks, plus a live readout useful for spotting frozen/stuck states.

const MENU_SIZE := Vector2i(340, 760)

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
	PixelUIScript.apply(heading, 16, true)
	layout.add_child(heading)

	layout.add_child(HSeparator.new())

	_add_button(layout, "steal cursor", _on_steal_cursor_pressed)
	_add_button(layout, "chase cursor", _on_chase_cursor_pressed)
	_add_button(layout, "write note", _on_write_note_pressed)
	_add_button(layout, "say something", _on_say_pressed)
	_add_button(layout, "eat tab", _on_eat_tab_pressed)
	_add_button(layout, "show pop-in", _on_show_popin_pressed)

	layout.add_child(HSeparator.new())

	var controls_heading := Label.new()
	controls_heading.text = "controls"
	PixelUIScript.apply(controls_heading, 12, true)
	layout.add_child(controls_heading)

	var config := {}
	if pet != null and pet.has_method("get_behavior_config"):
		config = pet.call("get_behavior_config")

	_add_check(layout, "paused", "paused", bool(config.get("paused", false)))
	_add_check(layout, "mischief", "mischief_enabled", bool(config.get("mischief_enabled", true)))
	_add_check(layout, "cursor gags", "allow_cursor_steal", bool(config.get("allow_cursor_steal", true)))
	_add_check(layout, "cursor chase", "allow_cursor_chase", bool(config.get("allow_cursor_chase", true)))
	_add_check(layout, "tab eating", "allow_tab_eat", bool(config.get("allow_tab_eat", true)))
	_add_check(layout, "notes", "allow_notes", bool(config.get("allow_notes", true)))
	_add_check(layout, "drag resistance", "allow_drag_resist", bool(config.get("allow_drag_resist", true)))
	_add_check(layout, "note reactions", "allow_note_reactions", bool(config.get("allow_note_reactions", true)))
	_add_check(layout, "pop-ins", "allow_popins", bool(config.get("allow_popins", true)))
	_add_check(layout, "custom content", "allow_custom_content", bool(config.get("allow_custom_content", true)))

	_add_slider(layout, "mischief intensity", "mischief_intensity", float(config.get("mischief_intensity", 1.0)))
	_add_slider(layout, "activity frequency", "activity_frequency", float(config.get("activity_frequency", 1.0)))
	_add_slider(layout, "dialogue frequency", "dialogue_frequency", float(config.get("dialogue_frequency", 1.0)))

	layout.add_child(HSeparator.new())

	var status_heading := Label.new()
	status_heading.text = "status"
	PixelUIScript.apply(status_heading, 12, true)
	layout.add_child(status_heading)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIScript.apply(status_label, 10)
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
	PixelUIScript.apply(button, 11)
	button.pressed.connect(callback)
	parent.add_child(button)


func _add_check(parent: Node, text: String, key: String, value: bool) -> void:
	var check := CheckButton.new()
	check.text = text
	PixelUIScript.apply(check, 10)
	check.button_pressed = value
	check.toggled.connect(_on_config_toggle.bind(key))
	parent.add_child(check)


func _add_slider(parent: Node, text: String, key: String, value: float) -> void:
	var label := Label.new()
	label.text = text
	PixelUIScript.apply(label, 10)
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(_on_config_slider.bind(key))
	parent.add_child(slider)


func _on_config_toggle(value: bool, key: String) -> void:
	if is_instance_valid(pet) and pet.has_method("set_behavior_config"):
		pet.call("set_behavior_config", key, value)


func _on_config_slider(value: float, key: String) -> void:
	if is_instance_valid(pet) and pet.has_method("set_behavior_config"):
		pet.call("set_behavior_config", key, value)


func refresh_status() -> void:
	if status_label == null:
		return

	if not is_instance_valid(pet):
		status_label.text = "jeremy is gone."
		return

	var status := {}
	if pet.has_method("get_behavior_status"):
		status = pet.call("get_behavior_status")

	var lines := [
		"state: " + str(status.get("state", "unknown")),
		"behavior: " + str(status.get("active_behavior", "unknown")),
		"paused: " + str(status.get("paused", false)),
		"mischief: " + str(status.get("mischief", true)),
		"mood: " + str(status.get("mood_label", "meh")) + " (" + ("%.2f" % float(status.get("mood", 0.0))) + ")",
		"grounded: " + str(status.get("grounded", false)),
		"airborne: " + str(status.get("airborne", false)),
		"walking: " + str(status.get("walking", false)),
		"dragging: " + str(status.get("dragging", false)),
		"cursor chase: " + str(status.get("cursor_chasing", false)),
		"cursor steal: " + str(status.get("cursor_stealing", false)),
		"tabs today: " + str(status.get("tabs_eaten", 0)),
	]

	var velocity: Vector2 = status.get("velocity", Vector2.ZERO)
	var desktop_position: Vector2 = status.get("position", Vector2.ZERO)
	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	lines.append("velocity: %.0f, %.0f" % [velocity.x, velocity.y])
	lines.append("position: %.0f, %.0f" % [desktop_position.x, desktop_position.y])
	lines.append("mouse: %.0f, %.0f" % [mouse_position.x, mouse_position.y])
	lines.append("jump timer: %.1f" % float(status.get("jump_timer", 0.0)))
	lines.append("walk timer: %.1f" % float(status.get("walk_timer", 0.0)))
	lines.append("chatter timer: %.1f" % float(status.get("chatter_timer", 0.0)))
	lines.append("chase cooldown: %.1f" % float(status.get("chase_cooldown", 0.0)))

	var notes_on := bool(status.get("notepads", false))
	lines.append("notepads: " + ("on" if notes_on else "off"))

	var recent: Array = status.get("recent", [])
	if not recent.is_empty():
		lines.append("last: " + str(recent[recent.size() - 1]))

	status_label.text = "\n".join(lines)


func _pet_request(action: String, args: Array = []) -> void:
	if not is_instance_valid(pet):
		return

	if pet.has_method("request_behavior"):
		pet.call("request_behavior", action, args)
	elif pet.has_method(action):
		pet.callv(action, args)


func _on_steal_cursor_pressed() -> void:
	_pet_request("steal_cursor")


func _on_chase_cursor_pressed() -> void:
	_pet_request("start_cursor_chase")


func _on_write_note_pressed() -> void:
	_pet_request("write_note")


func _on_say_pressed() -> void:
	_pet_request("speak", ["say_random_idle"])


func _on_eat_tab_pressed() -> void:
	_pet_request("steal_tab")


func _on_show_popin_pressed() -> void:
	_pet_request("show_popin")


func _on_close_pressed() -> void:
	queue_free()
