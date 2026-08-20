extends Node

## IDCourseRuntime (autoload)
## Owns navigation, visit/complete/reachable state, and course-level signals.
## Player and IDButton call this; they do not store course progress themselves.
## See: completion_evaluator.gd, navigation_resolver.gd, tracking/tracking_backend.gd

signal slide_entered(slide_id: String)
signal slide_exited(slide_id: String)
signal slide_completed(slide_id: String)
signal course_completed(success: bool, score: float)
signal navigation_blocked(reason: String)

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
	current_slide = null
	current_slide_id = ""
	if course == null or course.slide_count() == 0:
		navigation_blocked.emit("Course has no slides.")
		return
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
			navigation_blocked.emit("Required slides are still incomplete.")
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
	for slide in course.slides:
		var id: String = slide.slide_id
		var required: bool = _required.get(id, true)
		if not required:
			continue
		if not _reachable.has(id):
			continue
		if not _completed.has(id):
			return
	_course_finished = true
	course_completed.emit(true, 0.0)
	_tracking.on_course_completed(true, 0.0)
