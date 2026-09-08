@tool
extends EditorPlugin

## Editor entry point for CourseBuilder.
## Registers custom node types and the Course Viewer bottom panel.
## See: nodes/id_slide.gd, nodes/id_quiz_mc.gd, nodes/id_choice.gd, editor/course_viewer.gd

const SLIDE_SCRIPT := preload("res://addons/course_builder/nodes/id_slide.gd")
const BUTTON_SCRIPT := preload("res://addons/course_builder/nodes/id_button.gd")
const REVEAL_SCRIPT := preload("res://addons/course_builder/nodes/id_reveal.gd")
const ANIMATED_SCRIPT := preload("res://addons/course_builder/nodes/id_animated.gd")
const QUIZ_MC_SCRIPT := preload("res://addons/course_builder/nodes/id_quiz_mc.gd")
const CHOICE_SCRIPT := preload("res://addons/course_builder/nodes/id_choice.gd")
const COURSE_VIEWER_SCENE := preload("res://addons/course_builder/editor/course_viewer.tscn")

var _course_viewer: Control


func _enter_tree() -> void:
	add_custom_type("IDSlide", "Control", SLIDE_SCRIPT, null)
	add_custom_type("IDButton", "Button", BUTTON_SCRIPT, null)
	add_custom_type("IDReveal", "Button", REVEAL_SCRIPT, null)
	add_custom_type("IDAnimated", "Control", ANIMATED_SCRIPT, null)
	add_custom_type("IDQuiz_MC", "Control", QUIZ_MC_SCRIPT, null)
	add_custom_type("IDChoice", "Button", CHOICE_SCRIPT, null)
	_course_viewer = COURSE_VIEWER_SCENE.instantiate()
	add_control_to_bottom_panel(_course_viewer, "Course Viewer")
	if _course_viewer.has_method("setup"):
		_course_viewer.setup(self)


func _exit_tree() -> void:
	if _course_viewer != null:
		remove_control_from_bottom_panel(_course_viewer)
		_course_viewer.queue_free()
		_course_viewer = null
	remove_custom_type("IDSlide")
	remove_custom_type("IDButton")
	remove_custom_type("IDReveal")
	remove_custom_type("IDAnimated")
	remove_custom_type("IDQuiz_MC")
	remove_custom_type("IDChoice")
