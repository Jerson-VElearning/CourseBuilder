class_name IDScormCmi12
extends RefCounted

## Turns IDScormMapper dictionaries into SCORM 1.2 LMSSetValue pairs.
## See: tracking/scorm_mapper.gd, tracking/scorm_backend.gd


func pairs_init(reports_score: bool) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	_add(pairs, "cmi.core.lesson_status", "incomplete")
	if reports_score:
		_add(pairs, "cmi.core.score.min", "0")
		_add(pairs, "cmi.core.score.max", "100")
	return pairs


func pairs_location(payload: Dictionary) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if payload.is_empty() or not payload.has("location"):
		return pairs
	_add(pairs, "cmi.core.lesson_location", str(payload["location"]))
	return pairs


func pairs_interaction(payload: Dictionary, index: int) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if payload.is_empty() or not payload.has("interaction"):
		return pairs
	var item: Dictionary = payload["interaction"]
	var prefix := "cmi.interactions.%d." % index
	_add(pairs, prefix + "id", str(item.get("id", "")))
	_add(pairs, prefix + "type", str(item.get("type", "choice")))
	_add(pairs, prefix + "student_response", _choice_pattern_12(str(item.get("learner_response", ""))))
	_add(pairs, prefix + "correct_responses.0.pattern", _choice_pattern_12(str(item.get("correct_response", ""))))
	_add(pairs, prefix + "result", _result_12(str(item.get("result", ""))))
	_add(pairs, prefix + "weighting", str(item.get("weighting", 0.0)))
	_add(pairs, prefix + "latency", latency_cmi(float(item.get("latency_sec", 0.0))))
	var description := str(item.get("description", ""))
	if not description.is_empty():
		_add(pairs, prefix + "description", description)
	var quiz_id := str(item.get("quiz_id", ""))
	if not quiz_id.is_empty():
		_add(pairs, prefix + "objectives.0.id", quiz_id)
	return pairs


func pairs_objective(payload: Dictionary, index: int, reports_score: bool) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if payload.is_empty() or not payload.has("objective"):
		return pairs
	var item: Dictionary = payload["objective"]
	var prefix := "cmi.objectives.%d." % index
	_add(pairs, prefix + "id", str(item.get("id", "")))
	if reports_score:
		_add(pairs, prefix + "score.raw", str(item.get("score_raw", 0.0)))
	var complete := bool(item.get("complete", false))
	var success := bool(item.get("success", false))
	_add(pairs, prefix + "status", _status_12(complete, success, reports_score))
	return pairs


func pairs_course_completed(payload: Dictionary, reports_score: bool) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if payload.is_empty():
		return pairs
	var success := bool(payload.get("success", false))
	_add(pairs, "cmi.core.lesson_status", _status_12(true, success, reports_score))
	if reports_score:
		_add(pairs, "cmi.core.score.raw", str(payload.get("score_scaled", 0.0)))
		_add(pairs, "cmi.core.score.min", "0")
		_add(pairs, "cmi.core.score.max", "100")
	return pairs


func latency_cmi(seconds: float) -> String:
	var total := maxi(int(floor(seconds)), 0)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	return "%04d:%02d:%02d" % [hours, minutes, secs]


func _status_12(complete: bool, success: bool, reports_score: bool) -> String:
	if not complete:
		return "incomplete"
	if reports_score:
		return "passed" if success else "failed"
	return "completed"


func _result_12(result: String) -> String:
	if result == "incorrect":
		return "wrong"
	if result.is_empty():
		return "wrong"
	return result


func _choice_pattern_12(pattern: String) -> String:
	return pattern.replace("[,]", ",")


func _add(pairs: Array[Dictionary], element: String, value: String) -> void:
	pairs.append({"element": element, "value": value})
