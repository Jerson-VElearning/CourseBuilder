@tool
class_name IDCourseViewer
extends Control

## Editor Course Viewer: GraphEdit of slide GraphNodes in course order.
## Layout: Horizontal / Vertical auto-arrange (drag reorders), or Free place.
## Orange wires are Next; teal wires are IDButton jumps (read-only).
## Sections are GraphFrames; empty section_id leaves a slide ungrouped.
## See: editor/course_viewer_card.gd, editor/slide_link_scanner.gd, resources/section_data.gd

const _CARD_SCENE := preload("res://addons/course_builder/editor/course_viewer_card.tscn")
const _LINK_SCANNER := preload("res://addons/course_builder/editor/slide_link_scanner.gd")
const _DEFAULT_COURSE_PATH := "res://course/course.tres"
const _LAYOUT_ORIGIN := Vector2(32, 32)
const _NODE_MARGIN := 48.0
const _SECTION_GAP := 64.0
const _FRAME_CHROME := Vector2(24, 52)
const _PLACEHOLDER_CARD_SIZE := Vector2(220, 80)

@export var path_edit: LineEdit
@export var refresh_button: Button
@export var add_slide_button: Button
@export var add_section_button: Button
@export var layout_option: OptionButton
@export var status_label: Label
@export var graph_edit: GraphEdit

var _plugin: EditorPlugin
var _course: IDCourseData
var _course_path: String = _DEFAULT_COURSE_PATH
var _file_dialog: EditorFileDialog
var _confirm_remove: ConfirmationDialog
var _confirm_remove_section: ConfirmationDialog
var _section_dialog: AcceptDialog
var _section_name_edit: LineEdit
var _pending_remove_index: int = -1
var _pending_section_id: String = ""
var _rebuilding: bool = false
var _layout_generation: int = 0


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin
	refresh()


func _ready() -> void:
	if path_edit != null:
		if path_edit.text.is_empty():
			path_edit.text = _DEFAULT_COURSE_PATH
		path_edit.text_submitted.connect(func(_text: String) -> void: refresh())
	if refresh_button != null:
		refresh_button.pressed.connect(refresh)
	if add_slide_button != null:
		add_slide_button.pressed.connect(_on_add_slide_pressed)
	if add_section_button != null:
		add_section_button.pressed.connect(_on_add_section_pressed)
	if layout_option != null:
		_fill_layout_option()
		layout_option.item_selected.connect(_on_layout_item_selected)
	if graph_edit != null:
		graph_edit.end_node_move.connect(_on_end_node_move)
		graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
		graph_edit.connection_request.connect(_on_connection_request)
		graph_edit.graph_elements_linked_to_frame_request.connect(_on_linked_to_frame)
	visibility_changed.connect(_on_visibility_changed)
	_setup_dialogs()


func _fill_layout_option() -> void:
	layout_option.clear()
	layout_option.add_item("Horizontal", IDEnums.CourseViewerLayout.HORIZONTAL)
	layout_option.add_item("Vertical", IDEnums.CourseViewerLayout.VERTICAL)
	layout_option.add_item("Free", IDEnums.CourseViewerLayout.FREE)


