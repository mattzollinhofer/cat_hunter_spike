extends Node
## Headless test: the fox's bite is an ATTACK. When the bull is awake and the fox
## bites it in reach, the bull takes damage -- this checks the whole path from the
## cat's is_biting flag through the boss's own hit detection. Exits 0/1.

const CatController := preload("res://cat_controller.gd")
const Boss := preload("res://boss.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# A floor so the fox rests at ground level.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# An awake bull boss.
	var boss: Node3D = Boss.new()
	add_child(boss)
	boss.global_position = Vector3.ZERO
	boss.setup(Color(0.55, 0.09, 0.06), 0.75)
	boss.activate()

	# The fox, standing right next to the bull.
	var cat := CharacterBody3D.new()
	cat.set_script(CatController)
	cat.position = Vector3(0, 1, 2)
	add_child(cat)
	await get_tree().physics_frame

	if boss.get_health() != 5:
		failures.append("bull should start the fight at full health, got %d" % boss.get_health())

	# One bite should land one hit.
	cat.force_bite = true
	for _i in 20:
		await get_tree().physics_frame
		await get_tree().process_frame

	if boss.get_health() >= 5:
		failures.append("biting the bull in reach did not hurt it (health still %d)" % boss.get_health())

	if failures.is_empty():
		print("PASS: biting the bull hurts it -- the bite is an attack")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
