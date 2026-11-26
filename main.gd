extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var body: RigidBody2D = $RigidBody2D
@onready var sprite: AnimatedSprite2D = $RigidBody2D/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $RigidBody2D/CollisionShape2D
@onready var dialogue: CanvasLayer = $DialogueManager

const WINDOW_SIZE := Vector2i(400, 360)
const PET_RADIUS := 60.0
const PET_LOCAL_POSITION := Vector2(200, 240)
const DRAG_MOVE_THRESHOLD := 6.0
const EAT_ANIMATION := "eating"

@export var gravity := 1600.0
@export var bounce := 0.55
@export var throw_multiplier := 2.5
@export var max_throw_speed := 2200.0
@export var landing_threshold := 450.0
@export var settling_threshold := 60.0
@export var chatter_interval_min := 7.0
@export var chatter_interval_max := 16.0

var desktop_position := Vector2.ZERO
var velocity := Vector2.ZERO

var desktop_min := Vector2.ZERO
var desktop_max := Vector2.ZERO

var dragging := false
var drag_offset := Vector2.ZERO
var drag_start_mouse := Vector2.ZERO
var last_mouse_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var drag_moved := false

var velocity_before_drag := Vector2.ZERO
var grounded_before_drag := false
var airborne_before_drag := false

var grounded := false
var airborne := true
var celebrating := false
var chattering := false
var speaking := false
var eating := false
var chatter_timer := 0.0

var tab_layer: CanvasLayer
var tab_visual: PanelContainer

# Kept as files in user:// because inline PowerShell here-strings lose their
# quotes when passed through OS.execute's argument list on Windows.
var foreground_ps := "\n".join([
	"Add-Type @\"",
	"using System;",
	"using System.Runtime.InteropServices;",
	"using System.Text;",
	"public static class JeremyFg {",
	"  [DllImport(\"user32.dll\")] public static extern IntPtr GetForegroundWindow();",
	"  [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);",
	"  [DllImport(\"user32.dll\")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);",
	"  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }",
	"}",
	"\"@",
	"$h = [JeremyFg]::GetForegroundWindow()",
	"$r = New-Object JeremyFg+RECT",
	"[JeremyFg]::GetWindowRect($h, [ref]$r) | Out-Null",
	"$c = New-Object System.Text.StringBuilder 256",
	"[JeremyFg]::GetClassName($h, $c, 256) | Out-Null",
	"Write-Output (\"{0}|{1}|{2}|{3}\" -f $c.ToString(), $r.Left, $r.Top, $r.Right)"
])

var close_tab_ps := "\n".join([
	"Add-Type -AssemblyName System.Windows.Forms",
	"[System.Windows.Forms.SendKeys]::SendWait(\"^w\")"
])


func _ready() -> void:
	_setup_window()
	_setup_physics()

	await get_tree().process_frame

	update_desktop_bounds()

	var screen_position := Vector2(DisplayServer.screen_get_position(
		DisplayServer.window_get_current_screen()
	))
	var screen_size := Vector2(DisplayServer.screen_get_size(
		DisplayServer.window_get_current_screen()
	))

	desktop_position = screen_position + screen_size * 0.5
	desktop_position.x = clampf(desktop_position.x, desktop_min.x, desktop_max.x)
	desktop_position.y = clampf(desktop_position.y, desktop_min.y, desktop_max.y)

	body.position = PET_LOCAL_POSITION

	body.input_event.connect(_on_body_input_event)
	sprite.animation_finished.connect(_on_animation_finished)

	reset_chatter_timer()
	play_animation("default")

	update_window_position()
	update_mouse_passthrough()


func _process(delta: float) -> void:
	if dragging:
		handle_dragging(delta)
	else:
		handle_physics(delta)

	update_animation(delta)
	update_window_position()


func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			stop_dragging()
			get_viewport().set_input_as_handled()



