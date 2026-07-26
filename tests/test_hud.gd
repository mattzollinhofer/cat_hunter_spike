extends Node
## Headless test for the HUD (space_scroller convention: exits 0/1). Drives the
## widgets without real input:
##   1. set_level_name() updates the title.
##   2. bind() wires progress_changed/lives_changed to the task text and the
##      lives diamond row.
##   3. The pause button toggles get_tree().paused and back.

## Stub hunt: exposes just the two signals hud.bind() connects to, so the test
## can drive the HUD without spinning up the real Hunt/Prey systems.
class HuntStub extends Node:
	signal progress_changed(kills: int, goal: int)
	signal lives_changed(lives: int)

func _ready() -> void:
	call_deferred("_run")

func _make_hud() -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.set_script(load("res://hud.gd"))
	add_child(hud)
	return hud

func _run() -> void:
	var failures: Array[String] = []

	var hud := _make_hud()

	# 1. Level name title.
	hud.set_level_name("Test Level")
	if hud.get_level_title() != "Test Level":
		failures.append("set_level_name did not update the title (got '%s')" % hud.get_level_title())

	# 2. Objective + lives track the hunt's signals via bind().
	var stub := HuntStub.new()
	add_child(stub)
	hud.bind(stub)
	stub.progress_changed.emit(2, 5)
	stub.lives_changed.emit(3)
	var task_text: String = hud.get_task_text()
	if not (task_text.contains("2") and task_text.contains("5")):
		failures.append("task text did not reflect progress_changed(2, 5) (got '%s')" % task_text)
	if hud.get_lives_count() != 3:
		failures.append("lives display did not reflect lives_changed(3) (got %d)" % hud.get_lives_count())

	# 3. Pause button toggles get_tree().paused and back. No awaits while
	#    paused -- a paused test node's own process would never resume, so
	#    both checks happen synchronously right after the simulated tap.
	hud.simulate_pause_press()
	if not get_tree().paused:
		failures.append("pause button press did not pause the tree")
	hud.simulate_pause_press()
	if get_tree().paused:
		failures.append("second pause button press did not resume the tree")
	get_tree().paused = false  # belt-and-braces so the test can never hang

	if failures.is_empty():
		print("PASS: HUD level title, task/lives widgets, and pause toggle all OK")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
