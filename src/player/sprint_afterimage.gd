class_name SprintAfterimage
extends Node2D
## 跑步残影。只在真正冲刺时留,走路不留 —— 残影是"快"的信号,滥用就没信息量了。
##
## 每隔一段 **距离**(不是时间)抓一次快照,所以速度越快残影越密,减速时自然变疏。
## 快照只记位置和「当时是 6 姿里的哪一姿、朝向、身体状态」,绘制时让
## `RynSpriteVisual.draw_snapshot()` 用同一套部件把那一姿再画一遍 —— 不复制纹理。
## 旧版把整张静止图拉到碰撞高度来画,会把迈步动作盖成一个僵直的人形。
##
## 画在角色 **之后**(z_index 更低),否则残影会糊在脸上。
##
## ## 剪影,不是半透明原图(Celeste 的做法)
##
## Celeste 的冲刺尾迹是「当前精灵的纯色剪影,按时间淡出」。半透明原图会把眼睛、衣褶
## 这些细节也拖出一串,和本体抢视线;纯色剪影只留下动势。颜色从新到旧由
## `tint_new`(Ryn 发色)过渡到 `tint`(冷蓝)—— 最近的一个最像她,越远越融进夜色。

const SILHOUETTE: Shader = preload("res://src/player/afterimage_silhouette.gdshader")

class Ghost:
	var pos: Vector2
	var snap: Dictionary
	var life: float

@export var ryn: Ryn
@export var sprite: RynSpriteVisual
## 每跑多少 px 留一个残影。
## 2026-10-12 用户在三组对比里选了「少而清楚」(旧值 11 / 0.26 秒 / 7 个 / 0.38):一个个分开、不糊在身上,
## 冲刺时人的轮廓最清楚。对比:`src/dev/afterimage_compare.gd`、`production/qa/evidence/ryn-animation/13-afterimage-presets.gif`。
@export var spacing_px: float = 18.0
## 单个残影存活时长,秒。
@export var life_time: float = 0.22
## 最多同时存在几个。
@export var max_ghosts: int = 4
## 残影起始不透明度。
@export_range(0.0, 1.0) var start_alpha: float = 0.34
## 最旧的残影颜色 —— 冷蓝,融进夜色。
@export var tint: Color = Color("4C7BA8")
## 最新的残影颜色 —— 取 Ryn 的发色,让尾迹认得出是她。
@export var tint_new: Color = Color("D4566F")

var _ghosts: Array[Ghost] = []
var _since: float = 0.0


func _ready() -> void:
	z_index = -1
	# 项目默认过滤是线性(default_texture_filter=1 在 Godot 4 里是 Linear),
	# 残影用的是同一张像素部件图,不显式设最近邻就会糊边。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = SILHOUETTE
	material = mat
	set_process(true)


func _process(delta: float) -> void:
	if ryn == null:
		return
	if ryn.is_sprinting:
		_since += absf(ryn.velocity.x) * delta
		if _since >= spacing_px:
			_since = 0.0
			var g := Ghost.new()
			g.pos = ryn.global_position.round()
			g.snap = sprite.snapshot() if sprite != null else {}
			g.life = life_time
			_ghosts.append(g)
			if _ghosts.size() > max_ghosts:
				_ghosts.pop_front()
	else:
		_since = 0.0

	var alive: Array[Ghost] = []
	for g in _ghosts:
		g.life -= delta
		if g.life > 0.0:
			alive.append(g)
	_ghosts = alive
	queue_redraw()


func _draw() -> void:
	if sprite == null or sprite.texture == null:
		return
	for g in _ghosts:
		if g.snap.is_empty():
			continue
		var f: float = clampf(g.life / maxf(life_time, 0.0001), 0.0, 1.0)
		var c := tint.lerp(tint_new, f)
		c.a = start_alpha * f * f   # 平方衰减:尾部淡得更快,头部更实
		sprite.draw_snapshot(self, to_local(g.pos).round(), g.snap, c)