func _setup_window() -> void:
	# The scene's Camera2D has a large zoom; Jeremy must be drawn in plain
	# viewport coordinates for the desktop-pet window.
	camera.enabled = false
	DisplayServer.window_set_size(WINDOW_SIZE)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	# Never take the keyboard away from the browser: the pet stays clickable
	# but the foreground window is still the browser whose tab gets eaten.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _setup_physics() -> void:
	body.freeze = true
	body.gravity_scale = 0.0
	body.input_pickable = true

	var circle := CircleShape2D.new()
	circle.radius = PET_RADIUS
	collision_shape.shape = circle

	sprite.scale = Vector2(4.0, 4.0)


func update_desktop_bounds() -> void:
	var screen_count := DisplayServer.get_screen_count()

	if screen_count <= 0:
		desktop_min = Vector2.ZERO
		desktop_max = Vector2(1920, 1080)
		return

	var first_position := Vector2(DisplayServer.screen_get_position(0))
	var first_size := Vector2(DisplayServer.screen_get_size(0))

	var min_position := first_position
	var max_position := first_position + first_size

	for i in range(1, screen_count):
		var screen_position := Vector2(DisplayServer.screen_get_position(i))
		var screen_size := Vector2(DisplayServer.screen_get_size(i))

		min_position.x = minf(min_position.x, screen_position.x)
		min_position.y = minf(min_position.y, screen_position.y)

		max_position.x = maxf(max_position.x, screen_position.x + screen_size.x)
		max_position.y = maxf(max_position.y, screen_position.y + screen_size.y)

	desktop_min = min_position + Vector2(PET_RADIUS, PET_RADIUS)
	desktop_max = max_position - Vector2(PET_RADIUS, PET_RADIUS)


func handle_physics(delta: float) -> void:
	if grounded:
		desktop_position.y = desktop_max.y
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)

		if absf(velocity.x) < 1.0:
			velocity.x = 0.0

		airborne = false
		return

	airborne = true

	velocity.y += gravity * delta
	desktop_position += velocity * delta

	# Left wall.
	if desktop_position.x < desktop_min.x:
		desktop_position.x = desktop_min.x
		velocity.x = absf(velocity.x) * bounce

	# Right wall.
	if desktop_position.x > desktop_max.x:
		desktop_position.x = desktop_max.x
		velocity.x = -absf(velocity.x) * bounce

	# Ceiling.
	if desktop_position.y < desktop_min.y:
		desktop_position.y = desktop_min.y
		velocity.y = absf(velocity.y) * bounce

	# Floor.
	if desktop_position.y >= desktop_max.y:
		var impact_speed := maxf(velocity.y, 0.0)

		desktop_position.y = desktop_max.y

		if impact_speed >= landing_threshold:
			# Remember the hard impact, but keep bouncing. The celebration
			# fires only when this fall finally settles on the floor.
			start_celebration()

		if impact_speed <= settling_threshold:
			velocity.y = 0.0
			grounded = true
			airborne = false

			if celebrating and sprite.animation != "thumbs up!":
				speak("say_random_landing")
				play_animation("thumbs up!")
		else:
			velocity.y = -impact_speed * bounce
			grounded = false
			airborne = true


func _on_body_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			start_dragging()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			steal_tab()


func start_dragging() -> void:
	if dragging:
		return

	dragging = true
	drag_moved = false

	velocity_before_drag = velocity
	grounded_before_drag = grounded
	airborne_before_drag = airborne

	drag_velocity = Vector2.ZERO

	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	drag_offset = desktop_position - mouse_position
	drag_start_mouse = mouse_position
	last_mouse_position = mouse_position