func _setup_dialogs() -> void:
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tscn", "Slide scenes")
	_file_dialog.title = "Add slide to course"
	_file_dialog.file_selected.connect(_on_slide_scene_selected)
	add_child(_file_dialog)

	_confirm_remove = ConfirmationDialog.new()
	_confirm_remove.title = "Remove from course"
	_confirm_remove.dialog_text = "Remove this slide from the course? The scene file will not be deleted."
	_confirm_remove.confirmed.connect(_on_remove_confirmed)
	add_child(_confirm_remove)

	_confirm_remove_section = ConfirmationDialog.new()
	_confirm_remove_section.title = "Remove section"
	_confirm_remove_section.dialog_text = "Remove this section? Slides stay in the course, ungrouped."
	_confirm_remove_section.confirmed.connect(_on_remove_section_confirmed)
	add_child(_confirm_remove_section)

	_section_name_edit = LineEdit.new()
	_section_name_edit.placeholder_text = "Section name"
	_section_dialog = AcceptDialog.new()
	_section_dialog.title = "Add section"
	_section_dialog.ok_button_text = "Add"
	_section_dialog.add_child(_section_name_edit)
	_section_dialog.confirmed.connect(_on_section_name_confirmed)
	add_child(_section_dialog)


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_layout_generation += 1
	_rebuilding = false
	if path_edit != null and not path_edit.text.is_empty():
		_course_path = path_edit.text.strip_edges()
	_clear_nodes()
	if not ResourceLoader.exists(_course_path):
		_set_status("No course at %s" % _course_path)
		_course = null
		_set_course_controls_enabled(false)
		return
	var loaded := load(_course_path)
	_course = loaded as IDCourseData
	if _course == null:
		_set_status("Not an IDCourseData: %s" % _course_path)
		_set_course_controls_enabled(false)
		return
	_set_course_controls_enabled(true)
	if layout_option != null and layout_option.item_count == 0:
		_fill_layout_option()
	_sync_layout_option()
	if _course.slides.is_empty() and _course.sections.is_empty():
		_set_status("Course has no slides.")
		return
	_rebuilding = true
	var id_to_index := _slide_id_to_index()
	var jump_count := 0
	var unresolved := 0
	for i in _course.slides.size():
		var data: IDSlideData = _course.slides[i]
		var card: IDCourseViewerCard = _CARD_SCENE.instantiate() as IDCourseViewerCard
		graph_edit.add_child(card)
		var slide_title := ""
		var slide_id := ""
		var packed: PackedScene = null
		if data != null:
			slide_title = data.title
			slide_id = data.slide_id
			packed = data.scene
		var links: Dictionary = _LINK_SCANNER.scan(packed)
		var next_override := str(links.get("next_slide", ""))
		if not next_override.is_empty() and not id_to_index.has(next_override):
			unresolved += 1
		var valid_jumps: Array = []
		for jump in links.get("jumps", []):
			if typeof(jump) != TYPE_DICTIONARY:
				continue
			var target_id := str(jump.get("target_id", ""))
			if target_id.is_empty():
				continue
			if id_to_index.has(target_id):
				valid_jumps.append(jump)
				jump_count += 1
			else:
				unresolved += 1
		var in_section := false
		if data != null and not data.section_id.is_empty() and _course.get_section(data.section_id) != null:
			in_section = true
		card.setup(i, slide_title, slide_id, valid_jumps, next_override, in_section)
		card.position_offset = _card_offset(i, data)
		card.open_requested.connect(_on_open_slide)
		card.remove_requested.connect(_on_remove_requested)
		card.ungroup_requested.connect(_on_ungroup_requested)
	_build_section_frames()
	_connect_links(id_to_index)
	_set_status(_status_text(_course.slides.size(), jump_count, unresolved))
	if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
		_rebuilding = false
	else:
		call_deferred("_apply_auto_layout_deferred", _layout_generation)


func _slide_id_to_index() -> Dictionary:
	var id_to_index := {}
	if _course == null:
		return id_to_index
	for i in _course.slides.size():
		var data: IDSlideData = _course.slides[i]
		if data != null and not data.slide_id.is_empty():
			id_to_index[data.slide_id] = i
	return id_to_index


func _status_text(slide_count: int, jump_count: int, unresolved: int) -> String:
	var text := "%d slides" % slide_count
	if _course != null and not _course.sections.is_empty():
		text += ", %d sections" % _course.sections.size()
	if jump_count > 0:
		text += ", %d jumps" % jump_count
	if unresolved > 0:
		text += ", %d unresolved" % unresolved
	return text


