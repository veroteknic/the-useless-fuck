extends Node2D

const NotepadManagerScript = preload("res://notepad_manager.gd")
const JeremyMenuScript = preload("res://jeremy_menu.gd")
const BehaviorDirectorScript = preload("res://behavior_director.gd")
const LocomotionBehaviorScript = preload("res://locomotion_behavior.gd")
const AutonomyBehaviorScript = preload("res://autonomy_behavior.gd")
const DramaticCloseManagerScript = preload("res://dramatic_close_manager.gd")
const PixelUIScript = preload("res://pixel_ui.gd")

@onready var camera: Camera2D = $Camera2D
@onready var body: RigidBody2D = $RigidBody2D
@onready var sprite: AnimatedSprite2D = $RigidBody2D/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $RigidBody2D/CollisionShape2D
@onready var dialogue: CanvasLayer = $DialogueManager

const WINDOW_SIZE := Vector2i(400, 360)
const PET_RADIUS := 60.0
const CURSOR_FACE_OFFSET := Vector2(0.0, -24.0)
const PET_LOCAL_POSITION := Vector2(200, 240)
const DRAG_MOVE_THRESHOLD := 6.0
const EAT_ANIMATION := "eating"
const JUMP_ANIMATION := "jumping"
const SPRITE_BASE_SCALE := 4.0
const CURSOR_SCRIPT_NAME := "jeremy_cursor.ps1"
const CURSOR_TARGET_NAME := "jeremy_cursor_target.txt"
const CURSOR_STOP_NAME := "jeremy_cursor_stop.txt"
const TAB_COUNT_NAME := "jeremy_tabs.cfg"
const POPIN_DIR_NAME := "jeremy_popins"
const POPIN_MAX_SIZE := Vector2(220, 180)
const POPIN_VISIBLE_TIME := 2.6
const POPIN_FADE_TIME := 0.5
const MOOD_METER_SIZE := Vector2i(120, 240)
const MOOD_BAR_SIZE := Vector2(18.0, 180.0)

@export var gravity := 1600.0
@export var bounce := 0.55
@export var throw_multiplier := 2.5
@export var max_throw_speed := 2200.0
@export var landing_threshold := 450.0
@export var settling_threshold := 60.0
@export var chatter_interval_min := 7.0
@export var chatter_interval_max := 16.0
@export var walk_speed := 75.0
@export var walk_duration_min := 1.5
@export var walk_duration_max := 4.0
@export var walk_pause_min := 2.0
@export var walk_pause_max := 6.0
@export var jump_interval_min := 6.0
@export var jump_interval_max := 14.0
@export var jump_speed_min := 980.0
@export var jump_speed_max := 1150.0
@export var jump_horizontal_min := 90.0
@export var jump_horizontal_max := 180.0
@export var particles_enabled := true
@export var squash_stretch_enabled := true
@export var squash_strength := 0.22
@export var edge_behaviors_enabled := true
@export var edge_behavior_chance := 0.35
@export var cursor_steal_enabled := true
@export var cursor_steal_auto_enabled := true
@export var cursor_steal_duration := 1.6
@export var cursor_steal_auto_min := 28.0
@export var cursor_steal_auto_max := 55.0
@export var cursor_chase_enabled := true
@export var cursor_chase_radius := 360.0
@export var cursor_chase_speed := 135.0
@export var cursor_chase_timeout := 5.0
@export var cursor_chase_cooldown_min := 22.0
@export var cursor_chase_cooldown_max := 40.0
@export var notepads_enabled := true
@export var context_chatter_chance := 0.35

var desktop_position := Vector2.ZERO
var velocity := Vector2.ZERO

var desktop_min := Vector2.ZERO
var desktop_max := Vector2.ZERO
var active_screen := 0

var dragging := false
var drag_offset := Vector2.ZERO
var drag_start_mouse := Vector2.ZERO
var last_mouse_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var drag_moved := false
var drag_release_watchdog := 0.0
var stubborn_resist := false
var stubborn_timer := 0.0

var velocity_before_drag := Vector2.ZERO
var grounded_before_drag := false
var airborne_before_drag := false
var walking_before_drag := false
var walk_direction_before_drag := 1.0
var walk_timer_before_drag := 0.0
var walk_pause_timer_before_drag := 0.0
var jump_timer_before_drag := 0.0
var self_jump_before_drag := false
var jump_launch_before_drag := false

var grounded := false
var airborne := true
var celebrating := false
var chattering := false
var speaking := false
var eating := false
var dramatic_closing := false
var chatter_timer := 0.0
var mischief_timer := 0.0
var idle_time := 0.0
var last_autonomous_action := ""
var walking := false
var walk_direction := 1.0
var walk_timer := 0.0
var walk_pause_timer := 0.0
var walk_dust_timer := 0.0
var jump_timer := 0.0
var self_jump := false
var jump_launch := false

var tab_layer: CanvasLayer
var tab_visual: PanelContainer

var effects_layer: Node2D
var dust_particles: CPUParticles2D
var crumb_particles: CPUParticles2D
var dust_origin := Vector2.ZERO
var crumb_origin := Vector2.ZERO
var dust_origin_set := false
var crumb_origin_set := false

var squash := 0.0

var edge_hanging := false
var edge_hang_side := ""
var edge_hang_timer := 0.0
var edge_dust_timer := 0.0
var edge_peeking := false
var edge_peek_timer := 0.0

var cursor_stealing := false
var cursor_steal_timer := 0.0
var cursor_steal_target_timer := 0.0
var cursor_steal_pid := -1
var cursor_auto_timer := 0.0
var cursor_chasing := false
var cursor_chase_timer := 0.0
var cursor_chase_cooldown := 0.0

var notepad_manager: Node
var menu_window: Window
var behavior_director: Node
var dramatic_close_manager: Node
var tabs_eaten := 0

var popin_sprite: Sprite2D
var popin_timer := 0.0

var mood_window: Window
var mood_panel: PanelContainer
var mood_fill: ColorRect
var mood_label: Label

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

