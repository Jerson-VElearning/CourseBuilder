class_name IDButton
extends Button

## Course-aware button. Empty navigate_to calls request_next(); otherwise go_to(id).
## Does not walk the slide list itself — the runtime owns navigation.
## See: runtime/course_runtime.gd, nodes/id_slide.gd

## Slide id to open. Leave empty to continue (complete + next, or finish the course).
@export var navigate_to: String = ""


func _ready() -> void:
	pressed.connect(_on_pressed)
	_apply_default_style()


func _on_pressed() -> void:
	if not has_node("/root/IDCourseRuntime"):
		push_warning("IDButton: IDCourseRuntime autoload is missing.")
		return
	if navigate_to.is_empty():
		IDCourseRuntime.request_next()
	else:
		IDCourseRuntime.go_to(navigate_to)


func _apply_default_style() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("E97132")
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", normal)
	add_theme_stylebox_override("pressed", normal)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_font_size_override("font_size", 20)
