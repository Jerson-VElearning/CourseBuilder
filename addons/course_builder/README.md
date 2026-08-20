# CourseBuilder

Godot 4.5 plugin for instructional-design courses. One Godot project = one course.

## Folder map

| Path | Job |
|------|-----|
| `core/` | Shared enums. No UI, no navigation. |
| `resources/` | Course, slides, and sections. `player_config.tres` is unused for layout (edit the player scene). |
| `runtime/` | Navigation, completion, signals. Player and buttons call this. |
| `player/` | Prebuilt `course_player.tscn` (stage, chrome, menu overlay). Scripts bind nodes and refresh state. |
| `editor/` | Course Viewer bottom panel (`GraphEdit` of slide nodes, open/reorder/add/remove). |
| `nodes/` | `IDSlide`, `IDButton`, `IDReveal`, and `IDAnimated` for authors. |
| `tracking/` | No-op backend. SCORM/xAPI can implement the same methods later. |

## Course Viewer

Bottom panel **Course Viewer** (next to Output / Debugger). Each slide is a **GraphNode**: the title is in the node header, **×** removes it from the course (scene file is kept), and double-click opens the slide. **Layout** is Horizontal, Vertical, or Free. Horizontal and Vertical space nodes in course order; dragging past another node then releasing reorders and snaps to the line. Free lets you place nodes without changing order; positions are saved on the course. Orange wires follow Next (`IDSlide.next_slide` if set, otherwise course order). Teal wires are `IDButton.navigate_to` jumps scanned from each slide scene; they route around other nodes so skipped slides do not hide the line. Dragging a new wire does not change navigation. **Add slide** appends a `.tscn` to `course.tres`. **Add section** creates a named group (GraphFrame). Drag a slide onto a frame to assign it; **Ungroup** on the slide node removes it from the section (the frame still autoshrinks around the remaining slides). Section **×** removes the section and ungroups its slides (scenes stay). The player **Menu** lists those sections as headings with slides underneath; ungrouped slides stay in course order. Uncheck **Show in Menu** on `IDSlide` / `IDSlideData` to omit a slide from the TOC (Next/Previous still visit it). Locked slides follow **Menu Navigation** on `course.tres` (Sequential, Free, or Restricted). Restyle menu items by editing the placeholders on `course_player.tscn` (show `MenuOverlay` in the editor). If the panel is missing, disable and re-enable **CourseBuilder** under Project > Project Settings > Plugins.

## Course content (outside this addon)

- `res://course/` — `course.tres`
- `res://slides/` — one scene per slide
- `res://main.tscn` — instances the prebuilt course player (edit `addons/course_builder/player/course_player.tscn` to move chrome)

Add an **IDReveal** button on a slide and assign **Content** to a Control (TextureRect, Panel, Label — not Sprite2D or other Node2D). Pick animation (Fade, Slide, Grow), direction (Slide), and duration. Test in Play; the reveal does not run in the 2D editor. The panel stays hidden until the learner clicks. Set the slide **Completion Rule** to **All Reveals** to keep Next disabled until every IDReveal on that slide has been clicked.

Assign **Voice Over** on `IDSlide` to an `AudioStream`. It plays when the slide enters and stops when the learner leaves (the slide instance is freed). Any completion rule can have narration; set **Completion Rule** to **Media Finished** to keep Next disabled until the clip ends. With Media Finished and no clip assigned, the slide completes immediately. Test in Play; voice-over does not play in the 2D editor.

To time pop-ups to a clip with an **AnimationPlayer** instead of the Voice Over slot: add **IDAnimated** controls (or change an existing Control to that type), pick animation / direction / duration in the Inspector, and leave Voice Over empty so the clip does not play twice. On the slide, add an AnimationPlayer and an AudioStreamPlayer. Put the VO on an **Audio** track and add **Call Method** tracks that call `animate` on each IDAnimated at the times you want. Set Autoplay on the AnimationPlayer. Media Finished only watches the Voice Over slot, so use **On Continue** (or On Enter) on these slides. Test in Play; IDAnimated stays visible in the 2D editor so you can layout it.

## Runtime API (autoload `IDCourseRuntime`)

`start_course`, `go_to`, `can_go_to`, `request_next`, `request_previous`, `mark_complete`

Signals: `slide_entered`, `slide_exited`, `slide_completed`, `course_completed`, `navigation_blocked`

**Unlocking Next from a custom interaction:** For rules that do not complete on Continue (e.g. **All Reveals**, **Media Finished**, or your own GDScript), call `IDCourseRuntime.mark_complete()` when the learner has finished the interaction. That marks the current slide complete, emits `slide_completed`, and the player chrome enables Next via `can_go_next()`. Do not toggle the Next button yourself — stay on this API so menu locks and course finish stay consistent.
