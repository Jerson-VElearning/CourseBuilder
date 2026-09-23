@tool
class_name IDQuiz_MC
extends IDQuiz

## Multiple-choice or multiple-response quiz slide. Root of a question scene.
## Add IDChoice children (or attach id_choice.gd to a TextureButton). Check Is Correct on the answer(s).
## See: nodes/id_quiz.gd, nodes/id_choice.gd, resources/quiz_data.gd

@export var quiz_type: IDEnums.QuizType = IDEnums.QuizType.MULTIPLE_CHOICE:
	set(value):
		if quiz_type == value:
			return
		quiz_type = value
		update_configuration_warnings()

## Optional. Empty = every IDChoice descendant. Use this to skip decorative buttons.
@export var choices: Array[IDChoice] = []:
	set(value):
		choices = value
		update_configuration_warnings()

var _choices: Array[IDChoice] = []
var _button_group: ButtonGroup


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	var found := _editor_choices()
	if found.is_empty():
		warnings.append("Add IDChoice children (or assign them on Choices).")
		return warnings
	var correct_count := 0
	for choice in found:
		if choice.is_correct:
			correct_count += 1
	if quiz_type == IDEnums.QuizType.MULTIPLE_CHOICE:
		if correct_count != 1:
			warnings.append("Multiple choice needs exactly one IDChoice with Is Correct.")
	elif correct_count < 1:
		warnings.append("Multiple response needs at least one IDChoice with Is Correct.")
	return warnings


func _setup_question() -> void:
	_choices = _runtime_choices()
	var exclusive := quiz_type == IDEnums.QuizType.MULTIPLE_CHOICE
	if exclusive:
		_button_group = ButtonGroup.new()
		_button_group.allow_unpress = false
	for choice in _choices:
		choice.toggle_mode = true
		choice.button_group = _button_group if exclusive else null
		if not choice.toggled.is_connected(_on_choice_changed):
			choice.toggled.connect(_on_choice_changed)
		choice.button_pressed = false
		choice.disabled = false


func _get_selected_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for choice in _choices:
		if choice.button_pressed:
			ids.append(choice.get_choice_id())
	return ids


func _get_correct_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for choice in _choices:
		if choice.is_correct:
			ids.append(choice.get_choice_id())
	return ids


func _clear_selection() -> void:
	for choice in _choices:
		choice.set_pressed_no_signal(false)


func _set_choices_enabled(enabled: bool) -> void:
	for choice in _choices:
		choice.disabled = not enabled


func _runtime_choices() -> Array[IDChoice]:
	var assigned: Array[IDChoice] = []
	for choice in choices:
		if choice != null:
			assigned.append(choice)
	if not assigned.is_empty():
		return assigned
	return _find_choice_nodes()


func _editor_choices() -> Array[IDChoice]:
	if not choices.is_empty():
		var assigned: Array[IDChoice] = []
		for choice in choices:
			if choice != null:
				assigned.append(choice)
		if not assigned.is_empty():
			return assigned
	return _find_choice_nodes()


func _find_choice_nodes() -> Array[IDChoice]:
	var found: Array[IDChoice] = []
	for child in find_children("", "IDChoice", true, false):
		if child is IDChoice:
			found.append(child as IDChoice)
	return found
