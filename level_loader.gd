extends RefCounted
## Loads a level's data (ground, trees, cat start, prey config) from a JSON
## file so new maps can be authored without touching code.
##
## Any failure to produce a usable level — missing file, bad JSON, wrong
## shape, or the web export simply not packing the file — falls back to
## _default_level() and push_warning()s instead of crashing. That fallback is
## what guarantees the deployed web build always has a valid level even if
## the JSON didn't make it into the export.

const REQUIRED_KEYS := ["name", "ground_size", "ground_color", "cat_start", "trees", "prey"]
const REQUIRED_PREY_KEYS := ["goal", "lives", "first_spawn", "spawn_radius_min", "spawn_radius_max"]

static func load_level(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LevelLoader: '%s' not found, using default level" % path)
		return _default_level()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("LevelLoader: could not open '%s' (error %d), using default level" % [path, FileAccess.get_open_error()])
		return _default_level()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not _is_valid(parsed):
		push_warning("LevelLoader: '%s' did not contain a valid level, using default level" % path)
		return _default_level()
	return parsed

## Shape check for a hand-authored level file: every key main.gd reads must
## exist AND hold a usable value, so a typo (a 2-element cat_start, a string
## ground_size) falls back to the default level instead of silently building a
## broken world. Checks length and scalar type of the arrays/numbers that get
## converted or read directly, not a full schema.
static func _is_valid(data: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return false
	if not _is_number(data.ground_size):
		return false
	if not _is_vec3_array(data.ground_color) or not _is_vec3_array(data.cat_start):
		return false
	if not (data.trees is Array):
		return false
	for spot in data.trees:
		if not _is_vec3_array(spot):
			return false
	if not (data.prey is Dictionary):
		return false
	for key in REQUIRED_PREY_KEYS:
		if not data.prey.has(key):
			return false
	if not _is_vec3_array(data.prey.first_spawn):
		return false
	for key in ["goal", "lives", "spawn_radius_min", "spawn_radius_max"]:
		if not _is_number(data.prey[key]):
			return false
	return true

static func _is_number(value: Variant) -> bool:
	return value is int or value is float

static func _is_vec3_array(value: Variant) -> bool:
	if not (value is Array) or value.size() != 3:
		return false
	for element in value:
		if not _is_number(element):
			return false
	return true

static func _default_level() -> Dictionary:
	return {
		"name": "Pine Forest",
		"ground_size": 80,
		"ground_color": [0.22, 0.40, 0.18],
		"cat_start": [0, 1, 0],
		"trees": [
			[-6, 0, -5], [5, 0, -8], [-9, 0, -12],
			[8, 0, -3], [2, 0, -15], [-3, 0, -19],
			[11, 0, -11], [-12, 0, -6], [4, 0, -22],
		],
		"prey": {
			"goal": 5,
			"lives": 6,
			"first_spawn": [0, 0.5, -6],
			"spawn_radius_min": 6,
			"spawn_radius_max": 12,
		},
	}

## JSON [x, y, z] -> Vector3.
static func to_vector3(arr: Array) -> Vector3:
	return Vector3(arr[0], arr[1], arr[2])

## JSON [r, g, b] -> Color.
static func to_color(arr: Array) -> Color:
	return Color(arr[0], arr[1], arr[2])