func _connect_links(id_to_index: Dictionary) -> void:
	if graph_edit == null or _course == null:
		return
	graph_edit.clear_connections()
	for card in _cards():
		var from_name := card.name
		var next_index := card.slide_index + 1
		if not card.next_slide_override.is_empty():
			next_index = int(id_to_index.get(card.next_slide_override, -1))
		if next_index >= 0 and next_index < _course.slides.size() and next_index != card.slide_index:
			graph_edit.connect_node(from_name, 0, "slide_%d" % next_index, 0)
		for j in card.jump_targets.size():
			var target_id := card.jump_targets[j]
			if not id_to_index.has(target_id):
				continue
			var to_index: int = id_to_index[target_id]
			var from_port: int = card.jump_slots[j]
			graph_edit.connect_node(from_name, from_port, "slide_%d" % to_index, 0)


func _layout_mode() -> IDEnums.CourseViewerLayout:
	if _course == null:
		return IDEnums.CourseViewerLayout.HORIZONTAL
	return _course.viewer_layout


func _auto_layout_offset(index: int) -> Vector2:
	# Placeholder until size-based layout runs; Free uses this when a slide has no saved offset.
	var step := _PLACEHOLDER_CARD_SIZE.x + _NODE_MARGIN
	if _layout_mode() == IDEnums.CourseViewerLayout.VERTICAL:
		step = _PLACEHOLDER_CARD_SIZE.y + _NODE_MARGIN
		return Vector2(_LAYOUT_ORIGIN.x, _LAYOUT_ORIGIN.y + float(index) * step)
	return Vector2(_LAYOUT_ORIGIN.x + float(index) * step, _LAYOUT_ORIGIN.y)


func _card_offset(index: int, data: IDSlideData) -> Vector2:
	if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
		if data != null and data.viewer_offset != Vector2.ZERO:
			return data.viewer_offset
	return _auto_layout_offset(index)


func _card_size(card: IDCourseViewerCard) -> Vector2:
	card.reset_size()
	var sz := card.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = card.get_combined_minimum_size()
	if sz.x < _PLACEHOLDER_CARD_SIZE.x:
		sz.x = _PLACEHOLDER_CARD_SIZE.x
	if sz.y < _PLACEHOLDER_CARD_SIZE.y:
		sz.y = _PLACEHOLDER_CARD_SIZE.y
	return sz


func _cards() -> Array[IDCourseViewerCard]:
	var cards: Array[IDCourseViewerCard] = []
	if graph_edit == null:
		return cards
	for child in graph_edit.get_children():
		if child is IDCourseViewerCard:
			cards.append(child as IDCourseViewerCard)
	return cards


func _has_sections() -> bool:
	return _course != null and not _course.sections.is_empty()


func _section_frame_name(section_id: String) -> String:
	return "section_%s" % section_id


func _section_id_from_frame_name(frame_name: String) -> String:
	if frame_name.begins_with("section_"):
		return frame_name.substr("section_".length())
	return ""


func _frame_for_section(section_id: String) -> GraphFrame:
	if graph_edit == null or section_id.is_empty():
		return null
	var node := graph_edit.get_node_or_null(_section_frame_name(section_id))
	return node as GraphFrame


func _build_section_frames() -> void:
	if graph_edit == null or _course == null:
		return
	for section in _course.sections:
		if section == null or section.section_id.is_empty():
			continue
		var frame := IDCourseViewerSectionFrame.new()
		graph_edit.add_child(frame)
		var section_title := section.title if not section.title.is_empty() else section.section_id
		frame.setup(section.section_id, section_title)
		frame.remove_requested.connect(_on_section_remove_requested)
		for i in _course.slides.size():
			var data: IDSlideData = _course.slides[i]
			if data != null and data.section_id == section.section_id:
				graph_edit.attach_graph_element_to_frame("slide_%d" % i, frame.name)


