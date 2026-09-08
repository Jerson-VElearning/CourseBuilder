class_name IDChoice
extends BaseButton

## Selectable quiz answer. Attach this script to a Button, TextureButton, or CheckBox.
## Set Is Correct on the right choice(s). Choice Id is the SCORM response token.
## See: nodes/id_quiz_mc.gd, nodes/id_quiz.gd

## If true, this choice is part of the correct set (one for MC, one or more for MR).
@export var is_correct: bool = false

## Stable id for learner_response (e.g. "a"). Empty = node name.
@export var choice_id: String = ""


func get_choice_id() -> String:
	if not choice_id.is_empty():
		return choice_id
	return name
