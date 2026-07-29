extends Node
## Headless test: holding run moves the cat about twice as far as a plain walk,
## and stalking still wins over running (sneaking must stay slow). Exits 0/1.

const CatController := preload("res://cat_controller.gd")

const STEPS := 60

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var walked := await _distance_travelled(false, false)
	var ran := await _distance_travelled(true, false)
	var stalked_while_running := await _distance_travelled(true, true)

	if not is_equal_approx(CatController.RUN_SPEED, CatController.WALK_SPEED * 2.0):
		failures.append("run speed %.2f is not double the walk speed %.2f"
			% [CatController.RUN_SPEED, CatController.WALK_SPEED])

	if ran < walked * 1.8:
		failures.append("running (%.2f) is not roughly twice a walk (%.2f)" % [ran, walked])

	# Sneaking beats sprinting: a held run must not speed up a stalk, or the
	# stalk-and-pounce mechanic collapses into a footrace.
	if stalked_while_running >= walked:
		failures.append("stalking while running (%.2f) was not slower than a walk (%.2f)"
			% [stalked_while_running, walked])

	if failures.is_empty():
		print("PASS: running doubles walking speed, and stalking stays slow")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)

## Drives a fresh cat straight forward for STEPS physics frames and reports how
## far it got, so the speeds can be compared without touching the clock.
func _distance_travelled(running: bool, stalking: bool) -> float:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var cat := CharacterBody3D.new()
	cat.set_script(CatController)
	cat.position = Vector3(0, 1, 0)
	add_child(cat)
	await get_tree().physics_frame
	cat.use_force_input = true
	cat.force_input = Vector3(0, 0, -1)
	cat.force_run = running
	cat.force_stalk = stalking
	var start := cat.global_position
	for _i in STEPS:
		await get_tree().physics_frame
	var travelled := start.distance_to(cat.global_position)

	cat.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
	return travelled
