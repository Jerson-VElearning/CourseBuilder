@tool
class_name IDSectionData
extends Resource

## One named group of slides. Course order stays the flat slides array.
## Course Viewer shows GraphFrames; the player menu uses these as headings.
## See: resources/course_data.gd, editor/course_viewer.gd, player/player_menu.gd

## Unique id stored on IDSlideData.section_id (e.g. "intro").
@export var section_id: String = "":
	set(value):
		if section_id == value:
			return
		section_id = value
		_update_resource_name()
		emit_changed()

## Author-facing name (e.g. "Introduction").
@export var title: String = "":
	set(value):
		if title == value:
			return
		title = value
		_update_resource_name()
		emit_changed()


func _update_resource_name() -> void:
	var label := title if not title.is_empty() else section_id
	if resource_name != label:
		resource_name = label
