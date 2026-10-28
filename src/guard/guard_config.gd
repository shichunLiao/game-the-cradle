class_name GuardConfig
extends Resource
## Tuning values for a patrolling guard and its vision cone. Saved as a `.tres`
## under `assets/data/` so patrol feel, cone shape and the three state colours
## are tuned without touching code.
##
## Units: pixels, seconds and degrees (the game is 640x360, tiles are 16 px).
## Guard origin is at the FEET, matching Ryn.
##
## Colour defaults come from `美术规格.md` §2/§3: the cone is translucent
## cold-cyan on patrol, narrows and turns warm/yellow when suspicious, and goes
## red with a rust-red flash on a sighting.
##
## Usage:
##     var cfg: GuardConfig = load("res://assets/data/guard_default.tres")
##     guard.config = cfg
##     print(cfg.cone_half_angle_rad())

@export_group("Body")
## Collider and silhouette width, px.
@export var body_width: float = 12.0
## Collider and silhouette height, px (taller than Ryn's 42 by design — 守卫是成年人).
## 2026-10-10 随 Ryn 一起放大 1.5 倍(32 → 48),矮通道(净空 40)仍然钻不进来。
@export var body_height: float = 48.0
## Height of the eye above the feet, px. Cone apex and every sight ray start here.
## 与身高同比例放大(26/32 → 40/48)。
@export var eye_height: float = 40.0

@export_group("Patrol")
## Walking speed along the patrol route, px/s.
@export var patrol_speed: float = 46.0
## Pause at each endpoint before turning around, s.
@export var patrol_wait_time: float = 1.2
## How close to an endpoint counts as arrived, px. Geometry tolerance, not feel.
@export var patrol_arrive_tolerance: float = 1.5
## Downward acceleration, px/s^2.
@export var gravity: float = 900.0
## Terminal fall speed, px/s.
@export var max_fall_speed: float = 380.0

@export_group("Vision")
## Cone reach while patrolling or spotting, px.
## 2026-10-11 220 → 170:用户反馈「视野太广」。170 约是屏幕宽(640)的 1/4,
## 玩家能同时看见守卫和他视野的尽头,有余地判断。
@export var cone_range: float = 170.0
## Cone opening to EACH side of the facing axis while patrolling or spotting, deg.
## 2026-10-11 28 → 24(同上)。
@export var cone_half_angle_deg: float = 24.0
## Cone reach while suspicious, px (the guard peers rather than scans). 2026-10-11 170 → 140。
@export var suspicious_cone_range: float = 140.0
## Cone opening to each side while suspicious, deg. Narrower than patrol per the
## art spec ("锥变窄").
## 2026-10-11 13 → 18:身高放大 1.5 倍后眼睛变高,13° 的窄锥在守卫脚前留下站 ~80px /
## 蹲 ~100px 的盲区(以前约 52/82)。18° 把它缩回站 ~58px / 蹲 ~71px,与放大前相当。
@export var suspicious_cone_half_angle_deg: float = 18.0
## Arc segments used to build the fan polygon. Visual smoothness only.
@export var cone_segments: int = 14
## 低头看地上的扣件时(`Guard.gaze_down`,2026-10-14 用户:「守卫低头查看」):视线往下压多少度、
## 能看多远、张开多大。压低、缩短 —— 只看得到脚前那一块(躯干离他 8–26px 才会被看到):
## 从他身后、头上过去都看不到,直接踩到他眼前才会被发现。
@export var gaze_down_deg: float = 50.0
@export var gaze_down_range: float = 32.0
@export var gaze_down_half_angle_deg: float = 18.0
## 蹲下低头时眼睛比站着低多少,px(精灵蹲姿上身下沉 8px)。
@export var gaze_down_eye_drop: float = 8.0

@export_group("Suspicion")
## How long the guard stays suspicious with nothing visible before returning to
## patrol, s. Must be > 0 so suspicion can never stick permanently.
@export var suspicion_duration: float = 2.5

@export_group("Cone Colours")
## Patrol cone tint (palette: cold-cyan).
@export var patrol_cone_color: Color = Color("3D6B8A")
## Suspicious cone tint (palette: accent-warm — the palette has no pure yellow).
@export var suspicious_cone_color: Color = Color("C4A574")
## Spotted cone tint (red, brighter than rust-red so the flash reads against it).
@export var spotted_cone_color: Color = Color("C4453A")
## The alternate half of the spotted flash (palette: rust-red).
@export var flash_color: Color = Color("8B3A2F")
## Fill opacity of the patrol cone (0..1).
@export var cone_alpha: float = 0.33
## Fill opacity of the suspicious cone (0..1).
@export var suspicious_cone_alpha: float = 0.45
## Fill opacity of the spotted cone (0..1).
@export var spotted_cone_alpha: float = 0.55
## Half-period of the spotted flash, s. The cone alternates between
## `spotted_cone_color` and `flash_color` every `spotted_flash_period` seconds.
@export var spotted_flash_period: float = 0.18

@export_group("Body Colours")
## Guard silhouette fill (palette: steel-blue — darker than Ryn's tower-white).
@export var body_color: Color = Color("1A2A44")
## 1 px rim light on the silhouette (palette: cold-cyan).
@export var rim_color: Color = Color("3D6B8A")
## Silhouette fill on the lit half of the spotted flash (palette: rust-red).
@export var alert_body_color: Color = Color("8B3A2F")


## Patrol / spotted cone half-angle in radians.
##
## Usage: `GuardVision.is_in_cone(eye, t, dir, cfg.cone_half_angle_rad(), cfg.cone_range)`
func cone_half_angle_rad() -> float:
	return deg_to_rad(cone_half_angle_deg)


## Suspicious cone half-angle in radians.
##
## Usage: `cfg.suspicious_cone_half_angle_rad()`
func suspicious_cone_half_angle_rad() -> float:
	return deg_to_rad(suspicious_cone_half_angle_deg)
