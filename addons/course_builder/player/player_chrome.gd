class_name IDPlayerChrome
extends Control

## Updates Prev/Next enabled state and progress text.
## Does not create, move, or restyle controls — those live in the player scene.
## See: player/course_player.tscn, player/course_player.gd

signal previous_pressed
signal next_pressed

## Scene buttons/label. Assign in the inspector so they can be moved anywhere.
@export var previous_button: Button
@export var next_button: Button
@export var progress_label: Label


func _ready() -> void:
	if previous_button != null:
		previous_button.pressed.connect(func() -> void: previous_pressed.emit())
	if next_button != null:
		next_button.pressed.connect(func() -> void: next_pressed.emit())


## Sync chrome with runtime rules. Does not decide completion.
func refresh() -> void:
	if not has_node("/root/IDCourseRuntime"):
		return
	var runtime := IDCourseRuntime
	if previous_button != null:
		previous_button.disabled = not runtime.can_go_previous()
	if next_button != null:
		next_button.disabled = not runtime.can_go_next()
	if progress_label != null:
		var index: int = runtime.get_progress_index()
		var count: int = runtime.get_progress_count()
		var current: int = 0 if index < 0 else index + 1
		progress_label.text = "%d / %d" % [current, count]
		if runtime.is_course_finished():
			progress_label.text = "Complete"
			if next_button != null:
				next_button.disabled = true
