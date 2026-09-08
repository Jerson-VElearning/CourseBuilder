extends Node

## IDCourseRuntime (autoload)
## Owns navigation, visit/complete/reachable state, quiz results, and course-level signals.
## Player and IDButton call this; they do not store course progress themselves.
## See: completion_evaluator.gd, navigation_resolver.gd, tracking/tracking_backend.gd, resources/quiz_result.gd

const _QuizDataScript := preload("res://addons/course_builder/resources/quiz_data.gd")
const _QuizResultScript := preload("res://addons/course_builder/resources/quiz_result.gd")
const _InteractionRecordScript := preload("res://addons/course_builder/resources/interaction_record.gd")

signal slide_entered(slide_id: String)
signal slide_exited(slide_id: String)
signal slide_completed(slide_id: String)
signal course_completed(success: bool, score: float)
signal navigation_blocked(reason: String)
signal quiz_updated(quiz_id: String)

var course: IDCourseData
var current_slide_id: String = ""
## Live IDSlide for the current scene; set from IDSlide._ready via register_slide().
var current_slide: Node

var _visited: Dictionary = {}
var _completed: Dictionary = {}
var _reachable: Dictionary = {}
## slide_id -> required flag, filled when each IDSlide registers.
var _required: Dictionary = {}
var _history: Array[String] = []
var _course_finished: bool = false
## slide_id -> IDInteractionRecord (final attempt only).
var _interactions: Dictionary = {}
## quiz_id -> IDQuizResult
var _quiz_results: Dictionary = {}
## quiz_id -> Array of { slide_id, points, graded }
var _quiz_members: Dictionary = {}

var _evaluator := IDCompletionEvaluator.new()
var _resolver := IDNavigationResolver.new()
var _tracking := IDTrackingBackend.new()


## Loads course data, clears progress, and enters the first slide.
func start_course(course_data: IDCourseData) -> void:
	course = course_data
	_visited.clear()
	_completed.clear()
	_reachable.clear()
	_required.clear()
	_history.clear()
	_course_finished = false
	_interactions.clear()
	_quiz_results.clear()
	_quiz_members.clear()
	current_slide = null
	current_slide_id = ""
	if course == null or course.slide_count() == 0:
		navigation_blocked.emit("Course has no slides.")
		return
	_scan_quiz_membership()
	_init_quiz_results()
	var first_id := course.get_first_id()
	_reachable[first_id] = true
	_enter_slide(first_id, true)


## Opens a slide by id (explicit jump from a button or internal navigation).
## Explicit jumps add the target to the reachable set without completing skipped slides.
func go_to(slide_id: String, explicit: bool = true) -> void:
	if course == null:
		navigation_blocked.emit("Course has not started.")
		return
	if course.get_slide(slide_id) == null:
		navigation_blocked.emit("Unknown slide: %s" % slide_id)
		return
	if explicit:
		_reachable[slide_id] = true
	elif not _is_allowed(slide_id):
		navigation_blocked.emit("Slide is not reachable: %s" % slide_id)
		return
	_enter_slide(slide_id, false)


## Completes the current ON_CONTINUE slide if needed, then goes to the resolved next slide.
## On the last slide, completes the course when all reachable required slides are done.
func request_next() -> void:
	if current_slide_id.is_empty():
		navigation_blocked.emit("No current slide.")
		return
	if not is_slide_complete(current_slide_id):
		var rule := _current_rule()
		if _evaluator.can_complete_on_continue(rule):
			mark_complete(current_slide_id)
		else:
			navigation_blocked.emit("Current slide is not complete.")
			return
	if _course_finished:
		return
	var next_id := _resolver.resolve_next(course, current_slide_id, current_slide)
	if next_id.is_empty():
		_try_finish_course()
		if not _course_finished:
			navigation_blocked.emit("Course is not ready to finish.")
		return
	_reachable[next_id] = true
	go_to(next_id, false)


