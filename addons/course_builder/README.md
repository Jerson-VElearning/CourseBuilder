# CourseBuilder

Godot 4.5 plugin for instructional-design courses. One Godot project = one course.

## Folder map

| Path | Job |
|------|-----|
| `core/` | Shared enums. No UI, no navigation. |
| `resources/` | Course, slides, sections, and quizzes. `player_config.tres` is unused for layout (edit the player scene). |
| `runtime/` | Navigation, completion, quiz results, signals. Player and buttons call this. |
| `player/` | Prebuilt `course_player.tscn` (stage, chrome, menu overlay). Scripts bind nodes and refresh state. |
| `editor/` | Course Viewer bottom panel (`GraphEdit` of slide nodes, open/reorder/add/remove). |
| `nodes/` | `IDSlide`, `IDButton`, `IDReveal`, `IDAnimated`, `IDQuiz_MC`, and `IDChoice` for authors. |
| `tracking/` | No-op, debug logger in editor Play, or SCORM 1.2 `window.API` on HTML5 when the LMS preset is not Off. Course Viewer **Publish SCORM** wraps a Web export folder into a 1.2 zip (never automatic). |

LMS setup for authors: [LMS.md](LMS.md) (presets, identifier, Validate, Publish SCORM, Play log).

## Course Viewer

Bottom panel **Course Viewer** (next to Output / Debugger). Each slide is a **GraphNode**: the title is in the node header, **×** removes it from the course (scene file is kept), and double-click opens the slide. **Layout** is Horizontal, Vertical, or Free. Horizontal and Vertical space nodes in course order; dragging past another node then releasing reorders and snaps to the line. Free lets you place nodes without changing order; positions are saved on the course. Orange wires follow Next (`IDSlide.next_slide` if set, otherwise course order). Teal wires are `IDButton.navigate_to` jumps scanned from each slide scene; they route around other nodes so skipped slides do not hide the line. Dragging a new wire does not change navigation. **Add slide** appends a `.tscn` to `course.tres`. **Add section** creates a named group (GraphFrame). Drag a slide onto a frame to assign it; **Ungroup** on the slide node removes it from the section (the frame still autoshrinks around the remaining slides). Section **×** removes the section and ungroups its slides (scenes stay). The player **Menu** lists those sections as headings with slides underneath; ungrouped slides stay in course order. Uncheck **Show in Menu** on `IDSlide` / `IDSlideData` to omit a slide from the TOC (Next/Previous still visit it). Locked slides follow **Menu Navigation** on `course.tres` (Sequential, Free, or Restricted). Restyle menu items by editing the placeholders on `course_player.tscn` (show `MenuOverlay` in the editor). The **LMS** row sets a tracking preset (Off, Awareness, Graded exam, Knowledge checks, Custom). Awareness, Graded exam, and Knowledge checks rewrite **Completion By** and quiz **Report To Lms** on `course.tres`. **Validate** checks slide/quiz/choice ids for LMS use. **Publish SCORM** wraps a Godot Web export folder into a SCORM 1.2 zip; it never runs on save, Play, or export, and it is disabled when the preset is **Off**. Full walkthrough: [LMS.md](LMS.md). If the panel is missing, disable and re-enable **CourseBuilder** under Project > Project Settings > Plugins.

## Course content (outside this addon)

- `res://course/` — `course.tres`
- `res://slides/` — one scene per slide
- `res://main.tscn` — instances the prebuilt course player (edit `addons/course_builder/player/course_player.tscn` to move chrome)

Add an **IDReveal** button on a slide and assign **Content** to a Control (TextureRect, Panel, Label — not Sprite2D or other Node2D). Pick animation (Fade, Slide, Grow), direction (Slide), and duration. Test in Play; the reveal does not run in the 2D editor. The panel stays hidden until the learner clicks. Set the slide **Completion Rule** to **All Reveals** to keep Next disabled until every IDReveal on that slide has been clicked.

Assign **Voice Over** on `IDSlide` to an `AudioStream`. It plays when the slide enters and stops when the learner leaves (the slide instance is freed). Any completion rule can have narration; set **Completion Rule** to **Media Finished** to keep Next disabled until the clip ends. With Media Finished and no clip assigned, the slide completes immediately. Test in Play; voice-over does not play in the 2D editor.

To time pop-ups to a clip with an **AnimationPlayer** instead of the Voice Over slot: add **IDAnimated** controls (or change an existing Control to that type), pick animation / direction / duration in the Inspector, and leave Voice Over empty so the clip does not play twice. On the slide, add an AnimationPlayer and an AudioStreamPlayer. Put the VO on an **Audio** track and add **Call Method** tracks that call `animate` on each IDAnimated at the times you want. Set Autoplay on the AnimationPlayer. Media Finished only watches the Voice Over slot, so use **On Continue** (or On Enter) on these slides. Test in Play; IDAnimated stays visible in the 2D editor so you can layout it.

## Quizzes

How to author a multiple-choice or multiple-response slide. Completion Rule is always Quiz on these roots, so Next stays locked until the learner submits. To skip building from scratch, duplicate `res://slides/slide_quiz_mc.tscn`.