func handle_dragging(delta: float) -> void:
	var mouse_position := Vector2(DisplayServer.mouse_get_position())

	if not drag_moved:
		if mouse_position.distance_to(drag_start_mouse) <= DRAG_MOVE_THRESHOLD:
			# Still a plain press, not a drag. Let physics keep running.
			handle_physics(delta)
			last_mouse_position = mouse_position
			return

		# First real movement: from here on he is actively being dragged.
		drag_moved = true
		grounded = false
		airborne = false
		celebrating = false
		chattering = false
		speaking = false
		velocity = Vector2.ZERO
		speak("say_random_grab")

	desktop_position = mouse_position + drag_offset

	if delta > 0.0:
		drag_velocity = (mouse_position - last_mouse_position) / delta

	last_mouse_position = mouse_position


func stop_dragging() -> void:
	if not dragging:
		return

	dragging = false

	if not drag_moved:
		velocity = velocity_before_drag
		grounded = grounded_before_drag
		airborne = airborne_before_drag
		speak("say_random_click")
		return

	drag_velocity = drag_velocity.limit_length(max_throw_speed)

	velocity = (drag_velocity * throw_multiplier).limit_length(max_throw_speed)

	grounded = false
	airborne = true
	celebrating = false
	chattering = false
	speaking = false

	speak("say_random_throw")


func update_animation(delta: float) -> void:
	# Eating owns the sprite for the whole gag; nothing may overwrite it.
	if eating:
		return

	# A press is only a drag once the pointer has actually moved. Plain
	# clicks keep the grounded/airborne animation and never flail.
	if dragging and drag_moved:
		play_animation("flailing")
		return

	# Face the direction of travel for the whole airborne period, including
	# the tail of a celebration when the latch is still set.
	if airborne:
		sprite.flip_h = velocity.x < 0.0

	if celebrating:
		return

	if airborne:
		play_animation("falling")
		return

	if grounded:
		# Any spoken line uses the one-frame mouth-open animation. The
		# latch keeps default from overwriting it before it finishes.
		if speaking:
			play_animation("talkin")
			return

		if chattering:
			return

		chatter_timer -= delta

		if chatter_timer <= 0.0:
			chattering = true
			speak("say_random_idle")
		else:
			play_animation("default")


func speak(method: String) -> void:
	dialogue.call(method)
	# Only grounded speech can use talkin; falling and flailing keep their
	# priority, and a celebration must not be interrupted.
	if grounded and not dragging and not celebrating:
		speaking = true


func play_animation(animation_name: String) -> void:
	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _on_animation_finished() -> void:
	if sprite.animation == "thumbs up!":
		# The one-shot has played on solid ground; release the latch now.
		celebrating = false
		play_animation("falling" if airborne else "default")
		return

	if sprite.animation == "talkin":
		speaking = false
		chattering = false
		reset_chatter_timer()


func start_celebration() -> void:
	if celebrating:
		return

	celebrating = true
	chattering = false
	speaking = false


func reset_chatter_timer() -> void:
	chatter_timer = randf_range(
		chatter_interval_min,
		chatter_interval_max
	)


func update_window_position() -> void:
	var window_position := desktop_position - PET_LOCAL_POSITION

	DisplayServer.window_set_position(Vector2i(
		roundi(window_position.x),
		roundi(window_position.y)
	))


func update_mouse_passthrough() -> void:
	var circle_points := PackedVector2Array()
	var segments := 48

	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		circle_points.append(
			PET_LOCAL_POSITION
			+ Vector2(cos(angle), sin(angle)) * PET_RADIUS
		)

	var bubble := dialogue.get("bubble_panel") as Control

	if bubble == null or not bubble.visible:
		DisplayServer.window_set_mouse_passthrough(circle_points)
		return

	# A narrow bridge connects the speech bubble to Jeremy.
	var bridge := PackedVector2Array([
		Vector2(185, 65),
		Vector2(215, 65),
		Vector2(215, 190),
		Vector2(185, 190)
	])

	var merged := Geometry2D.merge_polygons(circle_points, bridge)

	if merged.size() != 1:
		DisplayServer.window_set_mouse_passthrough(circle_points)
		return

	var bubble_rect := PackedVector2Array([
		bubble.position,
		bubble.position + Vector2(bubble.size.x, 0),
		bubble.position + bubble.size,
		bubble.position + Vector2(0, bubble.size.y)
	])

	merged = Geometry2D.merge_polygons(merged[0], bubble_rect)

	if merged.size() == 1:
		DisplayServer.window_set_mouse_passthrough(merged[0])
	else:
		DisplayServer.window_set_mouse_passthrough(circle_points)


