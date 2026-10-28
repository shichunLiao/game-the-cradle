class_name VisionCone
extends Area2D
## The guard's vision cone: a fan polygon that is both the detection broad
## phase and the thing the player reads on screen.
##
## Design decision (story 002): broad phase is this Area2D polygon, then the
## guard confirms each overlapping body with ONE raycast. It is deliberately
## not a fan of rays — the polygon is cheap, and `GuardVision.is_in_cone`
## re-tests the exact angle, so a stale overlap can only cost one raycast, never
## a false sighting.
##
## The fan is built along +X and mirrored by rotating PI (a fan symmetric about
## its axis rotated by PI *is* its horizontal mirror), so no negative scale is
## ever applied to a collision shape.
##
## ## 绘制被墙截断(2026-10-04)
##
## 原先只靠 `z_index = -1` 让世界几何盖在锥上 —— 墙在锥上切出一个缺口,但 **多边形
## 仍然画到墙之后**。玩家看到锥覆盖了墙后的区域,会以为那里危险,其实安全。
## 那是视觉在说谎,和"蹲在亮处却显示藏好了"是同一类错误。
##
## 现在每帧对每条扇形边打一根射线,碰到 WORLD 就在那里截断 —— **只截断绘制**。
## `CollisionPolygon2D` 保持完整扇形:它只是广相位粗筛,精确判定仍由守卫的单根
## 射线做(`GuardVision.can_see`),所以裁剪绘制不会改变任何检测结果。
##
## 代价是每帧 `segments+1` 根射线。塔4 四个守卫 = 60 根/帧,在 2D 灰盒里可忽略。
## `clip_to_walls = false` 可退回原来的画法。
##
## Usage:
##     cone.set_segments(14)
##     cone.apply(deg_to_rad(28.0), 220.0, Color("3D6B8A88"))
##     cone.set_facing(-1)
##     for body in cone.overlapping_targets():
##         ...

var _half_angle: float = -1.0
var _range: float = -1.0
var _segments: int = 14
var _fill: Color = Color(0.0, 0.0, 0.0, 0.0)
# Reused every rebuild; the hot path (per-frame draw) allocates nothing.
var _points: PackedVector2Array = PackedVector2Array()
var _bodies: Array[Node2D] = []
## 绘制用的点(被墙截断)。与 `_points`(碰撞用,完整扇形)分开。
var _draw_points: PackedVector2Array = PackedVector2Array()
var _ray: PhysicsRayQueryParameters2D

## 关掉则绘制整块扇形(旧行为),不打射线。
@export var clip_to_walls: bool = true
## 裁剪后每条边的最小长度,px。
##
## 守卫贴墙时每根射线都立刻命中,裁剪后的点会全部塌缩到原点附近 —— 多边形面积
## 为零,`draw_colored_polygon` 的三角化直接失败并刷屏报错
## (`Invalid polygon data, triangulation failed`,2026-10-04 实测)。
## 留一个下限,锥至少还是个小扇形。
const MIN_REACH: float = 4.0

@onready var _polygon: CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	collision_layer = PhysicsLayers.GUARD_VISION
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 预分配一次,每帧只改 from/to —— 热路径不分配。
	# `.from`/`.to` 可写未被 docs/engine-reference 覆盖,实测可用(见 physics-2d.md)。
	_ray = PhysicsRayQueryParameters2D.create(Vector2.ZERO, Vector2.ZERO)
	_ray.collision_mask = PhysicsLayers.WORLD
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true


## Sets the arc resolution of the fan. Visual smoothness only; takes effect on
## the next `apply()` that changes the shape.
##
## Usage: `cone.set_segments(config.cone_segments)`
func set_segments(count: int) -> void:
	_segments = maxi(count, 2)


## Sets the cone's shape and fill colour. Rebuilds the polygon only when the
## shape actually changed, and redraws only when something changed, so calling
## this every physics tick is free.
##
## Usage: `cone.apply(config.cone_half_angle_rad(), config.cone_range, fill)`
func apply(half_angle_rad: float, range_px: float, fill: Color) -> void:
	if not is_equal_approx(half_angle_rad, _half_angle) or not is_equal_approx(range_px, _range):
		_half_angle = half_angle_rad
		_range = range_px
		_rebuild()
	if fill != _fill:
		_fill = fill
		queue_redraw()


## Points the cone left (-1) or right (1). `pitch` 往下压多少弧度(守卫低头看地,`Guard.gaze_down`)。
##
## Usage: `cone.set_facing(guard.facing)`
func set_facing(dir: int, pitch: float = 0.0) -> void:
	rotation = pitch if dir > 0 else PI - pitch


## Bodies currently overlapping the cone polygon. Treat as READ-ONLY — it is the
## live internal list, not a copy, precisely so the per-frame detection pass
## allocates nothing.
##
## Usage: `for body in cone.overlapping_targets(): guard.can_see(...)`
func overlapping_targets() -> Array[Node2D]:
	return _bodies


## 每帧重算绘制轮廓。空间状态只能在物理回调里访问(physics-2d.md)。
func _physics_process(_delta: float) -> void:
	if not clip_to_walls or _points.size() < 3 or _range <= 0.0:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return
	var n: int = _segments
	if _draw_points.size() != n + 2:
		_draw_points.resize(n + 2)
	_draw_points[0] = Vector2.ZERO
	var origin: Vector2 = global_position
	var rot: float = global_rotation
	for i in range(n + 1):
		var angle: float = lerpf(-_half_angle, _half_angle, float(i) / float(n))
		var local_dir := Vector2(cos(angle), sin(angle))
		_ray.from = origin
		_ray.to = origin + local_dir.rotated(rot) * _range
		var hit: Dictionary = space.intersect_ray(_ray)
		var reach: float = _range
		if hit:
			reach = minf(origin.distance_to(hit.position), _range)
		_draw_points[i + 1] = local_dir * maxf(reach, MIN_REACH)
	queue_redraw()


func _rebuild() -> void:
	var n: int = _segments
	if _points.size() != n + 2:
		_points.resize(n + 2)
	_points[0] = Vector2.ZERO
	for i in range(n + 1):
		var angle: float = lerpf(-_half_angle, _half_angle, float(i) / float(n))
		_points[i + 1] = Vector2(cos(angle), sin(angle)) * _range
	if _polygon != null:
		_polygon.polygon = _points
	queue_redraw()


func _draw() -> void:
	var pts: PackedVector2Array = _draw_points if (clip_to_walls and _draw_points.size() >= 3) else _points
	if pts.size() < 3 or _fill.a <= 0.0:
		return
	# 第二道防护:面积仍然接近零就不画。比把退化多边形丢给渲染器好 ——
	# 那会每帧刷一条 triangulation failed。
	if _area(pts) < 1.0:
		return
	draw_colored_polygon(pts, _fill)
	# Brighter edges so the cone's angle reads at a glance even at low opacity.
	var edge: Color = Color(_fill.r, _fill.g, _fill.b, minf(_fill.a * 2.0, 1.0))
	draw_line(Vector2.ZERO, pts[1], edge, 1.0, false)
	draw_line(Vector2.ZERO, pts[pts.size() - 1], edge, 1.0, false)


## 多边形面积(鞋带公式),用于退化检测。
func _area(pts: PackedVector2Array) -> float:
	var a: float = 0.0
	var n: int = pts.size()
	for i in n:
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		a += p1.x * p2.y - p2.x * p1.y
	return absf(a) * 0.5


func _on_body_entered(body: Node2D) -> void:
	if body != null and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
