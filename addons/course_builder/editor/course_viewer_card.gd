@tool
class_name IDCourseViewerCard
extends GraphNode

## One course slide as a GraphNode. Title is the GraphNode title bar.
## Extra output slots are IDButton jumps (read-only). Port 0 is sequence / next_slide.
## See: editor/course_viewer.gd, editor/slide_link_scanner.gd

signal open_requested(slide_index: int)
signal remove_requested(slide_index: int)
signal ungroup_requested(slide_index: int)

const _COLOR_IN := Color("9f1f63ff")
const _COLOR_NEXT := Color("E97132")
const _COLOR_JUMP := Color("2EAAA8")

var slide_index: int = 0
var next_slide_override: String = ""
var jump_targets: PackedStringArray = PackedStringArray()
var jump_slots: PackedInt32Array = PackedInt32Array()

@onready var _index_label: Label = $Index
@onready var _id_label: Label = $SlideId


func _ready() -> void:
	resizable = false
	_ensure_titlebar_buttons()
	set_slot(0, true, 0, _COLOR_IN, true, 0, _COLOR_NEXT)


func setup(index: int, slide_title: String, slide_id: String, jumps: Array = [], next_override: String = "", in_section: bool = false) -> void:
	slide_index = index
	name = "slide_%d" % index
	next_slide_override = next_override
	if _index_label == null:
		await ready
	title = slide_title if not slide_title.is_empty() else slide_id
	_index_label.text = "Slide %d" % (index + 1)
	_id_label.text = slide_id
	_apply_jumps(jumps)
	_set_ungroup_visible(in_section)


func _apply_jumps(jumps: Array) -> void:
	_clear_jump_labels()
	jump_targets = PackedStringArray()
	jump_slots = PackedInt32Array()
	set_slot(0, true, 0, _COLOR_IN, true, 0, _COLOR_NEXT)
	if _id_label != null:
		clear_slot(_id_label.get_index())
	for jump in jumps:
		if typeof(jump) != TYPE_DICTIONARY:
			continue
		var target_id := str(jump.get("target_id", ""))
		if target_id.is_empty():
			continue
		var jump_label := Label.new()
		jump_label.text = str(jump.get("label", target_id))
		jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		jump_label.add_theme_color_override("font_color", _COLOR_JUMP)
		add_child(jump_label)
		var slot_i := jump_label.get_index()
		set_slot(slot_i, false, 0, _COLOR_IN, true, 0, _COLOR_JUMP)
		jump_targets.append(target_id)
		jump_slots.append(_output_port_for_slot(slot_i))


func _output_port_for_slot(slot_i: int) -> int:
	for port in get_output_port_count():
		if get_output_port_slot(port) == slot_i:
			return port
	return jump_targets.size()


func _clear_jump_labels() -> void:
	var to_free: Array[Node] = []
	for child in get_children():
		if child is Label and child != _index_label and child != _id_label:
			to_free.append(child)
	for child in to_free:
		remove_child(child)
		child.queue_free()


func _ensure_titlebar_buttons() -> void:
	var bar := get_titlebar_hbox()
	if bar.get_node_or_null("Ungroup") == null:
		var ungroup_btn := Button.new()
		ungroup_btn.name = "Ungroup"
		ungroup_btn.text = "Ungroup"
		ungroup_btn.flat = true
		ungroup_btn.focus_mode = Control.FOCUS_NONE
		ungroup_btn.tooltip_text = "Remove from section"
		ungroup_btn.visible = false
		ungroup_btn.pressed.connect(_on_ungroup_pressed)
		bar.add_child(ungroup_btn)
	if bar.get_node_or_null("Remove") != null:
		return
	var close_btn := Button.new()
	close_btn.name = "Remove"
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.tooltip_text = "Remove from course (scene file is kept)"
	close_btn.pressed.connect(_on_remove_pressed)
	bar.add_child(close_btn)


func _set_ungroup_visible(in_section: bool) -> void:
	_ensure_titlebar_buttons()
	var bar := get_titlebar_hbox()
	var ungroup_btn := bar.get_node_or_null("Ungroup") as Button
	if ungroup_btn != null:
		ungroup_btn.visible = in_section


func _on_ungroup_pressed() -> void:
	ungroup_requested.emit(slide_index)


func _on_remove_pressed() -> void:
	remove_requested.emit(slide_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click and mouse.pressed:
			open_requested.emit(slide_index)
			accept_event()
