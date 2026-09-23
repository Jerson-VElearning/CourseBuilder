class_name IDTrackingBackend
extends RefCounted

## No-op tracking. Debug / SCORM 1.2 adapters implement the same methods.
## CourseRuntime calls these; it never imports an LMS API.
## See: runtime/course_runtime.gd, tracking/debug_tracking_backend.gd, tracking/scorm_backend.gd

func start_session() -> void:
	pass


func get_bookmark() -> String:
	return ""


func end_session() -> void:
	pass


func on_slide_entered(_slide_id: String) -> void:
	pass


func on_slide_exited(_slide_id: String) -> void:
	pass


func on_slide_completed(_slide_id: String) -> void:
	pass


func on_interaction(_record: IDInteractionRecord) -> void:
	pass


func on_objective(_quiz_id: String, _raw: float, _min: float, _max: float, _success: bool, _complete: bool) -> void:
	pass


func on_course_completed(_success: bool, _score: float) -> void:
	pass
