# CourseBuilder

Godot 4.5 plugin for instructional-design courses. One Godot project is one course: you author slides as scenes, arrange them in the **Course Viewer**, and play them in a prebuilt player with Next/Previous, a table of contents, and completion rules.

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

You should see custom types (`IDSlide`, `IDButton`, `IDReveal`, `IDAnimated`) in the Create New Node dialog, and **Course Viewer** next to Output / Debugger.

## Create a course

Course content lives **outside** the addon folder.

| Path | Role |
|------|------|
| `res://course/course.tres` | `IDCourseData` resource: slide order, sections, menu navigation |
| `res://slides/` | One `.tscn` per slide; root node type **IDSlide** |
| `res://main.tscn` | Instances the prebuilt player and assigns the course |

### 1. Course resource

Create `res://course/course.tres` as an `IDCourseData` resource (or use **Add slide** in the Course Viewer, which creates this file at `res://course/course.tres` if needed).

On `course.tres`, **Menu Navigation** controls how learners jump from the player menu:

- **Sequential** (default) — only completed-and-reachable slides (and the next locked one, depending on mode) are open from the menu
- **Free** — any slide listed in the menu
- **Restricted** — only slides the runtime has marked reachable

### 2. Slides

Add a scene under `res://slides/` with an **IDSlide** root. Set:

- **Title** — shown in the Course Viewer and player menu
- **Slide Id** — unique id used by `go_to()` and `IDButton.navigate_to` (for example `title`, `hazards`)
- **Completion Rule** — when Next unlocks (see [IDSlide](#idslide))
- **Show in Menu** — uncheck to hide the slide from the TOC; Next/Previous still visit it

Add the scene to the course from the Course Viewer (**Add slide**) or by appending it on `course.tres`.

### 3. Main scene / player

Instance `res://addons/course_builder/player/course_player.tscn` as your main scene (or a child of it). In the Inspector, assign **Course** to `res://course/course.tres`.

Set **Project → Project Settings → Application → Run → Main Scene** to that scene.

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

**Voice Over** — assign an `AudioStream`. It plays when the slide enters and stops when the learner leaves. Test in Play; it does not play in the 2D editor.

**Next Slide** — optional override for Next. Empty means the next slide in course order.

**Required** — if true, this slide must be complete (when reachable) before the course can finish.

### IDButton

Course-aware button. Empty **Navigate To** calls `request_next()` (complete + next, or finish the course). A slide id calls `go_to(id)`.

### IDReveal

Button that shows a hidden **Content** Control (TextureRect, Panel, Label — not Sprite2D or other Node2D). Pick animation (Fade, Slide, Grow), direction (Slide), and duration. The panel stays hidden until the learner clicks. Test in Play; the reveal does not run in the 2D editor.

Use **All Reveals** on the slide to keep Next disabled until every IDReveal has been clicked.

### IDAnimated

Timed pop-ups driven by an **AnimationPlayer** instead of the Voice Over slot. Pick animation / direction / duration in the Inspector, and leave Voice Over empty so a clip does not play twice.

On the slide, add an AnimationPlayer and an AudioStreamPlayer. Put narration on an **Audio** track and add **Call Method** tracks that call `animate` on each IDAnimated at the times you want. Set Autoplay on the AnimationPlayer. Media Finished only watches the Voice Over slot, so use **On Continue** (or On Enter) on these slides. IDAnimated stays visible in the 2D editor so you can layout it.

## Runtime API

Autoload: `IDCourseRuntime`

**Methods:** `start_course`, `go_to`, `can_go_to`, `request_next`, `request_previous`, `mark_complete`

**Signals:** `slide_entered`, `slide_exited`, `slide_completed`, `course_completed`, `navigation_blocked`

**Unlocking Next from a custom interaction:** For rules that do not complete on Continue (for example **All Reveals**, **Media Finished**, or your own GDScript), call `IDCourseRuntime.mark_complete()` when the learner has finished the interaction. That marks the current slide complete, emits `slide_completed`, and the player chrome enables Next via `can_go_next()`. Do not toggle the Next button yourself — stay on this API so menu locks and course finish stay consistent.

## License

MIT. See [LICENSE](LICENSE). Edit the copyright holder before you publish if you want a personal or company name on the license.
