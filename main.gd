extends Node3D
## Cat Hunter spike world builder.
##
## Constructs a minimal forest (ground, sky, sun, placeholder pine trees), the
## cat, and a trailing follow-camera entirely in code so there is no fragile
## hand-authored .tscn resource data. The cat's behaviour lives in
## cat_controller.gd; this node only stages the scene and follows the cat.
##
## The world's shape (ground size/color, tree positions, cat start, prey
## config) is data-driven: LEVEL_PATH points at a JSON file (level_loader.gd)
## so new maps can be authored without touching this script.

const LevelLoader := preload("res://level_loader.gd")
const Boss := preload("res://boss.gd")
const Fence := preload("res://fence.gd")
const CameraRig := preload("res://camera_rig.gd")
const LEVEL_PATH := "res://levels/level_1.json"

# Preview roster: one Bull model reskinned into distinct bosses by color + size.
# These just stand and idle for now -- a look at the roster mechanic, not a real
# encounter. Boss combat is a later, design-driven step; when it lands this data
# moves into the level file.
const BOSS_PREVIEW := [
	{"name": "Emberhorn", "color": Color(0.55, 0.09, 0.06), "size": 0.75, "pos": Vector3(0, 0, -26)},
]

var _level: Dictionary
var _cat: CharacterBody3D
var _camera_rig: Node3D
var _hud: CanvasLayer
var _boss: Node3D
var _hunt: Node

func _ready() -> void:
	_level = LevelLoader.load_level(LEVEL_PATH)
	_build_environment()
	_build_light()
	_build_ground()
	_build_bounds()
	_build_fence()
	_scatter_trees()
	_spawn_cat()
	_spawn_boss_preview()
	_build_camera()
	_start_hunt()
	_build_touch_controls()

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
	var ground_size: float = _level.ground_size
	plane.size = Vector2(ground_size, ground_size)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LevelLoader.to_color(_level.ground_color)
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	add_child(body)

func _build_bounds() -> void:
	# Invisible walls around the territory edge so the cat and prey can't leave
	# the visible ground. Sized from the level's ground_size, so the border always
	# matches the map. The ground itself is an infinite floor (no falling through);
	# these four walls provide the horizontal boundary.
	var size: float = _level.ground_size
	var half := size / 2.0
	var height := 8.0
	var thickness := 1.0
	var walls := [
		[Vector3(0.0, height / 2.0, -half), Vector3(size, height, thickness)],  # north (-Z)
		[Vector3(0.0, height / 2.0, half), Vector3(size, height, thickness)],   # south (+Z)
		[Vector3(-half, height / 2.0, 0.0), Vector3(thickness, height, size)],  # west (-X)
		[Vector3(half, height / 2.0, 0.0), Vector3(thickness, height, size)],   # east (+X)
	]
	for wall in walls:
		var body := StaticBody3D.new()
		body.collision_layer = 1  # world layer; cat (mask 1) and prey (mask 1) collide with it
		body.position = wall[0]
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		col.shape = box
		body.add_child(col)
		add_child(body)

func _build_fence() -> void:
	# Marks the territory edge so the player can see where the world ends. Sized
	# from the same ground_size as everything else, so it never drifts off the map.
	var fence := Fence.new()
	add_child(fence)
	fence.build(_level.ground_size)

func _scatter_trees() -> void:
	for spot in _level.trees:
		add_child(_make_tree(LevelLoader.to_vector3(spot)))

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
	_cat.position = LevelLoader.to_vector3(_level.cat_start)
	add_child(_cat)

func _spawn_boss_preview() -> void:
	var cat_start := LevelLoader.to_vector3(_level.cat_start)
	for data in BOSS_PREVIEW:
		var boss := Boss.new()
		add_child(boss)
		boss.global_position = data.pos
		# Turn to face the cat's start, kept level (same height) so the boss stands
		# upright instead of tilting its head down at the ground.
		var look_target := Vector3(cat_start.x, data.pos.y, cat_start.z)
		if not boss.global_position.is_equal_approx(look_target):
			boss.look_at(look_target, Vector3.UP)
		boss.setup(data.color, data.size)
		_boss = boss

func _build_camera() -> void:
	# Orbit camera: trails the cat and swings around it on a left-drag. The
	# following and the mouse-look both live in camera_rig.gd.
	_camera_rig = CameraRig.new()
	add_child(_camera_rig)
	_camera_rig.setup(_cat)

func _start_hunt() -> void:
	var hunt := Node.new()
	hunt.name = "Hunt"
	hunt.set_script(load("res://hunt.gd"))
	add_child(hunt)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://hud.gd"))
	add_child(hud)
	_hud = hud
	hud.bind(hunt)
	hud.set_level_name(_level.name)
	var prey_data: Dictionary = _level.prey
	var prey_config := {
		"goal": prey_data.goal,
		"lives": prey_data.lives,
		"first_spawn": LevelLoader.to_vector3(prey_data.first_spawn),
		"spawn_radius_min": prey_data.spawn_radius_min,
		"spawn_radius_max": prey_data.spawn_radius_max,
	}
	hunt.setup(_cat, self, prey_config)
	_hunt = hunt
	_wire_boss_fight()

func _wire_boss_fight() -> void:
	# Catching all the prey wakes the bull; biting it drives its health down and
	# beating it shows the win banner. The HUD and boss never reference each other
	# directly -- this node connects them.
	if _boss == null:
		return
	_hunt.goal_reached.connect(_boss.activate)
	_boss.health_changed.connect(_hud.set_boss_health)
	_boss.defeated.connect(_hud.show_win)
	# The bull's headbutt costs the fox one health; the hunt owns that rule and the
	# HUD just shows the result.
	_boss.hit_cat.connect(_hunt.take_damage)
	_hunt.health_changed.connect(_hud.set_fox_health)

func _build_touch_controls() -> void:
	var touch := CanvasLayer.new()
	touch.name = "TouchControls"
	touch.set_script(load("res://ui/touch_controls.gd"))
	add_child(touch)
	_cat.touch = touch
	touch.set_joystick_exclude(_hud.get_pause_button())
