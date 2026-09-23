# LMS settings guide

How to turn on tracking and build a **SCORM 1.2** zip. One Godot project = one course. Settings live on `res://course/course.tres`.

**Required order for a package:** Export **Web** first (folder with `index.html`), then Course Viewer → **Publish SCORM**. The button does not run Godot’s exporter. It never runs on save, Play, or Export — only when you click it. LMS preset **Off** greys it out.

Editor Play logs what would be sent (`[CourseBuilder LMS]` in Output). A Web build writes SCORM 1.2 CMI to `window.API`, or a browser-console mock if no LMS is present.

If the LMS row or **Publish SCORM** is missing, disable and re-enable **CourseBuilder** (Project → Project Settings → Plugins) or reload the project so the Course Viewer scene refreshes.

## What you set vs what you leave alone

You pick **when the course is finished**, **whether a score is reported**, and **ids** that an LMS can store. You do not type SCORM field names (`cmi.core.lesson_status`, and so on).

| You set | Already on the course / slides |
|---|---|
| LMS preset (Course Viewer) | **Completion By** (rewritten by most presets) |
| Course title and identifier (Inspector) | Quiz **Passing Percent**, **Report To Lms**, **Required To Pass** |
| Resume / report interactions (Inspector, or filled by a preset) | **Slide Id**, question **Quiz Id**, choice **Choice Id** |

## 1. Pick a preset (Course Viewer)

Open the bottom panel **Course Viewer** (next to Output / Debugger). The **second** toolbar is the LMS row:

`LMS` → preset dropdown → summary → **Validate** → **Publish SCORM**

**Publish SCORM** is not under Project → Export.

| Preset | Use when | What it writes |
|---|---|---|
| **Off** | Local preview only | Tracking stays off. **Publish SCORM** is disabled. Does not change completion or quizzes. |
| **Awareness** | “They viewed the required slides” | Finish = required slides. No course score. Resume on. Question-level records off. |
| **Graded exam** | Safety test / final exam | Finish = required slides **and** required quizzes passed. Quizzes marked **Required To Pass** report a score (or every quiz if none are flagged). Resume on. Question-level records on. |
| **Knowledge checks** | Practice questions, no exam score | Finish = required slides. No course score, but answers are still recorded. Resume on. |
| **Custom** | Mix the above | Does not rewrite flags. Edit **Completion By** and **Quizzes** on `course.tres` yourself. |

The summary line after the dropdown is the live mapping, for example: `Finish: slides + quiz. Score: 80%. Resume: on.`

Changing Awareness, Graded exam, or Knowledge checks **overwrites** **Completion By** and each quiz’s **Report To Lms**. Switching to Custom or Off leaves those flags as they are.

The sample course is **Graded exam** with quiz id `final`.

## 2. Set title and identifier (Inspector)

Select `res://course/course.tres` in the FileSystem dock. In the Inspector, open **Lms**:

1. **Course Title** — name the LMS should show (for example `Ladder Safety Training`). Used in `imsmanifest.xml`. Fill it before you publish.
2. **Identifier** — package id and default zip name. Letters, digits, `_`, `-`, and `.` only. No spaces. Example: `ladder_safety`.
3. **Resume** — bookmark the current **Slide Id** (`cmi.core.lesson_location`). Editor Play logs it; a Web/LMS launch can reopen that slide.
4. **Report Interactions** — send each graded answer (`cmi.interactions`). Editor Play logs them; Web writes them to the API.

The Course Viewer preset and these Inspector fields are the same `lms` resource. Edit either place; save the course.

If **Preset** is **Custom**, the Inspector also shows an Advanced hint: edit **Completion By** and **Quizzes** on this same course resource (not a second copy of those fields).

## 3. Slide Id and quizzes

**Slide Id** is stored twice. The **slide root** (`.tscn` Inspector on `IDSlide` / `IDQuiz_MC`) is the source of truth. The **Slides** row on `course.tres` is a copy used by Course Viewer, navigation, Validate, and the SCORM bookmark.

To change an id: edit the slide root, save the scene, select `course.tres` → that slide row → **Refresh from scene**. Editing only the course row does not update the `.tscn`. Validate reads the course copy, so a mismatch looks like the old id is still wrong.

Quizzes (only if you report a score):

1. On `course.tres`, under **Quizzes**, add a row: **Quiz Id** (`final`), **Title**, **Passing Percent** (0–100), **Report To Lms**, **Required To Pass**.
2. On each question slide (`IDQuiz_MC`), set **Quiz Id** to that same id. Empty **Quiz Id** = practice; recorded if **Report Interactions** is on, but not in the course score.
3. On each **IDChoice**, set **Choice Id** to a short token (`a`, `b`, `c`). Do not leave it empty (the node name is a fallback and breaks if you rename the node). Yellow warning on the choice if it is empty.

