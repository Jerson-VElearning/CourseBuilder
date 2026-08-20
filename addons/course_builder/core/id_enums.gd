class_name IDEnums
extends Object

## Shared enums for CourseBuilder.
## Completion rules: ON_ENTER, ON_CONTINUE, ALL_REVEALS, MEDIA_FINISHED.
## RevealAnimation / RevealDirection are used by IDReveal and IDAnimated.
## See: resources/slide_data.gd, runtime/completion_evaluator.gd, nodes/id_slide.gd, nodes/id_reveal.gd, nodes/id_animated.gd

enum CompletionRule {
	ON_ENTER,
	ON_CONTINUE,
	ALL_REVEALS,
	MEDIA_FINISHED,
}

enum AccessMode {
	FREE,
	SEQUENTIAL,
	RESTRICTED,
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
