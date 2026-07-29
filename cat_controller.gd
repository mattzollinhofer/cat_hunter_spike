extends CharacterBody3D
## The cat: walk / stalk movement, a pounce lunge, faces its travel direction,
## Walk / Survey / Run animations, gravity.
##
## Prey read three things off this node: `is_stalking`, `is_pouncing`, and the
## built-in `velocity`. The stalk/pounce split is the core mechanic: prey can
## outrun a walk, so you must stalk close (quiet) and pounce (a fast lunge) to
## catch it.
##
## Non-interactive hooks keep the loop verifiable:
##   * use_force_input / force_input, force_stalk, force_pounce — the headless
##     test drives movement, stalking and pouncing.
##   * CAT_CAPTURE env var — auto-stalks forward and saves one screenshot.

const WALK_SPEED := 4.5
const RUN_SPEED := 9.0        # hold Option; loud, so it is travel, not hunting
const STALK_SPEED := 1.8
const POUNCE_SPEED := 13.0
const POUNCE_TIME := 0.4
const POUNCE_COOLDOWN := 0.7
const BITE_TIME := 0.22        # a quick chomp, much shorter than a pounce
const BITE_LUNGE := 3.5        # a small forward snap, not a big leap
const BITE_COOLDOWN := 0.35
const GRAVITY := 22.0
const TURN_RATE := 9.0
const MODEL_SCALE := 0.02
const CAPTURE_AT_FRAME := 75

# Read by prey.
var is_stalking := false
var is_running := false
var is_pouncing := false
var is_biting := false

# Test / capture hooks.
var use_force_input := false
var force_input := Vector3.ZERO
var force_stalk := false
var force_run := false
var force_pounce := false
var force_bite := false

# Touch UI, assigned by main.gd during real play (present on desktop and mobile;
# it also accepts mouse). Stays null only in the unit tests that build a bare cat.
var touch: Node = null

# Which way the camera is facing, published by camera_rig.gd. Keyboard and
# joystick input is turned by this, so "forward" always means away from the
# camera. Stays 0 in the unit tests, where it is the identity.
var camera_yaw := 0.0

var _anim: AnimationPlayer
var _model: Node3D
var _pounce_timer := 0.0
var _cooldown := 0.0
var _pounce_dir := Vector3.ZERO
var _space_prev := false
var _bite_timer := 0.0
var _bite_dir := Vector3.ZERO
var _bite_prev := false
var _capture_path := ""
var _frames := 0
var _captured := false

func _ready() -> void:
	# Layer 2 = cat, mask 1 = world/ground only. The cat must NOT collide with
	# prey (layer 4) — catching is distance-based, so a pounce passes through.
	collision_layer = 2
	collision_mask = 1
	_build_collision()
	_load_model()
	add_to_group("cat")
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
	if _cooldown > 0.0:
		_cooldown -= delta

	if _pounce_timer > 0.0:
		_pounce_timer -= delta
		velocity.x = _pounce_dir.x * POUNCE_SPEED
		velocity.z = _pounce_dir.z * POUNCE_SPEED
		_play("Run")
	elif _bite_timer > 0.0:
		# A quick chomp: a short forward snap. The fox has no bite clip, so reuse
		# its fastest animation and let the lunge motion sell the grab.
		_bite_timer -= delta
		velocity.x = _bite_dir.x * BITE_LUNGE
		velocity.z = _bite_dir.z * BITE_LUNGE
		_play("Run")
	else:
		is_stalking = force_stalk or Input.is_physical_key_pressed(KEY_SHIFT) or _capture_active() or (touch != null and touch.is_stalk_on())
		# Stalking wins over running: a sneak that could be sprinted would turn the
		# stalk-and-pounce hunt into a footrace.
		is_running = not is_stalking and _wants_run()
		var input := _read_move_input()
		var speed := WALK_SPEED
		if is_stalking:
			speed = STALK_SPEED
		elif is_running:
			speed = RUN_SPEED
		if input.length() > 0.05:
			velocity.x = input.x * speed
			velocity.z = input.z * speed
			var target_yaw := atan2(input.x, input.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, TURN_RATE * delta)
			_play("Run" if is_running else "Walk")
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Survey")
		if _wants_pounce() and _cooldown <= 0.0:
			_start_pounce()
		elif _wants_bite() and _cooldown <= 0.0:
			_start_bite()

	is_pouncing = _pounce_timer > 0.0
	is_biting = _bite_timer > 0.0

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_maybe_capture()

func _read_move_input() -> Vector3:
	if use_force_input:
		return force_input.normalized()
	if _capture_active():
		return Vector3(0, 0, -1)  # stalk toward the prey for the screenshot
	var v := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		v.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		v.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		v.x += 1.0
	if touch != null:
		var joystick_dir: Vector2 = touch.get_move_direction()
		if joystick_dir.length() > 0.2:  # deadzone
			v = Vector3(joystick_dir.x, 0.0, joystick_dir.y)  # joystick up (-Y) is forward (-Z)
	return v.normalized().rotated(Vector3.UP, camera_yaw)

func _wants_run() -> bool:
	# Option (Alt), not Ctrl: Ctrl + arrow is a Mac desktop-switching shortcut and
	# would steal the key mid-run.
	return force_run or Input.is_physical_key_pressed(KEY_ALT)

func _wants_pounce() -> bool:
	var down := Input.is_physical_key_pressed(KEY_SPACE)
	var just := down and not _space_prev
	_space_prev = down
	if force_pounce:
		force_pounce = false
		return true
	return just or (touch != null and touch.consume_pounce())

func _start_pounce() -> void:
	# Lunge in the direction the cat is currently facing.
	_pounce_dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	_pounce_timer = POUNCE_TIME
	_cooldown = POUNCE_TIME + POUNCE_COOLDOWN
	is_stalking = false  # a pounce is loud

func _wants_bite() -> bool:
	var down := Input.is_physical_key_pressed(KEY_B)
	var just := down and not _bite_prev
	_bite_prev = down
	if force_bite:
		force_bite = false
		return true
	return just or (touch != null and touch.consume_bite())

func _start_bite() -> void:
	# Snap forward the way the fox is facing, a small version of the pounce lunge.
	_bite_dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	_bite_timer = BITE_TIME
	_cooldown = BITE_TIME + BITE_COOLDOWN

func _play(anim_name: String) -> void:
	if _anim and _anim.current_animation != anim_name:
		_anim.play(anim_name)

func get_current_anim() -> String:
	return _anim.current_animation if _anim else ""

func _capture_active() -> bool:
	return _capture_path != ""

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
