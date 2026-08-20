@tool
class_name IDCourseData
extends Resource

## Ordered list of slides plus course-level menu navigation.
## The runtime reads this; the player does not store its own copy of progress.
## See: runtime/course_runtime.gd, resources/slide_data.gd, resources/section_data.gd

## How learners may open slides from the menu (can_go_to). Default Sequential.
@export var menu_navigation: IDEnums.AccessMode = IDEnums.AccessMode.SEQUENTIAL

## Flow order. Index 0 is the first slide.
@export var slides: Array[IDSlideData] = []

## Ordered modules for Course Viewer frames and the player menu. Empty = ungrouped.
@export var sections: Array[IDSectionData] = []

## Course Viewer graph layout. Editor-only; the player ignores this.
@export_storage var viewer_layout: IDEnums.CourseViewerLayout = IDEnums.CourseViewerLayout.HORIZONTAL


func slide_count() -> int:
	return slides.size()


func get_first_id() -> String:
	if slides.is_empty():
		return ""
	return slides[0].slide_id


func get_index(slide_id: String) -> int:
	for i in slides.size():
		if slides[i].slide_id == slide_id:
			return i
	return -1


func get_slide(slide_id: String) -> IDSlideData:
	var index := get_index(slide_id)
	if index < 0:
		return null
	return slides[index]


func get_id_at(index: int) -> String:
	if index < 0 or index >= slides.size():
		return ""
	return slides[index].slide_id


func get_next_id(slide_id: String) -> String:
	var index := get_index(slide_id)
	if index < 0:
		return ""
	return get_id_at(index + 1)


func get_previous_id(slide_id: String) -> String:
	var index := get_index(slide_id)
	if index < 0:
		return ""
	return get_id_at(index - 1)


func get_section(section_id: String) -> IDSectionData:
	if section_id.is_empty():
		return null
	for section in sections:
		if section != null and section.section_id == section_id:
			return section
	return null


func slides_in_section(section_id: String) -> Array[IDSlideData]:
	var found: Array[IDSlideData] = []
	for data in slides:
		if data == null:
			continue
		if section_id.is_empty():
			if data.section_id.is_empty() or get_section(data.section_id) == null:
				found.append(data)
		elif data.section_id == section_id:
			found.append(data)
	return found
