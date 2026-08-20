class_name IDSlideLinkScanner
extends RefCounted

## Reads next_slide and IDButton.navigate_to from a slide PackedScene without instancing it.
## See: editor/course_viewer.gd, nodes/id_button.gd, nodes/id_slide.gd

const _BUTTON_SCRIPT_PATH := "res://addons/course_builder/nodes/id_button.gd"


## Returns { next_slide: String, jumps: Array[{ label: String, target_id: String }] }.
static func scan(scene: PackedScene) -> Dictionary:
	var result := {
		"next_slide": "",
		"jumps": [],
	}
	if scene == null:
		return result
	var state := scene.get_state()
	if state.get_node_count() < 1:
		return result
	for node_i in state.get_node_count():
		var script_path := ""
		var navigate_to := ""
		var button_text := ""
		var next_slide := ""
		for prop_i in state.get_node_property_count(node_i):
			var prop_name := state.get_node_property_name(node_i, prop_i)
			var prop_value: Variant = state.get_node_property_value(node_i, prop_i)
			match prop_name:
				"script":
					if prop_value is Script:
						script_path = (prop_value as Script).resource_path
				"navigate_to":
					navigate_to = str(prop_value)
				"text":
					button_text = str(prop_value)
				"next_slide":
					next_slide = str(prop_value)
		if node_i == 0 and not next_slide.is_empty():
			result["next_slide"] = next_slide
		if (script_path == _BUTTON_SCRIPT_PATH or script_path.ends_with("/id_button.gd")) and not navigate_to.is_empty():
			var label := button_text if not button_text.is_empty() else navigate_to
			result["jumps"].append({
				"label": label,
				"target_id": navigate_to,
			})
	return result
