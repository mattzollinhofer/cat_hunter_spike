extends Node
## Headless test: an invisible world-boundary wall (collision layer 1) stops the
## cat from crossing it, so the cat can't leave the territory. Exits 0/1.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# A floor so the cat stays at ground level (else gravity drops it below the wall).
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# An invisible boundary wall on the world layer at x = +6, like main.gd builds.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(6, 4, 0)
	var wall_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 8, 20)
	wall_col.shape = box
	wall.add_child(wall_col)
	add_child(wall)

	# A cat that walks straight into the wall.
	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	cat.position = Vector3(0, 1, 0)
	add_child(cat)
	await get_tree().physics_frame
	cat.use_force_input = true
	cat.force_input = Vector3(1, 0, 0)  # walk toward +X, into the wall at x=6
	for _i in 150:
		await get_tree().physics_frame

	# Wall's near face is at x = 6 - 0.5 = 5.5; the cat's capsule (radius 0.4)
	# should stop it around x = 5.1. It must not tunnel past the wall.
	if cat.global_position.x > 5.7:
		failures.append("cat crossed the boundary wall (x=%.2f)" % cat.global_position.x)

	if failures.is_empty():
		print("PASS: boundary wall stops the cat from leaving the territory")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
