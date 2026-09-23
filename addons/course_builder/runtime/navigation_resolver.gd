class_name IDNavigationResolver
extends RefCounted

## Picks the next slide id. Does not move the learner or change completion.
## Order: slide.next_slide override, then the next entry in course order.
## Explicit IDButton jumps call CourseRuntime.go_to() and skip this resolver.
## See: runtime/course_runtime.gd, nodes/id_slide.gd

func resolve_next(course: IDCourseData, current_id: String, slide: Node) -> String:
	if slide != null and slide.get("next_slide") != null:
		var override_id: String = slide.next_slide
		if not override_id.is_empty():
			return override_id
	if course == null:
		return ""
	return course.get_next_id(current_id)
