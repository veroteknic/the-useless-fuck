class_name PetBehavior
extends RefCounted

# Base contract for future autonomous behaviours. Phase 1 introduces the
# contract and director registration only; existing movement stays in main.gd
# until its behaviour wrappers are migrated in later phases.

enum Status {
	IDLE,
	RUNNING,
	SUCCESS,
	FAILURE,
	CANCELLED
}

var id := ""
var director: Node
var config: Resource

var priority := 0
var cooldown_key := ""
var interruption_policy := "normal"
var timeout := 0.0

var elapsed := 0.0


func _init(p_id: String, p_director: Node) -> void:
	id = p_id
	director = p_director

	if director != null:
		config = director.get("config")


func can_start(_ctx: Dictionary) -> bool:
	return true


func on_enter(_ctx: Dictionary) -> void:
	elapsed = 0.0


func tick(delta: float, _ctx: Dictionary) -> int:
	elapsed += delta

	if timeout > 0.0 and elapsed >= timeout:
		return Status.SUCCESS

	return Status.RUNNING


func on_exit(_reason: String) -> void:
	pass
