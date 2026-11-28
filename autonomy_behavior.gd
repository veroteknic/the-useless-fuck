extends PetBehavior

# Phase 3 slice: one director-ticked behaviour owns autonomous timing and
# weighted choice. main.gd still supplies the concrete actions; this behaviour
# only decides when to ask the director for them. Timers live on shared pet
# fields so the existing menu/readout keeps working without a second clock.

const DIALOGUE_METHODS := [
	"say_contextual",
	"say_random_custom",
	"say_random_idle"
]


func tick(delta: float, ctx: Dictionary) -> int:
	elapsed += delta

	var p = ctx.get("pet")
	if p == null or not is_instance_valid(p):
		return Status.FAILURE

	if director != null and bool(director.call("is_paused")):
		return Status.IDLE

	var settled := _is_settled(p)
	if settled:
		_set_num(p, "idle_time", _pet_num(p, "idle_time", 0.0) + delta)
	else:
		_set_num(p, "idle_time", 0.0)

	_tick_chatter(delta, p)
	_tick_cursor(delta, p)
	_tick_mischief(delta, p)
	return Status.RUNNING


func reset_chatter_timer() -> void:
	var p := _pet()
	if p == null:
		return

	var frequency := _config_number("dialogue_frequency", 1.0)
	if frequency <= 0.0:
		_set_num(p, "chatter_timer", 1.0e9)
		return

	_set_num(p, "chatter_timer", randf_range(
		_pet_num(p, "chatter_interval_min", 7.0),
		_pet_num(p, "chatter_interval_max", 16.0)
	) / maxf(frequency, 0.05))


func reset_cursor_auto_timer() -> void:
	var p := _pet()
	if p == null:
		return

	_set_num(p, "cursor_auto_timer", _scaled_interval(
		_pet_num(p, "cursor_steal_auto_min", 28.0),
		_pet_num(p, "cursor_steal_auto_max", 55.0),
		true
	))


func reset_cursor_chase_cooldown() -> void:
	var p := _pet()
	if p == null:
		return

	_set_num(p, "cursor_chase_cooldown", _scaled_interval(
		_pet_num(p, "cursor_chase_cooldown_min", 22.0),
		_pet_num(p, "cursor_chase_cooldown_max", 40.0),
		true
	))


func reset_mischief_timer() -> void:
	var p := _pet()
	if p == null:
		return

	var frequency := _config_number("activity_frequency", 1.0)
	var intensity := _config_number("mischief_intensity", 1.0)

	if frequency <= 0.0 or intensity <= 0.0:
		_set_num(p, "mischief_timer", 1.0e9)
		return

	var rate := clampf(frequency * minf(intensity, 2.0), 0.05, 4.0)
	_set_num(p, "mischief_timer", randf_range(9.0, 20.0) / rate)


func _tick_chatter(delta: float, p) -> void:
	if (
		_pet_bool(p, "speaking")
		or _pet_bool(p, "chattering")
		or _pet_bool(p, "dragging")
		or _pet_bool(p, "eating")
	):
		return

	var timer := _pet_num(p, "chatter_timer", 0.0) - delta
	_set_num(p, "chatter_timer", timer)

	if timer > 0.0:
		return

	reset_chatter_timer()

	var weights := {}
	if _available("speak"):
		weights["say_contextual"] = 0.45 * _config_number("curiosity", 1.0)
		weights["say_random_idle"] = 0.65 * _config_number("affection", 1.0)

		if bool(director.call("is_action_allowed", "custom_content")):
			weights["say_random_custom"] = (
				0.14 * _config_number("custom_content_chance", 0.35) * 3.0
			)
	if _available("show_popin"):
		weights["show_popin"] = (
			0.10 * _config_number("affection", 1.0)
			* _config_number("mischief_intensity", 1.0)
		)

	var choice := _weighted_pick(_apply_repeat_factor(weights))
	if choice.is_empty():
		return

	_set_str(p, "last_autonomous_action", choice)

	if choice == "show_popin":
		director.call("request_behavior", "show_popin", [])
		return

	_set_bool(p, "chattering", true)

	if not bool(director.call("request_behavior", "speak", [choice])):
		_set_bool(p, "chattering", false)