func _layout_blocks() -> Array:
	var blocks: Array = []
	if _course == null:
		return blocks
	var by_index := {}
	for card in _cards():
		by_index[card.slide_index] = card
	for section in _course.sections:
		if section == null or section.section_id.is_empty():
			continue
		var block_cards: Array[IDCourseViewerCard] = []
		for i in _course.slides.size():
			var data: IDSlideData = _course.slides[i]
			if data != null and data.section_id == section.section_id and by_index.has(i):
				block_cards.append(by_index[i])
		blocks.append({
			"section_id": section.section_id,
			"cards": block_cards,
		})
	var ungrouped: Array[IDCourseViewerCard] = []
	for i in _course.slides.size():
		var data: IDSlideData = _course.slides[i]
		var sid := ""
		if data != null:
			sid = data.section_id
		if sid.is_empty() or _course.get_section(sid) == null:
			if by_index.has(i):
				ungrouped.append(by_index[i])
	if not ungrouped.is_empty():
		blocks.append({
			"section_id": "",
			"cards": ungrouped,
		})
	return blocks


func _sort_cards_along_axis(cards: Array) -> void:
	var vertical := _layout_mode() == IDEnums.CourseViewerLayout.VERTICAL
	cards.sort_custom(func(a: IDCourseViewerCard, b: IDCourseViewerCard) -> bool:
		if vertical:
			return a.position_offset.y < b.position_offset.y
		return a.position_offset.x < b.position_offset.x
	)


func _sync_section_ids_from_frames() -> bool:
	if _course == null or graph_edit == null:
		return false
	var changed := false
	for card in _cards():
		if card.slide_index < 0 or card.slide_index >= _course.slides.size():
			continue
		var data: IDSlideData = _course.slides[card.slide_index]
		if data == null:
			continue
		var new_id := _section_id_at_card(card)
		if data.section_id != new_id:
			data.section_id = new_id
			changed = true
		_attach_card_to_section(card, new_id)
		card._set_ungroup_visible(not new_id.is_empty())
	return changed


func _section_id_at_card(card: IDCourseViewerCard) -> String:
	if _course == null or graph_edit == null:
		return ""
	var center := card.position_offset + card.size * 0.5
	for section in _course.sections:
		if section == null or section.section_id.is_empty():
			continue
		var frame := _frame_for_section(section.section_id)
		if frame == null:
			continue
		var rect := Rect2(frame.position_offset, frame.size)
		if rect.has_point(center):
			return section.section_id
	return ""


func _attach_card_to_section(card: IDCourseViewerCard, section_id: String) -> void:
	if graph_edit == null:
		return
	var card_name := StringName(card.name)
	var current := graph_edit.get_element_frame(card_name)
	if section_id.is_empty():
		if current != null:
			graph_edit.detach_graph_element_from_frame(card_name)
		return
	var frame_name := _section_frame_name(section_id)
	if current != null and str(current.name) == frame_name:
		return
	graph_edit.attach_graph_element_to_frame(card_name, StringName(frame_name))


func _is_graph_frame_selected() -> bool:
	if graph_edit == null:
		return false
	for child in graph_edit.get_children():
		if child is GraphFrame and (child as GraphFrame).selected:
			return true
	return false


func _reorder_single_flow() -> void:
	var cards := _cards()
	_sort_cards_along_axis(cards)
	var new_order: Array[IDSlideData] = []
	var changed := false
	for i in cards.size():
		var from_index: int = cards[i].slide_index
		if from_index != i:
			changed = true
		if from_index >= 0 and from_index < _course.slides.size():
			new_order.append(_course.slides[from_index])
	if not changed or new_order.size() != _course.slides.size():
		_apply_current_layout_in_place()
		return
	var old_order: Array[IDSlideData] = _course.slides.duplicate()
	_commit_slide_order("Reorder course slides", old_order, new_order)


