class_name RynMovementConfig
extends Resource
## Tuning values for Ryn's movement. Saved as a `.tres` under `assets/data/`
## so that feel is tweaked without touching code.
##
## Units: pixels and seconds (the game is 640x360, tiles are 16 px).
##
## Usage:
##     var cfg: RynMovementConfig = load("res://assets/data/ryn_movement.tres")
##     ryn.config = cfg
##     print(cfg.jump_velocity())

@export_group("Walk")
## Top speed while standing, px/s.
@export var walk_speed: float = 105.0
## Speed gain toward the target speed, px/s^2. Full speed takes walk_speed / this seconds.
@export var acceleration: float = 640.0
## Speed loss when stopping, reversing, or above target speed, px/s^2.
@export var deceleration: float = 900.0
## Multiplier applied to acceleration and deceleration while airborne (0..1).
@export var air_control: float = 0.6

@export_group("Sprint")
## 按住 Shift 时的速度倍率。1.0 = 关闭跑步。
##
## **不改变基础手感**:松开 Shift 立刻回到 `walk_speed`,Story 001 签字认可的
## 走路加减速曲线原样保留 —— 跑步是叠加档,不是替换。
@export var sprint_multiplier: float = 1.62
## 跑步时的加速度倍率。跑起来要更快进入状态,否则按住 Shift 半天没反应。
@export var sprint_accel_multiplier: float = 1.35
## 跑步噪音半径,px。比走路大得多 —— 跑是要付代价的。
@export var sprint_noise_radius: float = 150.0

@export_group("Crouch")
## Top speed while crouched, px/s.
@export var crouch_speed: float = 44.0
## Collider height standing, px. 与精灵表一致:站姿画出来 44px,减去头顶 2px 的呆毛 = 42。
## 2026-10-10 前是 28 —— 碰撞体比画出来的人矮一大截,钻矮通道时头会画进天花板里。
@export var stand_height: float = 42.0
## Collider height crouched, px. 潜行半蹲画出来 37px(站姿的 84%),减去呆毛 ≈ 34。
## 矮通道的净空必须在 crouch_height 与 stand_height 之间(关卡里统一用 40)。
@export var crouch_height: float = 34.0
## Collider and silhouette width, px (same in both poses).
@export var body_width: float = 10.0

@export_group("Jump")
## Apex height of a fully held jump, px. Jump velocity is derived from this and gravity.
@export var jump_height: float = 56.0
## Downward acceleration, px/s^2.
@export var gravity: float = 900.0
## Gravity multiplier while falling (snappier landings).
@export var fall_gravity_multiplier: float = 1.35
## Gravity multiplier while rising with the jump key released (the jump cut).
@export var jump_release_gravity_multiplier: float = 3.0
## Terminal fall speed, px/s.
@export var max_fall_speed: float = 380.0
## Grace time after leaving a floor during which a jump still works, s.
@export var coyote_time: float = 0.08
## How early a jump press is remembered before landing, s.
@export var jump_buffer_time: float = 0.1
## 空中还能再跳几次(二段跳,2026-10-14 用户要的)。0 = 关掉。
@export var air_jumps: int = 1
## 二段跳往上能再跳多高,px。第一段的 6 成左右(56 → 34,约 2 格):补救、调整用,不是第二个满跳 ——
## 关卡还是照「一段跳 3 格」设计,二段跳让人多一点余地(生成器另查它会不会让谜题被跳过)。
@export var air_jump_height: float = 34.0

@export_group("Climb")
## Vertical speed on a ladder or pipe, px/s.
@export var climb_speed: float = 40.0   # 2026-10-15 用户:爬慢一点(原 56)
## Fraction of normal jump velocity used when jumping off a ladder (0..1).
@export var ladder_jump_scale: float = 0.7
## 一格一格爬(2026-10-15 用户:「一格一格的爬」):每一步走一档横档的高度,px。等于 `Ladder.RUNG_SPACING`。
@export var climb_step_px: float = 8.0
## 每爬完一格停在横档上歇多久,秒。平均爬速还是 `climb_speed`(步子走得快一点补回来)。
@export var climb_step_pause: float = 0.06


## Launch velocity (px/s, positive) that reaches `jump_height` under `gravity`.
##
## Usage: `velocity.y = -config.jump_velocity()`
func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)


## 二段跳的起跳速度(px/s,正数)。
##
## Usage: `velocity.y = -config.air_jump_velocity()`
func air_jump_velocity() -> float:
	return sqrt(2.0 * gravity * air_jump_height)


## 一格之内的移动速度,px/s:走一格 + 歇一下的平均速度 = `climb_speed`。
func climb_step_speed() -> float:
	var period: float = climb_step_px / maxf(climb_speed, 0.001)
	return climb_step_px / maxf(period - climb_step_pause, 0.01)
