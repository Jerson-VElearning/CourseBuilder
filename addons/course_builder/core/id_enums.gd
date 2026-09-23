class_name IDEnums
extends Object

## Shared enums for CourseBuilder.
## Completion rules: ON_ENTER, ON_CONTINUE, ALL_REVEALS, MEDIA_FINISHED, QUIZ.
## RevealAnimation / RevealDirection are used by IDReveal and IDAnimated.
## See: resources/slide_data.gd, runtime/completion_evaluator.gd, nodes/id_slide.gd, nodes/id_reveal.gd, nodes/id_animated.gd, resources/lms_settings.gd

enum CompletionRule {
	ON_ENTER,
	ON_CONTINUE,
	ALL_REVEALS,
	MEDIA_FINISHED,
	QUIZ,
}

enum AccessMode {
	FREE,
	SEQUENTIAL,
	RESTRICTED,
}

## How the runtime decides the course may finish. SCORM can map this later.
enum CourseCompletionBy {
	REQUIRED_SLIDES,
	QUIZ_SUCCESS,
	SLIDES_AND_QUIZ,
}

## Course Viewer LMS preset. Maps to completion_by / quiz report flags; not a CMI field.
enum LmsPreset {
	OFF,
	AWARENESS,
	GRADED_EXAM,
	KNOWLEDGE_CHECKS,
	CUSTOM,
}

enum QuizType {
	MULTIPLE_CHOICE,
	MULTIPLE_RESPONSE,
}

enum QuizFailPolicy {
	CONTINUE,
	MUST_CORRECT,
}

## SCORM cmi.interactions.n.type. CHOICE covers MC and MR.
enum InteractionType {
	CHOICE,
	MATCHING,
	FILL_IN,
}

enum InteractionResult {
	CORRECT,
	INCORRECT,
	NEUTRAL,
}

enum ChromePosition {
	TOP,
	BOTTOM,
}

enum CourseViewerLayout {
	HORIZONTAL,
	VERTICAL,
	FREE,
}

enum RevealAnimation {
	FADE,
	SLIDE,
	GROW,
}

enum RevealDirection {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}