# Follows a target file so Jeremy can tug the pointer toward himself while he
# keeps moving. The stop file lets clicks cancel the gag immediately.
var cursor_ps := "\n".join([
	'param([string]$TargetFile, [string]$StopFile, [int]$DurationMs, [int]$StepMs)',
	'Add-Type @"',
	'using System;',
	'using System.Runtime.InteropServices;',
	'public static class JeremyCursor {',
	'  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);',
	'  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);',
	'  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);',
	'  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();',
	'  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }',
	'}',
	'"@',
	'# Godot reports physical desktop pixels. Make this helper use the same space',
	'# instead of scaled coordinates that land down/right on high-DPI displays.',
	'try {',
	'  [JeremyCursor]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null',
	'} catch {',
	'  try { [JeremyCursor]::SetProcessDPIAware() | Out-Null } catch {}',
	'}',
	'$deadline = [Environment]::TickCount + $DurationMs',
	'while ([Environment]::TickCount -lt $deadline) {',
	'  if (Test-Path -LiteralPath $StopFile) { break }',
	'  if (-not (Test-Path -LiteralPath $TargetFile)) { Start-Sleep -Milliseconds $StepMs; continue }',
	'  $raw = (Get-Content -LiteralPath $TargetFile -Raw -ErrorAction SilentlyContinue).Trim()',
	'  if (-not $raw.EndsWith(";")) { Start-Sleep -Milliseconds $StepMs; continue }',
	'  $raw = $raw.TrimEnd([char]59)',
	'  $parts = $raw.Split([char]44)',
	'  if ($parts.Length -ge 2) {',
	'    $tx = [int]$parts[0]',
	'    $ty = [int]$parts[1]',
	'    if ($tx -lt -10000 -or $tx -gt 10000 -or $ty -lt -10000 -or $ty -gt 10000) { Start-Sleep -Milliseconds $StepMs; continue }',
	'    $p = New-Object JeremyCursor+POINT',
	'    if ([JeremyCursor]::GetCursorPos([ref]$p)) {',
	'      $nx = [int]($p.X + ($tx - $p.X) * 1.0)',
	'      $ny = [int]($p.Y + ($ty - $p.Y) * 1.0)',
	'      [JeremyCursor]::SetCursorPos($nx, $ny) | Out-Null',
	'    }',
	'  }',
	'  Start-Sleep -Milliseconds $StepMs',
	'}'
])


func _ready() -> void:
	_setup_window()
	_setup_physics()
	_setup_particles()
	_setup_popin()
	_setup_mood_meter()

	dramatic_close_manager = DramaticCloseManagerScript.new()
	dramatic_close_manager.name = "DramaticCloseManager"
	add_child(dramatic_close_manager)

	if notepads_enabled:
		notepad_manager = NotepadManagerScript.new()
		notepad_manager.name = "NotepadManager"
		add_child(notepad_manager)

	behavior_director = BehaviorDirectorScript.new(self)
	behavior_director.name = "BehaviorDirector"
	add_child(behavior_director)

	var director_config = behavior_director.get("config")
	if director_config != null:
		director_config.set("allow_cursor_steal", cursor_steal_enabled)
		director_config.set("allow_cursor_chase", cursor_chase_enabled)
		director_config.set("allow_notes", notepads_enabled)

	# One continuous behaviour owns walk/jump/fall from here on. main.gd only
	# feeds the director input/window state and asks it to tick behaviours.
	var locomotion_behavior = LocomotionBehaviorScript.new("locomotion", behavior_director)
	behavior_director.call("register_behavior", locomotion_behavior)

	# One behaviour owns autonomous timing and weighted choice; the concrete
	# actions still go through the director's existing request path.
	var autonomy_behavior = AutonomyBehaviorScript.new("autonomy", behavior_director)
	behavior_director.call("register_behavior", autonomy_behavior)

	if notepad_manager != null:
		notepad_manager.set("note_read_callback", Callable(self, "_on_note_read"))
		if behavior_director != null:
			var pet_config = behavior_director.get("config")
			if pet_config != null:
				notepad_manager.set(
					"allow_custom_notes",
					bool(pet_config.get("allow_custom_content"))
				)
				notepad_manager.set(
					"custom_content_chance",
					float(pet_config.get("custom_content_chance"))
				)

	_load_tab_count()
	reset_cursor_auto_timer()
	reset_cursor_chase_cooldown()
	reset_mischief_timer()

	await get_tree().process_frame

	update_desktop_bounds()

	var screen_position := Vector2(DisplayServer.screen_get_position(
		DisplayServer.window_get_current_screen()
	))
	var screen_size := Vector2(DisplayServer.screen_get_size(
		DisplayServer.window_get_current_screen()
	))

	desktop_position = screen_position + screen_size * 0.5
	update_desktop_bounds()
	desktop_position.x = clampf(desktop_position.x, desktop_min.x, desktop_max.x)
	desktop_position.y = clampf(desktop_position.y, desktop_min.y, desktop_max.y)

	body.position = PET_LOCAL_POSITION

	body.input_event.connect(_on_body_input_event)
	sprite.animation_finished.connect(_on_animation_finished)

	reset_chatter_timer()
	reset_walk_pause_timer()
	reset_jump_timer()
	_update_mood_meter(0.0)
	play_animation("default")

	update_window_position()
	update_mouse_passthrough()


func _process(delta: float) -> void:
	if behavior_director != null:
		behavior_director.call("tick", delta)

	update_popin(delta)
	_update_mood_meter(delta)

	if behavior_director != null and bool(behavior_director.call("is_paused")):
		update_window_position()
		return

	sync_active_screen()

	if dragging:
		drag_release_watchdog -= delta
		if drag_release_watchdog <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			stop_dragging()

	if dragging:
		handle_dragging(delta)

	update_animation(delta)
	update_squash_stretch(delta)
	update_cursor_steal(delta)
	update_window_position()
	update_particle_positions()


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

	sprite.scale = Vector2(SPRITE_BASE_SCALE, SPRITE_BASE_SCALE)


func _setup_popin() -> void:
	# User-supplied images only. Nothing is bundled and nothing is copied from
	# another character or game.
	popin_sprite = Sprite2D.new()
	popin_sprite.name = "UserPopin"
	popin_sprite.z_index = 20
	popin_sprite.visible = false
	add_child(popin_sprite)


