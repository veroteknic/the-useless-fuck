extends Node

const PetConfigScript = preload("res://pet_config.gd")
const PetBehaviorScript = preload("res://pet_behavior.gd")

const HISTORY_LIMIT := 24
const MOOD_FILE := "jeremy_mood.cfg"

const COOLDOWNS := {
	"steal_cursor": 1.0,
	"start_cursor_chase": 2.0,
	"steal_tab": 3.0,
	"write_note": 2.0,
	"speak": 0.4,
	"stubborn_flail": 8.0,
	"show_popin": 18.0
}

var pet: Node
var config
var behaviors := {}

var cooldowns := {}
var active_state := "idle"
var previous_state := ""
var history: Array[Dictionary] = []

var mood := 0.0


func _init(p_pet: Node) -> void:
	pet = p_pet
	config = PetConfigScript.new()

	for key in COOLDOWNS.keys():
		cooldowns[key] = 0.0


func _ready() -> void:
	_load_mood()
	active_state = get_state()
	previous_state = active_state


func tick(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)

	mood = move_toward(mood, 0.0, 0.02 * delta)

	var next_state := get_state()
	if next_state != active_state:
		previous_state = active_state
		active_state = next_state
		_record_history("state:" + next_state)


func request_behavior(action: String, args: Array = []) -> bool:
	if pet == null or not is_instance_valid(pet):
		return false

	if bool(config.get("paused")):
		return false

	if not is_action_allowed(action):
		return false

	if float(cooldowns.get(action, 0.0)) > 0.0:
		return false

	var dispatched := _dispatch(action, args)
	if not dispatched:
		return false

	if COOLDOWNS.has(action):
		cooldowns[action] = float(COOLDOWNS[action])

	_record_history("request:" + action, {"args": args.size()})
	return dispatched


func adjust_mood(amount: float, reason: String = "") -> void:
	mood = clampf(mood + amount, -1.0, 1.0)

	var event := "mood"
	if not reason.is_empty():
		event += ":" + reason

	_record_history(event, {"amount": amount})
	_save_mood()


func get_mood_label() -> String:
	if mood <= -0.55:
		return "annoyed"
	if mood <= -0.2:
		return "grumpy"
	if mood < 0.2:
		return "meh"
	if mood < 0.55:
		return "curious"
	return "pleased"


func is_paused() -> bool:
	return bool(config.get("paused"))


func set_config_value(key: String, value: Variant) -> bool:
	if config == null:
		return false

	config.set(key, value)
	return true


func roll_stubborn_flail() -> bool:
	if not is_action_allowed("stubborn_flail"):
		return false

	if float(cooldowns.get("stubborn_flail", 0.0)) > 0.0:
		return false

	var chance := 0.18 * float(config.get("stubbornness"))
	chance *= clampf(float(config.get("mischief_intensity")), 0.0, 2.0)

	if mood <= -0.2:
		chance *= 1.6
	elif mood >= 0.55:
		chance *= 0.6

	chance = clampf(chance, 0.0, 0.75)
	cooldowns["stubborn_flail"] = float(COOLDOWNS["stubborn_flail"])
	_record_history("roll:stubborn_flail", {"chance": chance})
	return randf() < chance


func is_action_allowed(action: String) -> bool:
	var mischief := bool(config.get("mischief_enabled"))

	match action:
		"steal_cursor":
			return mischief and bool(config.get("allow_cursor_steal"))
		"start_cursor_chase":
			return mischief and bool(config.get("allow_cursor_chase"))
		"steal_tab":
			return mischief and bool(config.get("allow_tab_eat"))
		"write_note":
			return mischief and bool(config.get("allow_notes"))
		"stubborn_flail":
			return mischief and bool(config.get("allow_drag_resist"))
		"show_popin":
			return bool(config.get("allow_popins"))
		"note_reaction":
			return bool(config.get("allow_note_reactions"))
		"custom_content":
			return bool(config.get("allow_custom_content"))
		"speak":
			return true
		_:
			return false


func register_behavior(behavior) -> void:
	if behavior == null:
		return

	behavior.director = self
	behavior.config = config
	behaviors[str(behavior.id)] = behavior


func create_behavior(id: String):
	var behavior = PetBehaviorScript.new(id, self)
	register_behavior(behavior)
	return behavior


func get_state() -> String:
	if pet == null or not is_instance_valid(pet):
		return "gone"

	if _flag("dragging"):
		return "dragged" if _flag("drag_moved") else "pressed"
	if _flag("eating"):
		return "eating tab"
	if _flag("cursor_stealing"):
		return "cursor steal"
	if _flag("cursor_chasing"):
		return "cursor chase"
	if _flag("edge_hanging"):
		return "wall hang"
	if _flag("edge_peeking"):
		return "ceiling peek"
	if _flag("celebrating"):
		return "celebrating"
	if _flag("speaking"):
		return "talking"
	if _flag("airborne"):
		return "airborne"
	if _flag("walking"):
		return "walking"
	return "idle"


