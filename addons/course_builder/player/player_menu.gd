class_name IDPlayerMenu
extends Control

## Player table of contents. Overlay and row templates live in the player scene.
## Walks course.slides in order; consecutive section slides share a heading.
## See: player/course_player.tscn, runtime/course_runtime.gd, resources/section_data.gd

const _NESTED_MARGIN := 16
const _META_ROW := "menu_row"

@export var toggle_button: Button
@export var backdrop: Control
@export var close_button: Button
@export var list_container: Container
@export var heading_template: Label
@export var slide_template: Button
@export var current_template: Button
@export var disabled_template: Button


func _ready() -> void:
	if toggle_button != null:
		toggle_button.pressed.connect(toggle)
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	_hide_templates()
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false


func refresh() -> void:
	_build_list()


func _hide_templates() -> void:
	for template in [heading_template, slide_template, current_template, disabled_template]:
		if template != null:
			template.visible = false


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			close()


func _build_list() -> void:
	if list_container == null:
		return
	var to_free: Array[Node] = []
	for child in list_container.get_children():
		if bool(child.get_meta(_META_ROW, false)):
			to_free.append(child)
	for child in to_free:
		list_container.remove_child(child)
		child.queue_free()
	if not has_node("/root/IDCourseRuntime"):
		return
	var runtime := IDCourseRuntime
	var course: IDCourseData = runtime.course
	if course == null:
		return
	var last_section := ""
	var in_section := false
	for data in course.slides:
		if data == null or not data.show_in_menu:
			continue
		var section := _section_for(course, data)
		if section == null:
			_add_slide_row(data, runtime, false)
			last_section = ""
			in_section = false
			continue
		if not in_section or last_section != data.section_id:
			_add_heading(section.title if not section.title.is_empty() else section.section_id)
		_add_slide_row(data, runtime, true)
		last_section = data.section_id
		in_section = true


func _section_for(course: IDCourseData, data: IDSlideData) -> IDSectionData:
	if data.section_id.is_empty():
		return null
	return course.get_section(data.section_id)


func _add_heading(text: String) -> void:
	if heading_template == null:
		return
	var heading := heading_template.duplicate() as Label
	if heading == null:
		return
	heading.text = text
	_add_generated(heading, false)


func _add_slide_row(data: IDSlideData, runtime: Node, indented: bool) -> void:
	var slide_id := data.slide_id
	var label := data.title if not data.title.is_empty() else slide_id
	var is_current: bool = slide_id == str(runtime.current_slide_id)
	var allowed: bool = runtime.can_go_to(slide_id)
	var locked: bool = not allowed and not is_current
	var template: Button = slide_template
	if is_current:
		template = current_template
	elif locked:
		template = disabled_template
	if template == null:
		return
	var row := template.duplicate() as Button
	if row == null:
		return
	row.text = label
	row.disabled = locked
	if not locked:
		row.pressed.connect(_on_slide_pressed.bind(slide_id, is_current))
	_add_generated(row, indented)


func _add_generated(control: Control, indented: bool) -> void:
	control.visible = true
	control.set_meta(_META_ROW, true)
	if not indented:
		list_container.add_child(control)
		return
	var wrap := MarginContainer.new()
	wrap.set_meta(_META_ROW, true)
	wrap.add_theme_constant_override("margin_left", _NESTED_MARGIN)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(control)
	list_container.add_child(wrap)


func _on_slide_pressed(slide_id: String, is_current: bool) -> void:
	if not is_current and has_node("/root/IDCourseRuntime"):
		IDCourseRuntime.go_to(slide_id, false)
	close()
