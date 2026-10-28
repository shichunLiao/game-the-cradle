class_name RynIntent
extends RefCounted
## What the player wants Ryn to do this physics tick, independent of where the
## input came from (keyboard, gamepad, a test, or a script).
##
## Ryn reads this instead of calling `Input` directly inside its movement code,
## so movement can be driven without real input devices.
##
## Usage:
##     ryn.input_enabled = false
##     ryn.intent.move_x = 1.0
##     ryn.intent.jump_pressed = true

## Horizontal axis, -1 (left) .. 1 (right).
var move_x: float = 0.0
## Vertical axis, -1 (up) .. 1 (down). Down crouches on the floor and climbs down on a ladder.
var move_y: float = 0.0
## True only on the tick the jump key went down.
var jump_pressed: bool = false
## True while the jump key is held.
var jump_held: bool = false
## 按住跑步键。由 Ryn 从 Input Map 填,或外部驱动(测试/演出)。
var sprint: bool = false
## 按住丢扣件键(瞄准);松开就丢。由 `RynThrow` 读。
var throw_held: bool = false