## Goes to the previous visit in history, or the previous slide in course order.
func request_previous() -> void:
	if _history.size() > 1:
		_history.pop_back()
		var previous_id: String = _history[_history.size() - 1]
		_enter_slide(previous_id, true)
		return
	var order_previous := ""
	if course != null:
		order_previous = course.get_previous_id(current_slide_id)
	if order_previous.is_empty():
		navigation_blocked.emit("No previous slide.")
		return
	go_to(order_previous, false)


## Marks a slide complete (sticky for this attempt) and emits slide_completed once.
## Call this from custom slide logic when the learner has finished required interactions
## (e.g. IDSlide ALL_REVEALS / MEDIA_FINISHED, or a developer script). The player chrome listens to
## slide_completed and enables Next via can_go_next() — do not enable Next directly.
## Does not navigate; call request_next() separately if the learner should advance.
func mark_complete(slide_id: String = "") -> void:
	var id := slide_id if not slide_id.is_empty() else current_slide_id
	if id.is_empty():
		return
	if _completed.has(id):
		return
	_completed[id] = true
	_unlock_following(id)
	slide_completed.emit(id)
	_tracking.on_slide_completed(id)
	_try_finish_course()


func is_slide_complete(slide_id: String) -> bool:
	return _completed.has(slide_id)


func is_slide_visited(slide_id: String) -> bool:
	return _visited.has(slide_id)


func is_reachable(slide_id: String) -> bool:
	return _reachable.has(slide_id)


## True when menu_navigation allows opening this slide (menu / TOC). Does not jump.
func can_go_to(slide_id: String) -> bool:
	if course == null or slide_id.is_empty():
		return false
	if course.get_slide(slide_id) == null:
		return false
	return _is_allowed(slide_id)


## Called by IDSlide when the instanced scene is ready so ON_ENTER can run.
func register_slide(slide: Node) -> void:
	if slide == null:
		return
	var id: String = slide.slide_id
	if id != current_slide_id:
		return
	current_slide = slide
	if slide.get("required") != null:
		_required[id] = slide.required
	if _evaluator.should_complete_on_enter(_current_rule()):
		mark_complete(current_slide_id)


func can_go_next() -> bool:
	if current_slide_id.is_empty() or _course_finished:
		return false
	if is_slide_complete(current_slide_id):
		return true
	return _evaluator.can_complete_on_continue(_current_rule())


func can_go_previous() -> bool:
	if _history.size() > 1:
		return true
	if course == null:
		return false
	return not course.get_previous_id(current_slide_id).is_empty()


func is_course_finished() -> bool:
	return _course_finished


func get_progress_index() -> int:
	if course == null:
		return 0
	return course.get_index(current_slide_id)


func get_progress_count() -> int:
	if course == null:
		return 0
	return course.slide_count()


## Final attempt only. Practice questions (empty quiz_id) are stored but not rolled into a quiz.
func record_interaction(record: IDInteractionRecord) -> void:
	if record == null or record.id.is_empty():
		return
	if _interactions.has(record.id):
		return
	_interactions[record.id] = record
	_tracking.on_interaction(record)
	if record.quiz_id.is_empty():
		return
	var result := _ensure_quiz_result(record.quiz_id)
	result.replace_or_add(record)
	_refresh_quiz_result(result)
	quiz_updated.emit(record.quiz_id)
	_tracking.on_objective(
		result.quiz_id,
		result.score_raw,
		0.0,
		result.score_max,
		result.passed,
		result.complete
	)
	_try_finish_course()


func get_quiz_result(quiz_id: String) -> IDQuizResult:
	if quiz_id.is_empty() or not _quiz_results.has(quiz_id):
		return null
	return _quiz_results[quiz_id]


func get_interaction(slide_id: String) -> IDInteractionRecord:
	if slide_id.is_empty() or not _interactions.has(slide_id):
		return null
	return _interactions[slide_id]


func get_course_score() -> float:
	if course == null:
		return 0.0
	var raw := 0.0
	var max_score := 0.0
	var any_reported := false
	for quiz_data in course.quizzes:
		if quiz_data == null or quiz_data.quiz_id.is_empty() or not quiz_data.report_to_lms:
			continue
		any_reported = true
		var result := get_quiz_result(quiz_data.quiz_id)
		if result == null:
			max_score += _quiz_score_max(quiz_data.quiz_id)
			continue
		raw += result.score_raw
		max_score += result.score_max
	if not any_reported or max_score <= 0.0:
		return 0.0
	return (raw / max_score) * 100.0