func _reorder_within_sections(section_changed: bool) -> void:
	var new_order: Array[IDSlideData] = []
	for block in _layout_blocks():
		var block_cards: Array = (block["cards"] as Array).duplicate()
		_sort_cards_along_axis(block_cards)
		for card in block_cards:
			var viewer_card := card as IDCourseViewerCard
			if viewer_card.slide_index >= 0 and viewer_card.slide_index < _course.slides.size():
				new_order.append(_course.slides[viewer_card.slide_index])
	if new_order.size() != _course.slides.size():
		if section_changed:
			_save_course()
		_apply_current_layout_in_place()
		return
	var changed := false
	for i in new_order.size():
		if new_order[i] != _course.slides[i]:
			changed = true
			break
	if not changed:
		if section_changed:
			_save_course()
		_apply_current_layout_in_place()
		return
	var old_order: Array[IDSlideData] = _course.slides.duplicate()
	_commit_slide_order("Reorder course slides", old_order, new_order)


func _sync_layout_option() -> void:
	if layout_option == null or _course == null:
		return
	var idx := int(_course.viewer_layout)
	if layout_option.selected != idx:
		_rebuilding = true
		layout_option.select(idx)
		_rebuilding = false


func _on_layout_item_selected(index: int) -> void:
	if _rebuilding or _course == null or layout_option == null:
		return
	var new_layout: IDEnums.CourseViewerLayout = layout_option.get_item_id(index)
	if new_layout == _course.viewer_layout:
		return
	if new_layout == IDEnums.CourseViewerLayout.FREE:
		_seed_unset_free_offsets()
	_course.viewer_layout = new_layout
	_save_course()
	_apply_current_layout_in_place()


func _seed_unset_free_offsets() -> void:
	if _course == null:
		return
	for card in _cards():
		if card.slide_index < 0 or card.slide_index >= _course.slides.size():
			continue
		var data: IDSlideData = _course.slides[card.slide_index]
		if data != null and data.viewer_offset == Vector2.ZERO:
			data.viewer_offset = card.position_offset


func _apply_current_layout_in_place() -> void:
	if _course == null:
		return
	if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
		_layout_generation += 1
		_rebuilding = true
		for card in _cards():
			if card.slide_index < 0 or card.slide_index >= _course.slides.size():
				continue
			card.position_offset = _card_offset(card.slide_index, _course.slides[card.slide_index])
		_rebuilding = false
		return
	_rebuilding = true
	_layout_generation += 1
	call_deferred("_apply_auto_layout_deferred", _layout_generation)


func _apply_auto_layout_in_place() -> void:
	if _course == null:
		return
	if not _has_sections():
		_layout_single_flow()
		return
	_layout_section_blocks()


func _layout_single_flow() -> void:
	var ordered := _cards()
	ordered.sort_custom(func(a: IDCourseViewerCard, b: IDCourseViewerCard) -> bool:
		return a.slide_index < b.slide_index
	)
	var pos := _LAYOUT_ORIGIN
	var vertical := _layout_mode() == IDEnums.CourseViewerLayout.VERTICAL
	for card in ordered:
		card.position_offset = pos
		var sz := _card_size(card)
		if vertical:
			pos.y += sz.y + _NODE_MARGIN
		else:
			pos.x += sz.x + _NODE_MARGIN


func _layout_section_blocks() -> void:
	var origin := _LAYOUT_ORIGIN
	var vertical := _layout_mode() == IDEnums.CourseViewerLayout.VERTICAL
	for block in _layout_blocks():
		var cards: Array = block["cards"]
		var pos := origin + _FRAME_CHROME
		if cards.is_empty():
			var frame := _frame_for_section(str(block.get("section_id", "")))
			if frame != null:
				frame.position_offset = origin
			if vertical:
				origin.x += 240.0 + _SECTION_GAP
			else:
				origin.y += 80.0 + _SECTION_GAP
			continue
		var block_size := Vector2.ZERO
		for card in cards:
			var viewer_card := card as IDCourseViewerCard
			viewer_card.position_offset = pos
			var sz := _card_size(viewer_card)
			if vertical:
				pos.y += sz.y + _NODE_MARGIN
				block_size.x = maxf(block_size.x, sz.x)
				block_size.y = pos.y - origin.y
			else:
				pos.x += sz.x + _NODE_MARGIN
				block_size.x = pos.x - origin.x
				block_size.y = maxf(block_size.y, sz.y)
		if vertical:
			origin.x += maxf(block_size.x, 220.0) + _FRAME_CHROME.x + _SECTION_GAP
		else:
			origin.y += maxf(block_size.y, 80.0) + _FRAME_CHROME.y + _SECTION_GAP


