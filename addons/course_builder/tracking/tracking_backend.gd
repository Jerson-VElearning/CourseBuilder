class_name IDTrackingBackend
extends RefCounted

## No-op tracking. SCORM / xAPI adapters should implement the same methods later.
## CourseRuntime calls these; it never imports an LMS API.
## See: runtime/course_runtime.gd

func on_slide_entered(_slide_id: String) -> void:
	pass


func on_slide_exited(_slide_id: String) -> void:
	pass


func on_slide_completed(_slide_id: String) -> void:
	pass


func on_course_completed(_success: bool, _score: float) -> void:
	pass
