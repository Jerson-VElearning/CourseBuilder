class_name IDScormBackend
extends IDTrackingBackend

## HTML5 SCORM 1.2 adapter. Talks to window.API via a JS helper; mocks if none is found.
## Desktop Play never instantiates this. See: tracking/scorm_api.js, tracking/scorm_api_js.gd, tracking/scorm_cmi12.gd

const _JS_PATH := "res://addons/course_builder/tracking/scorm_api.js"

var _lms: IDLmsSettings
var _course: IDCourseData
var _mapper: IDScormMapper
var _cmi: IDScormCmi12
var _scorm: Variant = null
var _ready: bool = false
var _finished: bool = false
var _interaction_index: int = 0
var _objective_index: Dictionary = {}


func _init(lms: IDLmsSettings = null, course: IDCourseData = null) -> void:
	_lms = lms
	_course = course
	_mapper = IDScormMapper.new()
	_cmi = IDScormCmi12.new()


func start_session() -> void:
	if not _ensure_bridge():
		return
	if not _js_true(_js_call("init")):
		push_warning("CourseBuilder LMS: LMSInitialize failed (%s)." % _js_call("lastError"))
		return
	_apply(_cmi.pairs_init(_reports_score()), false)
	_js_commit()


func get_bookmark() -> String:
	if _lms == null or not _lms.resume:
		return ""
	if not _ready:
		return ""
	return str(_js_call("get", ["cmi.core.lesson_location"])).strip_edges()


func end_session() -> void:
	if _finished or not _ready:
		_finished = true
		return
	_finished = true
	_js_call("finish")


func on_slide_entered(slide_id: String) -> void:
	_apply(_cmi.pairs_location(_mapper.map_location(_lms, slide_id)), false)


func on_slide_exited(slide_id: String) -> void:
	_apply(_cmi.pairs_location(_mapper.map_location(_lms, slide_id)), true)


func on_interaction(record: IDInteractionRecord) -> void:
	var payload := _mapper.map_interaction(_lms, record)
	if payload.is_empty():
		return
	_apply(_cmi.pairs_interaction(payload, _interaction_index), true)
	_interaction_index += 1


func on_objective(quiz_id: String, raw: float, min_score: float, max_score: float, success: bool, complete: bool) -> void:
	var payload := _mapper.map_objective(_lms, quiz_id, raw, min_score, max_score, success, complete)
	if payload.is_empty():
		return
	var index := _objective_n(quiz_id)
	_apply(_cmi.pairs_objective(payload, index, _reports_score()), true)


func on_course_completed(success: bool, score: float) -> void:
	_apply(_cmi.pairs_course_completed(_mapper.map_course_completed(_lms, success, score), _reports_score()), true)
	end_session()


func _reports_score() -> bool:
	if _course == null:
		return false
	for quiz_data in _course.quizzes:
		if quiz_data != null and not quiz_data.quiz_id.is_empty() and quiz_data.report_to_lms:
			return true
	return false


func _objective_n(quiz_id: String) -> int:
	if _objective_index.has(quiz_id):
		return int(_objective_index[quiz_id])
	var index := _objective_index.size()
	_objective_index[quiz_id] = index
	return index


func _apply(pairs: Array[Dictionary], commit: bool) -> void:
	if not _ready or _finished:
		return
	for pair in pairs:
		var element := str(pair.get("element", ""))
		if element.is_empty():
			continue
		var ok := _js_true(_js_call("set", [element, str(pair.get("value", ""))]))
		if not ok:
			push_warning("CourseBuilder LMS: LMSSetValue failed for %s (%s)." % [element, _js_call("lastError")])
	if commit:
		_js_commit()


func _js_commit() -> void:
	if not _ready or _finished:
		return
	if not _js_true(_js_call("commit")):
		push_warning("CourseBuilder LMS: LMSCommit failed (%s)." % _js_call("lastError"))


func _ensure_bridge() -> bool:
	if _ready:
		return true
	if not OS.has_feature("web"):
		return false
	var js: Object = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		push_warning("CourseBuilder LMS: JavaScriptBridge is missing.")
		return false
	var code := ""
	if FileAccess.file_exists(_JS_PATH):
		code = FileAccess.get_file_as_string(_JS_PATH)
	if code.is_empty():
		code = IDScormApiJs.SOURCE
	if code.is_empty():
		push_warning("CourseBuilder LMS: SCORM JS helper is empty.")
		return false
	js.call("eval", code, true)
	_scorm = js.call("get_interface", "CourseBuilderScorm")
	if _scorm == null:
		push_warning("CourseBuilder LMS: CourseBuilderScorm was not installed.")
		return false
	_ready = true
	return true


func _js_call(method: String, args: Array = []) -> Variant:
	if _scorm == null:
		return ""
	match args.size():
		0:
			return _scorm.call(method)
		1:
			return _scorm.call(method, args[0])
		2:
			return _scorm.call(method, args[0], args[1])
		_:
			return _scorm.callv(method, args)


func _js_true(value: Variant) -> bool:
	return str(value) == "true"