func _apply_auto_layout_deferred(generation: int) -> void:
	if generation != _layout_generation:
		return
	if _course != null and _layout_mode() != IDEnums.CourseViewerLayout.FREE:
		_apply_auto_layout_in_place()
	_rebuilding = false


func _on_end_node_move() -> void:
	if _rebuilding or _course == null or graph_edit == null:
		return
	_rebuilding = true
	if _is_graph_frame_selected():
		if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
			_save_free_offsets()
		_rebuilding = false
		return
	var section_changed := _sync_section_ids_from_frames()
	if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
		_save_free_offsets()
		if section_changed:
			_save_course()
		_rebuilding = false
		return
	if not _has_sections():
		_reorder_single_flow()
		return
	_reorder_within_sections(section_changed)


func _save_free_offsets() -> void:
	if _course == null:
		return
	for card in _cards():
		if card.slide_index < 0 or card.slide_index >= _course.slides.size():
			continue
		var data: IDSlideData = _course.slides[card.slide_index]
		if data != null:
			data.viewer_offset = card.position_offset
	_save_course()


func _next_free_offset() -> Vector2:
	if _course == null or _course.slides.is_empty():
		return _LAYOUT_ORIGIN
	var last_i := _course.slides.size() - 1
	var last_pos := _card_offset(last_i, _course.slides[last_i])
	var last_size := _PLACEHOLDER_CARD_SIZE
	if graph_edit != null:
		var live := graph_edit.get_node_or_null("slide_%d" % last_i)
		if live is IDCourseViewerCard:
			var card := live as IDCourseViewerCard
			last_pos = card.position_offset
			last_size = _card_size(card)
	return last_pos + Vector2(last_size.x + _NODE_MARGIN, 0.0)


func _save_course() -> void:
	if _course != null and not _course.resource_path.is_empty():
		ResourceSaver.save(_course)


func _on_delete_nodes_request(node_names: Array) -> void:
	for node_name in node_names:
		var node := graph_edit.get_node_or_null(NodePath(str(node_name)))
		if node is IDCourseViewerSectionFrame:
			_on_section_remove_requested((node as IDCourseViewerSectionFrame).section_id)
			return
		if node is GraphFrame:
			_on_section_remove_requested(_section_id_from_frame_name(str(node.name)))
			return
		if node is IDCourseViewerCard:
			_on_remove_requested((node as IDCourseViewerCard).slide_index)
			return


func _on_connection_request(_from_node: StringName, _from_port: int, _to_node: StringName, _to_port: int) -> void:
	# Sequence and IDButton jumps are owned by slide scenes, not free wiring.
	pass


func _on_linked_to_frame(elements: Array, frame_name: StringName) -> void:
	if _rebuilding or _course == null or graph_edit == null:
		return
	var section_id := _section_id_from_frame_name(str(frame_name))
	if section_id.is_empty() or _course.get_section(section_id) == null:
		return
	var changed := false
	for element in elements:
		var element_name := StringName()
		if element is Node:
			element_name = (element as Node).name
		else:
			element_name = StringName(str(element))
		graph_edit.attach_graph_element_to_frame(element_name, frame_name)
		var node := graph_edit.get_node_or_null(NodePath(str(element_name)))
		if not (node is IDCourseViewerCard):
			continue
		var card := node as IDCourseViewerCard
		if card.slide_index < 0 or card.slide_index >= _course.slides.size():
			continue
		var data: IDSlideData = _course.slides[card.slide_index]
		if data != null and data.section_id != section_id:
			data.section_id = section_id
			changed = true
	if not changed:
		return
	_save_course()
	if _layout_mode() != IDEnums.CourseViewerLayout.FREE:
		_apply_current_layout_in_place()