func _setup_mood_meter() -> void:
	# A separate borderless, no-focus, fully click-through window pinned to the
	# left edge of Jeremy's current monitor. It fills upward as his mood rises.
	mood_window = Window.new()
	mood_window.name = "MoodMeter"
	mood_window.title = "jeremy mood"
	mood_window.size = MOOD_METER_SIZE
	mood_window.borderless = true
	mood_window.always_on_top = true
	mood_window.transparent = true
	mood_window.set_flag(Window.FLAG_BORDERLESS, true)
	mood_window.set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	mood_window.set_flag(Window.FLAG_TRANSPARENT, true)
	mood_window.set_flag(Window.FLAG_NO_FOCUS, true)
	mood_window.tree_entered.connect(_on_mood_window_ready, CONNECT_ONE_SHOT)
	# The main scene is still setting up its own children during _ready(), so
	# the OS subwindow has to be attached on the next deferred frame.
	get_tree().root.add_child.call_deferred(mood_window)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mood_window.add_child(root)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 4)
	root.add_child(layout)

	mood_label = Label.new()
	mood_label.text = "mood"
	PixelUIScript.apply(mood_label, 9, true)
	mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(mood_label)

	mood_panel = PanelContainer.new()
	mood_panel.custom_minimum_size = MOOD_BAR_SIZE
	mood_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mood_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.85, 0.85, 0.95)
	mood_panel.add_theme_stylebox_override("panel", style)
	layout.add_child(mood_panel)

	var background := ColorRect.new()
	background.color = Color(0.12, 0.12, 0.14, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mood_panel.add_child(background)

	mood_fill = ColorRect.new()
	mood_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mood_fill.anchor_left = 0.0
	mood_fill.anchor_top = 1.0
	mood_fill.anchor_right = 1.0
	mood_fill.anchor_bottom = 1.0
	mood_fill.offset_left = 2.0
	mood_fill.offset_right = -2.0
	mood_fill.offset_top = -MOOD_BAR_SIZE.y
	mood_fill.offset_bottom = -2.0
	mood_panel.add_child(mood_fill)


func _on_mood_window_ready() -> void:
	if mood_window == null:
		return

	var full_rect := PackedVector2Array([
		Vector2.ZERO,
		Vector2(MOOD_METER_SIZE.x, 0),
		Vector2(MOOD_METER_SIZE),
		Vector2(0, MOOD_METER_SIZE.y)
	])
	DisplayServer.window_set_mouse_passthrough(full_rect, mood_window.get_window_id())
	_position_mood_meter()


func _position_mood_meter() -> void:
	if mood_window == null:
		return

	var screen := active_screen
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		screen = DisplayServer.window_get_current_screen()

	var screen_position := Vector2(DisplayServer.screen_get_position(screen))
	var screen_size := Vector2(DisplayServer.screen_get_size(screen))
	var target := Vector2i(
		roundi(screen_position.x + 4.0),
		roundi(screen_position.y + (screen_size.y - float(MOOD_METER_SIZE.y)) * 0.5)
	)

	if mood_window.position != target:
		mood_window.position = target


func _update_mood_meter(_delta: float) -> void:
	if mood_window == null:
		return

	var show := true
	if behavior_director != null:
		var pet_config = behavior_director.get("config")
		if pet_config != null:
			var value: Variant = pet_config.get("show_mood_meter")
			show = true if value == null else bool(value)

	mood_window.visible = show
	if not show or behavior_director == null:
		return

	_position_mood_meter()

	var mood := clampf(float(behavior_director.get("mood")), -1.0, 1.0)
	if mood_label != null:
		mood_label.text = str(behavior_director.call("get_mood_tier"))

	var fill_height := MOOD_BAR_SIZE.y - 4.0
	mood_fill.offset_top = -fill_height * clampf((mood + 1.0) * 0.5, 0.0, 1.0)

	# Calm is green, curious is yellow, and high rambunctiousness is red.
	if mood <= -0.2:
		mood_fill.color = Color("#55c26a")
	elif mood < 0.55:
		mood_fill.color = Color("#e0c04a")
	else:
		mood_fill.color = Color("#e0524a")


func update_popin(delta: float) -> void:
	if popin_sprite == null or not popin_sprite.visible:
		return

	popin_timer -= delta

	if popin_timer <= 0.0:
		popin_sprite.visible = false
		popin_sprite.texture = null
		return

	if popin_timer < POPIN_FADE_TIME:
		popin_sprite.modulate.a = clampf(popin_timer / POPIN_FADE_TIME, 0.0, 1.0)


func show_random_popin() -> bool:
	if behavior_director != null:
		if not bool(behavior_director.call("is_action_allowed", "show_popin")):
			return false

	var dir_path := ProjectSettings.globalize_path("user://" + POPIN_DIR_NAME)
	var dir := DirAccess.open(dir_path)

	if dir == null:
		return false

	var candidates: Array[String] = []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var extension := file_name.get_extension().to_lower()
			if extension == "png" or extension == "jpg" or extension == "jpeg" or extension == "webp":
				candidates.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	if candidates.is_empty():
		return false

	var chosen_name := str(candidates.pick_random())
	var full_path := dir_path + "\\" + chosen_name
	var source := FileAccess.open(full_path, FileAccess.READ)

	if source == null:
		return false

	var file_size := source.get_length()
	source.close()

	if file_size > 8 * 1024 * 1024:
		return false

	var image := Image.load_from_file(full_path)

	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false

	var texture := ImageTexture.create_from_image(image)
	var texture_size := texture.get_size()
	var fit := minf(
		POPIN_MAX_SIZE.x / maxf(texture_size.x, 1.0),
		POPIN_MAX_SIZE.y / maxf(texture_size.y, 1.0)
	)
	var scale_factor := minf(1.0, fit)

	popin_sprite.texture = texture
	popin_sprite.scale = Vector2(scale_factor, scale_factor)
	popin_sprite.position = Vector2(
		clampf(randf_range(70.0, 330.0), 20.0, 380.0),
		clampf(PET_LOCAL_POSITION.y + randf_range(-120.0, -40.0), 20.0, 320.0)
	)
	popin_sprite.modulate.a = 1.0
	popin_sprite.visible = true
	popin_timer = POPIN_VISIBLE_TIME

	if behavior_director != null:
		behavior_director.call("adjust_mood", 0.08, "popin")

	return true


func _setup_particles() -> void:
	var particle_texture := _make_particle_texture()

	effects_layer = Node2D.new()
	effects_layer.name = "Particles"
	add_child(effects_layer)

	dust_particles = CPUParticles2D.new()
	dust_particles.name = "DustParticles"
	dust_particles.texture = particle_texture
	dust_particles.z_index = -1
	dust_particles.one_shot = true
	dust_particles.local_coords = true
	dust_particles.emitting = false
	dust_particles.amount = 16
	dust_particles.lifetime = 0.5
	dust_particles.lifetime_randomness = 0.35
	dust_particles.explosiveness = 1.0
	dust_particles.direction = Vector2.RIGHT
	dust_particles.spread = 50.0
	dust_particles.initial_velocity_min = 35.0
	dust_particles.initial_velocity_max = 110.0
	dust_particles.gravity = Vector2(0, 70.0)
	dust_particles.damping_min = 60.0
	dust_particles.damping_max = 130.0
	dust_particles.angle_min = 0.0
	dust_particles.angle_max = 360.0
	dust_particles.angular_velocity_min = -180.0
	dust_particles.angular_velocity_max = 180.0
	dust_particles.scale_amount_min = 0.5
	dust_particles.scale_amount_max = 1.4
	dust_particles.color = Color("#d8d1bf")
	dust_particles.color_ramp = _make_fade_gradient(0.85)
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	effects_layer.add_child(dust_particles)

	crumb_particles = CPUParticles2D.new()
	crumb_particles.name = "CrumbParticles"
	crumb_particles.texture = particle_texture
	crumb_particles.z_index = 1
	crumb_particles.one_shot = true
	crumb_particles.local_coords = true
	crumb_particles.emitting = false
	crumb_particles.amount = 22
	crumb_particles.lifetime = 0.85
	crumb_particles.lifetime_randomness = 0.4
	crumb_particles.explosiveness = 1.0
	crumb_particles.direction = Vector2.DOWN
	crumb_particles.spread = 60.0
	crumb_particles.initial_velocity_min = 60.0
	crumb_particles.initial_velocity_max = 170.0
	crumb_particles.gravity = Vector2(0, 520.0)
	crumb_particles.damping_min = 20.0
	crumb_particles.damping_max = 60.0
	crumb_particles.angle_min = 0.0
	crumb_particles.angle_max = 360.0
	crumb_particles.angular_velocity_min = -360.0
	crumb_particles.angular_velocity_max = 360.0
	crumb_particles.scale_amount_min = 0.5
	crumb_particles.scale_amount_max = 1.5
	crumb_particles.color = Color("#d9dde3")
	crumb_particles.color_ramp = _make_fade_gradient(1.0)
	crumb_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	effects_layer.add_child(crumb_particles)


func _make_particle_texture() -> ImageTexture:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)

	for y in range(8):
		for x in range(8):
			var distance := Vector2(x - 3.5, y - 3.5).length() / 4.5
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(image)


