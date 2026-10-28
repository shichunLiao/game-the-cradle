class_name ParticleBurst
extends Node2D
## 事件驱动的小颗粒。落地扬尘、拆解碎屑。
##
## `美术规格.md` §1「不做」原含 **粒子特效堆**,作者于 2026-10-04 删除该条。
## 这里仍然只在 **真实事件** 上爆发,不做常驻的装饰性发射器 —— 一个只为好看而
## 不断飘的粒子源,在潜行游戏里是纯粹的注意力噪声。
##
## 手写而非 GPUParticles2D:颗粒数极少(每次 6–14 个),用 `_draw` 更可控,
## 也能保证整数像素对齐,不破坏 640x360 的像素观感。
##
## 两种颗粒:
##   - `emit_at()` 碎屑:往上崩、受重力落下(拆解、旧的落地扬尘);
##   - `emit_dust()` 尘团:贴地往一侧/两侧散开、被空气阻力拖慢、微微上飘(Celeste、Hollow Knight
##     的落地灰和跑步脚下灰都是这种 —— 不往上喷,往两边铺)。
##
## Usage:
##     burst.emit_at(global_position, 10, Color("1A2A44"))
##     burst.emit_dust(ryn.global_position, 6, 0)     # 0 = 往两边;-1 / 1 = 只往一侧

class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var grav: float
	var drag: float
	## 尘团随寿命缩小(一团灰慢慢散掉);碎屑不缩。
	var shrink: bool

## 同屏最多存活的颗粒数。超过就不再生成 —— 硬上限,防止堆积。
@export var max_particles: int = 90
@export var gravity: float = 260.0
@export_group("Dust")
## 尘团颜色。比地面亮一档的冷灰,在暗背景上读得出、又不抢眼。
@export var dust_color: Color = Color("8A9AB2")
## 尘团的初速度范围(水平),px/s。
@export var dust_speed: Vector2 = Vector2(22.0, 64.0)
## 尘团的上飘加速度(负 = 往上),px/s²。
@export var dust_rise: float = -18.0
## 空气阻力,每秒速度剩下 exp(-drag)。
@export var dust_drag: float = 5.0
## 尘团寿命,秒。
@export var dust_life: float = 0.42

var _parts: Array[Particle] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 5
	_rng.randomize()
	set_process(false)


## 在某点爆一簇。`spread` 控制横向扩散,`up` 控制初始上扬。
func emit_at(at: Vector2, count: int, color: Color, spread: float = 48.0, up: float = 70.0, life: float = 0.5) -> void:
	for i in count:
		if _parts.size() >= max_particles:
			break
		var p := Particle.new()
		p.pos = to_local(at)
		p.vel = Vector2(_rng.randf_range(-spread, spread), -_rng.randf_range(up * 0.3, up))
		p.max_life = life * _rng.randf_range(0.7, 1.3)
		p.life = p.max_life
		p.size = _rng.randf_range(1.0, 2.0)
		p.color = color
		p.grav = gravity
		p.drag = 0.0
		_parts.append(p)
	set_process(true)


## 贴地的尘团。`dir`:0 = 往两边,1 / -1 = 只往那一侧。`strength` 放大速度和寿命(重落地 1.6)。
func emit_dust(at: Vector2, count: int, dir: int = 0, strength: float = 1.0) -> void:
	for i in count:
		if _parts.size() >= max_particles:
			break
		var p := Particle.new()
		var side: float = float(dir) if dir != 0 else (-1.0 if i % 2 == 0 else 1.0)
		p.pos = to_local(at) + Vector2(side * _rng.randf_range(1.0, 5.0), -_rng.randf_range(1.0, 4.0))
		p.vel = Vector2(side * _rng.randf_range(dust_speed.x, dust_speed.y) * strength,
				-_rng.randf_range(2.0, 12.0))
		p.max_life = dust_life * _rng.randf_range(0.7, 1.2) * lerpf(1.0, strength, 0.5)
		p.life = p.max_life
		p.size = float(_rng.randi_range(3, 4))
		p.color = dust_color
		p.grav = dust_rise
		p.drag = dust_drag
		p.shrink = true
		_parts.append(p)
	set_process(true)


func _process(delta: float) -> void:
	var alive: Array[Particle] = []
	for p in _parts:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.vel.y += p.grav * delta
		if p.drag > 0.0:
			p.vel *= exp(-p.drag * delta)
		p.pos += p.vel * delta
		alive.append(p)
	_parts = alive
	queue_redraw()
	if _parts.is_empty():
		set_process(false)


func _draw() -> void:
	for p in _parts:
		var k: float = clampf(p.life / maxf(p.max_life, 0.0001), 0.0, 1.0)
		var c := p.color
		c.a = k * 0.85
		var size: float = maxf(1.0, roundf(p.size * (0.4 + 0.6 * k))) if p.shrink else p.size
		# 以中心缩放,整数像素对齐
		var at := Vector2(roundf(p.pos.x - size * 0.5), roundf(p.pos.y - size * 0.5))
		draw_rect(Rect2(at, Vector2(size, size)), c, true)