func _on_add_section_pressed() -> void:
	if _course == null:
		_set_status("Load a course first.")
		return
	_section_name_edit.text = ""
	_section_dialog.popup_centered()
	_section_name_edit.grab_focus()


func _on_section_name_confirmed() -> void:
	if _course == null:
		return
	var section_title := _section_name_edit.text.strip_edges()
	if section_title.is_empty():
		_set_status("Section name is required.")
		return
	var section := IDSectionData.new()
	section.title = section_title
	section.section_id = _unique_section_id(section_title)
	var old_sections: Array[IDSectionData] = _course.sections.duplicate()
	var new_sections: Array[IDSectionData] = _course.sections.duplicate()
	new_sections.append(section)
	var ids := _snapshot_section_ids()
	_commit_section_state("Add course section", new_sections, ids, old_sections, ids)


func _unique_section_id(section_title: String) -> String:
	var slug := ""
	for ch in section_title.to_lower():
		var is_alnum := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if is_alnum:
			slug += ch
		elif ch == " " or ch == "-" or ch == "_":
			if not slug.ends_with("_"):
				slug += "_"
	slug = slug.trim_prefix("_").trim_suffix("_")
	if slug.is_empty():
		slug = "section"
	var section_id := slug
	var n := 2
	while _course != null and _course.get_section(section_id) != null:
		section_id = "%s_%d" % [slug, n]
		n += 1
	return section_id


func _snapshot_section_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if _course == null:
		return ids
	for data in _course.slides:
		ids.append(data.section_id if data != null else "")
	return ids


func _commit_section_state(
	action_name: String,
	new_sections: Array,
	new_ids: PackedStringArray,
	old_sections: Array,
	old_ids: PackedStringArray
) -> void:
	if _plugin == null:
		_apply_section_state(new_sections, new_ids)
		return
	var undo := _plugin.get_undo_redo()
	undo.create_action(action_name)
	undo.add_do_method(self, "_apply_section_state", new_sections, new_ids)
	undo.add_undo_method(self, "_apply_section_state", old_sections, old_ids)
	undo.commit_action()


func _apply_section_state(sections_order: Array, slide_section_ids: PackedStringArray) -> void:
	if _course == null:
		return
	var typed: Array[IDSectionData] = []
	typed.assign(sections_order)
	_course.sections = typed
	for i in _course.slides.size():
		if _course.slides[i] == null:
			continue
		var sid := ""
		if i < slide_section_ids.size():
			sid = slide_section_ids[i]
		_course.slides[i].section_id = sid
	_course.emit_changed()
	_save_course()
	refresh()


func _on_ungroup_requested(slide_index: int) -> void:
	if _course == null or slide_index < 0 or slide_index >= _course.slides.size():
		return
	var data: IDSlideData = _course.slides[slide_index]
	if data == null or data.section_id.is_empty():
		return
	var old_sections: Array[IDSectionData] = _course.sections.duplicate()
	var old_ids := _snapshot_section_ids()
	var new_ids := PackedStringArray()
	for i in old_ids.size():
		new_ids.append("" if i == slide_index else old_ids[i])
	_commit_section_state("Ungroup slide from section", old_sections, new_ids, old_sections, old_ids)


func _on_section_remove_requested(section_id: String) -> void:
	if _course == null or section_id.is_empty() or _course.get_section(section_id) == null:
		return
	_pending_section_id = section_id
	var section := _course.get_section(section_id)
	var label := section_id
	if section != null and not section.title.is_empty():
		label = section.title
	_confirm_remove_section.dialog_text = "Remove section \"%s\"?\nSlides stay in the course, ungrouped." % label
	_confirm_remove_section.popup_centered()


