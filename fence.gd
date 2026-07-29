extends Node3D
## A wooden fence standing along the territory border.
##
## Decoration only -- it has no collision of its own. The fence exists so the
## player can SEE where the territory ends instead of bumping into nothing. It is
## sized from the level's ground_size, so it always lands on the map's edge.
##
## Posts are drawn through a single MultiMeshInstance3D rather than one node per
## post: a 240-wide map needs well over a hundred of them, and the web export
## renders on the compatibility renderer where draw calls are the scarce thing.

const POST_SPACING := 6.0
const POST_HEIGHT := 2.2
const POST_RADIUS := 0.13
const RAIL_HEIGHTS := [0.75, 1.55]
const RAIL_THICKNESS := 0.14
const WOOD_COLOR := Color(0.42, 0.29, 0.18)

func build(ground_size: float) -> void:
	var half := ground_size / 2.0
	var material := _wood_material()
	add_child(_make_posts(ground_size, half, material))
	for rail in _make_rails(ground_size, half, material):
		add_child(rail)

func _wood_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = WOOD_COLOR
	material.roughness = 0.9
	return material

func _make_posts(ground_size: float, half: float, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = POST_RADIUS
	post_mesh.bottom_radius = POST_RADIUS
	post_mesh.height = POST_HEIGHT
	post_mesh.radial_segments = 6
	post_mesh.rings = 1
	post_mesh.material = material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = post_mesh
	var positions := _post_positions(ground_size, half)
	multi_mesh.instance_count = positions.size()
	for index in positions.size():
		multi_mesh.set_instance_transform(index, Transform3D(Basis(), positions[index]))

	var posts := MultiMeshInstance3D.new()
	posts.name = "Posts"
	posts.multimesh = multi_mesh
	return posts

func _post_positions(ground_size: float, half: float) -> Array[Vector3]:
	# Divide each side evenly instead of stepping by POST_SPACING directly, so a
	# post lands exactly on each corner however wide the map is.
	var per_side := maxi(1, int(round(ground_size / POST_SPACING)))
	var spacing := ground_size / per_side
	var post_center_y := POST_HEIGHT / 2.0
	var positions: Array[Vector3] = []
	for step in per_side + 1:
		var along := -half + step * spacing
		# West and east sides run the full length, corners included...
		positions.append(Vector3(-half, post_center_y, along))
		positions.append(Vector3(half, post_center_y, along))
		# ...so the north and south sides skip the corners already filled.
		if step > 0 and step < per_side:
			positions.append(Vector3(along, post_center_y, -half))
			positions.append(Vector3(along, post_center_y, half))
	return positions

func _make_rails(ground_size: float, half: float, material: StandardMaterial3D) -> Array[MeshInstance3D]:
	var sides := {
		"north": Vector3(0.0, 0.0, -half),
		"south": Vector3(0.0, 0.0, half),
		"west": Vector3(-half, 0.0, 0.0),
		"east": Vector3(half, 0.0, 0.0),
	}
	var rails: Array[MeshInstance3D] = []
	for side in sides:
		var center: Vector3 = sides[side]
		var runs_along_x := is_zero_approx(center.x)
		var size := Vector3(ground_size, RAIL_THICKNESS, RAIL_THICKNESS)
		if not runs_along_x:
			size = Vector3(RAIL_THICKNESS, RAIL_THICKNESS, ground_size)
		for height_index in RAIL_HEIGHTS.size():
			var rail := MeshInstance3D.new()
			rail.name = "Rail_%s_%d" % [side, height_index]
			var box := BoxMesh.new()
			box.size = size
			box.material = material
			rail.mesh = box
			rail.position = Vector3(center.x, RAIL_HEIGHTS[height_index], center.z)
			rails.append(rail)
	return rails
