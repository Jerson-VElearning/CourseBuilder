@tool
class_name IDSlideData
extends Resource

## One entry in a course's ordered slide list.
## Drop a slide scene onto Scene; title, slide_id, and show_in_menu copy from the IDSlide root.
## The Inspector array row shows resource_name (title, or slide_id if title is empty).
## See: resources/course_data.gd, nodes/id_slide.gd

## Scene whose root is an IDSlide. Assign this first.
@export var scene: PackedScene:
	set(value):
		if scene == value:
			return
		scene = value
		_pull_from_scene()
		emit_changed()

## Copied from IDSlide.title. Shown as the collapsed list label.
@export var title: String = "":
	set(value):
		if title == value:
			return
		title = value
		_update_resource_name()
		emit_changed()

## Unique id used by go_to() and IDButton.navigate_to. Copied from IDSlide.slide_id.
@export var slide_id: String = "":
	set(value):
		if slide_id == value:
			return
		slide_id = value
		_update_resource_name()
		emit_changed()

## Course Viewer Free-layout position. Editor-only; unused by the player.
@export_storage var viewer_offset: Vector2 = Vector2.ZERO

## IDSectionData.section_id this slide belongs to. Empty = ungrouped.
@export var section_id: String = "":
	set(value):
		if section_id == value:
			return
		section_id = value
		emit_changed()

## Copied from IDSlide.show_in_menu. If false, the player TOC skips this slide.
@export var show_in_menu: bool = true:
	set(value):
		if show_in_menu == value:
			return
		show_in_menu = value
		emit_changed()

## Re-read title, slide_id, and show_in_menu from the assigned scene after editing that slide.
@export_tool_button("Refresh from scene")
var refresh_from_scene: Callable = _on_refresh_from_scene


func _on_refresh_from_scene() -> void:
	_pull_from_scene()
	emit_changed()


func _pull_from_scene() -> void:
	if scene == null:
		_update_resource_name()
		return
	var state := scene.get_state()
	if state.get_node_count() < 1:
		_update_resource_name()
		return
	var pulled_title := ""
	var pulled_id := ""
	var pulled_menu := true
	var found_menu := false
	for i in state.get_node_property_count(0):
		var prop_name := state.get_node_property_name(0, i)
		var prop_value: Variant = state.get_node_property_value(0, i)
		match prop_name:
			"title":
				pulled_title = str(prop_value)
			"slide_id":
				pulled_id = str(prop_value)
			"show_in_menu":
				pulled_menu = bool(prop_value)
				found_menu = true
	if not pulled_title.is_empty():
		title = pulled_title
	if not pulled_id.is_empty():
		slide_id = pulled_id
	if found_menu:
		show_in_menu = pulled_menu
	_update_resource_name()


func _update_resource_name() -> void:
	var label := title if not title.is_empty() else slide_id
	if resource_name != label:
		resource_name = label
