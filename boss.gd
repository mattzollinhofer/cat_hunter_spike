extends Node3D
## A boss enemy built from the shared Bull model, reskinned per boss -- plus the
## boss fight itself: the bull sleeps until it is woken, then chases the fox,
## takes bite damage, flashes when it loses a life, and falls over when beaten.
##
## The bull's body is flat-colored StandardMaterial3D surfaces (no baked
## texture), so a boss's whole look is just a body color + a size. One
## downloaded model therefore yields a full roster of distinct bosses with no
## extra art.
##
## Fight rules (the game's young designer decided these):
##   * The boss has LIVES lives; each life has HEALTH_PER_LIFE health.
##   * Each bite removes one health. Emptying a life makes the boss FLASH and
##     refills its health for the next life.
##   * Losing the last life defeats it: it plays Death (falls over) and emits
##     `defeated`, which wins the game.

const BULL: PackedScene = preload("res://assets/Bull.gltf")

# The two surfaces that form the bull's coat. Everything else (Hooves, Muzzle,
# Eye_Black, Eye_White, Horns) keeps its original material so a recolored boss
# still reads as a bull, and so the flash only lights up the coat.
const BODY_SURFACES := ["Main", "Main_Light"]

# How close the fox must be for a bite to land on the boss.
const ATTACK_RANGE := 3.0
# The bull ships two flinch clips; alternate them so repeated hits vary.
const HIT_REACTS := ["Idle_HitReact1", "Idle_HitReact2"]

const LIVES := 3
const HEALTH_PER_LIFE := 5

const CHASE_SPEED := 2.5   # how fast the woken bull comes after the fox
const CHASE_STOP := 2.2    # stops this close, so it doesn't stand inside the fox
const HEADBUTT_GAP := 1.6  # seconds between headbutts once it is close
const FLASH_TIME := 0.5    # how long the hurt flash lasts
const BLINK_RATE := 12.0   # flash blinks per second

signal health_changed(lives: int, health: int)
signal hit_cat  # a headbutt landed -> the fox loses one health
signal defeated

var _anim: AnimationPlayer
var _idle_anim := "Idle"
var _cat: Node3D
var _was_bitten := false
var _react_index := 0

var _active := false
var _defeated := false
var _lives := LIVES
var _health := HEALTH_PER_LIFE

var _coat_materials: Array = []
var _coat_base: Array = []
var _flash_time := 0.0
var _headbutt_timer := 0.0

func setup(body_color: Color, size: float, idle_anim: String = "Idle") -> void:
	_idle_anim = idle_anim
	var model: Node3D = BULL.instantiate()
	model.scale = Vector3.ONE * size
	add_child(model)
	_recolor(model, body_color)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	# Idle loops forever; the one-shot clips (flinch, death) play once. Set this
	# explicitly so behaviour doesn't depend on glTF import loop defaults.
	_set_loop(idle_anim, Animation.LOOP_LINEAR)
	for clip in HIT_REACTS:
		_set_loop(clip, Animation.LOOP_NONE)
	_set_loop("Death", Animation.LOOP_NONE)
	_anim.animation_finished.connect(_on_anim_finished)
	if _anim.has_animation(idle_anim):
		_anim.play(idle_anim)

## Wakes the boss so it starts chasing the fox and can take bite damage.
func activate() -> void:
	_active = true
	_headbutt_timer = HEADBUTT_GAP
	health_changed.emit(_lives, _health)

## Applies one bite of damage. Does nothing unless the boss is awake and alive.
func hit() -> void:
	if not _active or _defeated:
		return
	_play_hit_react()
	_health -= 1
	if _health <= 0:
		_lives -= 1
		if _lives <= 0:
			_lives = 0
			_health = 0
			_defeat()
		else:
			_health = HEALTH_PER_LIFE
			_start_flash()
	health_changed.emit(_lives, _health)

func get_lives() -> int:
	return _lives

func get_health() -> int:
	return _health

func is_flashing() -> bool:
	return _flash_time > 0.0

func is_defeated() -> bool:
	return _defeated

func get_current_anim() -> String:
	return _anim.current_animation if _anim else ""

