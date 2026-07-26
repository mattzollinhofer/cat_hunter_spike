extends Node
## Runs the hunt: spawns prey, counts catches toward the level task, tracks lives.
## Emits signals so the HUD can display progress without this node knowing about
## the UI.
##
## Goal, lives, and spawn geometry come from the level's prey config (see
## level_loader.gd), passed into setup(). The DEFAULT_* consts below only
## backstop a config missing one of those keys.

signal progress_changed(kills: int, goal: int)
signal lives_changed(lives: int)

const DEFAULT_GOAL := 5
const DEFAULT_LIVES := 6
const DEFAULT_FIRST_SPAWN := Vector3(0, 0.5, -6)
const DEFAULT_SPAWN_RADIUS_MIN := 6.0
const DEFAULT_SPAWN_RADIUS_MAX := 12.0

var kills := 0
var goal := DEFAULT_GOAL
var lives := DEFAULT_LIVES

var _cat: Node3D
var _world: Node3D
var _first := true
var _first_spawn := DEFAULT_FIRST_SPAWN
var _spawn_radius_min := DEFAULT_SPAWN_RADIUS_MIN
var _spawn_radius_max := DEFAULT_SPAWN_RADIUS_MAX

func setup(cat: Node3D, world: Node3D, config: Dictionary) -> void:
	_cat = cat
	_world = world
	goal = config.get("goal", DEFAULT_GOAL)
	lives = config.get("lives", DEFAULT_LIVES)
	_first_spawn = config.get("first_spawn", DEFAULT_FIRST_SPAWN)
	_spawn_radius_min = config.get("spawn_radius_min", DEFAULT_SPAWN_RADIUS_MIN)
	_spawn_radius_max = config.get("spawn_radius_max", DEFAULT_SPAWN_RADIUS_MAX)
	_spawn_prey()
	progress_changed.emit(kills, goal)
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
		return _first_spawn  # first prey ahead of the cat, in view
	var angle := randf() * TAU
	var radius := randf_range(_spawn_radius_min, _spawn_radius_max)
	return Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)

func _on_caught() -> void:
	kills += 1
	progress_changed.emit(kills, goal)
	if kills < goal:
		_spawn_prey()
