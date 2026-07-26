extends Node
## Headless de-risk test. Exits 0 on pass, 1 on fail (matches the space_scroller
## test convention). Proves two things the build night depends on:
##   1. The CC0 asset pipeline: Fox.glb imports and carries its animations.
##   2. The controller actually walks and drives the Walk animation.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# 1. Asset pipeline: imported GLB is a PackedScene with an AnimationPlayer
	#    exposing the clips we need.
	var packed := load("res://assets/Fox.glb") as PackedScene
	if packed == null:
		failures.append("Fox.glb did not import/load as a PackedScene")
	else:
		var fox := packed.instantiate()
		var ap := fox.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null:
			failures.append("imported Fox has no AnimationPlayer")
		else:
			var anims := ap.get_animation_list()
			for needed in ["Walk", "Survey"]:
				if not (needed in anims):
					failures.append("Fox missing '%s' animation (has %s)" % [needed, anims])
		fox.free()

	# 2. Controller walks forward under forced input and plays Walk.
	var cat := CharacterBody3D.new()
	cat.set_script(load("res://cat_controller.gd"))
	add_child(cat)
	await get_tree().physics_frame
	cat.use_force_input = true
	cat.force_input = Vector3(0, 0, -1)
	var start_z: float = cat.global_position.z
	for _i in 40:
		await get_tree().physics_frame
	var advanced: float = start_z - cat.global_position.z
	if advanced < 0.5:
		failures.append("cat did not walk forward (dz=%.2f)" % advanced)
	if cat.get_current_anim() != "Walk":
		failures.append("cat not playing Walk while moving (got '%s')" % cat.get_current_anim())

	if failures.is_empty():
		print("PASS: asset import + animations + walking controller all OK")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