func get_config_snapshot() -> Dictionary:
	if config == null:
		return {}

	return {
		"paused": bool(config.get("paused")),
		"mischief_enabled": bool(config.get("mischief_enabled")),
		"mischief_intensity": float(config.get("mischief_intensity")),
		"activity_frequency": float(config.get("activity_frequency")),
		"dialogue_frequency": float(config.get("dialogue_frequency")),
		"allow_cursor_steal": bool(config.get("allow_cursor_steal")),
		"allow_cursor_chase": bool(config.get("allow_cursor_chase")),
		"allow_tab_eat": bool(config.get("allow_tab_eat")),
		"allow_notes": bool(config.get("allow_notes")),
		"allow_drag_resist": bool(config.get("allow_drag_resist")),
		"allow_note_reactions": bool(config.get("allow_note_reactions")),
		"allow_popins": bool(config.get("allow_popins")),
		"allow_custom_content": bool(config.get("allow_custom_content")),
		"custom_content_chance": float(config.get("custom_content_chance"))
	}


func get_status() -> Dictionary:
	if pet == null or not is_instance_valid(pet):
		return {"state": "gone", "active_behavior": "gone"}

	return {
		"state": get_state(),
		"active_behavior": active_state,
		"previous_behavior": previous_state,
		"grounded": _flag("grounded"),
		"airborne": _flag("airborne"),
		"walking": _flag("walking"),
		"dragging": _flag("dragging"),
		"cursor_chasing": _flag("cursor_chasing"),
		"cursor_stealing": _flag("cursor_stealing"),
		"eating": _flag("eating"),
		"tabs_eaten": int(_pet_value("tabs_eaten", 0)),
		"velocity": _pet_value("velocity", Vector2.ZERO),
		"position": _pet_value("desktop_position", Vector2.ZERO),
		"jump_timer": float(_pet_value("jump_timer", 0.0)),
		"walk_timer": float(_pet_value("walk_timer", 0.0)),
		"chatter_timer": float(_pet_value("chatter_timer", 0.0)),
		"chase_cooldown": float(_pet_value("cursor_chase_cooldown", 0.0)),
		"notepads": _pet_value("notepad_manager", null) != null,
		"paused": bool(config.get("paused")),
		"mischief": bool(config.get("mischief_enabled")),
		"mood": mood,
		"mood_label": get_mood_label(),
		"recent": get_recent_history(3)
	}


func get_recent_history(limit: int = 5) -> Array[String]:
	var result: Array[String] = []

	var start := maxi(0, history.size() - maxi(limit, 0))
	for i in range(history.size() - 1, start - 1, -1):
		result.append(str((history[i] as Dictionary).get("event", "?")))

	return result


func _dispatch(action: String, args: Array) -> bool:
	match action:
		"steal_cursor", "start_cursor_chase", "steal_tab":
			return _call_pet(action, [])
		"stubborn_flail", "show_popin":
			return _call_pet(action, [])
		"speak":
			if args.is_empty():
				return false
			return _call_pet("speak", [str(args[0])])
		"write_note":
			return _write_note(args)
		_:
			return false


func _call_pet(method: String, args: Array) -> bool:
	if pet == null or not is_instance_valid(pet):
		return false

	if not pet.has_method(method):
		return false

	var result = pet.callv(method, args)
	if result is bool:
		return result
	return true


func _write_note(args: Array) -> bool:
	if pet == null or not is_instance_valid(pet):
		return false

	var manager = pet.get("notepad_manager")
	if manager == null or not is_instance_valid(manager):
		return false

	if not manager.has_method("write_note"):
		return false

	if args.is_empty():
		manager.call("write_note")
	else:
		manager.call("write_note", str(args[0]))

	return true


func _mood_path() -> String:
	return ProjectSettings.globalize_path("user://" + MOOD_FILE)


func _save_mood() -> void:
	var file := ConfigFile.new()
	file.set_value("mood", "value", mood)

	var error := file.save(_mood_path())
	if error != OK:
		push_warning("jeremy could not save mood: " + str(error))


func _load_mood() -> void:
	var file := ConfigFile.new()
	var error := file.load(_mood_path())

	if error != OK:
		return

	var value: Variant = file.get_value("mood", "value", 0.0)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		mood = clampf(float(value), -1.0, 1.0)


func _flag(key: String) -> bool:
	return bool(_pet_value(key, false))


func _pet_value(key: String, fallback: Variant) -> Variant:
	if pet == null or not is_instance_valid(pet):
		return fallback

	var value: Variant = pet.get(key)
	return fallback if value == null else value


func _record_history(event: String, data: Dictionary = {}) -> void:
	history.append({
		"event": event,
		"time": Time.get_ticks_msec(),
		"data": data.duplicate(true)
	})

	if history.size() > HISTORY_LIMIT:
		history.remove_at(0)