func _make_fade_gradient(start_alpha: float) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, start_alpha))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	return gradient


func update_particle_positions() -> void:
	var window_position := desktop_position - PET_LOCAL_POSITION

	if dust_origin_set and dust_particles != null:
		dust_particles.position = dust_origin - window_position

	if crumb_origin_set and crumb_particles != null:
		crumb_particles.position = crumb_origin - window_position


func _edge_spawn(side: String) -> Dictionary:
	match side:
		"left":
			return {
				"position": Vector2(
					desktop_min.x - PET_RADIUS,
					desktop_position.y
				),
				"direction": Vector2.RIGHT
			}
		"right":
			return {
				"position": Vector2(
					desktop_max.x + PET_RADIUS,
					desktop_position.y
				),
				"direction": Vector2.LEFT
			}
		"top":
			return {
				"position": Vector2(
					desktop_position.x,
					desktop_min.y - PET_RADIUS
				),
				"direction": Vector2.DOWN
			}
		_:
			return {
				"position": Vector2(
					desktop_position.x,
					desktop_max.y + PET_RADIUS
				),
				"direction": Vector2.UP
			}


func burst_dust(side: String) -> void:
	if not particles_enabled or dust_particles == null:
		return

	var spawn := _edge_spawn(side)
	dust_origin = spawn["position"]
	dust_origin_set = true
	dust_particles.direction = spawn["direction"]
	dust_particles.position = dust_origin - (desktop_position - PET_LOCAL_POSITION)
	dust_particles.restart()
	dust_particles.emitting = true


func burst_crumbs() -> void:
	if not particles_enabled or crumb_particles == null:
		return

	var spawn := _edge_spawn(["left", "right", "top"].pick_random())
	crumb_origin = spawn["position"]
	crumb_origin_set = true
	crumb_particles.direction = spawn["direction"]
	crumb_particles.position = crumb_origin - (desktop_position - PET_LOCAL_POSITION)
	crumb_particles.restart()
	crumb_particles.emitting = true


func get_screen_rect(index: int) -> Rect2:
	var screen_count := DisplayServer.get_screen_count()

	if screen_count <= 0:
		return Rect2(Vector2.ZERO, Vector2(1920, 1080))

	var safe_index := clampi(index, 0, screen_count - 1)
	return Rect2(
		Vector2(DisplayServer.screen_get_position(safe_index)),
		Vector2(DisplayServer.screen_get_size(safe_index))
	)


func nearest_screen(position: Vector2) -> int:
	var screen_count := DisplayServer.get_screen_count()

	if screen_count <= 0:
		return 0

	var best_screen := 0
	var best_score := INF

	for i in range(screen_count):
		var rect := get_screen_rect(i)

		if rect.has_point(position):
			return i

		var horizontal_gap := maxf(
			rect.position.x - position.x,
			position.x - rect.end.x
		)
		horizontal_gap = maxf(horizontal_gap, 0.0)

		var vertical_gap := maxf(
			rect.position.y - position.y,
			position.y - rect.end.y
		)
		vertical_gap = maxf(vertical_gap, 0.0)

		# Prefer the nearby column of monitors when walking across the desktop;
		# a shorter monitor can have its floor above Jeremy's current height.
		var score := horizontal_gap * 10.0 + vertical_gap

		if score < best_score:
			best_score = score
			best_screen = i

	return best_screen


