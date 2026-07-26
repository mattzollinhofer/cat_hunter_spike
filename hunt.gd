extends Node
## Runs the hunt: spawns prey, counts catches toward the level task, tracks lives.
## Emits signals so the HUD can display progress without this node knowing about
## the UI.

signal progress_changed(kills: int, goal: int)
signal lives_changed(lives: int)

const GOAL := 5
const START_LIVES := 6

var kills := 0
var lives := START_LIVES

var _cat: Node3D
var _world: Node3D
var _first := true

func setup(cat: Node3D, world: Node3D) -> void:
	_cat = cat
	_world = world
	_spawn_prey()
	progress_changed.emit(kills, GOAL)
	lives_changed.emit(lives)

func _spawn_prey() -> void:
	var prey := CharacterBody3D.new()
	prey.set_script(load("res://prey.gd"))
	prey.target = _cat
	prey.position = _spawn_point()
	prey.caught.connect(_on_caught)
	_world.add_child(prey)

func _spawn_point() -> Vector3:
	if _first:
		_first = false
		return Vector3(0, 0.5, -6)  # first prey ahead of the cat, in view
	var angle := randf() * TAU
	var radius := randf_range(6.0, 12.0)
	return Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)

func _on_caught() -> void:
	kills += 1
	progress_changed.emit(kills, GOAL)
	if kills < GOAL:
		_spawn_prey()
