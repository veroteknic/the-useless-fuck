class_name PetConfig
extends Resource

# Runtime behaviour controls. The existing inspector exports on main.gd remain
# the tuning source for physics/timing; this resource holds the small set of
# preferences the behaviour director needs to arbitrate requests.

@export var paused := false
@export var mischief_enabled := true
@export var autonomous_activity_enabled := true

@export_range(0.0, 2.0, 0.05) var mischief_intensity := 1.0
@export_range(0.0, 2.0, 0.05) var activity_frequency := 1.0
@export_range(0.0, 2.0, 0.05) var dialogue_frequency := 1.0

@export var allow_cursor_steal := true
@export var allow_cursor_chase := true
@export var allow_tab_eat := true
@export var allow_notes := true

# Personality tendencies. These become selection weights when locomotion and
# mischief are migrated into concrete behaviours.
@export_range(0.0, 2.0, 0.05) var curiosity := 1.0
@export_range(0.0, 2.0, 0.05) var mischievousness := 1.0
@export_range(0.0, 2.0, 0.05) var laziness := 1.0
@export_range(0.0, 2.0, 0.05) var attention_seeking := 1.0
@export_range(0.0, 2.0, 0.05) var stubbornness := 1.0
@export_range(0.0, 2.0, 0.05) var affection := 1.0
@export_range(0.0, 2.0, 0.05) var stupidity := 1.0