1. **Optional: add the quiz on the course.** Select `res://course/course.tres`. Under **Quizzes**, add a row: **Quiz Id** (e.g. `final`), **Title**, **Passing Percent**, **Report To Lms**, **Required To Pass**. **Completion By** on the same resource chooses when the course may finish (required slides, quiz success, or both). Or pick **Graded exam** / **Knowledge checks** on the Course Viewer **LMS** row to set those flags. Skip this step for an unscored knowledge check. Editor Play logs a mapped LMS payload when the preset is not Off (Output, prefix `[CourseBuilder LMS]`). HTML5 export writes SCORM 1.2 CMI (`window.API`, or a console mock). Course Viewer **Publish SCORM** zips a Web export with `imsmanifest.xml`. See [LMS.md](LMS.md).

2. **New scene.** Scene → New Scene → **IDQuiz_MC** as the root (Create New Node). Save under `res://slides/`. If **IDQuiz_MC** is missing from the node list, disable and re-enable **CourseBuilder** under Project → Project Settings → Plugins.

3. **Root Inspector.** Set **Title**, **Slide Id** (unique in the course), and **Quiz Id** (must match the course row, or leave empty for practice). **Quiz Type** is **Multiple Choice** (exactly one correct) or **Multiple Response** (one or more correct; the learner must match the full set). Set **Points**, **Max Attempts**, **Fail Policy** (**Continue** shows Incorrect and unlocks Next after the last miss; **Must Correct** stays until they get it right), and **Graded** (off = survey: recorded, no points).

4. **Question stem.** Add a Label (or any Control) and type the question. There is no stem export; layout it like any other slide.

5. **Choices.** Add child **IDChoice** nodes (Create New Node), or add a **TextureButton** / **CheckBox** and attach `addons/course_builder/nodes/id_choice.gd`. Change Type from IDChoice to TextureButton is valid. On each choice set **Choice Id** (`a`, `b`, … — SCORM token, not a Godot node path) and check **Is Correct** on the right answer(s). Do not use **IDButton** for answers (that navigates). Leave the root **Choices** array empty to auto-find every IDChoice; fill it only to ignore a decorative button.

6. **Submit.** Add a Button or TextureButton, not **IDButton**. Select the **IDQuiz_MC** root and drag that button onto **Submit Button**.

7. **Feedback.** Add three Controls (Labels or Panels) for correct, try-again, and incorrect copy. Drag them onto **Correct Feedback**, **Try Again Feedback**, and **Incorrect Feedback** on the root. They stay visible in the 2D editor so you can layout them; Play hides them until Submit.

8. **Course Viewer.** Open the Course Viewer bottom panel → **Add slide** → pick the `.tscn`.

9. **Play.** Run `main.tscn` and open the slide. Submit stays disabled until a choice is selected. Next stays locked until Submit finishes. Yellow warnings on the **IDQuiz_MC** root mean Submit is missing or the number of **Is Correct** checks does not match **Quiz Type**.

Multiple response is exact-match (no partial credit). Drag-and-drop and fill-in types (`IDQuiz_DD`, `IDQuiz_Fill`) are not in this version.

### Showing results

Quiz totals live on the **IDCourseRuntime** autoload for this play session only. They reset when `start_course()` runs and are not saved to `course.tres`. There is no built-in results node; a normal **IDSlide** (or a Label on it) that reads this API is the intended custom results page.

Use the **Quiz Id** from the course row (the sample uses `final`):

- `IDCourseRuntime.get_quiz_result("final")` returns an **IDQuizResult**: `score_raw` (points earned), `score_max` (points possible), `percent` (0–100), `passed`, `complete` (every graded question answered), `interactions`.
- `IDCourseRuntime.get_course_score()` is 0–100 from quizzes with **Report To Lms**.
- `IDCourseRuntime.get_interaction("quiz_ladder_angle")` is one question (that slide’s **Slide Id**). Practice slides with an empty **Quiz Id** appear here but not in a quiz total.
- Pass bar: `IDCourseRuntime.course.get_quiz("final").passing_percent`.

Example on a Label (or any Control) on the results slide:

```gdscript
extends Label

func _ready() -> void:
	var result := IDCourseRuntime.get_quiz_result("final")
	if result == null:
		text = "No quiz results yet."
		return
	text = "You scored %d of %d (%d%%). %s" % [
		int(result.score_raw),
		int(result.score_max),
		int(result.percent),
		"Passed" if result.passed else "Did not pass",
	]
```

Connect `IDCourseRuntime.quiz_updated` if the results UI is already on screen when a later question is submitted. `course_completed` emits a 0–100 score from quizzes with **Report To Lms**.

## Runtime API (autoload `IDCourseRuntime`)

`start_course`, `go_to`, `can_go_to`, `request_next`, `request_previous`, `mark_complete`, `record_interaction`, `get_quiz_result`, `get_interaction`, `get_course_score`

Signals: `slide_entered`, `slide_exited`, `slide_completed`, `course_completed`, `navigation_blocked`, `quiz_updated`

**Unlocking Next from a custom interaction:** For rules that do not complete on Continue (e.g. **All Reveals**, **Media Finished**, or your own GDScript), call `IDCourseRuntime.mark_complete()` when the learner has finished the interaction. That marks the current slide complete, emits `slide_completed`, and the player chrome enables Next via `can_go_next()`. Do not toggle the Next button yourself — stay on this API so menu locks and course finish stay consistent.
