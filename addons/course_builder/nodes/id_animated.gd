@tool
class_name IDAnimated
extends Control

## Control that plays an Inspector-picked Tween when animate() is called.
## Use from an AnimationPlayer Call Method track to line up with VO.
## See: nodes/id_reveal.gd, core/id_enums.gd, nodes/id_slide.gd

const _DURATION_MIN := 0.05
const _DURATION_MAX := 2.0
const _DISTANCE_MIN := 0.0
const _DISTANCE_MAX := 400.0

## How this control appears when animate() runs.
@export var animation: IDEnums.RevealAnimation = IDEnums.RevealAnimation.FADE:
	set(value):
		if animation == value:
			return
		animation = value
		notify_property_list_changed()

## Used by Slide. Hidden for Fade and Grow.
@export var direction: IDEnums.RevealDirection = IDEnums.RevealDirection.LEFT

## Tween length in seconds.
@export var duration: float = 0.4:
	set(value):
		duration = clampf(value, _DURATION_MIN, _DURATION_MAX)

## Slide travel in pixels. Hidden for Fade and Grow.
@export var distance: float = 20.0:
	set(value):
		distance = clampf(value, _DISTANCE_MIN, _DISTANCE_MAX)

var _rest_position := Vector2.ZERO
var _rest_size := Vector2.ZERO
var _rest_modulate := Color.WHITE
var _rest_scale := Vector2.ONE
var _prepared := false
var _tween: Tween


func _validate_property(property: Dictionary) -> void:
	if property.name != "direction" and property.name != "distance":
		return
	if animation == IDEnums.RevealAnimation.FADE or animation == IDEnums.RevealAnimation.GROW:
		property.usage = PROPERTY_USAGE_STORAGE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_prepare.call_deferred()


func animate() -> void:
	if Engine.is_editor_hint():
		return
	if not _prepared:
		_prepare()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_play()


func _prepare() -> void:
	if _prepared:
		return
	_rest_position = position
	_rest_size = size
	_rest_modulate = modulate
	_rest_scale = scale
	visible = false
	_prepared = true
	if _rest_size == Vector2.ZERO:
		_capture_rest.call_deferred()


func _capture_rest() -> void:
	_rest_position = position
	_rest_size = size
	_rest_modulate = modulate
	_rest_scale = scale


func _play() -> void:
	var time := duration
	visible = true
	match animation:
		IDEnums.RevealAnimation.FADE:
			_play_fade(time)
		IDEnums.RevealAnimation.SLIDE:
			_play_slide(time)
		IDEnums.RevealAnimation.GROW:
			_play_grow(time)


func _play_fade(time: float) -> void:
	var start := _rest_modulate
	start.a = 0.0
	modulate = start
	position = _rest_position
	scale = _rest_scale
	_tween = create_tween()
	_tween.tween_property(self, "modulate", _rest_modulate, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_slide(time: float) -> void:
	var start_mod := _rest_modulate
	start_mod.a = 0.0
	modulate = start_mod
	position = _rest_position + _slide_offset()
	scale = _rest_scale
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", _rest_position, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", _rest_modulate, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_grow(time: float) -> void:
	modulate = _rest_modulate
	position = _rest_position
	pivot_offset = _rest_size * 0.5
	scale = Vector2.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "scale", _rest_scale, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _slide_offset() -> Vector2:
	match direction:
		IDEnums.RevealDirection.LEFT:
			return Vector2(-distance, 0.0)
		IDEnums.RevealDirection.RIGHT:
			return Vector2(distance, 0.0)
		IDEnums.RevealDirection.UP:
			return Vector2(0.0, -distance)
		_:
			return Vector2(0.0, distance)
