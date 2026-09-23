class_name IDLmsValidator
extends RefCounted

## Editor-only checks for LMS ids, quiz wiring, and choice tokens.
## Course Viewer runs this; it does not change resources.
## See: editor/course_viewer.gd, resources/lms_settings.gd, runtime/course_runtime.gd

const _QUIZ_SCRIPTS := ["/id_quiz.gd", "/id_quiz_mc.gd"]
const _CHOICE_SCRIPT := "/id_choice.gd"


func validate(course: IDCourseData) -> PackedStringArray:
	var warnings: PackedStringArray = []
	if course == null:
		warnings.append("No course loaded.")
		return warnings
	var lms := course.lms
	_check_lms_identity(lms, course, warnings)
	_check_slide_ids(course, warnings)
	_check_quiz_rows(course, warnings)
	_check_preset_and_completion(course, lms, warnings)
	_scan_slide_scenes(course, warnings)
	return warnings


func _check_lms_identity(lms: IDLmsSettings, course: IDCourseData, warnings: PackedStringArray) -> void:
	if lms == null or not lms.is_tracking_enabled():
		return
	if lms.identifier.is_empty():
		var suggestion := ""
		if not lms.course_title.is_empty():
			suggestion = lms.course_title
		elif course.slides.size() > 0 and course.slides[0] != null:
			suggestion = course.slides[0].title
		if suggestion.is_empty():
			warnings.append("Set LMS Identifier (letters, digits, _, -, .).")
		else:
			warnings.append("Set LMS Identifier (letters, digits, _, -, .). First slide title: \"%s\"." % suggestion)
	elif not IDLmsSettings.is_safe_id(lms.identifier):
		warnings.append("LMS Identifier \"%s\" has spaces or illegal characters." % lms.identifier)


func _check_slide_ids(course: IDCourseData, warnings: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for i in course.slides.size():
		var data: IDSlideData = course.slides[i]
		var label := "Slide %d" % (i + 1)
		if data == null:
			warnings.append("%s is empty." % label)
			continue
		if not data.title.is_empty():
			label = data.title
		if data.slide_id.is_empty():
			warnings.append("%s has an empty Slide Id." % label)
			continue
		if not IDLmsSettings.is_safe_id(data.slide_id):
			warnings.append("Slide Id \"%s\" has spaces or illegal characters." % data.slide_id.strip_edges())
		if seen.has(data.slide_id):
			warnings.append("Duplicate Slide Id \"%s\"." % data.slide_id)
		else:
			seen[data.slide_id] = true


func _check_quiz_rows(course: IDCourseData, warnings: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for quiz_data in course.quizzes:
		if quiz_data == null:
			continue
		if quiz_data.quiz_id.is_empty():
			var row_label := quiz_data.title if not quiz_data.title.is_empty() else "a quiz row"
			warnings.append("Quiz \"%s\" has an empty Quiz Id." % row_label)
			continue
		if not IDLmsSettings.is_safe_id(quiz_data.quiz_id):
			warnings.append("Quiz Id \"%s\" has spaces or illegal characters." % quiz_data.quiz_id)
		if seen.has(quiz_data.quiz_id):
			warnings.append("Duplicate Quiz Id \"%s\"." % quiz_data.quiz_id)
		else:
			seen[quiz_data.quiz_id] = true


func _check_preset_and_completion(course: IDCourseData, lms: IDLmsSettings, warnings: PackedStringArray) -> void:
	if lms != null and lms.preset == IDEnums.LmsPreset.GRADED_EXAM and course.quizzes.is_empty():
		warnings.append("Graded exam preset needs at least one quiz on the course.")
	var needs_quiz := course.completion_by == IDEnums.CourseCompletionBy.QUIZ_SUCCESS \
		or course.completion_by == IDEnums.CourseCompletionBy.SLIDES_AND_QUIZ
	if needs_quiz:
		var any_required := false
		for quiz_data in course.quizzes:
			if quiz_data != null and not quiz_data.quiz_id.is_empty() and quiz_data.required_to_pass:
				any_required = true
				break
		if not any_required:
			warnings.append("Completion By is quiz-based but no quiz is Required To Pass.")


func _scan_slide_scenes(course: IDCourseData, warnings: PackedStringArray) -> void:
	var members: Dictionary = {}
	for data in course.slides:
		if data == null or data.scene == null:
			continue
		var meta := _read_scene_meta(data.scene)
		var slide_label := data.slide_id if not data.slide_id.is_empty() else data.title
		if slide_label.is_empty():
			slide_label = data.scene.resource_path
		for choice_name in meta["empty_choice_ids"]:
			warnings.append("%s: IDChoice \"%s\" has an empty Choice Id." % [slide_label, choice_name])
		var qid: String = str(meta.get("quiz_id", ""))
		if qid.is_empty():
			continue
		if course.get_quiz(qid) == null:
			warnings.append("%s Quiz Id \"%s\" does not match a course quiz row." % [slide_label, qid])
		if not members.has(qid):
			members[qid] = []
		(members[qid] as Array).append(meta)
	for quiz_data in course.quizzes:
		if quiz_data == null or quiz_data.quiz_id.is_empty() or not quiz_data.report_to_lms:
			continue
		var list: Array = members.get(quiz_data.quiz_id, [])
		var graded_count := 0
		for meta in list:
			if bool(meta.get("graded", true)):
				graded_count += 1
		if graded_count == 0:
			warnings.append("Quiz \"%s\" is Report To Lms but has no graded questions." % quiz_data.quiz_id)


func _read_scene_meta(scene: PackedScene) -> Dictionary:
	var meta := {
		"quiz_id": "",
		"graded": true,
		"is_quiz": false,
		"empty_choice_ids": PackedStringArray(),
	}
	var state := scene.get_state()
	if state.get_node_count() < 1:
		return meta
	for i in state.get_node_count():
		var script_path := ""
		var choice_id := ""
		var found_choice_id := false
		for p in state.get_node_property_count(i):
			var prop_name := state.get_node_property_name(i, p)
			var prop_value: Variant = state.get_node_property_value(i, p)
			match prop_name:
				"script":
					if prop_value is Script:
						script_path = (prop_value as Script).resource_path
				"quiz_id":
					if i == 0:
						meta["quiz_id"] = str(prop_value)
				"graded":
					if i == 0:
						meta["graded"] = bool(prop_value)
				"choice_id":
					choice_id = str(prop_value)
					found_choice_id = true
		if _is_quiz_script(script_path):
			if i == 0:
				meta["is_quiz"] = true
		if _is_choice_script(script_path) and (not found_choice_id or choice_id.is_empty()):
			var names: PackedStringArray = meta["empty_choice_ids"]
			names.append(str(state.get_node_name(i)))
			meta["empty_choice_ids"] = names
	if not bool(meta["is_quiz"]):
		meta["quiz_id"] = ""
	return meta


func _is_quiz_script(path: String) -> bool:
	for suffix in _QUIZ_SCRIPTS:
		if path.ends_with(suffix):
			return true
	return false


func _is_choice_script(path: String) -> bool:
	return path.ends_with(_CHOICE_SCRIPT)
