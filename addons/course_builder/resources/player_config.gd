class_name IDPlayerConfig
extends Resource

## Optional player flags. Layout, colors, and chrome position are edited on
## course_player.tscn — this resource must not override the scene at runtime.
## See: player/course_player.tscn

## Deprecated: hide the Previous button in the player scene instead.
@export var show_previous: bool = true

## Deprecated: hide the Next button in the player scene instead.
@export var show_next: bool = true

## Deprecated: move the Chrome node in course_player.tscn instead.
@export var chrome_position: IDEnums.ChromePosition = IDEnums.ChromePosition.BOTTOM

## Deprecated: change the Chrome panel style in the player scene instead.
@export var chrome_color: Color = Color("0E2841")

## Deprecated: unused in v0.
@export var accent_color: Color = Color("156082")

## Deprecated: change button StyleBoxes in the player scene instead.
@export var button_color: Color = Color("E97132")

## Reserved for a future voice-over seekbar. Unused in v0.
@export var show_seekbar: bool = false
