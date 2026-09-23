@tool
class_name IDReveal
extends Button

## Hotspot that shows a Control with a one-shot Tween. Not a navigation button.
## Assign Content in the Inspector; Fade and Grow ignore Direction.
## See: nodes/id_button.gd, core/id_enums.gd, nodes/id_slide.gd

signal revealed

const _DURATION_MIN := 0.05
const _DURATION_MAX := 2.0

## Control to show. Must be a Control on the slide; not this button and not a Node2D.
@export var content: Control

## How the content appears.
@export var animation: IDEnums.RevealAnimation = IDEnums.RevealAnimation.FADE:
	set(value):
		if animation == value:
			return
		animation = value
		notify_property_list_changed()

## Used by Slide. Hidden for Fade and Grow.
@export var direction: IDEnums.RevealDirection = IDEnums.RevealDirection.LEFT

## Tween length in seconds.
@export var duration: float = 0.35:
	set(value):
		duration = clampf(value, _DURATION_MIN, _DURATION_MAX)

var _target: Control
var _rest_position := Vector2.ZERO
var _rest_size := Vector2.ZERO
var _rest_modulate := Color.WHITE
var _rest_scale := Vector2.ONE
var _revealed := false


func is_revealed() -> bool:
	return _revealed


func _validate_property(property: Dictionary) -> void:
	if property.name != "direction":
		return
	if animation == IDEnums.RevealAnimation.FADE or animation == IDEnums.RevealAnimation.GROW:
		property.usage = PROPERTY_USAGE_STORAGE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	pressed.connect(_on_pressed)
	_prepare_target.call_deferred()


func _prepare_target() -> void:
	if content == null or content == self:
		push_warning("IDReveal: Content must be a Control on the slide, not this button.")
		return
	_target = content
	_capture_rest()
	_target.visible = false
	if _rest_size == Vector2.ZERO:
		_capture_rest.call_deferred()


func _capture_rest() -> void:
	if _target == null:
		return
	_rest_position = _target.position
	_rest_size = _target.size
	_rest_modulate = _target.modulate
	_rest_scale = _target.scale


func _on_pressed() -> void:
	if _revealed:
		return
	if _target == null:
		_prepare_target()
	if _target == null:
		push_warning("IDReveal: Content is not assigned.")
		return
	if _rest_size == Vector2.ZERO:
		_capture_rest()
	_revealed = true
	revealed.emit()
	_play_reveal()


func _play_reveal() -> void:
	var time := duration
	_target.visible = true
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
	_target.modulate = start
	var tween := create_tween()
	tween.tween_property(_target, "modulate", _rest_modulate, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_slide(time: float) -> void:
	_target.position = _rest_position + _slide_offset()
	var tween := create_tween()
	tween.tween_property(_target, "position", _rest_position, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_grow(time: float) -> void:
	_target.pivot_offset = _rest_size * 0.5
	_target.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(_target, "scale", _rest_scale, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _slide_offset() -> Vector2:
	match direction:
		IDEnums.RevealDirection.LEFT:
			return Vector2(-_rest_size.x, 0.0)
		IDEnums.RevealDirection.RIGHT:
			return Vector2(_rest_size.x, 0.0)
		IDEnums.RevealDirection.UP:
			return Vector2(0.0, -_rest_size.y)
		_:
			return Vector2(0.0, _rest_size.y)
