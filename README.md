# CourseBuilder

Godot 4.5 plugin for instructional-design courses. One Godot project is one course: you author slides as scenes, arrange them in the **Course Viewer**, and play them in a prebuilt player with Next/Previous, a table of contents, completion rules, and quizzes.

Clone this repository and open `project.godot` in Godot 4.5 to inspect the plugin. Play will not show a course until you add slides (see [Create a course](#create-a-course)).

## Requirements

- [Godot 4.5](https://godotengine.org/download)

## Install

1. Copy `addons/course_builder/` into your Godot project's `addons/` folder. The path must be `res://addons/course_builder/` (scripts preload that location).
2. In Godot: **Project → Project Settings → Plugins** and enable **CourseBuilder**.
3. Still in Project Settings, open the **Autoload** tab. Add:
   - Path: `res://addons/course_builder/runtime/course_runtime.gd`
   - Node Name: `IDCourseRuntime`
   - Enable it.
4. If the **Course Viewer** bottom panel is missing, disable and re-enable the plugin.

You should see custom types (`IDSlide`, `IDButton`, `IDReveal`, `IDAnimated`, `IDQuiz_MC`, `IDChoice`) in the Create New Node dialog, and **Course Viewer** next to Output / Debugger.

## Create a course

Course content lives **outside** the addon folder.

| Path | Role |
|------|------|
| `res://course/course.tres` | `IDCourseData` resource: slide order, sections, quizzes, menu navigation |
| `res://slides/` | One `.tscn` per slide; root node type **IDSlide** (or **IDQuiz_MC** for questions) |
| `res://main.tscn` | Inherited scene of the prebuilt player, with the course assigned |

### 1. Course resource

Create `res://course/course.tres` as an `IDCourseData` resource (or use **Add slide** in the Course Viewer, which creates this file at `res://course/course.tres` if needed).

On `course.tres`, **Menu Navigation** controls how learners jump from the player menu:

- **Sequential** (default) — only completed-and-reachable slides (and the next locked one, depending on mode) are open from the menu
- **Free** — any slide listed in the menu
- **Restricted** — only slides the runtime has marked reachable

**Completion By** chooses when the course may finish: required slides, quiz success, or both.

### 2. Slides

Add a scene under `res://slides/` with an **IDSlide** root (use **IDQuiz_MC** for a question — see [Quizzes](#quizzes)). Set:

- **Title** — shown in the Course Viewer and player menu
- **Slide Id** — unique id used by `go_to()` and `IDButton.navigate_to` (for example `title`, `hazards`)
- **Completion Rule** — when Next unlocks (see [IDSlide](#idslide))
- **Show in Menu** — uncheck to hide the slide from the TOC; Next/Previous still visit it

Add the scene to the course from the Course Viewer (**Add slide**) or by appending it on `course.tres`.

### 3. Main scene / player

**Scene → New Inherited Scene…** and pick `res://addons/course_builder/player/course_player.tscn`. Save as `res://main.tscn`. In the Inspector, assign **Course** to `res://course/course.tres`.

Set **Project → Project Settings → Application → Run → Main Scene** to that scene.

You can instead instance `course_player.tscn` as a child of another root and assign **Course** on that child.

To move chrome (Prev/Next, progress, menu), edit `addons/course_builder/player/course_player.tscn` — show `MenuOverlay` in the editor to restyle menu placeholders.

## Course Viewer

Bottom panel **Course Viewer** (next to Output / Debugger). Each slide is a graph node:

- The title is in the node header; **×** removes the slide from the course (the `.tscn` file is kept).
- Double-click opens the slide scene.
- **Layout**: Horizontal, Vertical, or Free. Horizontal and Vertical space nodes in course order; dragging past another node then releasing reorders and snaps to the line. Free lets you place nodes without changing order; positions are saved on the course.
- **Orange wires** follow Next (`IDSlide.next_slide` if set, otherwise course order).
- **Teal wires** are `IDButton.navigate_to` jumps scanned from each slide scene; they route around other nodes so skipped slides do not hide the line. Dragging a new wire in the graph does **not** change navigation.
- **Add slide** appends a `.tscn` to `course.tres`.
- **Add section** creates a named group (GraphFrame). Drag a slide onto a frame to assign it; **Ungroup** on the slide node removes it from the section. Section **×** removes the section and ungroups its slides (scenes stay).

The player **Menu** lists sections as headings with slides underneath; ungrouped slides stay in course order.

## Authoring nodes

### IDSlide

Root of a slide scene. Completion rules:

| Rule | Next unlocks when |
|------|-------------------|
| **On Enter** | The slide is shown |
| **On Continue** | The learner presses Next / an `IDButton` with empty `navigate_to` |
| **All Reveals** | Every **IDReveal** on the slide has been clicked |
| **Media Finished** | The **Voice Over** clip ends (or immediately if none is assigned) |
| **Quiz** | The learner submits a final answer (`IDQuiz_MC` sets this automatically) |

**Voice Over** — assign an `AudioStream`. It plays when the slide enters and stops when the learner leaves. Test in Play; it does not play in the 2D editor.

**Next Slide** — optional override for Next. Empty means the next slide in course order.

**Required** — if true, this slide must be complete (when reachable) before the course can finish (when **Completion By** includes required slides).

### IDButton

Course-aware button. Empty **Navigate To** calls `request_next()` (complete + next, or finish the course). A slide id calls `go_to(id)`.

### IDReveal

Button that shows a hidden **Content** Control (TextureRect, Panel, Label — not Sprite2D or other Node2D). Pick animation (Fade, Slide, Grow), direction (Slide), and duration. The panel stays hidden until the learner clicks. Test in Play; the reveal does not run in the 2D editor.

Use **All Reveals** on the slide to keep Next disabled until every IDReveal has been clicked.

### IDAnimated

Timed pop-ups driven by an **AnimationPlayer** instead of the Voice Over slot. Pick animation / direction / duration in the Inspector, and leave Voice Over empty so a clip does not play twice.

On the slide, add an AnimationPlayer and an AudioStreamPlayer. Put narration on an **Audio** track and add **Call Method** tracks that call `animate` on each IDAnimated at the times you want. Set Autoplay on the AnimationPlayer. Media Finished only watches the Voice Over slot, so use **On Continue** (or On Enter) on these slides. IDAnimated stays visible in the 2D editor so you can layout it.

## Quizzes

How to author a multiple-choice or multiple-response slide. Completion Rule is always **Quiz** on these roots, so Next stays locked until the learner submits.

1. **Optional: add the quiz on the course.** Select `res://course/course.tres`. Under **Quizzes**, add a row: **Quiz Id** (e.g. `final`), **Title**, **Passing Percent**, **Report To Lms**, **Required To Pass**. Skip this step for an unscored knowledge check. A future SCORM plugin should read these fields; this addon does not package LMS files.

2. **New scene.** Scene → New Scene → **IDQuiz_MC** as the root (Create New Node). Save under `res://slides/`. If **IDQuiz_MC** is missing from the node list, disable and re-enable **CourseBuilder**.

3. **Root Inspector.** Set **Title**, **Slide Id** (unique in the course), and **Quiz Id** (must match the course row, or leave empty for practice). **Quiz Type** is **Multiple Choice** (exactly one correct) or **Multiple Response** (one or more correct; the learner must match the full set). Set **Points**, **Max Attempts**, **Fail Policy** (**Continue** shows Incorrect and unlocks Next after the last miss; **Must Correct** stays until they get it right), and **Graded** (off = survey: recorded, no points).

4. **Question stem.** Add a Label (or any Control) and type the question. There is no stem export; layout it like any other slide.

5. **Choices.** Add child **IDChoice** nodes (Create New Node), or add a **TextureButton** / **CheckBox** and attach `addons/course_builder/nodes/id_choice.gd`. On each choice set **Choice Id** (`a`, `b`, … — SCORM token, not a Godot node path) and check **Is Correct** on the right answer(s). Do not use **IDButton** for answers (that navigates). Leave the root **Choices** array empty to auto-find every IDChoice; fill it only to ignore a decorative button.

6. **Submit.** Add a Button or TextureButton, not **IDButton**. Select the **IDQuiz_MC** root and drag that button onto **Submit Button**.

7. **Feedback.** Add three Controls (Labels or Panels) for correct, try-again, and incorrect copy. Drag them onto **Correct Feedback**, **Try Again Feedback**, and **Incorrect Feedback** on the root. They stay visible in the 2D editor so you can layout them; Play hides them until Submit.

8. **Course Viewer.** Open the Course Viewer bottom panel → **Add slide** → pick the `.tscn`.

9. **Play.** Run `main.tscn` and open the slide. Submit stays disabled until a choice is selected. Next stays locked until Submit finishes. Yellow warnings on the **IDQuiz_MC** root mean Submit is missing or the number of **Is Correct** checks does not match **Quiz Type**.

Multiple response is exact-match (no partial credit). Drag-and-drop and fill-in types are not in this version. `IDCourseRuntime.get_quiz_result("final")` and `get_interaction(slide_id)` store score and the SCORM-shaped response for a later results scene. `course_completed` emits a 0–100 score from quizzes with **Report To Lms**.

## Runtime API

Autoload: `IDCourseRuntime`

**Methods:** `start_course`, `go_to`, `can_go_to`, `request_next`, `request_previous`, `mark_complete`, `record_interaction`, `get_quiz_result`, `get_interaction`, `get_course_score`

**Signals:** `slide_entered`, `slide_exited`, `slide_completed`, `course_completed`, `navigation_blocked`, `quiz_updated`

**Unlocking Next from a custom interaction:** For rules that do not complete on Continue (for example **All Reveals**, **Media Finished**, or your own GDScript), call `IDCourseRuntime.mark_complete()` when the learner has finished the interaction. That marks the current slide complete, emits `slide_completed`, and the player chrome enables Next via `can_go_next()`. Do not toggle the Next button yourself — stay on this API so menu locks and course finish stay consistent.

## License

MIT. See [LICENSE](LICENSE).