func _enter_slide(slide_id: String, replace_history_tail: bool) -> void:
	if not current_slide_id.is_empty() and current_slide_id != slide_id:
		slide_exited.emit(current_slide_id)
		_tracking.on_slide_exited(current_slide_id)
	current_slide = null
	current_slide_id = slide_id
	_visited[slide_id] = true
	_reachable[slide_id] = true
	if replace_history_tail:
		if _history.is_empty() or _history[_history.size() - 1] != slide_id:
			_history.append(slide_id)
	else:
		if _history.is_empty() or _history[_history.size() - 1] != slide_id:
			_history.append(slide_id)
	slide_entered.emit(slide_id)
	_tracking.on_slide_entered(slide_id)


func _current_rule() -> IDEnums.CompletionRule:
	if current_slide != null and current_slide.get("completion_rule") != null:
		return current_slide.completion_rule
	return IDEnums.CompletionRule.ON_CONTINUE


func _is_allowed(slide_id: String) -> bool:
	if course == null:
		return false
	match course.menu_navigation:
		IDEnums.AccessMode.FREE:
			return true
		IDEnums.AccessMode.RESTRICTED:
			return _visited.has(slide_id) or slide_id == current_slide_id
		_:
			return _reachable.has(slide_id) or _all_before_complete(slide_id)


func _all_before_complete(slide_id: String) -> bool:
	var index := course.get_index(slide_id)
	if index <= 0:
		return index == 0
	for i in range(index):
		var prior_id := course.get_id_at(i)
		if not _completed.has(prior_id):
			return false
	return true


## Completing a slide unlocks the next one in course order (Sequential).
func _unlock_following(slide_id: String) -> void:
	if course == null:
		return
	if course.menu_navigation == IDEnums.AccessMode.FREE:
		for slide in course.slides:
			_reachable[slide.slide_id] = true
		return
	var next_id := course.get_next_id(slide_id)
	if not next_id.is_empty():
		_reachable[next_id] = true


func _try_finish_course() -> void:
	if _course_finished or course == null:
		return
	if not _finish_requirements_met():
		return
	_course_finished = true
	var success := _course_success()
	var score := get_course_score()
	course_completed.emit(success, score)
	_tracking.on_course_completed(success, score)


func _finish_requirements_met() -> bool:
	var by := course.completion_by
	match by:
		IDEnums.CourseCompletionBy.QUIZ_SUCCESS:
			return _quizzes_success_met()
		IDEnums.CourseCompletionBy.SLIDES_AND_QUIZ:
			return _required_slides_complete() and _quizzes_success_met()
		_:
			return _required_slides_complete()


func _course_success() -> bool:
	match course.completion_by:
		IDEnums.CourseCompletionBy.QUIZ_SUCCESS, IDEnums.CourseCompletionBy.SLIDES_AND_QUIZ:
			return _quizzes_success_met()
		_:
			return true


func _required_slides_complete() -> bool:
	for slide in course.slides:
		var id: String = slide.slide_id
		var required: bool = _required.get(id, true)
		if not required:
			continue
		if not _reachable.has(id):
			continue
		if not _completed.has(id):
			return false
	return true


func _quizzes_success_met() -> bool:
	if course.quizzes.is_empty():
		return false
	var check: Array[IDQuizData] = []
	for quiz_data in course.quizzes:
		if quiz_data == null or quiz_data.quiz_id.is_empty():
			continue
		if quiz_data.required_to_pass:
			check.append(quiz_data)
	if check.is_empty():
		for quiz_data in course.quizzes:
			if quiz_data != null and not quiz_data.quiz_id.is_empty():
				check.append(quiz_data)
	if check.is_empty():
		return false
	for quiz_data in check:
		var result := get_quiz_result(quiz_data.quiz_id)
		if result == null or not result.complete or not result.passed:
			return false
	return true


