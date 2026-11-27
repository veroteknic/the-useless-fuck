extends PetBehavior

# Phase 2 slice: one continuous behaviour owns autonomous walk/jump/fall.
# It writes the shared pet fields directly so the director, drag, cursor and
# eating systems still observe the same values they always have. main.gd only
# asks the director to tick this behaviour; it no longer runs locomotion.

const JUMP_ANIMATION := "jumping"


func tick(delta: float, ctx: Dictionary) -> int:
	elapsed += delta

	var p = ctx.get("pet")
	if p == null or not is_instance_valid(p):
		return Status.FAILURE

	if director != null and bool(director.call("is_paused")):
		return Status.IDLE

	# main.gd used to sync the active monitor before physics. Keep that here so
	# the director-owned behaviour sees fresh bounds on the first tick too.
	p.call("sync_active_screen")

	# Edge gags keep their own tight loop, exactly as before.
	if _pet_bool(p, "edge_hanging"):
		p.call("update_edge_hang", delta)
		return Status.RUNNING

	if _pet_bool(p, "edge_peeking"):
		p.call("update_edge_peek", delta)
		return Status.RUNNING

	# Once a drag really starts, dragging owns position. A plain press still
	# lets physics run so clicks do not freeze Jeremy mid-fall.
	if _pet_bool(p, "dragging") and _pet_bool(p, "drag_moved"):
		return Status.RUNNING

	_tick_physics(delta, p)
	return Status.RUNNING


func reset_walk_pause_timer() -> void:
	var p := _pet()
	if p == null:
		return

	p.set("walk_pause_timer", _scaled_interval(
		_pet_num(p, "walk_pause_min", 2.0),
		_pet_num(p, "walk_pause_max", 6.0),
		"activity_frequency"
	))


func reset_jump_timer() -> void:
	var p := _pet()
	if p == null:
		return

	p.set("jump_timer", _scaled_interval(
		_pet_num(p, "jump_interval_min", 6.0),
		_pet_num(p, "jump_interval_max", 14.0),
		"activity_frequency"
	))


func can_start_jump() -> bool:
	var p := _pet()
	if p == null:
		return false

	return (
		_pet_bool(p, "grounded")
		and not _pet_bool(p, "dragging")
		and not _pet_bool(p, "eating")
		and not _pet_bool(p, "celebrating")
		and not _pet_bool(p, "speaking")
		and not _pet_bool(p, "chattering")
		and not _pet_bool(p, "edge_hanging")
		and not _pet_bool(p, "edge_peeking")
		and not _pet_bool(p, "cursor_stealing")
		and not _pet_bool(p, "cursor_chasing")
	)


func start_walking() -> void:
	var p := _pet()
	if p == null or not _can_start_walk(p):
		return

	var direction: float = [-1.0, 1.0].pick_random()
	var velocity := _pet_vec(p, "velocity", Vector2.ZERO)
	velocity.x = direction * _pet_num(p, "walk_speed", 75.0)

	p.set("walking", true)
	p.set("walk_direction", direction)
	p.set("walk_timer", randf_range(
		_pet_num(p, "walk_duration_min", 1.5),
		_pet_num(p, "walk_duration_max", 4.0)
	))
	p.set("walk_dust_timer", 0.0)
	p.set("velocity", velocity)

	var sprite = p.get("sprite")
	if sprite != null:
		sprite.flip_h = direction < 0.0


func stop_walking() -> void:
	var p := _pet()
	if p == null:
		return

	var velocity := _pet_vec(p, "velocity", Vector2.ZERO)
	velocity.x = 0.0
	p.set("walking", false)
	p.set("velocity", velocity)
	reset_walk_pause_timer()


func start_jump() -> void:
	var p := _pet()
	if p == null or not can_start_jump():
		return

	var velocity := _pet_vec(p, "velocity", Vector2.ZERO)
	var direction: float = [-1.0, 1.0].pick_random()
	velocity.x = direction * randf_range(
		_pet_num(p, "jump_horizontal_min", 90.0),
		_pet_num(p, "jump_horizontal_max", 180.0)
	)
	velocity.y = -randf_range(
		_pet_num(p, "jump_speed_min", 980.0),
		_pet_num(p, "jump_speed_max", 1150.0)
	)

	p.set("walking", false)
	p.set("grounded", false)
	p.set("airborne", true)
	p.set("self_jump", true)
	p.set("jump_launch", true)
	p.set("velocity", velocity)

	var sprite = p.get("sprite")
	if sprite != null:
		sprite.flip_h = velocity.x < 0.0

	p.call("burst_dust", "bottom")
	reset_jump_timer()
	reset_walk_pause_timer()


