extends Node
## Headless test for touch controls (space_scroller convention: exits 0/1).
## Drives the joystick, stalk toggle, and pounce button through their test
## helpers only — no real touch/mouse events — and checks the contract
## cat_controller.gd relies on:
##   1. Joystick "up" (Vector2(0, -1)) moves the cat -Z (forward).
##   2. Stalk toggle on makes cat.is_stalking true.
##   3. A pounce press makes cat.is_pouncing true, and is one-shot.

func _ready() -> void:
	call_deferred("_run")

func _make_cat() -> CharacterBody3D:
	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	add_child(cat)
	return cat

func _make_touch() -> CanvasLayer:
	var touch := CanvasLayer.new()
	touch.set_script(load("res://ui/touch_controls.gd"))
	add_child(touch)
	return touch

func _run() -> void:
	var failures: Array[String] = []

	var cat := _make_cat()
	var touch := _make_touch()
	await get_tree().physics_frame
	cat.touch = touch

	# 1. Joystick pointing "up" moves the cat forward (-Z).
	touch.set_test_move(Vector2(0, -1))
	var start_z: float = cat.global_position.z
	for _i in 30:
		await get_tree().physics_frame
	var advanced: float = start_z - cat.global_position.z
	if advanced < 0.5:
		failures.append("joystick 'up' did not move the cat forward (dz=%.2f)" % advanced)
	touch.set_test_move(Vector2.ZERO)

	# 1b. A deflection inside the deadzone (< 0.2) must NOT move the cat.
	touch.set_test_move(Vector2(0, -0.1))
	var deadzone_start_z: float = cat.global_position.z
	for _i in 15:
		await get_tree().physics_frame
	if absf(deadzone_start_z - cat.global_position.z) > 0.05:
		failures.append("joystick inside deadzone wrongly moved the cat")
	touch.set_test_move(Vector2.ZERO)

	# 2. Stalk toggle on sets cat.is_stalking.
	touch.set_test_stalk(true)
	await get_tree().physics_frame
	if not cat.is_stalking:
		failures.append("stalk toggle on did not set cat.is_stalking")
	touch.set_test_stalk(false)

	# 3. A pounce press sets cat.is_pouncing and is consumed exactly once.
	touch.press_pounce()
	await get_tree().physics_frame
	if not cat.is_pouncing:
		failures.append("pounce press did not set cat.is_pouncing")
	if touch.consume_pounce():
		failures.append("consume_pounce() did not clear after cat_controller read it (not one-shot)")

	if failures.is_empty():
		print("PASS: touch joystick movement, stalk toggle, and one-shot pounce all OK")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
