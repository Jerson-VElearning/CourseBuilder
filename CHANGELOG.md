# Changelog

## Unreleased

- LMS settings on `course.tres` (**Lms**): course title, identifier, resume, report interactions
- Course Viewer **LMS** row: presets (Off, Awareness, Graded exam, Knowledge checks, Custom) with a live summary
- **Validate** checks Slide, Quiz, and Choice ids for LMS use
- Editor Play logs the mapped LMS payload to Output (`[CourseBuilder LMS]`)
- SCORM 1.2 tracking on Web exports through `window.API` (console mock when no LMS is present); resume reopens the bookmarked slide
- **Publish SCORM** wraps a Web export folder with `imsmanifest.xml` into a zip (one SCO, `adlcp:masteryScore` from **Passing Percent**)
- Docs: [addons/course_builder/LMS.md](addons/course_builder/LMS.md)

## 0.2.0

- Multiple-choice and multiple-response slides (`IDQuiz_MC`, `IDChoice`)
- Completion rule **Quiz**; course **Completion By** (required slides, quiz success, or both)
- Runtime: `record_interaction`, `get_quiz_result`, `get_interaction`, `get_course_score`, and `quiz_updated`

## 0.1.0

Initial public plugin release.

- Course Viewer bottom panel for adding, opening, reordering, and grouping slides
- Custom nodes: `IDSlide`, `IDButton`, `IDReveal`, `IDAnimated`
- Prebuilt course player with chrome and menu overlay
- Navigation runtime (`IDCourseRuntime`) with completion rules and menu access modes
