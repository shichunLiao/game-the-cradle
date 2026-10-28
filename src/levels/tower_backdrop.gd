class_name TowerBackdrop
extends Node2D
## 塔内背景:五层石砌纵深 + 后装工业管道。
##
## ## 五层,从远到近
##
##   L0 纵深    最暗、最慢 —— 门洞之后那片空间
##   L1 远墙    粗砌、低细节,只给轮廓
##   L2 拱廊    一排拱券剪影,这一层负责"深度"的读数
##   L3 主墙    全细节:砖的立体边、斑驳、腰线、箭窗、壁龛
##   L4 近景    管道、梁托、瓦砾,与前景同速
##
## 两层做不出纵深:只有当相邻层之间 **明度与速度同时递进**,眼睛才读成"远近"。
## 这也是为什么每层压暗量是固定递进的,而不是各调各的。
##
## ## 视差系数保守
##
## 塔内的墙离镜头近,现实里视差就小。拉大会读作"墙在滑动"而不是"有纵深"。
##
## ## 一次生成,之后只画贴图
##
## 逐砖级别的细节需要上千次绘制调用。五层墙在 `_ready` 生成 `ImageTexture`,
## 之后每帧只是五次 `draw_texture_rect`。

@export var area: Rect2 = Rect2(0, -140, 1536, 500):
	set(value):
		area = value
		_dirty = true
		queue_redraw()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		_dirty = true
		queue_redraw()

@export_group("Stone")
## 主墙(L3)砖面色。必须明显暗于前景方块(#1A2A44)。
@export var stone_color: Color = Color("0C1220")
@export var mortar_color: Color = Color("060A12")
## 破损、拱洞、箭窗透出的纵深。接近纯黑。
@export var depth_color: Color = Color("05080D")
## 箭窗透进来的光。a=0 则不透光。
@export var glow_color: Color = Color(0.34, 0.45, 0.58, 0.14)
## 每退一层额外压暗多少。层次感的主要来源。
@export_range(0.0, 0.6) var layer_darken: float = 0.3

@export_group("Detail counts — 主墙")
@export var breaches: int = 11
@export var arches: int = 4
@export var slits: int = 6
@export var niches: int = 3
@export var pilaster_spacing: int = 170
## 腰线行间隔。
@export var course_every: int = 6

@export_group("Industrial — 后装设备")
@export var pipes: int = 5
@export var pipe_color: Color = Color("16243A")
@export var rubble_count: int = 46
@export var rubble_color: Color = Color("111A28")
@export var ground_y: float = 320.0

@export_group("Parallax")
@export_range(0.0, 1.0) var depth_parallax: float = 0.74
@export_range(0.0, 1.0) var far_parallax: float = 0.81
@export_range(0.0, 1.0) var arcade_parallax: float = 0.87
@export_range(0.0, 1.0) var wall_parallax: float = 0.93

## 纹理密度倍率。与相机 zoom 一致。
const DENSITY: int = 2

var _depth: ImageTexture
var _far: ImageTexture
var _arcade: ImageTexture
var _wall: ImageTexture
var _dirty: bool = true
var _cam: Camera2D


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	_rebuild()
	set_process(true)


func _process(_delta: float) -> void:
	_cam = get_viewport().get_camera_2d()
	queue_redraw()


