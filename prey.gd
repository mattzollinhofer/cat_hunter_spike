extends CharacterBody3D
## Prey (squirrel stand-in): grazes until the cat gets close, then flees.
##
## The tuning is the whole game: the cat can only catch prey by POUNCING within
## CATCH_RADIUS. Walking toward prey is detected far away (BASE_DETECT) and prey
## flees faster than a walk, so a straight chase never works. Stalking shrinks
## the detection range (STALK_DETECT) enough to sneak into pounce range. That is
## the stalk-then-pounce loop from the sketches.

signal caught

const BASE_DETECT := 7.0     # spotted this far off while the cat walks
const STALK_DETECT := 3.0    # ...only this far while the cat stalks (quiet)
const PANIC := 1.6           # always bolts if the cat is this close
const FLEE_SPEED := 6.0      # faster than a walk, slower than a pounce
const CATCH_RADIUS := 1.3
const GRAVITY := 22.0

enum { GRAZE, FLEE }

var target: Node3D  # the cat
var _state := GRAZE

func _ready() -> void:
	# Layer 4 = prey, mask 1 = world/ground only. Prey never physically collides
	# with the cat (layer 2) or other prey — catching is distance-based.
	collision_layer = 4
	collision_mask = 1
	add_to_group("prey")
	_build_body()

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 0.7
	col.shape = shape
	col.position.y = 0.35
	add_child(col)
	var mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.28)  # squirrel brown
	body.material = mat
	mesh.mesh = body
	mesh.position.y = 0.35
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var flat := Vector2(
		global_position.x - target.global_position.x,
		global_position.z - target.global_position.z)
	var dist := flat.length()
	var detect: float = STALK_DETECT if target.is_stalking else BASE_DETECT
	if _state == GRAZE and (dist < PANIC or dist < detect):
		_state = FLEE

	if _state == FLEE and flat.length() > 0.001:
		var away := Vector3(flat.x, 0.0, flat.y).normalized()
		velocity.x = away.x * FLEE_SPEED
		velocity.z = away.z * FLEE_SPEED
		rotation.y = atan2(away.x, away.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if target.is_pouncing and dist < CATCH_RADIUS:
		caught.emit()
		queue_free()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func get_state() -> int:
	return _state