func apply_active_screen_bounds() -> void:
	var rect := get_screen_rect(active_screen)
	desktop_min = rect.position + Vector2(PET_RADIUS, PET_RADIUS)
	desktop_max = rect.end - Vector2(PET_RADIUS, PET_RADIUS)


func sync_active_screen() -> void:
	var next_screen := nearest_screen(desktop_position)

	if next_screen != active_screen:
		active_screen = next_screen
		apply_active_screen_bounds()
		desktop_position.y = clampf(desktop_position.y, desktop_min.y, desktop_max.y)


func update_desktop_bounds() -> void:
	active_screen = nearest_screen(desktop_position)
	apply_active_screen_bounds()


func maybe_start_wall_behavior(side: String, impact_speed: float) -> bool:
	if not edge_behaviors_enabled:
		return false

	if impact_speed < landing_threshold:
		return false

	if randf() >= edge_behavior_chance:
		return false

	edge_hanging = true
	edge_hang_side = side
	edge_hang_timer = randf_range(0.35, 0.85)
	edge_dust_timer = 0.2
	grounded = false
	airborne = true
	walking = false
	celebrating = false
	chattering = false
	speaking = false
	self_jump = false
	jump_launch = false
	velocity.x = 0.0
	velocity.y = clampf(velocity.y, -80.0, 160.0)
	sprite.flip_h = side == "right"

	if randf() < 0.4:
		speak("say_random_edge")

	return true


func update_edge_hang(delta: float) -> void:
	edge_hang_timer -= delta
	desktop_position.x = desktop_min.x if edge_hang_side == "left" else desktop_max.x

	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity * 0.35 * delta, 280.0)
	desktop_position.y += velocity.y * delta

	edge_dust_timer -= delta
	if edge_dust_timer <= 0.0:
		burst_dust(edge_hang_side)
		edge_dust_timer = 0.24

	if desktop_position.y >= desktop_max.y:
		desktop_position.y = desktop_max.y
		velocity.y = 0.0
		edge_hanging = false
		grounded = true
		airborne = false
		reset_walk_pause_timer()
		reset_jump_timer()
		return

	if edge_hang_timer <= 0.0:
		edge_hanging = false
		var inward := 1.0 if edge_hang_side == "left" else -1.0
		velocity.x = inward * randf_range(200.0, 340.0)
		velocity.y = -randf_range(300.0, 460.0)
		jump_launch = false
		burst_dust(edge_hang_side)


func maybe_start_ceiling_peek(impact_speed: float) -> bool:
	if not edge_behaviors_enabled:
		return false

	if impact_speed < landing_threshold:
		return false

	if randf() >= edge_behavior_chance:
		return false

	edge_peeking = true
	edge_peek_timer = randf_range(0.3, 0.7)
	grounded = false
	airborne = true
	walking = false
	celebrating = false
	chattering = false
	speaking = false
	self_jump = false
	jump_launch = false
	velocity = Vector2.ZERO
	burst_dust("top")
	speak("say_random_edge")
	return true


func update_edge_peek(delta: float) -> void:
	edge_peek_timer -= delta
	desktop_position.y = desktop_min.y

	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	velocity.y = 0.0

	if edge_peek_timer <= 0.0:
		edge_peeking = false
		velocity.y = randf_range(140.0, 240.0)
		burst_dust("top")


func clear_edge_states() -> void:
	edge_hanging = false
	edge_hang_side = ""
	edge_hang_timer = 0.0
	edge_dust_timer = 0.0
	edge_peeking = false
	edge_peek_timer = 0.0


func update_squash_stretch(delta: float) -> void:
	if not squash_stretch_enabled:
		sprite.scale = Vector2(SPRITE_BASE_SCALE, SPRITE_BASE_SCALE)
		return

	squash = move_toward(squash, 0.0, delta * 2.6)

	var scale_x := 1.0
	var scale_y := 1.0

	if edge_hanging:
		scale_x = 1.12
		scale_y = 0.9
	elif edge_peeking:
		scale_x = 0.9
		scale_y = 1.1
	elif airborne:
		var stretch := (
			clampf(absf(velocity.y) / maxf(jump_speed_max, 1.0), 0.0, 1.0) * 0.12
		)
		scale_x = 1.0 - stretch
		scale_y = 1.0 + stretch

	scale_x += squash * 0.75
	scale_y -= squash

	sprite.scale = Vector2(
		SPRITE_BASE_SCALE * clampf(scale_x, 0.7, 1.35),
		SPRITE_BASE_SCALE * clampf(scale_y, 0.65, 1.35)
	)


func get_config_number(key: String, fallback: float) -> float:
	if behavior_director == null:
		return fallback

	var pet_config = behavior_director.get("config")
	if pet_config == null:
		return fallback

	var value: Variant = pet_config.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)

	return fallback


func scaled_interval(
	min_value: float,
	max_value: float,
	frequency_key: String,
	use_mischief: bool = false
) -> float:
	var frequency := get_config_number(frequency_key, 1.0)

	if frequency <= 0.0:
		return 1.0e9

	if use_mischief:
		var intensity := get_config_number("mischief_intensity", 1.0)
		if intensity <= 0.0:
			return 1.0e9
		frequency *= minf(intensity, 2.0)

	return randf_range(min_value, max_value) / maxf(frequency, 0.05)


# Locomotion wrappers: other systems still ask for these timers/guards, but
# the decision itself lives in the director-owned LocomotionBehavior.
func reset_walk_pause_timer() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "locomotion", "reset_walk_pause_timer"
		)


func reset_jump_timer() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "locomotion", "reset_jump_timer"
		)


func can_start_jump() -> bool:
	if behavior_director == null:
		return false
	return bool(behavior_director.call(
		"call_behavior_method", "locomotion", "can_start_jump"
	))


