extends CanvasLayer
## Mobile touch controls: a floating virtual joystick for movement, a
## momentary Pounce button, and a toggle Stalk button. Mirrors space_scroller's
## touch UI pattern (Control nodes drawn with _draw() and read via _input(),
## exposing plain getters the cat controller polls each physics frame). The
## Pounce and Stalk buttons are always visible; the joystick only appears
## once pressed, wherever that press lands in the left half of the screen.
## All controls also accept mouse input, so this works in a desktop browser too.

const MARGIN := 40.0
const BUTTON_SIZE := 170.0
const BUTTON_GAP := 20.0

## Circular touch/mouse button, drawn and read like fire_button.gd. In
## momentary mode is_pressed() reflects the held state and consume_press()
## reports a one-shot "just pressed" edge (used for Pounce). In toggle mode a
## tap flips is_on(), which then holds until tapped again (used for Stalk).
class TouchButton extends Control:
	var toggle_mode: bool = false
	var fill_color: Color = Color(0.2, 0.22, 0.28, 0.5)
	var ring_color: Color = Color(1, 1, 1, 0.8)
	var core_color: Color = Color(0.85, 0.87, 0.95, 0.9)
	var core_on_color: Color = Color(0.4, 1, 0.55, 1)

	var _is_pressed: bool = false
	var _is_on: bool = false
	var _just_pressed: bool = false
	var _touch_index: int = -2

	func _draw() -> void:
		var button_center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 6.0
		draw_circle(button_center, radius, fill_color)
		draw_circle(button_center, radius, ring_color, false, 6.0, true)
		var lit := _is_on if toggle_mode else _is_pressed
		var core := core_on_color if lit else core_color
		draw_circle(button_center, radius * 0.42, core)

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_handle_touch(event)
		elif event is InputEventMouseButton:
			_handle_mouse_button(event)

	func _handle_touch(event: InputEventScreenTouch) -> void:
		if event.pressed:
			var local_pos = _get_local_position(event.position)
			if _is_within_bounds(local_pos):
				_press(event.index)
		else:
			if event.index == _touch_index:
				_release()

	func _handle_mouse_button(event: InputEventMouseButton) -> void:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = _get_local_position(event.position)
				if _is_within_bounds(local_pos):
					_press(-1)
			else:
				if _touch_index == -1:
					_release()

	func _get_local_position(global_pos: Vector2) -> Vector2:
		return global_pos - global_position

	func _is_within_bounds(local_pos: Vector2) -> bool:
		return local_pos.x >= 0 and local_pos.x <= size.x and \
			   local_pos.y >= 0 and local_pos.y <= size.y

	func _press(index: int) -> void:
		_is_pressed = true
		_just_pressed = true
		_touch_index = index
		if toggle_mode:
			_is_on = not _is_on
		queue_redraw()

	func _release() -> void:
		_is_pressed = false
		_touch_index = -2
		queue_redraw()

	func is_pressed() -> bool:
		return _is_pressed

	func is_on() -> bool:
		return _is_on

	## Returns true exactly once per press (edge-triggered); for momentary buttons.
	func consume_press() -> bool:
		if _just_pressed:
			_just_pressed = false
			return true
		return false

	## Test helper: simulate a press/release, mirroring fire_button.gd's _simulate_press.
	func _simulate_press(pressed: bool) -> void:
		if pressed:
			_press(-1)
		else:
			_release()

	## Test helper: force a toggle button directly to a known on/off state.
	func _simulate_toggle(on: bool) -> void:
		_is_on = on
		queue_redraw()


var _joystick: Control
var _pounce_button: TouchButton
var _stalk_button: TouchButton

func _ready() -> void:
	_build_joystick()
	_build_pounce_button()
	_build_stalk_button()

func _build_joystick() -> void:
	_joystick = Control.new()
	_joystick.name = "VirtualJoystick"
	_joystick.set_script(load("res://ui/virtual_joystick.gd"))
	_joystick.joystick_radius = 90.0
	_joystick.thumb_radius = 40.0
	# Cover the left half of the screen with no offsets, so the floating
	# joystick can appear wherever the player presses in that region.
	_joystick.anchor_left = 0.0
	_joystick.anchor_top = 0.0
	_joystick.anchor_right = 0.5
	_joystick.anchor_bottom = 1.0
	add_child(_joystick)

func _build_pounce_button() -> void:
	_pounce_button = TouchButton.new()
	_pounce_button.name = "PounceButton"
	_pounce_button.fill_color = Color(0.7, 0.15, 0.15, 0.5)
	_pounce_button.core_color = Color(1, 0.45, 0.3, 0.9)
	_pounce_button.core_on_color = Color(1, 0.8, 0.4, 1)
	_position_bottom_right(_pounce_button, -MARGIN)
	add_child(_pounce_button)

func _build_stalk_button() -> void:
	_stalk_button = TouchButton.new()
	_stalk_button.name = "StalkButton"
	_stalk_button.toggle_mode = true
	_stalk_button.fill_color = Color(0.15, 0.35, 0.25, 0.5)
	_stalk_button.core_color = Color(0.5, 0.8, 0.6, 0.9)
	_stalk_button.core_on_color = Color(0.4, 1, 0.55, 1)
	# Stacked above the pounce button, sharing its right edge.
	_position_bottom_right(_stalk_button, _pounce_button.offset_top - BUTTON_GAP)
	add_child(_stalk_button)

func _position_bottom_right(button: TouchButton, bottom_offset: float) -> void:
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_right = -MARGIN
	button.offset_left = button.offset_right - BUTTON_SIZE
	button.offset_bottom = bottom_offset
	button.offset_top = button.offset_bottom - BUTTON_SIZE

## Returns the current joystick direction (normalized, zero if not touching).
func get_move_direction() -> Vector2:
	return _joystick.get_direction()

## Returns whether the stalk toggle is currently on.
func is_stalk_on() -> bool:
	return _stalk_button.is_on()

## Returns true exactly once per pounce button press (one-shot).
func consume_pounce() -> bool:
	return _pounce_button.consume_press()

## Excludes taps landing on `control` from activating the joystick, so a tap
## on that control (e.g. the pause button) isn't also swallowed by the
## joystick underneath it.
func set_joystick_exclude(control: Control) -> void:
	_joystick.exclude_control = control

## Test helper: inject a joystick direction without real touch input.
func set_test_move(v: Vector2) -> void:
	_joystick.set_test_direction(v)

## Test helper: activate the floating joystick at `center` and drag its
## thumb toward `drag_to` (both local coordinates), without real touch input.
func set_test_floating(center: Vector2, drag_to: Vector2) -> void:
	_joystick.set_test_touch(center, drag_to)

## Test helper: force the stalk toggle to a known state.
func set_test_stalk(on: bool) -> void:
	_stalk_button._simulate_toggle(on)

## Test helper: simulate a pounce button tap.
func press_pounce() -> void:
	_pounce_button._simulate_press(true)
	_pounce_button._simulate_press(false)
