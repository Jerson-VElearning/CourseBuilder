@tool
class_name IDQuizData
extends Resource

## Storyline-style quiz settings on the course. Question slides opt in via IDQuiz.quiz_id.
## See: resources/course_data.gd, resources/quiz_result.gd, nodes/id_quiz.gd

## Unique id matched by IDQuiz.quiz_id (e.g. "final"). Also SCORM objective id.
@export var quiz_id: String = "":
	set(value):
		if quiz_id == value:
			return
		quiz_id = value
		_update_resource_name()
		emit_changed()

## Author-facing name (e.g. "Final exam").
@export var title: String = "":
	set(value):
		if title == value:
			return
		title = value
		_update_resource_name()
		emit_changed()

## Pass when the quiz is complete and percent is at least this value (0–100).
@export var passing_percent: float = 80.0:
	set(value):
		var next := clampf(value, 0.0, 100.0)
		if is_equal_approx(passing_percent, next):
			return
		passing_percent = next
		emit_changed()

## If true, this quiz is included in the course score rollup for LMS reporting.
@export var report_to_lms: bool = true:
	set(value):
		if report_to_lms == value:
			return
		report_to_lms = value
		emit_changed()

## If true, QUIZ_SUCCESS / SLIDES_AND_QUIZ completion requires this quiz to be complete and passed.
@export var required_to_pass: bool = false:
	set(value):
		if required_to_pass == value:
			return
		required_to_pass = value
		emit_changed()


func _update_resource_name() -> void:
	var label := title if not title.is_empty() else quiz_id
	if resource_name != label:
		resource_name = label