func _tick_cursor(delta: float, p) -> void:
	if (
		_pet_bool(p, "cursor_stealing")
		or _pet_bool(p, "cursor_chasing")
		or _pet_bool(p, "dragging")
		or _pet_bool(p, "eating")
	):
		return

	if (
		not _config_bool("autonomous_activity_enabled", true)
		or not _pet_bool(p, "cursor_steal_auto_enabled", true)
		or not _available("steal_cursor")
		or not _available("start_cursor_chase")
	):
		return

	var auto_timer := _pet_num(p, "cursor_auto_timer", 0.0) - delta
	var chase_timer := _pet_num(p, "cursor_chase_cooldown", 0.0) - delta
	_set_num(p, "cursor_auto_timer", auto_timer)
	_set_num(p, "cursor_chase_cooldown", chase_timer)

	if not bool(p.call("can_start_jump")) or _pet_bool(p, "walking"):
		return

	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	var horizontal_distance := absf(mouse_position.x - _pet_vec(p, "desktop_position").x)

	# Stealing is the bolder move: it waits for a worked-up Jeremy and real
	# hitbox contact, exactly like the old automatic timer did.
	if (
		auto_timer <= 0.0
		and _effective_mood() >= 0.2
		and bool(p.call("mouse_touches_pet"))
	):
		if bool(director.call("request_behavior", "steal_cursor", [])):
			_set_str(p, "last_autonomous_action", "steal_cursor")
			reset_cursor_auto_timer()
			reset_cursor_chase_cooldown()
		return

	if (
		chase_timer <= 0.0
		and horizontal_distance <= _pet_num(p, "cursor_chase_radius", 360.0)
	):
		if bool(director.call("request_behavior", "start_cursor_chase", [])):
			_set_str(p, "last_autonomous_action", "start_cursor_chase")
			reset_cursor_chase_cooldown()


func _tick_mischief(delta: float, p) -> void:
	var timer := _pet_num(p, "mischief_timer", 0.0) - delta
	_set_num(p, "mischief_timer", timer)

	if timer > 0.0:
		return

	reset_mischief_timer()

	if not _config_bool("autonomous_activity_enabled", true):
		return

	if (
		_pet_bool(p, "dragging")
		or _pet_bool(p, "eating")
		or _pet_bool(p, "dramatic_closing")
		or _pet_bool(p, "cursor_stealing")
		or _pet_bool(p, "cursor_chasing")
		or _pet_bool(p, "edge_hanging")
		or _pet_bool(p, "edge_peeking")
	):
		return

	var choice := _weighted_pick(get_weights_snapshot())
	if choice.is_empty():
		return

	_set_str(p, "last_autonomous_action", choice)
	director.call("request_behavior", choice, [])


func get_weights_snapshot() -> Dictionary:
	var p := _pet()
	if p == null:
		return {}

	var mood_value := _effective_mood()
	var intensity := clampf(_config_number("mischief_intensity", 1.0), 0.0, 2.0)
	var idle_bonus := 1.0 + clampf(_pet_num(p, "idle_time", 0.0) / 90.0, 0.0, 0.75)

	var weights := {}
	weights["write_note"] = (
		0.85
		* _config_number("attention_seeking", 1.0)
		* (0.7 + 0.3 * _config_number("curiosity", 1.0))
		* intensity
		* idle_bonus
	)
	weights["show_popin"] = (
		0.30
		* _config_number("affection", 1.0)
		* intensity
	)
	weights["steal_tab"] = (
		0.55
		* _config_number("mischievousness", 1.0)
		* intensity
		* idle_bonus
		* (1.0 + clampf(mood_value - 0.2, 0.0, 0.8))
	)
	weights["dramatic_close"] = (
		0.24
		* _config_number("mischievousness", 1.0)
		* _config_number("stupidity", 1.0)
		* intensity
		* idle_bonus
		* (1.0 + clampf(mood_value - 0.55, 0.0, 0.5) * 2.0)
	)

	if mood_value < 0.2:
		weights.erase("steal_tab")
	if mood_value < 0.55 or _pet_num(p, "idle_time", 0.0) < 8.0:
		weights.erase("dramatic_close")

	for key in weights.keys():
		if not _available(str(key)):
			weights.erase(key)

	return _apply_repeat_factor(weights)


