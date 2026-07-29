extends Node
## Headless test: the orbit camera rig follows its target, swings around it when
## orbited, keeps its up/down angle inside sane limits, and steers the cat's
## movement so "forward" means away from the camera. Exits 0/1.

const CameraRig := preload("res://camera_rig.gd")
const CatController := preload("res://cat_controller.gd")

## Stands in for the cat: something that faces a direction and reports a speed,
## which is all the rig needs to decide where "behind" is.
class FakeCat extends Node3D:
	var velocity := Vector3.ZERO

## Stands in for ui/touch_controls.gd so the cat can be fed a joystick direction
## without building the real touch UI.
class FakeTouch extends Node:
	var direction := Vector2.ZERO

	func get_move_direction() -> Vector2:
		return direction

	func is_stalk_on() -> bool:
		return false

	func consume_pounce() -> bool:
		return false

	func consume_bite() -> bool:
		return false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await _test_follows_target())
	failures.append_array(await _test_orbits_around_target())
	failures.append_array(await _test_pitch_is_clamped())
	failures.append_array(await _test_movement_follows_the_camera())
	failures.append_array(await _test_swings_back_behind_a_moving_cat())

	if failures.is_empty():
		print("PASS: orbit camera follows, swings behind, clamps pitch, and steers movement")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)

func _test_follows_target() -> Array[String]:
	var failures: Array[String] = []
	var target := Node3D.new()
	add_child(target)
	var rig := CameraRig.new()
	add_child(rig)
	rig.setup(target)

	target.global_position = Vector3(20, 0, -14)
	for _i in 120:
		await get_tree().process_frame
	var gap := rig.global_position.distance_to(target.global_position)
	if gap > 0.5:
		failures.append("rig did not catch up to its target (gap %.2f)" % gap)

	rig.queue_free()
	target.queue_free()
	await get_tree().process_frame
	return failures

func _test_orbits_around_target() -> Array[String]:
	var failures: Array[String] = []
	var target := Node3D.new()
	add_child(target)
	var rig := CameraRig.new()
	add_child(rig)
	rig.setup(target)
	# The spring arm places the camera from a physics query, so it needs a
	# physics frame before the camera has a real position.
	await get_tree().physics_frame
	await get_tree().process_frame

	# Camera starts behind the target (+Z) and above it.
	var camera := rig.get_camera()
	if camera.global_position.z <= 0.5:
		failures.append("camera did not start behind the target (z=%.2f)" % camera.global_position.z)
	if camera.global_position.y <= target.global_position.y:
		failures.append("camera did not start above the target (y=%.2f)" % camera.global_position.y)
	var start_distance := camera.global_position.distance_to(target.global_position)

	# Half a turn puts it on the opposite side, the same distance out.
	rig.orbit(PI, 0.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	if camera.global_position.z >= -0.5:
		failures.append("camera did not swing to the far side (z=%.2f)" % camera.global_position.z)
	var turned_distance := camera.global_position.distance_to(target.global_position)
	if absf(turned_distance - start_distance) > 0.1:
		failures.append("orbiting changed the camera distance (%.2f -> %.2f)"
			% [start_distance, turned_distance])

	rig.queue_free()
	target.queue_free()
	await get_tree().process_frame
	return failures

func _test_pitch_is_clamped() -> Array[String]:
	var failures: Array[String] = []
	var rig := CameraRig.new()
	add_child(rig)
	var target := Node3D.new()
	add_child(target)
	rig.setup(target)

	rig.orbit(0.0, -100.0)
	if not is_equal_approx(rig.pitch, CameraRig.PITCH_MIN):
		failures.append("pitch ran past its lowest limit (%.2f)" % rig.pitch)
	rig.orbit(0.0, 100.0)
	if not is_equal_approx(rig.pitch, CameraRig.PITCH_MAX):
		failures.append("pitch ran past its highest limit (%.2f)" % rig.pitch)

	rig.queue_free()
	target.queue_free()
	await get_tree().process_frame
	return failures

## The camera drifts back behind the cat on its own, so the player never has to
## drag to see where they are going -- but only while the cat is actually moving,
## and only once the pause after a hand-drag has run out.
func _test_swings_back_behind_a_moving_cat() -> Array[String]:
	var failures: Array[String] = []
	var cat := FakeCat.new()
	add_child(cat)
	cat.rotation.y = PI  # the cat's facing when it travels toward -Z
	var rig := CameraRig.new()
	add_child(rig)
	rig.setup(cat)
	await get_tree().process_frame

	# Standing still: a hand-placed view must stay where it was put.
	rig.orbit(PI / 2.0, 0.0)
	rig.recenter_pause = 0.0
	cat.velocity = Vector3.ZERO
	for _i in 60:
		rig.recenter_step(1.0 / 60.0)
	if absf(angle_difference(rig.yaw, PI / 2.0)) > 0.05:
		failures.append("camera drifted while the cat stood still (yaw %.2f)" % rig.yaw)

	# Walking: it eases around to sit behind the cat, which faces -Z, so yaw 0.
	cat.velocity = Vector3(0, 0, -4)
	for _i in 180:
		rig.recenter_step(1.0 / 60.0)
	if absf(angle_difference(rig.yaw, 0.0)) > 0.05:
		failures.append("camera did not swing back behind the moving cat (yaw %.2f)" % rig.yaw)

	# A fresh hand-drag wins for a moment, so auto-follow can't fight the player.
	rig.orbit(1.0, 0.0)
	var dragged_yaw := rig.yaw
	rig.recenter_step(1.0 / 60.0)
	if not is_equal_approx(rig.yaw, dragged_yaw):
		failures.append("auto-follow overrode a fresh drag")

	rig.queue_free()
	cat.queue_free()
	await get_tree().process_frame
	return failures

func _test_movement_follows_the_camera() -> Array[String]:
	var failures: Array[String] = []
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var cat := CharacterBody3D.new()
	cat.set_script(CatController)
	cat.position = Vector3(0, 1, 0)
	add_child(cat)
	var touch := FakeTouch.new()
	add_child(touch)
	cat.touch = touch
	touch.direction = Vector2(0, -1)  # joystick pushed forward
	await get_tree().physics_frame

	# With the camera behind the cat, forward is away from the camera: -Z.
	for _i in 10:
		await get_tree().physics_frame
	if cat.velocity.z > -1.0:
		failures.append("forward did not move the cat away from the camera (vz=%.2f)" % cat.velocity.z)

	# Swing the camera a quarter turn and forward should swing with it.
	cat.camera_yaw = PI / 2.0
	for _i in 10:
		await get_tree().physics_frame
	if cat.velocity.x > -1.0 or absf(cat.velocity.z) > 1.0:
		failures.append("forward did not turn with the camera (v=%s)" % cat.velocity)

	cat.queue_free()
	touch.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
	return failures
