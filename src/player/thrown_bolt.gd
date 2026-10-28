class_name ThrownBolt
extends Node2D
## Ryn 丢出去的一个扣件:抛物线飞,撞墙弹一下,落地「叮」一声发出噪音,在地上躺一会儿再消失。
##
## 噪音走 `Noise`(`GuardPursuit` 听到就走过去查看),所以它**只会把守卫引开**,打不到人、
## 不算发现。飞行和 `RynThrow` 的预览用同一个 `step()`:固定 1/60 秒一步、同样的射线,
## 预览画在哪儿就落在哪儿。
##
## 扣件呼应 叙事脚本.md 塔 2 入塔句「这种扣件……她教过我」—— 手巧的人身上总有几个。
##
## Usage (from code):
##     var bolt := ThrownBolt.new()
##     bolt.config = cfg
##     bolt.velocity = ThrownBolt.launch_velocity(cfg, 96.0)
##     bolt.position = hand
##     level.add_child(bolt)

## 落地时发出(位置是落点)。扔进深坑飞太久不落地就不发。
signal landed(at: Vector2)
## 被守卫捡走时发出。
signal picked_up

## 地上躺着的扣件都在这个组里(`GuardPursuit` 听到落地声时找它)。
const GROUP: StringName = &"thrown_bolt"

## 一步的时长 = 物理帧。预览和真的飞行都按它算。
const DT: float = 1.0 / 60.0

enum Phase { FLYING, RESTING }
enum Hit { NONE, FLOOR, WALL, CEILING }

@export var config: ThrowConfig
var velocity: Vector2 = Vector2.ZERO

var _phase: Phase = Phase.FLYING
var _t: float = 0.0
var _spin: float = 0.0
var _query: PhysicsRayQueryParameters2D
## 正在走过来捡它的守卫(2026-10-14:守卫走过去低头看、捡起来)。有人认领就不消失。
var _claimed_by: Node = null


## 平地上落在 `distance`(带正负号,负 = 往左)处的出手速度。
static func launch_velocity(cfg: ThrowConfig, distance: float) -> Vector2:
	var ang: float = deg_to_rad(cfg.launch_angle_deg)
	var d: float = maxf(absf(distance), 1.0)
	var v: float = sqrt(d * cfg.gravity / maxf(sin(2.0 * ang), 0.01))
	return Vector2(cos(ang) * v * signf(distance), -sin(ang) * v)


## 往前走一步。返回 `{pos, vel, hit}`,`hit` 是 `Hit`。
static func step(space: PhysicsDirectSpaceState2D, query: PhysicsRayQueryParameters2D,
		pos: Vector2, vel: Vector2, cfg: ThrowConfig) -> Dictionary:
	var v: Vector2 = vel + Vector2(0.0, cfg.gravity * DT)
	var to: Vector2 = pos + v * DT
	query.from = pos
	query.to = to
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return {"pos": to, "vel": v, "hit": Hit.NONE}
	var n: Vector2 = hit["normal"]
	var at: Vector2 = hit["position"]
	if n.y < -0.5:
		return {"pos": at, "vel": Vector2.ZERO, "hit": Hit.FLOOR}
	if absf(n.x) >= 0.5:
		return {"pos": at + n, "vel": Vector2(-v.x * cfg.wall_bounce, v.y), "hit": Hit.WALL}
	return {"pos": at + n, "vel": Vector2(v.x, absf(v.y) * 0.3), "hit": Hit.CEILING}


## 预览:从 `from` 以 `vel` 出手,一路算到落地。返回 `{points, landed, at}`。
static func predict(space: PhysicsDirectSpaceState2D, from: Vector2, vel: Vector2,
		cfg: ThrowConfig) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.new()
	query.collision_mask = PhysicsLayers.WORLD
	var pts := PackedVector2Array([from])
	var pos: Vector2 = from
	var v: Vector2 = vel
	for _i in int(cfg.max_flight_time / DT):
		var r: Dictionary = step(space, query, pos, v, cfg)
		pos = r["pos"]
		v = r["vel"]
		pts.append(pos)
		if r["hit"] == Hit.FLOOR:
			return {"points": pts, "landed": true, "at": pos}
	return {"points": pts, "landed": false, "at": pos}


func _ready() -> void:
	add_to_group(GROUP)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	_query = PhysicsRayQueryParameters2D.new()
	_query.collision_mask = PhysicsLayers.WORLD


## 落地了吗(验证脚本用)。
func has_landed() -> bool:
	return _phase == Phase.RESTING


## 守卫认领:他在走过来,别先消失。已经被别人认领了就返回 false。
##
## Usage: `if bolt.claim(guard): ...`
func claim(by: Node) -> bool:
	if _claimed_by != null and is_instance_valid(_claimed_by) and _claimed_by != by:
		return false
	_claimed_by = by
	return true


## 不来捡了(被打断):照常躺满 `rest_time` 再消失。
func release(by: Node) -> void:
	if _claimed_by == by:
		_claimed_by = null


## 被 `by` 认领着吗。
func is_claimed_by(by: Node) -> bool:
	return _claimed_by == by


## 守卫捡起来:轻轻一声,扣件没了。
func pick_up() -> void:
	Audio.play(&"bolt_tick", -16.0, 0.85)
	picked_up.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	if _phase == Phase.RESTING:
		if _claimed_by != null and not is_instance_valid(_claimed_by):
			_claimed_by = null
		if _claimed_by != null:
			_t = minf(_t, config.rest_time - 1.0)   # 有人要来捡:不消失,也不淡掉
		elif _t >= config.rest_time:
			queue_free()
		queue_redraw()
		return
	var r: Dictionary = step(get_world_2d().direct_space_state, _query, global_position, velocity, config)
	global_position = r["pos"]
	velocity = r["vel"]
	_spin += delta * 14.0 * signf(velocity.x if velocity.x != 0.0 else 1.0)
	match r["hit"]:
		Hit.FLOOR:
			_land()
		Hit.WALL, Hit.CEILING:
			Audio.play(&"bolt_tick", -14.0, randf_range(0.95, 1.1))
	if _phase == Phase.FLYING and _t >= config.max_flight_time:
		queue_free()   # 扔进深坑了:不出声
	queue_redraw()


func _land() -> void:
	_phase = Phase.RESTING
	_t = 0.0
	_spin = 0.0
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.call(&"emit_noise", global_position, config.noise_radius)
	Audio.play(&"bolt_clink", -6.0, randf_range(0.95, 1.08))
	landed.emit(global_position)


func _draw() -> void:
	# 一颗六角螺母:飞的时候转,落地后平躺;最后一秒淡掉
	var a: float = 1.0
	if _phase == Phase.RESTING:
		a = clampf(config.rest_time - _t, 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in 6:
		var ang: float = _spin + TAU * float(i) / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * 2.6 + Vector2(0.0, -2.0))
	draw_colored_polygon(pts, Color(config.bolt_color, a))
	draw_rect(Rect2(-0.5, -2.5, 1.0, 1.0), Color(0.05, 0.06, 0.08, a))
	draw_rect(Rect2(-2.0, -4.0, 1.0, 1.0), Color(config.bolt_shine, a))