func _available(action: String) -> bool:
	if director == null:
		return false

	if not bool(director.call("is_action_allowed", action)):
		return false

	return float(director.call("get_cooldown", action)) <= 0.0


func _apply_repeat_factor(weights: Dictionary) -> Dictionary:
	var recent := director.call("get_recent_history", 7) as Array[String]
	var adjusted := {}

	for key in weights.keys():
		var action := str(key)
		var weight := maxf(0.0, float(weights[key]))

		if _pet_str(_pet(), "last_autonomous_action", "") == action:
			weight *= 0.35

		var event := "request:" + action
		for item in recent:
			if str(item) == event:
				weight *= 0.35
				break

		adjusted[action] = weight

	return adjusted


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0

	for key in weights.keys():
		total += maxf(0.0, float(weights[key]))

	if total <= 0.0:
		return ""

	var roll := randf() * total

	for key in weights.keys():
		roll -= maxf(0.0, float(weights[key]))
		if roll <= 0.0:
			return str(key)

	return ""


func _is_settled(p) -> bool:
	return (
		_pet_bool(p, "grounded")
		and not _pet_bool(p, "dragging")
		and not _pet_bool(p, "eating")
		and not _pet_bool(p, "dramatic_closing")
		and not _pet_bool(p, "celebrating")
		and not _pet_bool(p, "speaking")
		and not _pet_bool(p, "chattering")
		and not _pet_bool(p, "edge_hanging")
		and not _pet_bool(p, "edge_peeking")
		and not _pet_bool(p, "cursor_stealing")
		and not _pet_bool(p, "cursor_chasing")
	)


func _effective_mood() -> float:
	var mood := 0.0
	if director != null:
		mood = clampf(float(director.get("mood")), -1.0, 1.0)

	# Long idle stretches raise the effective rambunctiousness without changing
	# the persisted mood value.
	return mood + clampf(_pet_num(_pet(), "idle_time", 0.0) / 120.0, 0.0, 0.15)


func _scaled_interval(min_value: float, max_value: float, use_mischief: bool) -> float:
	var frequency := _config_number("activity_frequency", 1.0)
	if frequency <= 0.0:
		return 1.0e9

	if use_mischief:
		var intensity := _config_number("mischief_intensity", 1.0)
		if intensity <= 0.0:
			return 1.0e9
		frequency *= minf(intensity, 2.0)

	return randf_range(min_value, max_value) / maxf(frequency, 0.05)


func _pet() -> Object:
	if director == null:
		return null

	var p = director.get("pet")
	if p == null or not is_instance_valid(p):
		return null
	return p as Object


func _pet_bool(p, key: String, fallback: bool = false) -> bool:
	if p == null:
		return fallback
	var value = p.get(key)
	return fallback if value == null else bool(value)


func _pet_num(p, key: String, fallback: float = 0.0) -> float:
	if p == null:
		return fallback
	var value = p.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _pet_vec(p, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if p == null:
		return fallback
	var value = p.get(key)
	return value if value is Vector2 else fallback


func _pet_str(p, key: String, fallback: String = "") -> String:
	if p == null:
		return fallback
	var value = p.get(key)
	return fallback if value == null else str(value)


func _set_num(p, key: String, value: float) -> void:
	if p != null:
		p.set(key, value)


func _set_bool(p, key: String, value: bool) -> void:
	if p != null:
		p.set(key, value)


func _set_str(p, key: String, value: String) -> void:
	if p != null:
		p.set(key, value)


func _config_number(key: String, fallback: float) -> float:
	if config == null:
		return fallback
	var value = config.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _config_bool(key: String, fallback: bool) -> bool:
	if config == null:
		return fallback
	var value = config.get(key)
	return fallback if value == null else bool(value)
