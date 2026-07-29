extends Node3D
## Third-person orbit camera.
##
## The rig trails the cat's position (smoothed, so the camera never snaps) and
## eases around to sit behind the cat whenever it moves, so the player can just
## run and always see where they are going. Dragging with the left mouse button
## swings the view by hand and wins for a moment afterwards, so auto-follow never
## fights the player mid-drag.
##
## Yaw lives on this node, pitch on a child pivot, and the camera hangs off a
## SpringArm3D so it pulls in instead of burying itself in the ground or the
## boundary wall.
##
## The rig also publishes its yaw to the cat (`camera_yaw`) so "forward" means
## away from the camera. Without that, swinging the view leaves the controls
## pointing the wrong way.

const FOLLOW_SMOOTHING := 0.12   # matches the old fixed follow-cam's feel
const DISTANCE := 7.2
const PIVOT_HEIGHT := 2.0
const DEFAULT_PITCH := -0.30     # roughly the old camera's -22 degree tilt
const PITCH_MIN := -1.10         # high above, looking down at the cat
const PITCH_MAX := 0.25          # low behind, looking slightly up
const DRAG_SENSITIVITY := 0.005  # radians per pixel of mouse movement
const RECENTER_RATE := 2.2       # how fast the view swings back behind the cat
const RECENTER_DELAY := 1.2      # seconds a hand-drag holds off the auto-follow
const MOVING_SPEED := 0.5        # below this the cat counts as standing still

var yaw := 0.0
var pitch := DEFAULT_PITCH
## Seconds left before auto-follow resumes after a hand-drag.
var recenter_pause := 0.0

var _target: Node3D
var _pitch_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _dragging := false

func _ready() -> void:
	_pitch_pivot = Node3D.new()
	_pitch_pivot.name = "PitchPivot"
	_pitch_pivot.position.y = PIVOT_HEIGHT
	add_child(_pitch_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm"
	_spring_arm.spring_length = DISTANCE
	_spring_arm.collision_mask = 1  # world layer only; never the cat or prey
	_spring_arm.margin = 0.3
	_pitch_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_spring_arm.add_child(_camera)
	_camera.current = true

	_apply_angles()

## Points the rig at the node it should follow, starting on top of it so the
## first frame doesn't sweep in from the world origin.
func setup(target: Node3D) -> void:
	_target = target
	if is_inside_tree() and target != null:
		global_position = target.global_position

func get_camera() -> Camera3D:
	return _camera

## Swings the view. Yaw wraps freely; pitch is clamped so the camera can never
## flip over the top or sink under the ground.
func orbit(yaw_delta: float, pitch_delta: float) -> void:
	yaw = wrapf(yaw + yaw_delta, -PI, PI)
	pitch = clampf(pitch + pitch_delta, PITCH_MIN, PITCH_MAX)
	recenter_pause = RECENTER_DELAY
	_apply_angles()

## Eases the view back behind a moving cat. Split out from _process so the test
## can step it with a fixed delta instead of racing the real clock.
func recenter_step(delta: float) -> void:
	if recenter_pause > 0.0:
		recenter_pause = maxf(0.0, recenter_pause - delta)
		return
	if not _target_is_moving():
		return
	# The cat faces its travel direction, so "behind the cat" is half a turn from
	# the way it faces. Ease rather than snap, or every corner would whip the view.
	var behind := wrapf(_target.rotation.y - PI, -PI, PI)
	yaw = lerp_angle(yaw, behind, minf(1.0, RECENTER_RATE * delta))
	_apply_angles()

func _target_is_moving() -> bool:
	if _target == null or not ("velocity" in _target):
		return false
	var travel: Vector3 = _target.velocity
	return Vector2(travel.x, travel.z).length() > MOVING_SPEED

func _apply_angles() -> void:
	rotation.y = yaw
	if _pitch_pivot:
		_pitch_pivot.rotation.x = pitch

func _process(delta: float) -> void:
	if _target == null:
		return
	global_position = global_position.lerp(_target.global_position, FOLLOW_SMOOTHING)
	recenter_step(delta)
	# The cat steers relative to the camera, so it needs the current yaw.
	if "camera_yaw" in _target:
		_target.camera_yaw = yaw

func _unhandled_input(event: InputEvent) -> void:
	# Left-drag to look around. The virtual joystick owns the left half of the
	# screen, so only drags that start on the right half turn the camera --
	# otherwise steering the cat with the mouse would spin the view too.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and event.position.x > _half_screen_width()
	elif event is InputEventMouseMotion and _dragging:
		# Drag right, the view swings right; drag down, the camera rises and
		# looks down. Both are the directions the hand expects.
		orbit(-event.relative.x * DRAG_SENSITIVITY, -event.relative.y * DRAG_SENSITIVITY)

func _half_screen_width() -> float:
	return get_viewport().get_visible_rect().size.x / 2.0
