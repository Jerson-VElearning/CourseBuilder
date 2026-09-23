@tool
class_name IDQuiz
extends IDSlide

## Shared quiz-slide base. Authors pick IDQuiz_MC (or a future type), not this node.
## Next stays locked until the question records a final answer and calls mark_complete().
## See: nodes/id_quiz_mc.gd, resources/quiz_data.gd, runtime/course_runtime.gd

const _InteractionRecordScript := preload("res://addons/course_builder/resources/interaction_record.gd")

## Matches IDQuizData.quiz_id. Empty = practice; not counted in any quiz total.
@export var quiz_id: String = ""

## If false, the response is recorded as NEUTRAL with weighting 0 (survey).
@export var graded: bool = true

## Points awarded when the final answer is correct (SCORM weighting).
@export var points: float = 1.0:
	set(value):
		points = maxf(value, 0.0)

## Tries before Incorrect feedback. Ignored as a hard stop when Fail Policy is Must Correct.
@export var max_attempts: int = 1:
	set(value):
		max_attempts = maxi(value, 1)

@export var fail_policy: IDEnums.QuizFailPolicy = IDEnums.QuizFailPolicy.CONTINUE

## Check/Submit. Use a Button or TextureButton, not IDButton (that navigates).
@export var submit_button: BaseButton

@export var correct_feedback: Control
@export var try_again_feedback: Control
@export var incorrect_feedback: Control

var _attempts_left: int = 1
var _enter_ms: int = 0
var _resolved: bool = false


func _init() -> void:
	completion_rule = IDEnums.CompletionRule.QUIZ


func _validate_property(property: Dictionary) -> void:
	if property.name == "completion_rule":
		property.usage = PROPERTY_USAGE_STORAGE


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if submit_button == null:
		warnings.append("Assign a Submit button (Button or TextureButton, not IDButton).")
	elif submit_button is IDButton:
		warnings.append("Submit should not be an IDButton; IDButton navigates instead of grading.")
	return warnings


func _ready() -> void:
	if completion_rule != IDEnums.CompletionRule.QUIZ:
		completion_rule = IDEnums.CompletionRule.QUIZ
	if Engine.is_editor_hint():
		return
	super._ready()
	_attempts_left = max_attempts
	_enter_ms = Time.get_ticks_msec()
	_hide_feedback()
	_setup_question()
	_wire_submit()
	_set_choices_enabled(true)
	_update_submit_enabled()


func _setup_question() -> void:
	pass


func _get_selected_ids() -> PackedStringArray:
	return PackedStringArray()


func _get_correct_ids() -> PackedStringArray:
	return PackedStringArray()


func _has_selection() -> bool:
	return not _get_selected_ids().is_empty()


func _clear_selection() -> void:
	pass


func _set_choices_enabled(_enabled: bool) -> void:
	pass


func _on_choice_changed(_pressed: bool = false) -> void:
	_update_submit_enabled()


func _wire_submit() -> void:
	if submit_button == null:
		push_warning("IDQuiz: Submit button is not assigned.")
		return
	if submit_button is IDButton:
		push_warning("IDQuiz: Submit should not be an IDButton.")
	if not submit_button.pressed.is_connected(_on_submit):
		submit_button.pressed.connect(_on_submit)


func _update_submit_enabled() -> void:
	if submit_button == null:
		return
	submit_button.disabled = _resolved or not _has_selection()


func _on_submit() -> void:
	if _resolved or not _has_selection():
		return
	if not graded:
		_finalize(IDEnums.InteractionResult.NEUTRAL)
		return
	if _is_answer_correct():
		_finalize(IDEnums.InteractionResult.CORRECT)
		return
	var keep_trying := fail_policy == IDEnums.QuizFailPolicy.MUST_CORRECT or _attempts_left > 1
	if keep_trying:
		if fail_policy == IDEnums.QuizFailPolicy.CONTINUE:
			_attempts_left -= 1
		_show_feedback(try_again_feedback)
		_clear_selection()
		_set_choices_enabled(true)
		_update_submit_enabled()
		return
	_finalize(IDEnums.InteractionResult.INCORRECT)


func _is_answer_correct() -> bool:
	return IDInteractionRecord.choice_pattern(_get_selected_ids()) == IDInteractionRecord.choice_pattern(_get_correct_ids())


func _finalize(result: IDEnums.InteractionResult) -> void:
	_resolved = true
	_set_choices_enabled(false)
	_update_submit_enabled()
	match result:
		IDEnums.InteractionResult.CORRECT:
			_show_feedback(correct_feedback)
		IDEnums.InteractionResult.INCORRECT:
			_show_feedback(incorrect_feedback)
		_:
			_show_feedback(correct_feedback)
	_record_and_complete(result)


func _record_and_complete(result: IDEnums.InteractionResult) -> void:
	if not has_node("/root/IDCourseRuntime"):
		return
	var record := IDInteractionRecord.new()
	record.id = slide_id
	record.quiz_id = quiz_id
	record.type = IDEnums.InteractionType.CHOICE
	record.learner_response = IDInteractionRecord.choice_pattern(_get_selected_ids())
	record.correct_response = IDInteractionRecord.choice_pattern(_get_correct_ids())
	record.result = result
	record.weighting = points if graded else 0.0
	record.latency_sec = maxf(float(Time.get_ticks_msec() - _enter_ms) / 1000.0, 0.0)
	record.description = title if not title.is_empty() else notes
	IDCourseRuntime.record_interaction(record)
	IDCourseRuntime.mark_complete()


func _hide_feedback() -> void:
	if correct_feedback != null:
		correct_feedback.visible = false
	if try_again_feedback != null:
		try_again_feedback.visible = false
	if incorrect_feedback != null:
		incorrect_feedback.visible = false


func _show_feedback(layer: Control) -> void:
	_hide_feedback()
	if layer != null:
		layer.visible = true
