extends Node

# Jeremy writes himself little sticky notes. Each note is its own native
# always-on-top, no-focus window so it can live anywhere on the desktop without
# stealing keyboard focus from the browser.

@export var notes_enabled := true
@export var max_notes := 3
@export var note_lifetime := 20.0
@export var note_interval_min := 28.0
@export var note_interval_max := 60.0

var notes: Array[Dictionary] = []
var next_note_timer := 0.0

var note_lines := [
	"note to self: the floor is friendly.",
	"note to self: tabs are snacks.",
	"note to self: do not trust gravity.",
	"note to self: gravity is still winning.",
	"note to self: the cursor looks lonely.",
	"note to self: ask about toast.",
	"note to self: i am very small.",
	"note to self: i am still very small.",
	"note to self: the desktop is mine.",
	"note to self: be nice to the human.",
	"note to self: the human is weird.",
	"note to self: weird is fine.",
	"note to self: blink occasionally.",
	"note to self: naps are important.",
	"note to self: walking is just falling twice.",
	"note to self: bouncing counts as exercise.",
	"note to self: the top edge is cold.",
	"note to self: the side edges are sticky.",
	"note to self: leave one tab for later.",
	"note to self: maybe don't eat that one.",
	"note to self: too late.",
	"note to self: i have no hands.",
	"note to self: i wrote this anyway.",
	"note to self: remember the hat.",
	"note to self: find the hat.",
	"note to self: there is no hat.",
	"note to self: keep going.",
	"note to self: stay tiny.",
	"note to self: stay weird.",
	"note to self: nobody reads these.",
]

var late_note_lines := [
	"note to self: the human should be asleep.",
	"note to self: i am still awake.",
	"note to self: night duty is important.",
	"note to self: watch the desktop.",
	"note to self: don't wake the human.",
	"note to self: the moon is outside.",
	"note to self: i cannot see the moon.",
	"note to self: that's fine.",
	"note to self: quiet is nice.",
	"note to self: quiet is too quiet.",
	"note to self: tomorrow is a problem for tomorrow.",
	"note to self: i'll keep watch.",
]


func _ready() -> void:
	reset_note_timer()


func _process(delta: float) -> void:
	if not notes_enabled:
		return

	next_note_timer -= delta
	if next_note_timer <= 0.0:
		write_note()
		reset_note_timer()

	for i in range(notes.size() - 1, -1, -1):
		var entry: Dictionary = notes[i]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			_close_note(entry)


func reset_note_timer() -> void:
	next_note_timer = randf_range(note_interval_min, note_interval_max)


func write_note(message: String = "") -> void:
	if not notes_enabled:
		return

	if notes.size() >= max_notes and not notes.is_empty():
		_close_note(notes[0])

	var text := message if not message.is_empty() else _pick_note_text()
	var note_window := Window.new()
	note_window.title = "jeremy's note"
	note_window.size = Vector2i(220, 116)
	note_window.always_on_top = true
	note_window.borderless = true
	note_window.transparent = true
	note_window.exclusive = false
	note_window.transient = false

	get_tree().root.add_child(note_window)
	note_window.set_flag(Window.FLAG_NO_FOCUS, true)
	note_window.set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	note_window.set_flag(Window.FLAG_BORDERLESS, true)
	note_window.set_flag(Window.FLAG_TRANSPARENT, true)
	note_window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2dc78")
	style.border_color = Color("#c4a93f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	note_window.add_child(panel)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(layout)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#2d2819"))
	layout.add_child(label)

	var signature := Label.new()
	signature.text = "- jeremy"
	signature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	signature.add_theme_font_size_override("font_size", 12)
	signature.add_theme_color_override("font_color", Color("#6b5a26"))
	layout.add_child(signature)

	var hint := Vector2(DisplayServer.mouse_get_position())
	var target := _random_note_position(note_window.size, hint)
	note_window.position = Vector2i(roundi(hint.x), roundi(hint.y))

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(note_window, "position", target, 0.42)

	notes.append({
		"window": note_window,
		"control": panel,
		"remaining": note_lifetime,
		"closing": false
	})


func _pick_note_text() -> String:
	var date := Time.get_datetime_dict_from_system()
	var hour := int(date.get("hour", 12))

	if hour >= 22 or hour < 5:
		return str(late_note_lines.pick_random())

	return str(note_lines.pick_random())


func _random_note_position(window_size: Vector2i, hint: Vector2) -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := Vector2(DisplayServer.screen_get_position(screen))
	var screen_size := Vector2(DisplayServer.screen_get_size(screen))
	var margin := 24.0

	var max_x := maxf(screen_position.x + margin, screen_position.x + screen_size.x - float(window_size.x) - margin)
	var max_y := maxf(screen_position.y + margin, screen_position.y + screen_size.y - float(window_size.y) - margin)

	var x := clampf(hint.x + randf_range(-280.0, 280.0), screen_position.x + margin, max_x)
	var y := clampf(hint.y + randf_range(-200.0, 200.0), screen_position.y + margin, max_y)
	return Vector2i(roundi(x), roundi(y))


func _close_note(entry: Dictionary) -> void:
	if bool(entry.get("closing", false)):
		return

	entry["closing"] = true
	notes.erase(entry)

	var note_window: Window = entry.get("window")
	var panel: Control = entry.get("control")

	if note_window == null:
		return

	if panel == null:
		note_window.queue_free()
		return

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(note_window.queue_free)