func _scan_quiz_membership() -> void:
	_quiz_members.clear()
	if course == null:
		return
	for data in course.slides:
		if data == null or data.scene == null:
			continue
		var meta := _read_question_meta(data.scene)
		var qid: String = str(meta.get("quiz_id", ""))
		if qid.is_empty():
			continue
		if not _quiz_members.has(qid):
			_quiz_members[qid] = []
		var member_id := data.slide_id if not data.slide_id.is_empty() else str(meta.get("slide_id", ""))
		_quiz_members[qid].append({
			"slide_id": member_id,
			"points": float(meta.get("points", 1.0)),
			"graded": bool(meta.get("graded", true)),
		})


func _read_question_meta(scene: PackedScene) -> Dictionary:
	var meta := {
		"quiz_id": "",
		"slide_id": "",
		"points": 1.0,
		"graded": true,
		"is_quiz": false,
	}
	var state := scene.get_state()
	if state.get_node_count() < 1:
		return meta
	for i in state.get_node_property_count(0):
		var prop_name := state.get_node_property_name(0, i)
		var prop_value: Variant = state.get_node_property_value(0, i)
		match prop_name:
			"script":
				if prop_value is Script:
					var path := (prop_value as Script).resource_path
					if path.ends_with("/id_quiz.gd") or path.ends_with("/id_quiz_mc.gd"):
						meta["is_quiz"] = true
			"quiz_id":
				meta["quiz_id"] = str(prop_value)
			"slide_id":
				meta["slide_id"] = str(prop_value)
			"points":
				meta["points"] = float(prop_value)
			"graded":
				meta["graded"] = bool(prop_value)
	if not bool(meta["is_quiz"]):
		meta["quiz_id"] = ""
	return meta


func _init_quiz_results() -> void:
	if course != null:
		for quiz_data in course.quizzes:
			if quiz_data != null and not quiz_data.quiz_id.is_empty():
				_ensure_quiz_result(quiz_data.quiz_id)
	for quiz_id in _quiz_members.keys():
		_ensure_quiz_result(str(quiz_id))


func _ensure_quiz_result(quiz_id: String) -> IDQuizResult:
	if _quiz_results.has(quiz_id):
		return _quiz_results[quiz_id]
	var result := IDQuizResult.new()
	result.quiz_id = quiz_id
	_quiz_results[quiz_id] = result
	_refresh_quiz_result(result)
	return result


func _refresh_quiz_result(result: IDQuizResult) -> void:
	if result == null:
		return
	result.score_max = _quiz_score_max(result.quiz_id)
	result.score_raw = 0.0
	for record in result.interactions:
		if record != null and record.result == IDEnums.InteractionResult.CORRECT:
			result.score_raw += record.weighting
	if result.score_max <= 0.0:
		result.percent = 0.0
	else:
		result.percent = (result.score_raw / result.score_max) * 100.0
	result.complete = _quiz_members_complete(result.quiz_id)
	var passing := 80.0
	if course != null:
		var data := course.get_quiz(result.quiz_id)
		if data != null:
			passing = data.passing_percent
	if result.score_max <= 0.0:
		result.passed = result.complete
	else:
		result.passed = result.complete and result.percent + 0.0001 >= passing


func _quiz_score_max(quiz_id: String) -> float:
	var total := 0.0
	if not _quiz_members.has(quiz_id):
		return total
	for member in _quiz_members[quiz_id]:
		if bool(member.get("graded", true)):
			total += float(member.get("points", 0.0))
	return total


func _quiz_members_complete(quiz_id: String) -> bool:
	if not _quiz_members.has(quiz_id):
		return false
	var members: Array = _quiz_members[quiz_id]
	if members.is_empty():
		return false
	var graded_count := 0
	for member in members:
		if not bool(member.get("graded", true)):
			continue
		graded_count += 1
		var member_id := str(member.get("slide_id", ""))
		if member_id.is_empty() or not _interactions.has(member_id):
			return false
	if graded_count > 0:
		return true
	for member in members:
		var member_id := str(member.get("slide_id", ""))
		if member_id.is_empty() or not _interactions.has(member_id):
			return false
	return true
