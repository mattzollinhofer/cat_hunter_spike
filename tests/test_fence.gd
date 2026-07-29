extends Node
## Headless test: the visible border fence (fence.gd) lines the four edges of the
## territory, matching the invisible boundary walls main.gd builds. Exits 0/1.

const Fence := preload("res://fence.gd")

const GROUND_SIZE := 20.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var half := GROUND_SIZE / 2.0

	var fence := Fence.new()
	add_child(fence)
	fence.build(GROUND_SIZE)
	await get_tree().process_frame

	var posts := fence.get_node_or_null("Posts") as MultiMeshInstance3D
	if posts == null:
		failures.append("fence has no Posts node")
	elif posts.multimesh == null or posts.multimesh.instance_count < 4:
		failures.append("fence has too few posts")

	# One rail per side per height, so the fence reads as a fence from any angle.
	var rails: Array[MeshInstance3D] = []
	for child in fence.get_children():
		if child is MeshInstance3D and child.name.begins_with("Rail"):
			rails.append(child)
	if rails.size() != Fence.RAIL_HEIGHTS.size() * 4:
		failures.append("expected %d rails, found %d" % [Fence.RAIL_HEIGHTS.size() * 4, rails.size()])

	# Every rail must sit on the border line, not somewhere inside the field.
	var sides_covered := {}
	for rail in rails:
		var on_x_edge := is_equal_approx(absf(rail.position.x), half) and absf(rail.position.z) < 0.001
		var on_z_edge := is_equal_approx(absf(rail.position.z), half) and absf(rail.position.x) < 0.001
		if on_x_edge:
			sides_covered["x%d" % signi(int(rail.position.x))] = true
		elif on_z_edge:
			sides_covered["z%d" % signi(int(rail.position.z))] = true
		else:
			failures.append("rail at %s is not on the territory border" % rail.position)
	if sides_covered.size() != 4:
		failures.append("fence covers %d sides, expected 4" % sides_covered.size())

	# The fence must stand tall enough to be seen, and low enough to be a fence.
	if not (Fence.POST_HEIGHT > 1.0 and Fence.POST_HEIGHT < 4.0):
		failures.append("post height %.2f is not fence-sized" % Fence.POST_HEIGHT)

	if failures.is_empty():
		print("PASS: fence lines all four borders of the territory")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
