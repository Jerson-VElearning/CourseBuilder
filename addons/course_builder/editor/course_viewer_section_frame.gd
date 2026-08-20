@tool
class_name IDCourseViewerSectionFrame
extends GraphFrame

## Course Viewer frame for one IDSectionData. × removes the section, not the slides.
## See: editor/course_viewer.gd, resources/section_data.gd

signal remove_requested(section_id: String)

var section_id: String = ""


func _ready() -> void:
	autoshrink_enabled = true
	custom_minimum_size = Vector2(240, 80)
	_ensure_close_button()


func setup(id: String, section_title: String) -> void:
	section_id = id
	name = "section_%s" % id
	title = section_title if not section_title.is_empty() else id
	_ensure_close_button()


func _ensure_close_button() -> void:
	var bar := _titlebar()
	if bar == null:
		return
	if bar.get_node_or_null("Remove") != null:
		return
	var close_btn := Button.new()
	close_btn.name = "Remove"
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.tooltip_text = "Remove section (slides are kept, ungrouped)"
	close_btn.pressed.connect(_on_remove_pressed)
	bar.add_child(close_btn)


func _titlebar() -> HBoxContainer:
	if has_method("get_titlebar_hbox"):
		return get_titlebar_hbox() as HBoxContainer
	for child in get_children():
		if child is HBoxContainer:
			return child as HBoxContainer
	return null


func _on_remove_pressed() -> void:
	remove_requested.emit(section_id)
