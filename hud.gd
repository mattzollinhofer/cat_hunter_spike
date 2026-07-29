extends CanvasLayer
## In-game HUD, laid out to match the kid's sketch: the level name centered at
## the top, lives as a row of diamond icons top-left, a tasks panel (heading +
## objective) on the right, and a "Paws" pause button bottom-left that raises a
## full-screen pause overlay. Listens to the hunt's signals so it stays in sync
## without reaching into game logic.
##
## process_mode is ALWAYS so the pause button and overlay keep responding to
## input while get_tree().paused is true -- otherwise this CanvasLayer (and
## everything under it) would freeze along with the rest of the game.

const PANEL_MARGIN := 16.0
const PAUSE_BUTTON_SIZE := Vector2(112, 56)

## Draws one filled diamond per remaining life in a horizontal row.
class LivesDisplay extends Control:
	const DIAMOND_SIZE := Vector2(20, 26)
	const DIAMOND_GAP := 8.0

	var _lives := 0

	func set_lives(lives: int) -> void:
		_lives = maxi(lives, 0)
		custom_minimum_size = Vector2(
			_lives * DIAMOND_SIZE.x + maxi(_lives - 1, 0) * DIAMOND_GAP,
			DIAMOND_SIZE.y,
		)
		queue_redraw()

	func get_lives() -> int:
		return _lives

	func _draw() -> void:
		for i in _lives:
			var left := i * (DIAMOND_SIZE.x + DIAMOND_GAP)
			var cx := left + DIAMOND_SIZE.x / 2.0
			var points := PackedVector2Array([
				Vector2(cx, 0),
				Vector2(left + DIAMOND_SIZE.x, DIAMOND_SIZE.y / 2.0),
				Vector2(cx, DIAMOND_SIZE.y),
				Vector2(left, DIAMOND_SIZE.y / 2.0),
			])
			draw_colored_polygon(points, Color(0.95, 0.25, 0.35))
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
				Color(1, 1, 1, 0.9), 2.0, true)


## Bottom-left "Paws" button: tap to toggle get_tree().paused. Mirrors the
## touch/mouse handling in ui/touch_controls.gd's TouchButton and
## space_scroller's fire_button.gd.
class PauseButton extends Control:
	signal pressed

	var _touch_index := -2

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.05, 0.08, 0.12, 0.7), true)
		draw_rect(rect, Color(1, 1, 1, 0.5), false, 2.0, true)
		_draw_pause_bars()
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 6), "Paws",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)

	func _draw_pause_bars() -> void:
		var bar_size := Vector2(size.x * 0.09, size.y * 0.32)
		var gap := size.x * 0.06
		var cy := size.y * 0.34
		var cx := size.x / 2.0
		draw_rect(Rect2(Vector2(cx - gap - bar_size.x, cy - bar_size.y / 2.0), bar_size), Color.WHITE)
		draw_rect(Rect2(Vector2(cx + gap, cy - bar_size.y / 2.0), bar_size), Color.WHITE)

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_handle_touch(event)
		elif event is InputEventMouseButton:
			_handle_mouse_button(event)

	func _handle_touch(event: InputEventScreenTouch) -> void:
		if event.pressed:
			if _is_within_bounds(_local_position(event.position)):
				_touch_index = event.index
				pressed.emit()
		elif event.index == _touch_index:
			_touch_index = -2

	func _handle_mouse_button(event: InputEventMouseButton) -> void:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _is_within_bounds(_local_position(event.position)):
				_touch_index = -1
				pressed.emit()
		elif _touch_index == -1:
			_touch_index = -2

	func _local_position(global_pos: Vector2) -> Vector2:
		return global_pos - global_position

	func _is_within_bounds(local_pos: Vector2) -> bool:
		return local_pos.x >= 0 and local_pos.x <= size.x and \
			   local_pos.y >= 0 and local_pos.y <= size.y

	## True if a GLOBAL point hits this button, using the same inclusive bounds
	## as the button's own input hit-test. The pause overlay defers to this so a
	## tap on the button can't fire both the overlay and the button handlers.
	func contains_global_point(global_pos: Vector2) -> bool:
		return _is_within_bounds(_local_position(global_pos))

	## Test helper: simulate a tap without real input, mirroring
	## ui/touch_controls.gd's TouchButton._simulate_press.
	func _simulate_press() -> void:
		pressed.emit()


## Full-screen dim + "Paused" message shown while get_tree().paused is true.
## Tapping anywhere resumes, except over the pause button itself -- that tap
## is left for the button's own handler so a tap on the button while the
## overlay is up doesn't fire both handlers at once.
class PauseOverlay extends Control:
	signal resume_requested

	var pause_button: PauseButton

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55), true)

	func _input(event: InputEvent) -> void:
		if not visible:
			return
		if event is InputEventScreenTouch:
			_handle_touch(event)
		elif event is InputEventMouseButton:
			_handle_mouse_button(event)

	func _handle_touch(event: InputEventScreenTouch) -> void:
		if event.pressed:
			_maybe_resume(event.position)

	func _handle_mouse_button(event: InputEventMouseButton) -> void:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_maybe_resume(event.position)

	## Resumes on any tap outside the pause button's own rect; a tap on the
	## button itself is left for the button's handler to resume.
	func _maybe_resume(pos: Vector2) -> void:
		if pause_button and pause_button.contains_global_point(pos):
			return
		resume_requested.emit()

	## Test helper: simulate a tap on the overlay without real input.
	func _simulate_tap() -> void:
		resume_requested.emit()


