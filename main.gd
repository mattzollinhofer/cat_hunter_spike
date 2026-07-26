extends Node3D
## Cat Hunter spike world builder.
##
## Constructs a minimal forest (ground, sky, sun, placeholder pine trees), the
## cat, and a trailing follow-camera entirely in code so there is no fragile
## hand-authored .tscn resource data. The cat's behaviour lives in
## cat_controller.gd; this node only stages the scene and follows the cat.

var _cat: CharacterBody3D
var _camera_rig: Node3D

func _ready() -> void:
	_build_environment()
	_build_light()
	_build_ground()
	_scatter_trees()
	_spawn_cat()
	_build_camera()
	_start_hunt()

func _process(_delta: float) -> void:
	# Trailing follow: track the cat's position, keep a fixed orientation so the
	# camera never whips around when the cat turns to face its travel direction.
	if _cat and _camera_rig:
		_camera_rig.global_position = _camera_rig.global_position.lerp(_cat.global_position, 0.12)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.40, 0.18)
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	add_child(body)

func _scatter_trees() -> void:
	var spots := [
		Vector3(-6, 0, -5), Vector3(5, 0, -8), Vector3(-9, 0, -12),
		Vector3(8, 0, -3), Vector3(2, 0, -15), Vector3(-3, 0, -19),
		Vector3(11, 0, -11), Vector3(-12, 0, -6), Vector3(4, 0, -22),
	]
	for spot in spots:
		add_child(_make_tree(spot))

func _make_tree(pos: Vector3) -> Node3D:
	# Placeholder pine: brown cylinder trunk + green cone canopy. Real CC0 tree
	# GLBs (Kenney/Quaternius) drop in here later; the GLB import path is already
	# proven by the Fox, and a static prop is strictly simpler than a rigged one.
	var tree := Node3D.new()
	tree.position = pos
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 1.6
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.24, 0.14)
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.8
	tree.add_child(trunk)
	var canopy := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.4
	cone.height = 3.2
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.15, 0.33, 0.16)
	cone.material = canopy_mat
	canopy.mesh = cone
	canopy.position.y = 2.9
	tree.add_child(canopy)
	return tree

func _spawn_cat() -> void:
	_cat = CharacterBody3D.new()
	_cat.set_script(load("res://cat_controller.gd"))
	_cat.position = Vector3(0, 1.0, 0)
	add_child(_cat)

func _build_camera() -> void:
	_camera_rig = Node3D.new()
	add_child(_camera_rig)
	_camera_rig.global_position = _cat.global_position
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.0, 6.5)
	cam.rotation_degrees = Vector3(-22, 0, 0)
	_camera_rig.add_child(cam)

func _start_hunt() -> void:
	var hunt := Node.new()
	hunt.name = "Hunt"
	hunt.set_script(load("res://hunt.gd"))
	add_child(hunt)
	hunt.setup(_cat, self)
