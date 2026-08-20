class_name IDCompletionEvaluator
extends RefCounted

## Decides when a slide may complete or advance. Does not store progress.
## ON_ENTER completes immediately; ON_CONTINUE on Next; ALL_REVEALS and MEDIA_FINISHED wait for mark_complete().
## See: runtime/course_runtime.gd, core/id_enums.gd, nodes/id_slide.gd

## True when entering the slide should mark it complete.
func should_complete_on_enter(rule: IDEnums.CompletionRule) -> bool:
	return rule == IDEnums.CompletionRule.ON_ENTER


## True when Next / request_next() may mark complete and then navigate.
## ALL_REVEALS and MEDIA_FINISHED block until mark_complete().
func can_complete_on_continue(rule: IDEnums.CompletionRule) -> bool:
	return rule == IDEnums.CompletionRule.ON_CONTINUE
