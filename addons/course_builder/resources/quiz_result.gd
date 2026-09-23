class_name IDQuizResult
extends RefCounted

## Session totals for one IDQuizData. Reset when the course starts.
## A later results scene can bind to IDCourseRuntime.get_quiz_result(quiz_id).
## See: resources/quiz_data.gd, resources/interaction_record.gd, runtime/course_runtime.gd

var quiz_id: String = ""
var score_raw: float = 0.0
var score_max: float = 0.0
var percent: float = 0.0
var passed: bool = false
var complete: bool = false
var interactions: Array[IDInteractionRecord] = []


func get_interaction(slide_id: String) -> IDInteractionRecord:
	for record in interactions:
		if record != null and record.id == slide_id:
			return record
	return null


func replace_or_add(record: IDInteractionRecord) -> void:
	if record == null:
		return
	for i in interactions.size():
		if interactions[i] != null and interactions[i].id == record.id:
			interactions[i] = record
			return
	interactions.append(record)