func _tick_physics(delta: float, p) -> void:
	if _pet_bool(p, "grounded"):
		var grounded_position := _pet_vec(p, "desktop_position", Vector2.ZERO)
		var grounded_max := _pet_vec(p, "desktop_max", Vector2.ZERO)
		var grounded_velocity := _pet_vec(p, "velocity", Vector2.ZERO)
		grounded_position.y = grounded_max.y
		grounded_velocity.y = 0.0
		_apply(p, grounded_position, grounded_velocity)
		_tick_ground_movement(delta, p)
		p.set("airborne", false)
		return

	p.set("airborne", true)

	var gravity := _pet_num(p, "gravity", 1600.0)
	var bounce := _pet_num(p, "bounce", 0.55)
	var settling_threshold := _pet_num(p, "settling_threshold", 60.0)
	var landing_threshold := _pet_num(p, "landing_threshold", 450.0)

	var position := _pet_vec(p, "desktop_position", Vector2.ZERO)
	var velocity := _pet_vec(p, "velocity", Vector2.ZERO)
	velocity.y += gravity * delta
	position += velocity * delta
	_apply(p, position, velocity)
	p.call("sync_active_screen")

	position = _pet_vec(p, "desktop_position", Vector2.ZERO)
	velocity = _pet_vec(p, "velocity", Vector2.ZERO)
	var screen_min := _pet_vec(p, "desktop_min", Vector2.ZERO)
	var screen_max := _pet_vec(p, "desktop_max", Vector2.ZERO)

	# Left wall.
	if position.x < screen_min.x:
		var left_impact_speed := absf(velocity.x)
		position.x = screen_min.x
		velocity.x = absf(velocity.x) * bounce
		_apply(p, position, velocity)
		if left_impact_speed > settling_threshold:
			p.call("burst_dust", "left")
			if bool(p.call("maybe_start_wall_behavior", "left", left_impact_speed)):
				return
		velocity = _pet_vec(p, "velocity", Vector2.ZERO)
		position = _pet_vec(p, "desktop_position", Vector2.ZERO)

	# Right wall.
	if position.x > screen_max.x:
		var right_impact_speed := absf(velocity.x)
		position.x = screen_max.x
		velocity.x = -absf(velocity.x) * bounce
		_apply(p, position, velocity)
		if right_impact_speed > settling_threshold:
			p.call("burst_dust", "right")
			if bool(p.call("maybe_start_wall_behavior", "right", right_impact_speed)):
				return
		velocity = _pet_vec(p, "velocity", Vector2.ZERO)
		position = _pet_vec(p, "desktop_position", Vector2.ZERO)

	# Ceiling.
	if position.y < screen_min.y:
		var ceiling_impact_speed := absf(velocity.y)
		position.y = screen_min.y
		velocity.y = absf(velocity.y) * bounce
		_apply(p, position, velocity)
		if ceiling_impact_speed > settling_threshold:
			p.call("burst_dust", "top")
			if bool(p.call("maybe_start_ceiling_peek", ceiling_impact_speed)):
				return
		velocity = _pet_vec(p, "velocity", Vector2.ZERO)
		position = _pet_vec(p, "desktop_position", Vector2.ZERO)

	# Floor.
	if position.y >= screen_max.y:
		var impact_speed := maxf(velocity.y, 0.0)
		position.y = screen_max.y
		p.set("jump_launch", false)
		_apply(p, position, velocity)

		if impact_speed > settling_threshold:
			p.call("burst_dust", "bottom")

		if _pet_bool(p, "squash_stretch_enabled"):
			p.set("squash", maxf(
				_pet_num(p, "squash", 0.0),
				clampf(
					impact_speed / maxf(landing_threshold, 1.0),
					0.0,
					1.0
				) * _pet_num(p, "squash_strength", 0.22)
			))

		if impact_speed >= landing_threshold and not _pet_bool(p, "self_jump"):
			# The hard impact is remembered, but the celebration only fires
			# once the bouncing fall finally settles on the floor.
			p.call("start_celebration")

		if impact_speed <= settling_threshold:
			velocity.y = 0.0
			p.set("velocity", velocity)
			p.set("grounded", true)
			p.set("airborne", false)
			p.set("walking", false)
			p.set("self_jump", false)
			reset_walk_pause_timer()
			reset_jump_timer()

			var sprite = p.get("sprite")
			if (
				_pet_bool(p, "celebrating")
				and sprite != null
				and sprite.animation != "thumbs up!"
			):
				p.call("speak", "say_random_landing")
				p.call("play_animation", "thumbs up!")
		else:
			velocity.y = -impact_speed * bounce
			p.set("velocity", velocity)
			p.set("grounded", false)
			p.set("airborne", true)


