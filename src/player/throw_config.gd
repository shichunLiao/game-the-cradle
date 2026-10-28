class_name ThrowConfig
extends Resource
## 丢扣件的手感与规则数值。`assets/data/throw_default.tres`。
##
## 扣件落地「叮」一声,半径 `noise_radius` 以内的守卫走过去查看(`GuardPursuit`)。
## 只引开,不打人、不算发现;每个存档点补满。

## 身上最多几个(到存档点、被发现重来都补满)。
@export var max_count: int = 3
## 落点离 Ryn 最近 / 最远,px(水平)。
@export var min_distance: float = 24.0
@export var max_distance: float = 208.0
## 刚开始瞄准时的落点距离,px。
@export var start_distance: float = 96.0
## 瞄准时左右键移动落点的速度,px/秒。
@export var aim_speed: float = 150.0
## 出手角度(往上),度。
@export var launch_angle_deg: float = 50.0
## 扣件受的重力,px/秒²。
@export var gravity: float = 700.0
## 撞墙后水平速度保留多少(反弹)。
@export var wall_bounce: float = 0.35
## 最多飞多久,秒(扔进深坑就不再管它,也不出声)。
@export var max_flight_time: float = 3.0
## 落地声音能被听到的距离,px。介于落地(130)和拆东西(220)之间。
## 150 → 200(2026-10-12):塔是垂直的,扣件常落在守卫上面一层,竖直距离一扣,150 能引到的太少。
@export var noise_radius: float = 200.0
## 落地后在地上躺多久再消失,秒。
@export var rest_time: float = 6.0
## 出手点相对脚底的高度,px(站 / 蹲)。
@export var hand_height_stand: float = 30.0
@export var hand_height_crouch: float = 18.0
@export_group("Look")
@export var bolt_color: Color = Color("8C98A8")
@export var bolt_shine: Color = Color("D8E2EC")
@export var arc_color: Color = Color(0.85, 0.80, 0.55, 0.85)
@export var ring_color: Color = Color(0.85, 0.80, 0.55, 0.55)
## 预览弧线每隔几个物理步画一个点。
@export var arc_dot_every: int = 3
