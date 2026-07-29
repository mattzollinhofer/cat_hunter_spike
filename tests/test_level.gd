extends Node
## Headless test for level_loader.gd. Exits 0/1 (space_scroller convention).
## Locks in the two rules the data-driven level system depends on:
##   1. A valid level file loads its data as-is.
##   2. A missing/invalid file falls back to the default level instead of
##      crashing, so the deployed build always has something to play.

const LevelLoader := preload("res://level_loader.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# 1. A real level file loads its own data.
	var level := LevelLoader.load_level("res://levels/level_1.json")
	if level.get("name") != "Pine Forest":
		failures.append("level_1.json name expected 'Pine Forest', got '%s'" % level.get("name"))
	if level.get("ground_size") != 240:
		failures.append("level_1.json ground_size expected 240, got %s" % level.get("ground_size"))
	if level.get("trees", []).is_empty():
		failures.append("level_1.json should load a forest, got no trees")
	var prey: Dictionary = level.get("prey", {})
	if prey.get("goal") != 5:
		failures.append("level_1.json prey.goal expected 5, got %s" % prey.get("goal"))
	if prey.get("lives") != 6:
		failures.append("level_1.json prey.lives expected 6, got %s" % prey.get("lives"))

	# 2. A missing file falls back to the default level, not a crash.
	var missing := LevelLoader.load_level("res://levels/does_not_exist.json")
	if missing.is_empty():
		failures.append("missing level file returned an empty dictionary instead of the default level")
	for key in ["name", "ground_size", "ground_color", "cat_start", "trees", "prey"]:
		if not missing.has(key):
			failures.append("default level fallback missing required key '%s'" % key)

	# 3. Content-malformed levels (right keys, bad values) are rejected by
	#    _is_valid, so a hand-authored typo falls back rather than building a
	#    silently broken world.
	if not LevelLoader._is_valid(LevelLoader._default_level()):
		failures.append("_is_valid rejected the default level, which should be valid")
	var short_cat: Dictionary = LevelLoader._default_level()
	short_cat.cat_start = [0, 1]  # only 2 elements
	if LevelLoader._is_valid(short_cat):
		failures.append("_is_valid accepted a 2-element cat_start")
	var string_size: Dictionary = LevelLoader._default_level()
	string_size.ground_size = "80"  # a string, not a number
	if LevelLoader._is_valid(string_size):
		failures.append("_is_valid accepted a string ground_size")
	var bad_goal: Dictionary = LevelLoader._default_level()
	bad_goal.prey.goal = "five"  # not a number
	if LevelLoader._is_valid(bad_goal):
		failures.append("_is_valid accepted a non-numeric prey.goal")

	if failures.is_empty():
		print("PASS: level_1.json loads correctly and a missing file falls back to the default level")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
