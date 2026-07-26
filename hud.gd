extends CanvasLayer
## Minimal in-game HUD: the level task (prey caught / goal) and remaining lives,
## mirroring the tasks panel + lives row from the sketches. Listens to the hunt's
## signals so it stays in sync without reaching into game logic.

var _task_label: Label
var _lives_label: Label

func _ready() -> void:
	_task_label = _make_label(Vector2(24, 20))
	_lives_label = _make_label(Vector2(24, 56))

func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label

func bind(hunt: Node) -> void:
	hunt.progress_changed.connect(_on_progress)
	hunt.lives_changed.connect(_on_lives)

func _on_progress(kills: int, goal: int) -> void:
	_task_label.text = "Task  -  catch prey: %d / %d" % [kills, goal]

func _on_lives(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives
