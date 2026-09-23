@tool
class_name IDLmsSettings
extends Resource

## ID-facing LMS tracking settings on the course. Presets write completion_by and quiz flags.
## A later SCORM package is built only when you click Publish SCORM; HTML5 uses the SCORM 1.2 backend, editor Play logs debug.
## See: resources/course_data.gd, editor/course_viewer.gd, tracking/debug_tracking_backend.gd

const _IDENTIFIER_REGEX := "^[A-Za-z0-9._-]+$"

@export_group("LMS")
## Off = no tracking. Other presets rewrite Completion By and quiz Report To Lms.
@export var preset: IDEnums.LmsPreset = IDEnums.LmsPreset.OFF:
	set(value):
		if preset == value:
			return
		preset = value
		notify_property_list_changed()
		emit_changed()

## Manifest / display title. Empty = validator suggests the first slide title.
@export var course_title: String = "":
	set(value):
		if course_title == value:
			return
		course_title = value
		emit_changed()

## LMS package id. Letters, digits, underscore, hyphen, and period only.
@export var identifier: String = "":
	set(value):
		if identifier == value:
			return
		identifier = value
		emit_changed()

## Bookmark the current slide_id for a later resume.
@export var resume: bool = true:
	set(value):
		if resume == value:
			return
		resume = value
		emit_changed()

## Send question-level interaction records.
@export var report_interactions: bool = false:
	set(value):
		if report_interactions == value:
			return
		report_interactions = value
		emit_changed()

## Last Web export folder chosen in Publish SCORM. Editor-only.
@export_storage var last_export_dir: String = ""

## Last zip path chosen in Publish SCORM. Editor-only.
@export_storage var last_zip_path: String = ""

@export_group("Advanced")
## Shown only when Preset is Custom. Not stored.
@export_multiline var advanced_hint: String = "Edit Completion By and Quizzes on this course resource."


func _validate_property(property: Dictionary) -> void:
	if property.name != "advanced_hint":
		return
	if preset == IDEnums.LmsPreset.CUSTOM:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	else:
		property.usage = PROPERTY_USAGE_NONE


## True when Play should use the debug tracking backend.
func is_tracking_enabled() -> bool:
	return preset != IDEnums.LmsPreset.OFF


static func is_safe_id(value: String) -> bool:
	if value.is_empty():
		return false
	var re := RegEx.new()
	if re.compile(_IDENTIFIER_REGEX) != OK:
		return false
	return re.search(value) != null


## Writes existing course / quiz flags for Awareness, Graded exam, and Knowledge checks.
## Off and Custom leave those fields alone.
func apply_to_course(course: IDCourseData) -> void:
	if course == null:
		return
	match preset:
		IDEnums.LmsPreset.AWARENESS:
			course.completion_by = IDEnums.CourseCompletionBy.REQUIRED_SLIDES
			_set_all_quizzes_report(course, false)
			resume = true
			report_interactions = false
		IDEnums.LmsPreset.GRADED_EXAM:
			course.completion_by = IDEnums.CourseCompletionBy.SLIDES_AND_QUIZ
			_set_graded_exam_report(course)
			resume = true
			report_interactions = true
		IDEnums.LmsPreset.KNOWLEDGE_CHECKS:
			course.completion_by = IDEnums.CourseCompletionBy.REQUIRED_SLIDES
			_set_all_quizzes_report(course, false)
			resume = true
			report_interactions = true
		_:
			return
	course.emit_changed()
	emit_changed()


func summary_text(course: IDCourseData) -> String:
	if not is_tracking_enabled():
		return "Tracking off."
	var finish := "required slides"
	if course != null:
		match course.completion_by:
			IDEnums.CourseCompletionBy.QUIZ_SUCCESS:
				finish = "quiz"
			IDEnums.CourseCompletionBy.SLIDES_AND_QUIZ:
				finish = "slides + quiz"
			_:
				finish = "required slides"
	var score := "none"
	if course != null:
		var percents: PackedStringArray = []
		for quiz_data in course.quizzes:
			if quiz_data == null or quiz_data.quiz_id.is_empty() or not quiz_data.report_to_lms:
				continue
			percents.append("%d%%" % int(quiz_data.passing_percent))
		if not percents.is_empty():
			score = ", ".join(percents)
	var resume_text := "on" if resume else "off"
	return "Finish: %s. Score: %s. Resume: %s." % [finish, score, resume_text]


func _set_all_quizzes_report(course: IDCourseData, report: bool) -> void:
	for quiz_data in course.quizzes:
		if quiz_data == null:
			continue
		quiz_data.report_to_lms = report


func _set_graded_exam_report(course: IDCourseData) -> void:
	var any_required := false
	for quiz_data in course.quizzes:
		if quiz_data != null and not quiz_data.quiz_id.is_empty() and quiz_data.required_to_pass:
			any_required = true
			break
	for quiz_data in course.quizzes:
		if quiz_data == null or quiz_data.quiz_id.is_empty():
			continue
		if any_required:
			quiz_data.report_to_lms = quiz_data.required_to_pass
		else:
			quiz_data.report_to_lms = true
