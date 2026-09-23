class_name IDScormMapper
extends RefCounted

## Maps runtime tracking events plus IDLmsSettings into logical CMI keys.
## IDScormBackend translates these for SCORM 1.2 LMSSetValue on HTML5.
## See: tracking/debug_tracking_backend.gd, tracking/scorm_backend.gd, tracking/scorm_cmi12.gd

func map_location(lms: IDLmsSettings, slide_id: String) -> Dictionary:
	if lms == null or not lms.resume or slide_id.is_empty():
		return {}
	return {"location": slide_id}


func map_interaction(lms: IDLmsSettings, record: IDInteractionRecord) -> Dictionary:
	if lms == null or not lms.report_interactions or record == null:
		return {}
	return {
		"interaction": {
			"id": record.id,
			"quiz_id": record.quiz_id,
			"type": _interaction_type_token(record.type),
			"learner_response": record.learner_response,
			"correct_response": record.correct_response,
			"result": _interaction_result_token(record.result),
			"weighting": record.weighting,
			"latency_sec": record.latency_sec,
			"description": record.description,
		}
	}


func map_objective(
	lms: IDLmsSettings,
	quiz_id: String,
	raw: float,
	min_score: float,
	max_score: float,
	success: bool,
	complete: bool
) -> Dictionary:
	if lms == null or quiz_id.is_empty():
		return {}
	return {
		"objective": {
			"id": quiz_id,
			"score_raw": raw,
			"score_min": min_score,
			"score_max": max_score,
			"success": success,
			"complete": complete,
		}
	}


func map_course_completed(lms: IDLmsSettings, success: bool, score: float) -> Dictionary:
	if lms == null:
		return {}
	return {
		"completion": true,
		"success": success,
		"score_scaled": score,
	}


func _interaction_type_token(kind: IDEnums.InteractionType) -> String:
	match kind:
		IDEnums.InteractionType.MATCHING:
			return "matching"
		IDEnums.InteractionType.FILL_IN:
			return "fill-in"
		_:
			return "choice"


func _interaction_result_token(result: IDEnums.InteractionResult) -> String:
	match result:
		IDEnums.InteractionResult.CORRECT:
			return "correct"
		IDEnums.InteractionResult.NEUTRAL:
			return "neutral"
		_:
			return "incorrect"