var _level_label: Label
var _task_label: Label
var _lives_display: LivesDisplay
var _pause_button: PauseButton
var _pause_overlay: PauseOverlay
var _win_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_level_title()
	_build_lives()
	_build_tasks()
	_build_pause_button()
	_build_pause_overlay()
	_build_win_banner()

func bind(hunt: Node) -> void:
	hunt.progress_changed.connect(_on_progress)
	hunt.lives_changed.connect(_on_lives)

func set_level_name(level_name: String) -> void:
	_level_label.text = level_name

## Test getters -- read what the widgets are currently displaying without
## reaching into private fields.
func get_level_title() -> String:
	return _level_label.text

func get_task_text() -> String:
	return _task_label.text

func get_lives_count() -> int:
	return _lives_display.get_lives()

## Test helper: simulate a tap on the pause button without real input.
func simulate_pause_press() -> void:
	_pause_button._simulate_press()

## Returns the pause button control, so callers (e.g. the touch controls'
## floating joystick) can exclude its rect from their own hit-testing.
func get_pause_button() -> Control:
	return _pause_button

## Switches the task to the boss fight and shows the bull's remaining lives and
## the health left in the current life.
func set_boss_health(lives: int, health: int) -> void:
	_task_label.text = "Beat the bull!   Lives: %d   Health: %d" % [lives, health]

## Big centered "YOU WIN!" once the bull is beaten.
func show_win() -> void:
	_win_label.visible = true
	_task_label.text = "You beat the bull!"

## Test getter for the win banner's visibility.
func is_win_shown() -> bool:
	return _win_label.visible

func _build_win_banner() -> void:
	# Hidden until the bull is beaten, then a big celebratory banner over the game.
	_win_label = _make_label("YOU WIN!", 56, Color(1, 0.86, 0.4))
	_win_label.anchor_right = 1.0
	_win_label.anchor_bottom = 1.0
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_label.visible = false
	add_child(_win_label)

func _on_progress(kills: int, goal: int) -> void:
	_task_label.text = "Catch prey   %d / %d" % [kills, goal]

func _on_lives(lives: int) -> void:
	_lives_display.set_lives(lives)

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_overlay.visible = get_tree().paused

func _build_level_title() -> void:
	# Level name centered at the top, per the sketch.
	_level_label = _make_label("", 26, Color(1, 0.86, 0.4))
	_level_label.anchor_left = 0.0
	_level_label.anchor_right = 1.0
	_level_label.offset_top = PANEL_MARGIN
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_level_label)

func _build_lives() -> void:
	# Lives diamonds in the top-left corner, per the sketch.
	var panel := _make_lives_panel()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = PANEL_MARGIN
	panel.offset_top = PANEL_MARGIN
	add_child(panel)

func _build_tasks() -> void:
	# Tasks panel (with the level name) on the right side, per the sketch. Anchored
	# to the right edge and grown leftward so it stays right-aligned as it resizes.
	var panel := _make_tasks_panel()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_top = PANEL_MARGIN
	add_child(panel)

func _make_tasks_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var heading := _make_label("Tasks", 16, Color(0.85, 0.85, 0.9))
	vbox.add_child(heading)

	_task_label = _make_label("Catch prey   0 / 0", 20, Color.WHITE)
	vbox.add_child(_task_label)

	return panel

func _make_lives_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	hbox.add_child(_make_label("Lives", 16, Color(0.85, 0.85, 0.9)))

	_lives_display = LivesDisplay.new()
	hbox.add_child(_lives_display)

	return panel

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.62)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	return style

func _build_pause_button() -> void:
	# Pause in the bottom-left corner, per the sketch.
	_pause_button = PauseButton.new()
	_pause_button.anchor_left = 0.0
	_pause_button.anchor_right = 0.0
	_pause_button.anchor_top = 1.0
	_pause_button.anchor_bottom = 1.0
	_pause_button.offset_left = PANEL_MARGIN
	_pause_button.offset_right = PANEL_MARGIN + PAUSE_BUTTON_SIZE.x
	_pause_button.offset_top = -PANEL_MARGIN - PAUSE_BUTTON_SIZE.y
	_pause_button.offset_bottom = -PANEL_MARGIN
	_pause_button.pressed.connect(_toggle_pause)
	add_child(_pause_button)

func _build_pause_overlay() -> void:
	_pause_overlay = PauseOverlay.new()
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.pause_button = _pause_button
	_pause_overlay.visible = false
	_pause_overlay.resume_requested.connect(_toggle_pause)
	add_child(_pause_overlay)

	var message := _make_label("Paused", 40, Color.WHITE)
	message.anchor_right = 1.0
	message.offset_top = 160
	message.offset_bottom = 210
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_overlay.add_child(message)

	var hint := _make_label("tap to resume", 20, Color(0.85, 0.85, 0.9))
	hint.anchor_right = 1.0
	hint.offset_top = 210
	hint.offset_bottom = 240
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_overlay.add_child(hint)
