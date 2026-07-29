extends Node
## Headless test: a boss is the shared Bull model, reskinned by color + size.
## Locks in the roster mechanic -- one downloaded model, many distinct bosses --
## so a change that breaks recoloring or drops the bull rig is caught. Exits 0/1.

const Boss := preload("res://boss.gd")
const BOSS_COLOR := Color(0.05, 0.05, 0.06)  # near-black "Darktail"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var boss: Node3D = Boss.new()
	add_child(boss)
	boss.setup(BOSS_COLOR, 2.5, "Idle")
	await get_tree().process_frame

	# It really is the bull: its idle animation is playing.
	if boss.get_current_anim() != "Idle":
		failures.append("boss should play its idle animation, got '%s'" % boss.get_current_anim())

	var model: Node3D = boss.get_child(0)
	if not model.scale.is_equal_approx(Vector3.ONE * 2.5):
		failures.append("boss size not applied, scale=%s" % model.scale)

	# The coat is recolored to the boss color; the horns keep their original
	# material, so the reskinned boss still reads as a bull.
	var mesh_instance := _first_mesh(model)
	var mesh: Mesh = mesh_instance.mesh
	var coat_recolored := false
	var horns_untouched := false
	for surface in mesh.get_surface_count():
		var mat_name := mesh.surface_get_material(surface).resource_name
		var override := mesh_instance.get_surface_override_material(surface)
		if mat_name == "Main":
			coat_recolored = override != null and override.albedo_color.is_equal_approx(BOSS_COLOR)
		if mat_name == "Horns":
			horns_untouched = override == null

	if not coat_recolored:
		failures.append("boss coat (Main surface) was not recolored to the boss color")
	if not horns_untouched:
		failures.append("horns were overridden -- they should keep the original bull material")

	if failures.is_empty():
		print("PASS: a boss is the bull model, reskinned by color and size")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found:
			return found
	return null
