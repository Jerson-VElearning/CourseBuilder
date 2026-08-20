class_name IDSlide
extends Control

## Root node for a course slide scene. Holds completion and notes for the runtime.
## The player instances this scene; IDSlide registers itself on ready.
## See: runtime/course_runtime.gd, nodes/id_button.gd, nodes/id_reveal.gd

## Author-facing name shown in the course list. Need not be unique.
@export var title: String = ""

## Unique id used by go_to() and IDButton.navigate_to (e.g. "title", "hazards").
@export var slide_id: String = ""

## When this slide is marked complete. ALL_REVEALS waits for every IDReveal click.
## MEDIA_FINISHED waits until voice_over ends (or completes immediately if none is assigned).
@export var completion_rule: IDEnums.CompletionRule = IDEnums.CompletionRule.ON_CONTINUE

## Optional override for Next. Empty = next slide in course order.
@export var next_slide: String = ""

## If true, this slide must be complete (when reachable) before the course can finish.
@export var required: bool = true

## If false, the player menu omits this slide. Next/Previous and jumps still reach it.
@export var show_in_menu: bool = true

## Speaker notes / future caption or VO script. Not shown in the v0 player chrome.
@export_multiline var notes: String = ""

## Plays on slide enter. MEDIA_FINISHED unlocks Next when the clip ends.
@export var voice_over: AudioStream

const _VO_PLAYER_NAME := "VoiceOverPlayer"

var _reveals: Array[IDReveal] = []
var _vo_player: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if has_node("/root/IDCourseRuntime"):
		IDCourseRuntime.register_slide(self)
	if completion_rule == IDEnums.CompletionRule.ALL_REVEALS:
		_setup_all_reveals()
	if not Engine.is_editor_hint():
		_setup_voice_over()


func _setup_voice_over() -> void:
	if voice_over == null:
		_try_complete_media_finished()
		return
	_vo_player = get_node_or_null(_VO_PLAYER_NAME) as AudioStreamPlayer
	if _vo_player == null:
		_vo_player = AudioStreamPlayer.new()
		_vo_player.name = _VO_PLAYER_NAME
		add_child(_vo_player)
	_vo_player.stream = voice_over
	if not _vo_player.finished.is_connected(_on_voice_over_finished):
		_vo_player.finished.connect(_on_voice_over_finished)
	_vo_player.play()


func _on_voice_over_finished() -> void:
	_try_complete_media_finished()


func _try_complete_media_finished() -> void:
	if completion_rule != IDEnums.CompletionRule.MEDIA_FINISHED:
		return
	if not is_inside_tree():
		return
	if not has_node("/root/IDCourseRuntime"):
		return
	if IDCourseRuntime.current_slide_id != slide_id:
		return
	IDCourseRuntime.mark_complete()


func _setup_all_reveals() -> void:
	_reveals.clear()
	for child in find_children("", "IDReveal", true, false):
		if child is IDReveal:
			var reveal := child as IDReveal
			_reveals.append(reveal)
			if not reveal.revealed.is_connected(_on_reveal_fired):
				reveal.revealed.connect(_on_reveal_fired)
	if _reveals.is_empty():
		_try_complete_all_reveals()


func _on_reveal_fired() -> void:
	_try_complete_all_reveals()


func _try_complete_all_reveals() -> void:
	if completion_rule != IDEnums.CompletionRule.ALL_REVEALS:
		return
	if not has_node("/root/IDCourseRuntime"):
		return
	for reveal in _reveals:
		if not reveal.is_revealed():
			return
	# Same unlock path any custom interaction should use: mark_complete → slide_completed → Next.
	IDCourseRuntime.mark_complete()