func _on_body_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			start_dragging()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			toggle_menu()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			request_behavior("steal_cursor")


func toggle_menu() -> void:
	if menu_window != null and is_instance_valid(menu_window):
		menu_window.queue_free()
		menu_window = null
		return

	# Capture before the menu appears so dramatic close targets the window the
	# human was actually using, not the menu itself.
	if dramatic_close_manager != null:
		dramatic_close_manager.call("capture_foreground")

	menu_window = JeremyMenuScript.new(self)
	get_tree().root.add_child(menu_window)
	menu_window.tree_exited.connect(_on_menu_closed.bind(menu_window))
	menu_window.place_near(Vector2(DisplayServer.mouse_get_position()))


func _on_menu_closed(window: Window) -> void:
	if menu_window == window:
		menu_window = null

	if dramatic_close_manager != null:
		dramatic_close_manager.call("clear_capture")


func get_state() -> String:
	if behavior_director == null:
		return "unknown"
	return str(behavior_director.call("get_state"))


func get_behavior_status() -> Dictionary:
	if behavior_director == null:
		return {"state": "unknown", "active_behavior": "unknown"}

	var status := behavior_director.call("get_status") as Dictionary

	var weights = behavior_director.call(
		"call_behavior_method", "autonomy", "get_weights_snapshot"
	)
	if weights is Dictionary:
		status["autonomy_weights"] = weights

	if dramatic_close_manager != null:
		status["close_allowlist"] = int(
			dramatic_close_manager.call("get_allowlist_count")
		)

		var captured = dramatic_close_manager.call("get_captured_info")
		if captured is Dictionary and not (captured as Dictionary).is_empty():
			var info := captured as Dictionary
			status["close_target"] = str(
				info.get("title", info.get("name", ""))
			)

	return status


func get_behavior_config() -> Dictionary:
	if behavior_director == null:
		return {}
	return behavior_director.call("get_config_snapshot") as Dictionary


func set_behavior_config(key: String, value: Variant) -> bool:
	if behavior_director == null:
		return false

	var applied := bool(behavior_director.call("set_config_value", key, value))

	if applied and key == "paused" and bool(value):
		if cursor_stealing:
			_stop_cursor_steal()
		if cursor_chasing:
			_stop_cursor_chase()

	if applied and key == "show_mood_meter":
		_update_mood_meter(0.0)

	if applied and notepad_manager != null:
		if key == "allow_notes":
			notepad_manager.set("notes_enabled", bool(value))
		elif key == "allow_custom_content":
			notepad_manager.set("allow_custom_notes", bool(value))
		elif key == "custom_content_chance":
			notepad_manager.set("custom_content_chance", float(value))

	return applied


func behavior_allows(action: String) -> bool:
	if behavior_director == null:
		return true
	return bool(behavior_director.call("is_action_allowed", action))


func request_behavior(action: String, args: Array = []) -> bool:
	if behavior_director == null:
		return false
	return bool(behavior_director.call("request_behavior", action, args))


func allow_foreground_close(use_captured_target: bool = false) -> bool:
	if dramatic_close_manager == null:
		return false

	var info := {}
	if use_captured_target:
		info = dramatic_close_manager.call("get_captured_info") as Dictionary

	return bool(dramatic_close_manager.call("add_foreground_to_allowlist", info))


func allow_captured_foreground_close() -> bool:
	return allow_foreground_close(true)


func dramatic_close(use_captured_target: bool = false) -> bool:
	if dramatic_close_manager == null or eating or dramatic_closing or dragging:
		return false

	var info := {}
	if use_captured_target:
		info = dramatic_close_manager.call("get_captured_info") as Dictionary

	if not bool(dramatic_close_manager.call("perform", info)):
		return false

	dramatic_closing = true

	if dialogue != null and dialogue.has_method("say"):
		dialogue.call("say", "oops.", 1.2)

	if behavior_director != null:
		behavior_director.call("adjust_mood", 0.06, "dramatic_close")

	_finish_dramatic_close()
	return true


func dramatic_close_captured() -> bool:
	return dramatic_close(true)


func _finish_dramatic_close() -> void:
	await get_tree().create_timer(1.8).timeout
	dramatic_closing = false

	if dialogue != null and dialogue.has_method("say"):
		dialogue.call("say", "never happened.", 1.4)


func _on_note_read(_text: String, _entry: Dictionary) -> void:
	if behavior_director != null:
		if not bool(behavior_director.call("is_action_allowed", "note_reaction")):
			return
		behavior_director.call("adjust_mood", 0.2, "note_read")

	if dialogue != null and dialogue.has_method("say_random_note_read"):
		dialogue.call("say_random_note_read")
	elif dialogue != null and dialogue.has_method("say"):
		dialogue.call("say", "you read it.", 2.2)

	if behavior_director != null and randf() < 0.35:
		request_behavior("show_popin")


func start_dragging() -> void:
	if dragging or eating:
		return

	if cursor_stealing:
		_stop_cursor_steal()

	if cursor_chasing:
		_stop_cursor_chase()

	dragging = true
	drag_moved = false
	drag_release_watchdog = 0.12

	velocity_before_drag = velocity
	grounded_before_drag = grounded
	airborne_before_drag = airborne
	walking_before_drag = walking
	walk_direction_before_drag = walk_direction
	walk_timer_before_drag = walk_timer
	walk_pause_timer_before_drag = walk_pause_timer
	jump_timer_before_drag = jump_timer
	self_jump_before_drag = self_jump
	jump_launch_before_drag = jump_launch

	drag_velocity = Vector2.ZERO

	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	drag_offset = desktop_position - mouse_position
	drag_start_mouse = mouse_position
	last_mouse_position = mouse_position