# ==================================================
# TAB STEALING (right-click Jeremy)
# ==================================================

func steal_tab() -> void:
	if eating or dragging:
		return

	var info := _foreground_browser()
	if info.is_empty():
		return

	var window_position := Vector2(DisplayServer.window_get_position())
	var tab_screen_position := Vector2(
		float(info["left"]) + 140.0,
		float(info["top"]) + 18.0
	)

	eating = true
	_play_eat_animation()
	_animate_tab_eaten(tab_screen_position - window_position)
	dialogue.call("say", "mine now.", 2.0)

	# Let the visual tab reach his mouth before the real tab goes away.
	await get_tree().create_timer(0.45).timeout
	_close_active_tab()

	await get_tree().create_timer(0.25).timeout
	eating = false

	# Hand the sprite back to the normal state machine.
	if dragging and drag_moved:
		play_animation("flailing")
	elif airborne:
		play_animation("falling")
	elif grounded:
		play_animation("default")


func _run_powershell_file(file_name: String, script: String) -> Array[String]:
	var path := ProjectSettings.globalize_path("user://" + file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return []

	file.store_string(script)
	file.close()

	var output: Array[String] = []

	if OS.execute("powershell.exe", ["-NoProfile", "-File", path], output) != 0:
		return []

	return output


func _foreground_browser() -> Dictionary:
	var output := _run_powershell_file("jeremy_foreground.ps1", foreground_ps)

	if output.is_empty():
		return {}

	var parts := (output[0] as String).strip_edges().split("|")
	if parts.size() < 4:
		return {}

	var window_class := parts[0]
	var is_browser := (
		window_class.begins_with("Chrome_WidgetWin")
		or window_class.begins_with("MozillaWindowClass")
		or window_class.begins_with("Chromium")
	)

	if not is_browser:
		return {}

	return {
		"class": window_class,
		"left": int(parts[1]),
		"top": int(parts[2]),
		"right": int(parts[3])
	}


func _close_active_tab() -> void:
	_run_powershell_file("jeremy_close_tab.ps1", close_tab_ps)


func _play_eat_animation() -> void:
	# Drop in an "eating" animation on the SpriteFrames and it will be used
	# automatically; until then talkin covers the mouth opening.
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(EAT_ANIMATION):
		sprite.play(EAT_ANIMATION)
	else:
		sprite.play("talkin")


func _animate_tab_eaten(from_viewport: Vector2) -> void:
	if tab_layer == null:
		tab_layer = CanvasLayer.new()
		tab_layer.layer = 20
		add_child(tab_layer)

		tab_visual = PanelContainer.new()
		tab_visual.custom_minimum_size = Vector2(120, 24)
		tab_visual.pivot_offset = Vector2(60, 12)
		tab_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.bg_color = Color("#d9dde3")
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_top = 3
		tab_visual.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = "tab"
		label.add_theme_color_override("font_color", Color("#242424"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab_visual.add_child(label)

		tab_layer.add_child(tab_visual)

	tab_visual.visible = true
	tab_visual.scale = Vector2.ONE
	tab_visual.modulate.a = 1.0
	tab_visual.position = from_viewport

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tab_visual, "position", PET_LOCAL_POSITION, 0.5)
	tween.tween_property(tab_visual, "scale", Vector2.ZERO, 0.5)
	tween.chain().tween_callback(_hide_tab_visual)


func _hide_tab_visual() -> void:
	if tab_visual != null:
		tab_visual.visible = false