func _tick_ground_movement(delta: float, p) -> void:
	if _pet_bool(p, "cursor_chasing"):
		p.call("update_cursor_chase", delta)
		return

	var jump_timer := _pet_num(p, "jump_timer", 0.0) - delta
	p.set("jump_timer", jump_timer)

	if jump_timer <= 0.0:
		if can_start_jump():
			start_jump()
			return
		reset_jump_timer()

	var position := _pet_vec(p, "desktop_position", Vector2.ZERO)
	var velocity := _pet_vec(p, "velocity", Vector2.ZERO)
	var screen_min := _pet_vec(p, "desktop_min", Vector2.ZERO)
	var screen_max := _pet_vec(p, "desktop_max", Vector2.ZERO)

	if _pet_bool(p, "walking"):
		var direction := _pet_num(p, "walk_direction", 1.0)
		velocity.x = direction * _pet_num(p, "walk_speed", 75.0)
		position.x += velocity.x * delta
		_apply(p, position, velocity)
		p.call("sync_active_screen")

		position = _pet_vec(p, "desktop_position", Vector2.ZERO)
		velocity = _pet_vec(p, "velocity", Vector2.ZERO)

		# Turn around instead of walking off the desktop.
		if position.x <= screen_min.x:
			position.x = screen_min.x
			_apply(p, position, velocity)
			direction = 1.0
			p.set("walk_direction", direction)
		elif position.x >= screen_max.x:
			position.x = screen_max.x
			_apply(p, position, velocity)
			direction = -1.0
			p.set("walk_direction", direction)

		var sprite = p.get("sprite")
		if sprite != null:
			sprite.flip_h = direction < 0.0

		var dust_timer := _pet_num(p, "walk_dust_timer", 0.0) - delta
		if dust_timer <= 0.0:
			p.call("burst_dust", "bottom")
			dust_timer = 0.6
		p.set("walk_dust_timer", dust_timer)

		var walk_timer := _pet_num(p, "walk_timer", 0.0) - delta
		p.set("walk_timer", walk_timer)
		if walk_timer <= 0.0:
			stop_walking()
		return

	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)

	if absf(velocity.x) < 1.0:
		velocity.x = 0.0

	position.x += velocity.x * delta
	_apply(p, position, velocity)
	p.call("sync_active_screen")

	position = _pet_vec(p, "desktop_position", Vector2.ZERO)
	velocity = _pet_vec(p, "velocity", Vector2.ZERO)

	# Landed slides still need to respect the screen edges.
	if position.x < screen_min.x:
		position.x = screen_min.x
		velocity.x = 0.0
		_apply(p, position, velocity)
	elif position.x > screen_max.x:
		position.x = screen_max.x
		velocity.x = 0.0
		_apply(p, position, velocity)

	var pause_timer := _pet_num(p, "walk_pause_timer", 0.0) - delta
	p.set("walk_pause_timer", pause_timer)
	if pause_timer <= 0.0 and not _pet_bool(p, "dragging") and not _pet_bool(p, "eating"):
		start_walking()


func _can_start_walk(p) -> bool:
	return (
		_pet_bool(p, "grounded")
		and not _pet_bool(p, "dragging")
		and not _pet_bool(p, "eating")
		and not _pet_bool(p, "celebrating")
		and not _pet_bool(p, "speaking")
		and not _pet_bool(p, "chattering")
		and not _pet_bool(p, "edge_hanging")
		and not _pet_bool(p, "edge_peeking")
		and not _pet_bool(p, "cursor_stealing")
		and not _pet_bool(p, "cursor_chasing")
	)


func _apply(p, position: Vector2, velocity: Vector2) -> void:
	p.set("desktop_position", position)
	p.set("velocity", velocity)


func _pet() -> Object:
	if director == null:
		return null

	var p = director.get("pet")
	if p == null or not is_instance_valid(p):
		return null
	return p as Object


func _pet_bool(p, key: String, fallback: bool = false) -> bool:
	var value = p.get(key)
	return fallback if value == null else bool(value)


func _pet_num(p, key: String, fallback: float) -> float:
	var value = p.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _pet_vec(p, key: String, fallback: Vector2) -> Vector2:
	var value = p.get(key)
	if value is Vector2:
		return value as Vector2
	return fallback


func _config_number(key: String, fallback: float) -> float:
	if config == null:
		return fallback

	var value = config.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _scaled_interval(
	min_value: float,
	max_value: float,
	frequency_key: String,
	use_mischief: bool = false
) -> float:
	var frequency := _config_number(frequency_key, 1.0)

	if frequency <= 0.0:
		return 1.0e9

	if use_mischief:
		var intensity := _config_number("mischief_intensity", 1.0)
		if intensity <= 0.0:
			return 1.0e9
		frequency *= minf(intensity, 2.0)

	return randf_range(min_value, max_value) / maxf(frequency, 0.05)
