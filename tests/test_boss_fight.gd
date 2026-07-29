extends Node
## Headless test for the boss fight rules the game's designer chose:
##   * the bull sleeps until woken (bites do nothing while asleep),
##   * 3 lives x 5 health -- 5 bites empties a life and makes it flash,
##   * losing the last life defeats it: it plays Death (falls over) and fires
##     `defeated` (which wins the game).
## Exits 0/1.

const Boss := preload("res://boss.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var boss: Node3D = Boss.new()
	add_child(boss)
	boss.setup(Color(0.55, 0.09, 0.06), 0.75)
	await get_tree().process_frame

	# Asleep: bites are ignored.
	boss.hit()
	if boss.get_lives() != 3 or boss.get_health() != 5:
		failures.append("a sleeping bull should ignore bites (lives=%d health=%d)" % [boss.get_lives(), boss.get_health()])

	boss.activate()

	# One life = five bites; emptying it drops a life, refills health, and flashes.
	for _i in 5:
		boss.hit()
	if boss.get_lives() != 2:
		failures.append("after 5 bites the bull should have 2 lives, got %d" % boss.get_lives())
	if boss.get_health() != 5:
		failures.append("after losing a life, health should refill to 5, got %d" % boss.get_health())
	if not boss.is_flashing():
		failures.append("losing a life should make the bull flash")

	for _i in 5:
		boss.hit()
	if boss.get_lives() != 1:
		failures.append("after 10 bites the bull should have 1 life, got %d" % boss.get_lives())

	# The last life: defeat.
	var won := [false]
	boss.defeated.connect(func(): won[0] = true)
	for _i in 5:
		boss.hit()
	if not won[0]:
		failures.append("beating the last life should emit `defeated`")
	if not boss.is_defeated():
		failures.append("bull should report defeated after its last life")
	if boss.get_current_anim() != "Death":
		failures.append("a defeated bull should play Death (fall over), got '%s'" % boss.get_current_anim())

	# Already beaten: further bites do nothing.
	boss.hit()
	if boss.get_lives() != 0:
		failures.append("a defeated bull should ignore further bites, lives=%d" % boss.get_lives())

	if failures.is_empty():
		print("PASS: boss fight -- sleep, 3 lives x 5 health, flash on life lost, falls over when beaten")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)
