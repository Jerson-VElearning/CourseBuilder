class_name IDCoursePlayer
extends Control

## Course player: instances the current slide into a prebuilt Stage.
## Chrome look lives in course_player.tscn — this script does not create or restyle UI.
## See: player/course_player.tscn, player/player_chrome.gd, player/player_menu.gd, runtime/course_runtime.gd

## Course to play (ordered slides).
@export var course: IDCourseData

## Control that receives the current slide scene.
@export var stage: Control

## Shown when the course finishes. Leave hidden in the scene.
@export var complete_overlay: CanvasItem

## Optional “Slide area” hint; hidden once a slide is shown.
@export var stage_placeholder: CanvasItem

## Chrome helper that updates Prev/Next/progress. Does not own layout.
@export var chrome: IDPlayerChrome

## Optional table of contents overlay. Assign in the player scene.
@export var menu: IDPlayerMenu

var _current_instance: Node


func _ready() -> void:
	if chrome != null:
		chrome.previous_pressed.connect(_on_previous_pressed)
		chrome.next_pressed.connect(_on_next_pressed)
	if not has_node("/root/IDCourseRuntime"):
		push_error("IDCoursePlayer: IDCourseRuntime autoload is missing.")
		return
	var runtime := IDCourseRuntime
	runtime.slide_entered.connect(_on_slide_entered)
	runtime.slide_completed.connect(_on_progress_changed)
	runtime.course_completed.connect(_on_course_completed)
	runtime.navigation_blocked.connect(_on_navigation_blocked)
	runtime.start_course(course)


func _on_slide_entered(slide_id: String) -> void:
	_show_slide(slide_id)
	_refresh_chrome()


func _on_progress_changed(_slide_id: String) -> void:
	_refresh_chrome()


func _on_course_completed(_success: bool, _score: float) -> void:
	_refresh_chrome()
	if complete_overlay != null:
		complete_overlay.visible = true


func _on_navigation_blocked(reason: String) -> void:
	push_warning("Navigation blocked: %s" % reason)
	_refresh_chrome()


func _refresh_chrome() -> void:
	if chrome != null:
		chrome.refresh()
	if menu != null:
		menu.refresh()


func _on_previous_pressed() -> void:
	IDCourseRuntime.request_previous()


func _on_next_pressed() -> void:
	IDCourseRuntime.request_next()


func _show_slide(slide_id: String) -> void:
	if _current_instance != null:
		if stage != null:
			stage.remove_child(_current_instance)
		_current_instance.queue_free()
		_current_instance = null
	if stage == null or course == null:
		return
	var data := course.get_slide(slide_id)
	if data == null or data.scene == null:
		push_warning("No scene for slide '%s'." % slide_id)
		return
	if stage_placeholder != null:
		stage_placeholder.visible = false
	_current_instance = data.scene.instantiate()
	stage.add_child(_current_instance)
	if _current_instance is Control:
		(_current_instance as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