func _process(delta: float) -> void:
	if _anim == null:
		return
	_update_flash(delta)
	if not _active or _defeated:
		return
	if _cat == null or not is_instance_valid(_cat):
		_cat = get_tree().get_first_node_in_group("cat") as Node3D
		if _cat == null:
			return
	_chase(delta)
	_detect_bite()

func _chase(delta: float) -> void:
	var to_cat := _cat.global_position - global_position
	to_cat.y = 0.0
	var dist := to_cat.length()
	_face(_cat.global_position)
	if dist > CHASE_STOP:
		var step := minf(CHASE_SPEED * delta, dist - CHASE_STOP)
		global_position += to_cat.normalized() * step
		_locomote("Walk")
	else:
		# Close enough to attack: headbutt the fox on a gentle cadence. Each
		# headbutt lands, so the fox loses one health per swing rather than per
		# frame spent standing next to the bull.
		_headbutt_timer -= delta
		if _headbutt_timer <= 0.0:
			_headbutt_timer = HEADBUTT_GAP
			if _anim.has_animation("Attack_Headbutt"):
				_anim.play("Attack_Headbutt")
			hit_cat.emit()
		else:
			_locomote(_idle_anim)

func _detect_bite() -> void:
	var in_reach := global_position.distance_to(_cat.global_position) < ATTACK_RANGE
	var bitten: bool = in_reach and _cat.is_biting
	if bitten and not _was_bitten:
		hit()
	_was_bitten = bitten

func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if not flat.is_equal_approx(global_position):
		look_at(flat, Vector3.UP)

## Plays a looping locomotion clip, but never cuts off a one-shot (flinch,
## headbutt, death) that is still playing.
func _locomote(clip: String) -> void:
	if _is_busy_anim(_anim.current_animation):
		return
	if _anim.current_animation != clip and _anim.has_animation(clip):
		_set_loop(clip, Animation.LOOP_LINEAR)
		_anim.play(clip)

func _is_busy_anim(anim_name: String) -> bool:
	return anim_name == "Death" or anim_name == "Attack_Headbutt" or HIT_REACTS.has(anim_name)

func _play_hit_react() -> void:
	var clip: String = HIT_REACTS[_react_index % HIT_REACTS.size()]
	_react_index += 1
	if _anim.has_animation(clip):
		_anim.play(clip)

func _defeat() -> void:
	_defeated = true
	if _anim.has_animation("Death"):
		_anim.play("Death")
	defeated.emit()

func _on_anim_finished(anim_name: String) -> void:
	# A defeated bull stays down; otherwise settle back into the looping idle.
	if _defeated:
		return
	if anim_name != _idle_anim and _anim.has_animation(_idle_anim):
		_anim.play(_idle_anim)

func _start_flash() -> void:
	_flash_time = FLASH_TIME

func _update_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time -= delta
	var lit := int(_flash_time * BLINK_RATE) % 2 == 0
	for i in _coat_materials.size():
		_coat_materials[i].albedo_color = Color.WHITE if lit else _coat_base[i]
	if _flash_time <= 0.0:
		for i in _coat_materials.size():
			_coat_materials[i].albedo_color = _coat_base[i]

func _set_loop(clip: String, mode: int) -> void:
	if _anim.has_animation(clip):
		_anim.get_animation(clip).loop_mode = mode

func _recolor(root: Node, body_color: Color) -> void:
	_coat_materials.clear()
	_coat_base.clear()
	for mesh_instance in _mesh_instances(root):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material == null:
				continue
			if not BODY_SURFACES.has(material.resource_name):
				continue
			var tinted := material.duplicate() as StandardMaterial3D
			# "Main" is the coat; "Main_Light" is the lighter underside. Lighten the
			# same color for the underside so the boss keeps the bull's two-tone
			# shading instead of flattening to one slab of color.
			var col: Color = body_color if material.resource_name == "Main" else body_color.lightened(0.3)
			tinted.albedo_color = col
			mesh_instance.set_surface_override_material(surface, tinted)
			_coat_materials.append(tinted)
			_coat_base.append(col)

func _mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_mesh_instances(child))
	return out
