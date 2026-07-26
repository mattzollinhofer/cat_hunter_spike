extends Node
## Headless test for the stalk-and-pounce hunt loop. Exits 0/1 (space_scroller
## convention). Locks in the three rules that make the loop work:
##   1. A walking cat is spotted far off — prey flees.
##   2. A stalking cat at the same distance stays undetected — prey grazes.
##   3. A pounce within range catches the prey.
##
## Each sub-test runs at a far-apart origin and cleans up before the next, so
## bodies from one case can never interfere with another.

const GRAZE := 0
const FLEE := 1

var _caught := false

func _ready() -> void:
	call_deferred("_run")

func _make_cat(pos: Vector3) -> CharacterBody3D:
	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	cat.position = pos
	add_child(cat)
	return cat

func _make_prey(cat: Node3D, pos: Vector3) -> CharacterBody3D:
	var prey := CharacterBody3D.new()
	prey.set_script(load("res://prey.gd"))
	prey.target = cat
	prey.position = pos
	add_child(prey)
	return prey

func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame

func _run() -> void:
	var failures: Array[String] = []

	# 1. Walking cat (not stalking) within BASE_DETECT (7m) makes prey flee.
	var cat1 := _make_cat(Vector3(0, 1, 5))
	var prey1 := _make_prey(cat1, Vector3(0, 0.5, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if prey1.get_state() != FLEE:
		failures.append("prey did not flee from a walking cat at 5m")
	await _clear([cat1, prey1])

	# 2. Stalking cat at the same 5m stays undetected (STALK_DETECT is 3m).
	var cat2 := _make_cat(Vector3(100, 1, 5))
	cat2.force_stalk = true
	var prey2 := _make_prey(cat2, Vector3(100, 0.5, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if prey2.get_state() != GRAZE:
		failures.append("prey wrongly fled from a stalking cat at 5m")
	await _clear([cat2, prey2])

	# 3. A pounce within range catches the prey.
	var cat3 := _make_cat(Vector3(200, 1, 2.5))
	cat3.rotation.y = PI  # face -Z, toward the prey
	var prey3 := _make_prey(cat3, Vector3(200, 0.5, 0))
	prey3.caught.connect(func() -> void: _caught = true)
	await get_tree().physics_frame
	cat3.force_pounce = true
	for _i in 40:
		await get_tree().physics_frame
		if _caught:
			break
	if not _caught:
		failures.append("pounce did not catch prey within range")

	if failures.is_empty():
		print("PASS: flee detection, stalk stealth, and pounce-catch all OK")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