func handle_dragging(delta: float) -> void:
	var mouse_position := Vector2(DisplayServer.mouse_get_position())

	if not drag_moved:
		if mouse_position.distance_to(drag_start_mouse) <= DRAG_MOVE_THRESHOLD:
			# Still a plain press. The director already ticked locomotion this
			# frame, so there is nothing extra to do here.
			last_mouse_position = mouse_position
			return

		# First real movement: from here on he is actively being dragged.
		drag_moved = true
		clear_edge_states()
		grounded = false
		airborne = false
		walking = false
		self_jump = false
		jump_launch = false
		celebrating = false
		chattering = false
		speaking = false
		velocity = Vector2.ZERO

		if behavior_director != null and bool(behavior_director.call("roll_stubborn_flail")):
			start_stubborn_flail()

		if stubborn_resist:
			speak("say_random_stubborn")
		else:
			speak("say_random_grab")

		if behavior_director != null:
			behavior_director.call(
				"adjust_mood",
				-0.24 if stubborn_resist else -0.12,
				"dragged"
			)

	var target_position := mouse_position + drag_offset

	if stubborn_resist:
		stubborn_timer -= delta
		desktop_position = desktop_position.lerp(target_position, 0.14)
		if stubborn_timer <= 0.0:
			stubborn_resist = false
			if dialogue != null and dialogue.has_method("say"):
				dialogue.call("say", "fine.", 1.6)
	else:
		desktop_position = target_position

	sync_active_screen()
	desktop_position.x = clampf(desktop_position.x, desktop_min.x, desktop_max.x)
	desktop_position.y = clampf(desktop_position.y, desktop_min.y, desktop_max.y)

	if delta > 0.0:
		drag_velocity = (mouse_position - last_mouse_position) / delta
		if stubborn_resist:
			drag_velocity *= 0.25

	last_mouse_position = mouse_position


func start_stubborn_flail() -> bool:
	if not dragging or not drag_moved:
		return false

	stubborn_resist = true
	stubborn_timer = maxf(stubborn_timer, 0.45)
	return true


func stop_dragging() -> void:
	if not dragging:
		return

	dragging = false
	drag_release_watchdog = 0.0
	stubborn_resist = false
	stubborn_timer = 0.0

	if not drag_moved:
		velocity = velocity_before_drag
		grounded = grounded_before_drag
		airborne = airborne_before_drag
		walking = walking_before_drag
		walk_direction = walk_direction_before_drag
		walk_timer = walk_timer_before_drag
		walk_pause_timer = walk_pause_timer_before_drag
		jump_timer = jump_timer_before_drag
		self_jump = self_jump_before_drag
		jump_launch = jump_launch_before_drag
		speak("say_random_click")
		return

	drag_velocity = drag_velocity.limit_length(max_throw_speed)

	velocity = (drag_velocity * throw_multiplier).limit_length(max_throw_speed)

	grounded = false
	airborne = true
	walking = false
	self_jump = false
	jump_launch = false
	celebrating = false
	chattering = false
	speaking = false

	speak("say_random_throw")


func update_animation(delta: float) -> void:
	# Eating owns the sprite for the whole gag; nothing may overwrite it.
	if eating:
		return

	if edge_hanging or edge_peeking:
		play_animation("falling")
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
		# "jumping" plays only on the initial upward hop; every other airborne
		# frame uses "falling".
		if (
			jump_launch
			and velocity.y < 0.0
			and sprite.sprite_frames != null
			and sprite.sprite_frames.has_animation(JUMP_ANIMATION)
		):
			play_animation(JUMP_ANIMATION)
		else:
			play_animation("falling")
		return

	if grounded:
		# Any spoken line uses the one-frame mouth-open animation. The
		# latch keeps default/walking from overwriting it before it finishes.
		if speaking:
			play_animation("talkin")
			return

		if chattering:
			return

		# Dialogue timing and choice belong to the director-ticked autonomy
		# behaviour now. This function only draws the resulting state.
		if walking:
			play_animation("walking")
			return

		play_animation("default")


func speak(method: String) -> void:
	if dialogue == null or not dialogue.has_method(method):
		return

	dialogue.call(method)
	reset_chatter_timer()
	# Only grounded speech can use talkin; falling, flailing, eating and
	# celebrations keep their priority.
	if grounded and not dragging and not eating and not celebrating:
		speaking = true
		walking = false


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
	walking = false
	reset_jump_timer()
	chattering = false
	speaking = false


# Autonomy wrappers: callers can still reset timers or ask for actions, but the
# clocks and selections live in the director-ticked AutonomyBehavior.
func reset_chatter_timer() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "autonomy", "reset_chatter_timer"
		)


func reset_mischief_timer() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "autonomy", "reset_mischief_timer"
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
# CURSOR STEALING (middle-click Jeremy, or he gets bold)
# ==================================================

func _user_path(file_name: String) -> String:
	return ProjectSettings.globalize_path("user://" + file_name)


func _write_user_script(file_name: String, script: String) -> String:
	var path := _user_path(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return ""

	file.store_string(script)
	file.close()
	return path


func _write_cursor_target() -> void:
	var file := FileAccess.open(_user_path(CURSOR_TARGET_NAME), FileAccess.WRITE)

	if file == null:
		return

	var target := desktop_position + CURSOR_FACE_OFFSET
	file.store_string("%d,%d;" % [
		roundi(target.x),
		roundi(target.y)
	])
	file.close()


func reset_cursor_auto_timer() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "autonomy", "reset_cursor_auto_timer"
		)


func reset_cursor_chase_cooldown() -> void:
	if behavior_director != null:
		behavior_director.call(
			"call_behavior_method", "autonomy", "reset_cursor_chase_cooldown"
		)


func mouse_touches_pet() -> bool:
	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	return mouse_position.distance_to(desktop_position) <= PET_RADIUS


func steal_cursor(require_contact: bool = false) -> bool:
	if (
		not cursor_steal_enabled
		or cursor_stealing
		or dragging
		or eating
		or dramatic_closing
	):
		return false

	if require_contact and not mouse_touches_pet():
		return false

	if cursor_chasing:
		_stop_cursor_chase()

	var stop_path := _user_path(CURSOR_STOP_NAME)
	if FileAccess.file_exists(stop_path):
		DirAccess.remove_absolute(stop_path)

	_write_cursor_target()

	var script_path := _write_user_script(CURSOR_SCRIPT_NAME, cursor_ps)
	if script_path.is_empty():
		return false

	cursor_stealing = true
	cursor_steal_timer = cursor_steal_duration
	cursor_steal_target_timer = 0.0

	cursor_steal_pid = OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		_user_path(CURSOR_TARGET_NAME),
		stop_path,
		str(roundi(cursor_steal_duration * 1000.0)),
		"16"
	]), false)

	if cursor_steal_pid <= 0:
		_stop_cursor_steal()
		return false

	speak("say_random_cursor")
	if behavior_director != null:
		behavior_director.call("adjust_mood", 0.12, "cursor")
	return true


