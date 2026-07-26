extends Control
## Floating virtual joystick for touch input on mobile devices.
## The base appears wherever the player first presses inside this control's
## rect and the thumb tracks from there; releasing hides it again. Provides a
## normalized direction vector that the player script can read.
## Ported from space_scroller's scripts/ui/virtual_joystick.gd (game-agnostic),
## then reworked from a fixed-position joystick to a floating one.

## Radius of the joystick base in pixels
@export var joystick_radius: float = 130.0

## Radius of the thumb (inner circle) in pixels
@export var thumb_radius: float = 55.0

## Color of the joystick base (semi-transparent)
@export var base_color: Color = Color(0.2, 0.22, 0.28, 0.5)

## Color of the thumb indicator
@export var thumb_color: Color = Color(0.85, 0.87, 0.95, 0.9)

## Color of the outline ring drawn around the base and thumb
@export var ring_color: Color = Color(1, 1, 1, 0.8)

## If set, a press landing inside this control's global rect does not
## activate the joystick -- it is left for that control to handle instead
## (used to keep a press on the pause button from also spawning the
## joystick underneath it).
var exclude_control: Control = null

## Current input direction (normalized, or zero if not touching)
var _direction: Vector2 = Vector2.ZERO

## Whether the joystick is currently being touched
var _is_active: bool = false

## Touch index being tracked (-1 if using mouse)
var _touch_index: int = -1

## Center position of the joystick in local coordinates, set to wherever the
## activating press landed
var _center: Vector2 = Vector2.ZERO

## Current thumb position offset from center
var _thumb_offset: Vector2 = Vector2.ZERO

func _draw() -> void:
	# Nothing to draw until a press activates the joystick at a dynamic center.
	if not _is_active:
		return
	# Base: translucent fill plus a bright ring so it reads as a control
	draw_circle(_center, joystick_radius, base_color)
	draw_circle(_center, joystick_radius, ring_color, false, 6.0, true)
	# Thumb knob with an outline
	var thumb_center := _center + _thumb_offset
	draw_circle(thumb_center, thumb_radius, thumb_color)
	draw_circle(thumb_center, thumb_radius, ring_color, false, 4.0, true)

func _input(event: InputEvent) -> void:
	# Handle touch events
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	# Also support mouse for testing on desktop
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_active and _touch_index == -1:
		_handle_mouse_motion(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var local_pos = _get_local_position(event.position)
		if _is_within_control(local_pos) and not _is_excluded(event.position):
			_activate(local_pos, event.index)
	else:
		# Touch released
		if event.index == _touch_index:
			_reset_joystick()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _is_active and event.index == _touch_index:
		var local_pos = _get_local_position(event.position)
		_update_direction(local_pos)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos = _get_local_position(event.position)
			if _is_within_control(local_pos) and not _is_excluded(event.position):
				_activate(local_pos, -1)  # -1 indicates mouse
		else:
			if _touch_index == -1:
				_reset_joystick()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var local_pos = _get_local_position(event.position)
	_update_direction(local_pos)

func _get_local_position(global_pos: Vector2) -> Vector2:
	return global_pos - global_position

func _is_within_control(local_pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(local_pos)

## True if a GLOBAL press position lands on exclude_control, meaning this
## joystick should leave the press alone rather than activate underneath it.
func _is_excluded(global_pos: Vector2) -> bool:
	return exclude_control != null and exclude_control.get_global_rect().has_point(global_pos)

## Activates the joystick with its base centered on the pressed position.
func _activate(local_pos: Vector2, index: int) -> void:
	_is_active = true
	_touch_index = index
	_center = local_pos
	_thumb_offset = Vector2.ZERO
	_direction = Vector2.ZERO
	queue_redraw()

func _update_direction(local_pos: Vector2) -> void:
	var offset = local_pos - _center
	var distance = offset.length()

	# Clamp the offset to the joystick radius
	if distance > joystick_radius:
		offset = offset.normalized() * joystick_radius

	_thumb_offset = offset

	# Calculate normalized direction
	if distance > 0:
		_direction = offset / joystick_radius
	else:
		_direction = Vector2.ZERO

	queue_redraw()

func _reset_joystick() -> void:
	_is_active = false
	_touch_index = -1
	_direction = Vector2.ZERO
	_thumb_offset = Vector2.ZERO
	queue_redraw()

## Returns the current input direction as a normalized vector.
## Called by the player script to get joystick input.
func get_direction() -> Vector2:
	return _direction

## Test helper: inject a direction directly, mirroring fire_button.gd's
## _simulate_press so headless tests can drive input without real touch events.
func set_test_direction(v: Vector2) -> void:
	_direction = v
	_thumb_offset = v * joystick_radius
	queue_redraw()

## Test helper: activate the floating joystick at `center` (local coords) and
## drag the thumb toward `drag_to` (local coords), mirroring a real press +
## drag so headless tests can exercise the floating-center math.
func set_test_touch(center: Vector2, drag_to: Vector2) -> void:
	_activate(center, -1)
	_update_direction(drag_to)