func _rebuild() -> void:
	# 纹理按 2 倍密度生成,绘制时缩回世界尺寸 —— zoom=2 下正好 1:1,不糊。
	var w: int = (int(area.size.x) + 500) * DENSITY
	var h: int = int(area.size.y) * DENSITY

	# L3 主墙:全细节
	var main := StoneWallTexture.Spec.new()
	main.width = w
	main.height = h
	main.seed_value = seed_value
	main.stone = stone_color
	main.mortar = mortar_color
	main.dark = depth_color
	main.glow = glow_color
	main.breaches = breaches
	main.arches = arches
	main.slits = slits
	main.niches = niches
	main.pilaster_spacing = pilaster_spacing * DENSITY
	main.course_every = course_every
	main.speckle = 3
	_wall = StoneWallTexture.build_spec(main)

	# L2 拱廊:拱券多、砖细节少 —— 它负责"深度"的读数,不该抢细节
	var arcade := StoneWallTexture.Spec.new()
	arcade.width = w
	arcade.height = h
	arcade.seed_value = seed_value + 401
	arcade.stone = stone_color.darkened(layer_darken)
	arcade.mortar = mortar_color.darkened(layer_darken)
	arcade.dark = depth_color
	arcade.glow = Color(glow_color, glow_color.a * 0.6)
	arcade.breaches = breaches / 2
	arcade.arches = arches * 3
	arcade.slits = slits / 2
	arcade.niches = 0
	arcade.pilaster_spacing = (pilaster_spacing + 50) * DENSITY
	arcade.course_every = 0
	arcade.speckle = 1
	arcade.top_darken = 0.42
	_arcade = StoneWallTexture.build_spec(arcade)

	# L1 远墙:只剩轮廓
	var far := StoneWallTexture.Spec.new()
	far.width = w
	far.height = h
	far.seed_value = seed_value + 977
	far.stone = stone_color.darkened(layer_darken * 1.9)
	far.mortar = mortar_color.darkened(layer_darken * 1.9)
	far.dark = depth_color
	far.glow = Color(glow_color, 0.0)
	far.breaches = breaches / 3
	far.arches = arches
	far.slits = 0
	far.niches = 0
	far.pilaster_spacing = (pilaster_spacing + 110) * DENSITY
	far.course_every = 0
	far.speckle = 0
	far.top_darken = 0.5
	_far = StoneWallTexture.build_spec(far)

	# L0 纵深:几乎纯黑,只有极少拱洞透出一点结构
	var deep := StoneWallTexture.Spec.new()
	deep.width = w
	deep.height = h
	deep.seed_value = seed_value + 1543
	deep.stone = stone_color.darkened(layer_darken * 2.6)
	deep.mortar = depth_color
	deep.dark = depth_color
	deep.glow = Color(glow_color, 0.0)
	deep.breaches = 0
	deep.arches = arches / 2
	deep.slits = 0
	deep.niches = 0
	deep.pilaster_spacing = (pilaster_spacing + 200) * DENSITY
	deep.course_every = 0
	deep.speckle = 0
	deep.top_darken = 0.6
	_depth = StoneWallTexture.build_spec(deep)

	_dirty = false


func _shift(factor: float) -> float:
	if _cam == null:
		return 0.0
	return (_cam.global_position.x - global_position.x) * (1.0 - factor)


func _draw() -> void:
	if _dirty:
		_rebuild()
	if _wall == null:
		return
	var x0: float = area.position.x - 250.0
	var y0: float = area.position.y
	var size := Vector2(_wall.get_width(), _wall.get_height()) / float(DENSITY)

	draw_texture_rect(_depth, Rect2(Vector2(x0 + _shift(depth_parallax), y0), size), false)
	draw_texture_rect(_far, Rect2(Vector2(x0 + _shift(far_parallax), y0), size), false)
	draw_texture_rect(_arcade, Rect2(Vector2(x0 + _shift(arcade_parallax), y0), size), false)
	draw_texture_rect(_wall, Rect2(Vector2(x0 + _shift(wall_parallax), y0), size), false)

	# L4 后装设备与瓦砾 —— 与前景同速
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31
	var aw: float = area.size.x
	var ax: float = area.position.x
	for i in pipes:
		var qx: float = ax + rng.randf_range(0.0, maxf(aw - 8.0, 1.0))
		var top: float = y0 + rng.randf_range(0.0, area.size.y * 0.35)
		var bot: float = ground_y - rng.randf_range(0.0, 60.0)
		draw_rect(Rect2(qx, top, 5.0, maxf(bot - top, 1.0)), pipe_color, true)
		draw_rect(Rect2(qx, top, 1.0, maxf(bot - top, 1.0)), pipe_color.lightened(0.14), true)
		var cy: float = top + 16.0
		while cy < bot:
			draw_rect(Rect2(qx - 2.0, cy, 9.0, 2.0), pipe_color.lightened(0.1), true)
			draw_rect(Rect2(qx - 2.0, cy + 2.0, 9.0, 1.0), pipe_color.darkened(0.3), true)
			cy += rng.randf_range(42.0, 76.0)
	for i in rubble_count:
		var s: float = rng.randf_range(3.0, 10.0)
		var sx: float = ax + rng.randf_range(0.0, maxf(aw - s, 1.0))
		var lift: float = rng.randf() * rng.randf() * 44.0
		draw_rect(Rect2(sx, ground_y - s - lift, s, s), rubble_color, true)
		draw_rect(Rect2(sx, ground_y - s - lift, s, 1.0), rubble_color.lightened(0.1), true)
