extends CharacterBody3D
## The cat: WASD / arrow-key movement, body turns to face its travel direction,
## Walk / Survey (idle) animations driven from the imported Fox model, gravity.
##
## Two non-interactive hooks keep the de-risk verifiable:
##   * use_force_input / force_input — lets the headless test drive movement.
##   * CAT_CAPTURE env var — auto-walks and saves one screenshot, then quits,
##     so a non-headless run can produce visual proof.
##
## The Fox (a rigged, animated CC0 quadruped from the Khronos glTF samples) is a
## stand-in for the real cat model; it proves the exact import + animation path a
## custom cat GLB will use later.

const SPEED := 4.5
const GRAVITY := 22.0
const TURN_RATE := 9.0
const MODEL_SCALE := 0.02  # Fox is authored ~100x; shrink to ~1.5 units tall.
const CAPTURE_AT_FRAME := 75

var use_force_input := false
var force_input := Vector3.ZERO

var _anim: AnimationPlayer
var _model: Node3D
var _capture_path := ""
var _frames := 0
var _captured := false

func _ready() -> void:
	_build_collision()
	_load_model()
	_capture_path = OS.get_environment("CAT_CAPTURE")

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	col.shape = capsule
	col.position.y = 0.7
	add_child(col)

func _load_model() -> void:
	var packed := load("res://assets/Fox.glb") as PackedScene
	if packed == null:
		push_error("Fox.glb failed to load — was the import step run?")
		return
	_model = packed.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_anim.play("Survey")

func _physics_process(delta: float) -> void:
	var input := _read_input()
	if input.length() > 0.05:
		velocity.x = input.x * SPEED
		velocity.z = input.z * SPEED
		var target_yaw := atan2(input.x, input.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_RATE * delta)
		_play("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Survey")

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_maybe_capture()

func _read_input() -> Vector3:
	if use_force_input:
		return force_input.normalized()
	if _capture_path != "":
		return Vector3(0, 0, -1)  # auto-walk for the screenshot
	var v := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		v.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		v.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		v.x += 1.0
	return v.normalized()

func _play(anim_name: String) -> void:
	if _anim and _anim.current_animation != anim_name:
		_anim.play(anim_name)

func get_current_anim() -> String:
	return _anim.current_animation if _anim else ""

func _maybe_capture() -> void:
	if _capture_path == "" or _captured:
		return
	_frames += 1
	if _frames >= CAPTURE_AT_FRAME:
		_captured = true
		_do_capture()

func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_capture_path)
	print("screenshot -> %s (err %d)" % [_capture_path, err])
	get_tree().quit()