**Completion By** (Inspector, or set by the preset):

- **Required Slides** — course may finish when reachable required slides are done.
- **Quiz Success** — when required quizzes are complete and passed.
- **Slides And Quiz** — both (Graded exam uses this).

Uncheck **Required** on a slide if it should not block course completion.

## 4. Validate

In Course Viewer, click **Validate**. The LMS row shows the first issue; the full list is in **Output** (`CourseBuilder LMS: ...`). **Publish SCORM** also runs these checks and stops if anything is wrong.

Typical fixes:

- **Identifier** empty or has spaces
- **Slide Id** empty, duplicate, or has spaces (often the course row is stale; **Refresh from scene**)
- Question **Quiz Id** does not match a course quiz row
- **Graded exam** with no quizzes, or quiz-based completion with no **Required To Pass** quiz
- **Report To Lms** on a quiz that has no graded questions
- Empty **Choice Id**

Ids must match `letters, digits, _, -, .` — the same rule as **Identifier**.

## 5. Test in Play (editor)

Run `main.tscn` in the Godot editor. If the preset is not **Off**, **Output** prints mapped lines with the prefix `[CourseBuilder LMS]`, for example:

```
[CourseBuilder LMS] location=title
[CourseBuilder LMS] interaction.id=quiz_ladder_angle interaction.type=choice ...
[CourseBuilder LMS] objective.id=final score_raw=1.0 ...
[CourseBuilder LMS] completion=true success=true score_scaled=100.0
```

- `location` only if **Resume** is on
- `interaction` only if **Report Interactions** is on
- `score_scaled` is 0–100 from quizzes with **Report To Lms**
- Desktop / editor Play does **not** contact an LMS and does **not** create a zip

Turn the preset to **Off** if you want a quiet Output log.

## 6. Export Web, then test HTML5

1. Project → Export → **Web**.
2. Export into an empty folder. That folder must contain `index.html` (plus Godot’s `.js` / `.wasm` / `.pck`).
3. Open `index.html` in a browser with the LMS preset not **Off**.

- **No LMS** (plain browser): a mock `window.API` logs `LMSSetValue` / `LMSCommit` to the browser console (`[CourseBuilder LMS mock]`).
- **Inside an LMS** that provides SCORM 1.2 `window.API`: the same CMI elements are written for real (`cmi.core.lesson_location`, `lesson_status`, `score.raw`, interactions, objectives).
- **Resume** on: the next launch reads `cmi.core.lesson_location` and opens that slide (does not mark skipped slides complete).
- Closing the tab calls `LMSFinish`.

This browser test is optional. For an LMS upload you still need the zip in the next step.

## 7. Publish SCORM (wrap the Web folder)

Do **not** go straight to **Publish SCORM**. There is nothing to wrap until a Web export exists.

1. Finish section 6 step 2 (Web export folder with `index.html`).
2. Course Viewer LMS row: preset not **Off**, **Validate** clean.
3. Click **Publish SCORM**.
4. Choose **that same Web export folder**.
5. Save a `.zip` (default name is the **Identifier**, e.g. `ladder_safety.zip`).
6. Upload that zip to the LMS.

The plugin writes `imsmanifest.xml` into the export folder, then zips the folder. One SCO; launch file is `index.html`. Quizzes with **Report To Lms** add `adlcp:masteryScore` from **Passing Percent**.

If the folder has no `index.html`, Publish stops with an error. If the button is grey, the LMS preset is **Off**.

## 8. Developer notes

- `IDCourseRuntime` calls `IDTrackingBackend`. Non-Off presets use `IDDebugTrackingBackend` in the editor and `IDScormBackend` on Web (`OS.has_feature("web")`).
- Logical payload is `IDScormMapper` (`completion`, `success`, `score_scaled`, `location`, `objective`, `interaction`). `IDScormCmi12` maps those to SCORM 1.2 element names. `IDScormPackager` builds the zip from Course Viewer.
- Do not add parallel “SCORM completion” fields on slides. Custom interactions should keep calling `IDCourseRuntime.record_interaction()` and `mark_complete()`.
- SCORM 2004 packaging is not in this addon.

## Quick checklist

1. Course Viewer LMS row visible (`LMS` … **Validate** … **Publish SCORM**). If not, re-enable the plugin.
2. Preset: **Awareness**, **Graded exam**, or **Knowledge checks** (not **Off**)
3. `course.tres` → **Course Title** and **Identifier**
4. Unique, legal **Slide Id** on each slide root, then **Refresh from scene** on the course row
5. Exam: matching **Quiz Id** and **Choice Id** tokens
6. **Validate**, then Play and read `[CourseBuilder LMS]` in Output
7. Project → Export → Web (folder with `index.html`)
8. **Publish SCORM** → that folder → save zip → upload to the LMS
