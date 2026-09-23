class_name IDInteractionRecord
extends RefCounted

## One final graded response for a question slide. Shaped for a later SCORM / xAPI mapper.
## See: resources/quiz_result.gd, runtime/course_runtime.gd, tracking/tracking_backend.gd

## Question id (IDSlide.slide_id) → cmi.interactions.n.id.
var id: String = ""
## Owning quiz. Empty = practice / knowledge check (not in a quiz total).
var quiz_id: String = ""
var type: IDEnums.InteractionType = IDEnums.InteractionType.CHOICE
## SCORM choice pattern, e.g. "a" or "a[,]c". Use choice_id tokens, not node paths.
var learner_response: String = ""
var correct_response: String = ""
var result: IDEnums.InteractionResult = IDEnums.InteractionResult.INCORRECT
## Question point value (SCORM weighting), not points earned.
var weighting: float = 0.0
var latency_sec: float = 0.0
var description: String = ""


## Sorted choice_ids joined with SCORM's multiple-response delimiter.
static func choice_pattern(ids: PackedStringArray) -> String:
	var list: Array[String] = []
	for item in ids:
		var token := str(item)
		if not token.is_empty():
			list.append(token)
	list.sort()
	var joined := ""
	for i in list.size():
		if i > 0:
			joined += "[,]"
		joined += list[i]
	return joined