func _on_remove_section_confirmed() -> void:
	var section_id := _pending_section_id
	_pending_section_id = ""
	if _course == null or section_id.is_empty():
		return
	var old_sections: Array[IDSectionData] = _course.sections.duplicate()
	var old_ids := _snapshot_section_ids()
	var new_sections: Array[IDSectionData] = _course.sections.duplicate()
	for i in range(new_sections.size() - 1, -1, -1):
		var section: IDSectionData = new_sections[i]
		if section != null and section.section_id == section_id:
			new_sections.remove_at(i)
	var new_ids := PackedStringArray()
	for sid in old_ids:
		new_ids.append("" if sid == section_id else sid)
	_commit_section_state("Remove course section", new_sections, new_ids, old_sections, old_ids)


func _on_add_slide_pressed() -> void:
	if _course == null:
		_set_status("Load a course first.")
		return
	_file_dialog.current_dir = "res://slides"
	_file_dialog.popup_centered_ratio(0.6)


func _on_slide_scene_selected(path: String) -> void:
	if _course == null:
		return
	var packed := load(path) as PackedScene
	if packed == null:
		_set_status("Not a scene: %s" % path)
		return
	for existing: IDSlideData in _course.slides:
		if existing != null and existing.scene != null and existing.scene.resource_path == path:
			_set_status("That slide is already in the course.")
			return
	var data := IDSlideData.new()
	data.scene = packed
	if _layout_mode() == IDEnums.CourseViewerLayout.FREE:
		data.viewer_offset = _next_free_offset()
	var old_order: Array[IDSlideData] = _course.slides.duplicate()
	var new_order: Array[IDSlideData] = _course.slides.duplicate()
	new_order.append(data)
	_commit_slide_order("Add slide to course", old_order, new_order)


func _on_remove_requested(slide_index: int) -> void:
	if _course == null or slide_index < 0 or slide_index >= _course.slides.size():
		return
	_pending_remove_index = slide_index
	var data: IDSlideData = _course.slides[slide_index]
	var label := "this slide"
	if data != null:
		if not data.title.is_empty():
			label = data.title
		elif not data.slide_id.is_empty():
			label = data.slide_id
	_confirm_remove.dialog_text = "Remove \"%s\" from the course?\nThe scene file will not be deleted." % label
	_confirm_remove.popup_centered()


func _on_remove_confirmed() -> void:
	var slide_index := _pending_remove_index
	_pending_remove_index = -1
	if _course == null or slide_index < 0 or slide_index >= _course.slides.size():
		return
	var old_order: Array[IDSlideData] = _course.slides.duplicate()
	var new_order: Array[IDSlideData] = _course.slides.duplicate()
	new_order.remove_at(slide_index)
	_commit_slide_order("Remove slide from course", old_order, new_order)


func _commit_slide_order(action_name: String, old_order: Array, new_order: Array) -> void:
	if _plugin == null:
		_apply_slide_order(new_order)
		return
	var undo := _plugin.get_undo_redo()
	undo.create_action(action_name)
	undo.add_do_method(self, "_apply_slide_order", new_order)
	undo.add_undo_method(self, "_apply_slide_order", old_order)
	undo.commit_action()


func _apply_slide_order(order: Array) -> void:
	if _course == null:
		return
	var typed: Array[IDSlideData] = []
	typed.assign(order)
	_course.slides = typed
	_course.emit_changed()
	_save_course()
	refresh()


func _on_open_slide(slide_index: int) -> void:
	if _course == null or slide_index < 0 or slide_index >= _course.slides.size():
		return
	var data: IDSlideData = _course.slides[slide_index]
	if data == null or data.scene == null:
		_set_status("Slide has no scene.")
		return
	var path := data.scene.resource_path
	if path.is_empty():
		_set_status("Slide scene has no path.")
		return
	EditorInterface.open_scene_from_path(path)


func _clear_nodes() -> void:
	if graph_edit == null:
		return
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphElement:
			graph_edit.remove_child(child)
			child.queue_free()


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _set_course_controls_enabled(enabled: bool) -> void:
	if add_slide_button != null:
		add_slide_button.disabled = not enabled
	if add_section_button != null:
		add_section_button.disabled = not enabled
	if layout_option != null:
		layout_option.disabled = not enabled