func update_cursor_steal(delta: float) -> void:
	if cursor_stealing:
		cursor_steal_timer -= delta
		cursor_steal_target_timer -= delta

		if cursor_steal_target_timer <= 0.0:
			_write_cursor_target()
			cursor_steal_target_timer = 0.06

		if cursor_steal_timer <= 0.0:
			_stop_cursor_steal()

		return

	if cursor_chasing:
		return

	# Autonomous steal/chase timing now belongs to AutonomyBehavior. This
	# function only finishes an active cursor steal.


func start_cursor_chase() -> bool:
	if not cursor_steal_enabled or not cursor_chase_enabled:
		return false

	if cursor_chasing or cursor_stealing or dragging or eating:
		return false

	cursor_chasing = true
	cursor_chase_timer = cursor_chase_timeout
	walking = true
	velocity.x = 0.0
	walk_dust_timer = 0.0
	reset_jump_timer()
	return true


func update_cursor_chase(delta: float) -> void:
	cursor_chase_timer -= delta

	var mouse_x := float(DisplayServer.mouse_get_position().x)
	var delta_x := mouse_x - desktop_position.x
	var horizontal_distance := absf(delta_x)
	var direction := 0.0 if horizontal_distance < 1.0 else signf(delta_x)

	velocity.x = direction * cursor_chase_speed
	desktop_position.x += velocity.x * delta
	sync_active_screen()
	desktop_position.x = clampf(desktop_position.x, desktop_min.x, desktop_max.x)

	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	walk_dust_timer -= delta
	if walk_dust_timer <= 0.0:
		burst_dust("bottom")
		walk_dust_timer = 0.5

	if mouse_touches_pet():
		_stop_cursor_chase()
		steal_cursor(true)
		return

	if cursor_chase_timer <= 0.0:
		_stop_cursor_chase()


func _stop_cursor_chase() -> void:
	if not cursor_chasing:
		return

	cursor_chasing = false
	cursor_chase_timer = 0.0
	walking = false
	velocity.x = 0.0
	reset_walk_pause_timer()
	reset_jump_timer()
	reset_cursor_chase_cooldown()


func _stop_cursor_steal() -> void:
	if not cursor_stealing and cursor_steal_pid <= 0:
		return

	cursor_stealing = false

	var stop_path := _user_path(CURSOR_STOP_NAME)
	var file := FileAccess.open(stop_path, FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()

	if cursor_steal_pid > 0:
		OS.kill(cursor_steal_pid)
		cursor_steal_pid = -1

	reset_cursor_auto_timer()


# ==================================================
# TAB STEALING (right-click Jeremy)
# ==================================================

func steal_tab() -> void:
	if eating or dragging or dramatic_closing:
		return

	var info := _foreground_browser()
	if info.is_empty():
		return

	var window_position := Vector2(DisplayServer.window_get_position())
	var tab_screen_position := Vector2(
		float(info["left"]) + 140.0,
		float(info["top"]) + 18.0
	)

	if cursor_chasing:
		_stop_cursor_chase()

	eating = true
	speaking = false
	chattering = false
	walking = false
	jump_launch = false
	velocity.x = 0.0
	_play_eat_animation()
	_animate_tab_eaten(tab_screen_position - window_position)

	if dialogue != null and dialogue.has_method("say"):
		dialogue.call("say", "mine now.", 2.0)

	# Let the visual tab reach his mouth before the real tab goes away.
	await get_tree().create_timer(0.45).timeout
	_close_active_tab()
	burst_crumbs()
	_register_eaten_tab()

	await get_tree().create_timer(0.25).timeout
	eating = false

	# Hand the sprite back to the normal state machine.
	if dragging and drag_moved:
		play_animation("flailing")
	elif airborne and jump_launch and velocity.y < 0.0 and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(JUMP_ANIMATION):
		play_animation(JUMP_ANIMATION)
	elif airborne:
		play_animation("falling")
	elif celebrating:
		play_animation("thumbs up!")
	elif grounded:
		play_animation("default")


func _run_powershell_file(file_name: String, script: String) -> Array[String]:
	var path := _write_user_script(file_name, script)
	if path.is_empty():
		return []

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


func _today_string() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]


func _load_tab_count() -> void:
	var config := ConfigFile.new()
	if config.load(_user_path(TAB_COUNT_NAME)) != OK:
		return

	if str(config.get_value("jeremy", "date", "")) == _today_string():
		tabs_eaten = int(config.get_value("jeremy", "eaten", 0))


func _save_tab_count() -> void:
	var config := ConfigFile.new()
	config.set_value("jeremy", "date", _today_string())
	config.set_value("jeremy", "eaten", tabs_eaten)
	config.save(_user_path(TAB_COUNT_NAME))


func _register_eaten_tab() -> void:
	tabs_eaten += 1
	_save_tab_count()

	if behavior_director != null:
		behavior_director.call("adjust_mood", 0.18, "tab")

	if dialogue != null and dialogue.has_method("say_eaten_tab"):
		dialogue.call("say_eaten_tab", tabs_eaten)

	if notepad_manager != null and notepad_manager.has_method("write_note"):
		var notes := [
			"note to self: that tab was delicious.",
			"note to self: tabs are snacks.",
			"note to self: i regret nothing.",
			"note to self: maybe leave one next time.",
			"note to self: the human is doing fine.",
			"note to self: i am doing better."
		]
		notepad_manager.call("write_note", notes.pick_random())


func _play_eat_animation() -> void:
	# The optional "eating" animation is used when present. The current sheet
	# has no such frame, so "talkin" covers the mouth opening.
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
		PixelUIScript.apply(label, 10, true)
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
