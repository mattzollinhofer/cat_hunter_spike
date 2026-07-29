extends Node3D
## Headless test: the bull's headbutt costs the fox one health, and emptying all
## four health costs the fox one life and refills the health. Exits 0/1.
##
## A Node3D root because hunt.setup() spawns prey into the world it is handed.

const Boss := preload("res://boss.gd")
const Hunt := preload("res://hunt.gd")

const START_LIVES := 6
const FRAME_CAP := 4000  # plenty of frames for one headbutt cadence to come round

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await _test_health_and_lives_rules())
	failures.append_array(await _test_bull_headbutt_costs_health())

	if failures.is_empty():
		print("PASS: a bull headbutt costs the fox health, and empty health costs a life")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)

func _test_health_and_lives_rules() -> Array[String]:
	var failures: Array[String] = []
	var hunt := await _make_hunt()

	var reported_health: Array[int] = []
	hunt.health_changed.connect(func(health: int) -> void: reported_health.append(health))
	var reported_lives: Array[int] = []
	hunt.lives_changed.connect(func(lives: int) -> void: reported_lives.append(lives))

	hunt.take_damage()
	if hunt.health != Hunt.HEALTH_PER_LIFE - 1:
		failures.append("one hit should cost one health, health is %d" % hunt.health)
	if hunt.lives != START_LIVES:
		failures.append("one hit should not cost a life, lives is %d" % hunt.lives)
	if reported_health != [Hunt.HEALTH_PER_LIFE - 1]:
		failures.append("health change was not reported once, got %s" % [reported_health])

	# Emptying the last health costs a life, and the health refills for that life.
	for _i in Hunt.HEALTH_PER_LIFE - 1:
		hunt.take_damage()
	if hunt.lives != START_LIVES - 1:
		failures.append("empty health should cost one life, lives is %d" % hunt.lives)
	if hunt.health != Hunt.HEALTH_PER_LIFE:
		failures.append("health should refill after losing a life, health is %d" % hunt.health)
	if reported_lives != [START_LIVES - 1]:
		failures.append("life change was not reported once, got %s" % [reported_lives])

	hunt.queue_free()
	await get_tree().process_frame
	return failures

func _test_bull_headbutt_costs_health() -> Array[String]:
	var failures: Array[String] = []
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	cat.position = Vector3(0, 1, 0)
	add_child(cat)

	var boss := Boss.new()
	add_child(boss)
	boss.setup(Color(0.5, 0.1, 0.1), 0.75)
	boss.global_position = Vector3(0, 0, -1.5)  # already nose to nose with the fox
	boss.activate()

	# Counted into an array, not an int: a GDScript lambda captures a local number
	# by value, so `hits += 1` inside one would never reach this scope.
	var hits: Array[int] = []
	boss.hit_cat.connect(func() -> void: hits.append(1))
	for _i in FRAME_CAP:
		if not hits.is_empty():
			break
		await get_tree().process_frame
	if hits.is_empty():
		failures.append("a bull standing on the fox never landed a headbutt")

	# A defeated bull stops hitting; the fight is over.
	while not boss.is_defeated():
		boss.hit()
	hits.clear()
	for _i in FRAME_CAP:
		await get_tree().process_frame
		if not hits.is_empty():
			break
	if not hits.is_empty():
		failures.append("a beaten bull kept headbutting the fox")

	boss.queue_free()
	cat.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
	return failures

## A hunt wired to a bare cat, so the fox's health and lives rules can be
## exercised without the rest of the game.
func _make_hunt() -> Node:
	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	add_child(cat)
	var hunt := Hunt.new()
	add_child(hunt)
	hunt.setup(cat, self, {"goal": 5, "lives": START_LIVES})
	await get_tree().process_frame
	return hunt
