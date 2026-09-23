class_name IDDebugTrackingBackend
extends IDTrackingBackend

## Logs mapped LMS payload in editor / desktop Play. HTML5 uses IDScormBackend instead.
## See: tracking/scorm_mapper.gd, tracking/scorm_backend.gd, runtime/course_runtime.gd, resources/lms_settings.gd

const _PREFIX := "[CourseBuilder LMS]"

var _lms: IDLmsSettings
var _mapper: IDScormMapper


func _init(lms: IDLmsSettings = null) -> void:
	_lms = lms
	_mapper = IDScormMapper.new()


func on_slide_entered(slide_id: String) -> void:
	_log(_mapper.map_location(_lms, slide_id))


func on_slide_exited(slide_id: String) -> void:
	_log(_mapper.map_location(_lms, slide_id))


func on_slide_completed(_slide_id: String) -> void:
	pass


func on_interaction(record: IDInteractionRecord) -> void:
	_log(_mapper.map_interaction(_lms, record))


func on_objective(quiz_id: String, raw: float, min_score: float, max_score: float, success: bool, complete: bool) -> void:
	_log(_mapper.map_objective(_lms, quiz_id, raw, min_score, max_score, success, complete))


func on_course_completed(success: bool, score: float) -> void:
	_log(_mapper.map_course_completed(_lms, success, score))


func _log(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	print("%s %s" % [_PREFIX, _format(payload)])


func _format(payload: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in payload.keys():
		var value: Variant = payload[key]
		if value is Dictionary:
			var nested: Dictionary = value
			for nested_key in nested.keys():
				parts.append("%s.%s=%s" % [str(key), str(nested_key), nested[nested_key]])
		else:
			parts.append("%s=%s" % [str(key), value])
	return " ".join(parts)
