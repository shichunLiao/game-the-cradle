class_name SlumRoomBackdrop
extends Node2D
## 序章「贫民窟旧屋」的室内画面。`_ready` 里画一次到 ImageTexture,之后只贴图。
##
## 这间房要讲一件事:屋里是仅有的暖,窗外那道惨白光是她要走进去的高塔。
## Ryn 从窗边醒来 → 向右走到桌前看合影 → 从最右侧窄门离开。
##
## ## 只管画面,不管碰撞
##
## 地面/墙/天花板/架子/门楣的 `GrayBlock` 仍在场景里负责碰撞,只是 `modulate.a = 0`。
## `GrayBlock` 会画石砌缝和冷青顶边(塔关的语言),不适合这间屋,所以藏起来,
## 但它的脚本不改 —— 塔关还在用。
##
## ## 窗
##
## 窗框、十字棂、冷光柱、6 秒呼吸仍由 `WindowLight` 负责,这里不碰它的行为。
## 但它会给整块窗洞盖一层 alpha≈0.5 的惨白,画在它**下面**的夜空和远塔会被洗掉。
## 所以窗洞内容单独做成一张小贴图,z 放在 `WindowLight` 之上,并在十字棂的位置
## 留空 —— 窗棂仍是 `WindowLight` 自己画的那两条。
##
## ## 颜色纪律
##
## 暖色 `MEMORY` 只出现在:烛火、照片边、被子上一块、炉膛的火。其余一律棕灰家族
## (Vera 的围巾是她工装的蓝,和塔2 那件工装、坑底她手腕的布同一个颜色)。墙角暗角按级量化,保持像素画的硬边。
##
## ## 精装修(2026-10-13,`docs/polish-research.md` §3.1–3.2)
##
## 用户:「Ryn 和姐姐的房间应该更加温馨。」照 Project Horseshoe 的温馨三件事 —— 安全、富足、柔软:
##   - **两处有来源的暖光**:桌上的蜡烛(`LampGlow` CANDLE)和炉子(EMBER),环境光仍然很低;
##     窗外那道惨白光留着 —— 冷在外面,进不来。光不再烤进贴图,会闪。
##   - **两个人一起过日子的东西**(环境叙事,GDC《What Happened Here?》):两个枕头、拼布被子、
##     两只杯子(一只有缺口)、Vera 的工作台和她那盏没点的台灯、门边两排身高刻痕「V」「R」、
##     墙上空的钉子(吊坠原来挂在这)、Vera 的蓝围巾、窗台上 Ryn 顺来的小东西、晾衣绳、炉子上的水壶。
##   - 会动的小东西(汽、火星、灰尘、火苗)在 `HomeAmbience`。
##
## Usage (in a scene):
##     [node name="Backdrop" type="Node2D" parent="." node_paths=PackedStringArray("window")]
##     script = res://src/levels/slum_room_backdrop.gd
##     window = NodePath("../Window")

const WALL: Color = Color("2A2118")
const PATCH: Color = Color("3A2E22")
const STAIN: Color = Color("1A140F")
const FLOOR: Color = Color("3C2E20")
const SEAM: Color = Color("241910")
const BEAM: Color = Color("2C2218")
const WOOD_LIT: Color = Color("6B5340")
const MEMORY: Color = Color("C4A574")
const TOWER_LIGHT: Color = Color("C8D4E0")
const NIGHT: Color = Color("0B1220")
const TOWER: Color = Color("1A2A44")
const STREET: Color = Color("0E1520")
const BRICK: Color = Color("5C4030")
const CORNER: Color = Color("120E0C")
const WOOL: Color = Color("4A3A2C")
const IRON: Color = Color("1C1A1E")
const IRON_LIT: Color = Color("3A3840")
const CERAMIC: Color = Color("7A6A58")
const SCARF: Color = Color("5B7FA3")
const EMBER_DIM: Color = Color("8A6A40")
## 刻痕:刀刻进灰泥,露出底下浅一点的颜色。
const SCRATCH: Color = Color("6B5340")

## 贴图覆盖的世界范围:左墙外侧到右墙外侧,相机可达的最高处到画面底。
const ORIGIN := Vector2i(-16, -40)
const TEX_SIZE := Vector2i(652, 400)

## 房间结构。和场景里隐藏的 GrayBlock 对齐,改这里之前先看 prologue_slum.tscn。
const CEILING_Y: int = 140
const WALL_TOP: int = 156
const FLOOR_Y: int = 320
const BEAM_BOTTOM: int = 204
const ROOM_RIGHT: int = 620

## 门洞:必须盖住 TowerExit 的占用区(x 580..620, y 264..320)。
const DOOR := Rect2i(572, 256, 48, 64)

## 烛火(火焰 2x2 的左上角)。桌上的蜡烛和炉子是屋里的两处暖光。
const FLAME := Vector2i(364, 298)
## 炉子:左上角 + 尺寸;炉膛格栅;水壶嘴。`HomeAmbience` 的默认坐标和这里一致。
const STOVE := Rect2i(426, 290, 32, 30)
const GRATE := Rect2i(434, 305, 14, 6)
## 两根梁的 x。右边那根原来在 452,炉子的烟囱要从那里上去,挪到 474。
const BEAMS: Array[int] = [236, 474]

## 窗。读它的位置和尺寸来摆夜空贴图,不写死第二份坐标。
@export var window: WindowLight

var _room: ImageTexture
var _pane: Sprite2D


func _ready() -> void:
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room = ImageTexture.create_from_image(_paint_room())
	_add_lights()
	if window != null:
		_pane = Sprite2D.new()
		_pane.centered = false
		_pane.texture = ImageTexture.create_from_image(_paint_pane(Vector2i(window.size)))
		_pane.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 必须高于 WindowLight(z -3),低于 Ryn(z 0)。用绝对 z,不跟着本节点的 -10。
		_pane.z_as_relative = false
		_pane.z_index = -2
		_pane.position = window.position - global_position + Vector2(0.0, -window.size.y)
		add_child(_pane)
	queue_redraw()


func _draw() -> void:
	if _room != null:
		draw_texture(_room, Vector2(ORIGIN))


## 两处暖光 + 会动的小东西。光是叠加的(不改贴图),画在家具之上、Ryn 之下。
func _add_lights() -> void:
	var candle := LampGlow.new()
	candle.color = MEMORY
	candle.radius = 52.0
	candle.energy = 0.36
	candle.steps = 8
	candle.flicker = LampGlow.Flicker.CANDLE
	candle.position = Vector2(FLAME) + Vector2(1.0, 1.0) - global_position
	candle.z_as_relative = false
	candle.z_index = -1
	add_child(candle)
	var hearth := LampGlow.new()
	hearth.color = MEMORY
	hearth.radius = 72.0
	hearth.energy = 0.32
	hearth.steps = 8
	hearth.squash = 0.7
	hearth.flicker = LampGlow.Flicker.EMBER
	hearth.position = Vector2(GRATE.get_center()) - global_position
	hearth.z_as_relative = false
	hearth.z_index = -1
	add_child(hearth)
	var amb := HomeAmbience.new()
	amb.window = window
	amb.grate = Rect2(GRATE)
	amb.flame_tip = Vector2(FLAME) + Vector2(0.0, -2.0)
	amb.position = -global_position
	add_child(amb)


# ---------------------------------------------------------------- 房间

func _paint_room() -> Image:
	var img := Image.create(TEX_SIZE.x, TEX_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(CORNER)

	# 天花板与墙体
	_rect(img, -16, CEILING_Y, 652, 16, BEAM)
	_rect(img, -16, WALL_TOP - 1, 652, 1, STAIN)
	_rect(img, 0, WALL_TOP, ROOM_RIGHT, FLOOR_Y - WALL_TOP, WALL)
	_rect(img, -16, WALL_TOP, 16, FLOOR_Y - WALL_TOP, STAIN)           # 左墙剖面
	_rect(img, ROOM_RIGHT, WALL_TOP, 16, FLOOR_Y - WALL_TOP, STAIN)    # 右墙剖面

	_paint_wall_wear(img)
	_paint_beams(img)
	_paint_clothesline(img)
	_paint_floor(img)
	_paint_rug(img)
	_paint_bedroll(img)
	_paint_windowsill(img)
	_paint_workbench(img)
	_paint_table(img)
	_paint_hook(img)
	_paint_stove(img)
	_paint_shelf(img)
	_paint_scarf(img)
	_paint_height_marks(img)
	_paint_door(img)

	_apply_corners(img)
	# 被子上那块暖色在暗角**之后**再画:它离左下墙角只有约 50px,会被暗角压成别的颜色。
	# 实测第一版里它一个精确的暖色像素都没剩下。炉膛的火同理。
	_rect(img, 52, FLOOR_Y - 13, 5, 3, MEMORY)
	_rect(img, GRATE.position.x, GRATE.position.y, GRATE.size.x, GRATE.size.y, EMBER_DIM)
	for gx in range(GRATE.position.x + 2, GRATE.end.x, 3):
		_rect(img, gx, GRATE.position.y, 1, GRATE.size.y, IRON)
	return img


## 不平的灰泥:墙脚和墙顶的污渍、两块补丁、一条裂缝、零星露出的砖。
func _paint_wall_wear(img: Image) -> void:
	_rect(img, 0, WALL_TOP, ROOM_RIGHT, 2, STAIN)          # 天花板下沿的阴影
	_rect(img, 0, FLOOR_Y - 2, ROOM_RIGHT, 2, STAIN)       # 墙脚
	_rect(img, 0, WALL_TOP, 4, FLOOR_Y - WALL_TOP, STAIN)  # 左墙角
	# 窗台和窗下的水渍:几道细的垂痕,不要画成一块(第一版读成了托架)
	_outlined(img, 116, 252, 60, 4, BEAM)
	for drip in [Vector3i(128, 256, 10), Vector3i(133, 256, 5), Vector3i(141, 256, 14),
			Vector3i(160, 256, 7)]:
		_rect(img, drip.x, drip.y, 1, drip.z, STAIN)
	# 两块补丁,形状不同,一块描了边
	_outlined(img, 60, 212, 28, 16, PATCH)
	_rect(img, 504, 280, 20, 12, PATCH)
	_rect(img, 508, 276, 12, 4, PATCH)
	# 从天花板斜下来的细裂缝,逐级错开
	var x: int = 300
	var y: int = WALL_TOP
	for step in 6:
		_rect(img, x, y, 1, 6, STAIN)
		_rect(img, x, y + 6, 4 if step % 2 == 0 else 2, 1, STAIN)
		x += 4 if step % 2 == 0 else 2
		y += 7
	# 灰泥底下露出的砖点,每面墙不超过 8 个
	for p in [Vector2i(36, 180), Vector2i(92, 272), Vector2i(256, 236), Vector2i(304, 176),
			Vector2i(340, 262), Vector2i(508, 212), Vector2i(540, 288)]:
		_rect(img, p.x, p.y, 2, 2, BRICK)


## 天花板下挂的两根梁。底边 y=204:进得了 zoom 4 的取景(画面顶 y=180),
## 又远高于 Ryn 的头(y≈292)和要求的 250 上限。避开窗(x 118..174)和炉子的烟囱。
func _paint_beams(img: Image) -> void:
	for bx in BEAMS:
		_outlined(img, bx, WALL_TOP, 12, BEAM_BOTTOM - WALL_TOP, BEAM)
		_rect(img, bx + 1, WALL_TOP + 1, 1, BEAM_BOTTOM - WALL_TOP - 2, WOOD_LIT)  # 朝窗一侧受光
		_rect(img, bx - 6, BEAM_BOTTOM - 10, 6, 2, STAIN)                         # 斜撑
		_rect(img, bx + 12, BEAM_BOTTOM - 10, 6, 2, STAIN)


## 横向木板,板高 8px。两块短板。窗光落点处顶边提 1px。
func _paint_floor(img: Image) -> void:
	_rect(img, -16, FLOOR_Y, 652, 40, FLOOR)
	var joints: Array = [
		[96, 220, 340, 470, 590],
		[40, 160, 184, 300, 420, 540],          # 160..184 是短板
		[120, 250, 380, 500, 600],
		[70, 200, 330, 354, 460, 580],          # 330..354 是短板
		[30, 150, 280, 410, 530],
	]
	for row in joints.size():
		var ry: int = FLOOR_Y + row * 8
		if row > 0:
			_rect(img, -16, ry, 652, 1, SEAM)
		for jx in joints[row]:
			_rect(img, jx, ry, 1, 8, SEAM)
	_rect(img, -16, FLOOR_Y, 652, 1, SEAM)
	# 窗光落在地面的位置由 WindowLight 的几何决定(此处约 x 188..240)
	for seg in [Vector2i(188, 32), Vector2i(221, 19)]:
		_rect(img, seg.x, FLOOR_Y, seg.y, 1, WOOD_LIT)


## 窗下偏左的地铺:一张垫子睡两个人 —— 两个枕头并排,一床拼布被子。被子上一块暖色在 _paint_room 末尾画。
func _paint_bedroll(img: Image) -> void:
	_outlined(img, 18, FLOOR_Y - 7, 60, 7, PATCH)            # 垫子
	_outlined(img, 20, FLOOR_Y - 12, 12, 6, WOOL)            # 枕头(Vera)
	_outlined(img, 31, FLOOR_Y - 11, 11, 5, WOOL)            # 枕头(Ryn,压扁一点)
	_rect(img, 22, FLOOR_Y - 11, 3, 1, CERAMIC)              # 枕头上的褶
	# 拼布被子:一格格不同的旧布,针脚是深色的缝
	_outlined(img, 40, FLOOR_Y - 15, 38, 9, BEAM)
	var cols: Array[Color] = [PATCH, WOOL, BEAM, PATCH, WOOL, BEAM]
	for i in 6:
		_rect(img, 41 + i * 6, FLOOR_Y - 14, 6, 4, cols[i])
		_rect(img, 41 + i * 6, FLOOR_Y - 10, 6, 3, cols[(i + 3) % 6])
	for i in range(1, 6):
		_rect(img, 41 + i * 6, FLOOR_Y - 14, 1, 7, STAIN)
	_rect(img, 41, FLOOR_Y - 10, 36, 1, STAIN)
	_rect(img, 40, FLOOR_Y - 15, 1, 1, CORNER)               # 被子圆角
	_rect(img, 77, FLOOR_Y - 15, 1, 1, CORNER)


## 窗台上 Ryn 顺来的小东西:一排瓶盖、一个铁皮小人、一罐亮晶晶的螺丝。
func _paint_windowsill(img: Image) -> void:
	for i in 4:
		_rect(img, 121 + i * 3, 250, 2, 2, IRON_LIT if i % 2 == 0 else BRICK)    # 瓶盖
	_outlined(img, 140, 243, 5, 9, IRON_LIT)                 # 铁皮小人:身子
	_rect(img, 141, 240, 3, 3, IRON_LIT)                     # 头
	_rect(img, 142, 241, 1, 1, MEMORY.darkened(0.3))         # 一只眼睛,铜的
	_outlined(img, 160, 244, 7, 8, IRON)                     # 玻璃罐
	_rect(img, 161, 248, 5, 3, IRON_LIT)                     # 罐底的螺丝
	_rect(img, 162, 247, 1, 1, TOWER_LIGHT.darkened(0.3))    # 一颗反光


## 晾衣绳:两根梁之间垂下来,挂着一件小衣服、一只袜子、一块布。
func _paint_clothesline(img: Image) -> void:
	var x0: int = BEAMS[0] + 12
	var x1: int = BEAMS[1]
	for x in range(x0, x1):
		var t: float = float(x - x0) / float(x1 - x0)
		var sag: int = int(roundf(sin(t * PI) * 6.0))
		_rect(img, x, 194 + sag, 1, 1, STAIN)
	_outlined(img, 296, 199, 10, 10, WOOL)                   # 小衣服(Ryn 的)
	_rect(img, 294, 200, 3, 4, WOOL)                         # 袖子
	_rect(img, 305, 200, 3, 4, WOOL)
	_outlined(img, 338, 200, 4, 8, PATCH)                    # 袜子
	_rect(img, 338, 206, 6, 2, PATCH)
	_outlined(img, 408, 199, 8, 9, BEAM)                     # 一块布


## 炉子前的旧地毯:侧面看只是贴着地的一条,带流苏。
func _paint_rug(img: Image) -> void:
	_rect(img, 376, FLOOR_Y - 2, 100, 2, BRICK)
	for x in range(378, 474, 6):
		_rect(img, x, FLOOR_Y - 2, 3, 1, PATCH)
	for x in [375, 377, 474, 476]:
		_rect(img, x, FLOOR_Y - 1, 1, 1, PATCH)


## Vera 的工作台:拆开的收音机、台钳、螺丝盘;墙上挂工具的洞洞板;她那盏改装的台灯没点 —— 她不在。
func _paint_workbench(img: Image) -> void:
	# 洞洞板 + 工具
	_outlined(img, 252, 224, 66, 34, PATCH)
	for yy in range(228, 256, 5):
		for xx in range(256, 316, 5):
			_rect(img, xx, yy, 1, 1, STAIN)
	_rect(img, 260, 230, 2, 16, IRON_LIT)                    # 螺丝刀
	_rect(img, 259, 230, 4, 4, BRICK)                        # 把手
	_rect(img, 270, 232, 2, 14, IRON_LIT)                    # 扳手
	_rect(img, 268, 230, 6, 3, IRON_LIT)
	_rect(img, 269, 231, 2, 1, PATCH)
	_rect(img, 282, 234, 2, 10, IRON_LIT)                    # 钳子
	_rect(img, 286, 234, 2, 10, IRON_LIT)
	_rect(img, 283, 242, 4, 2, IRON_LIT)
	for i in 4:                                               # 一卷铜线
		_rect(img, 298 + i, 236 + i, 8 - i * 2, 1, EMBER_DIM)
	_rect(img, 298, 240, 8, 4, EMBER_DIM.darkened(0.3))
	# 台面 + 腿 + 下层
	_outlined(img, 248, 286, 86, 5, BEAM)
	_rect(img, 249, 286, 84, 1, WOOD_LIT)
	_outlined(img, 250, 291, 4, 29, BEAM)
	_outlined(img, 328, 291, 4, 29, BEAM)
	_outlined(img, 254, 306, 74, 3, BEAM)
	_outlined(img, 260, 296, 20, 10, WOOL)                   # 下层一箱零件
	_rect(img, 264, 296, 12, 1, IRON_LIT)
	# 拆开的收音机:外壳、旋钮、两根管子
	_outlined(img, 256, 274, 22, 12, IRON)
	_rect(img, 258, 276, 7, 7, IRON_LIT)                     # 喇叭格
	for yy in range(277, 283, 2):
		_rect(img, 258, yy, 7, 1, IRON)
	_rect(img, 268, 277, 3, 3, BRICK)                        # 旋钮
	_rect(img, 273, 276, 2, 6, TOWER_LIGHT.darkened(0.55))  # 真空管
	_rect(img, 280, 282, 6, 4, IRON)                         # 拆下来的面板
	# 台钳 + 螺丝盘
	_outlined(img, 298, 278, 8, 8, IRON_LIT)
	_rect(img, 296, 280, 2, 2, IRON_LIT)
	_outlined(img, 312, 283, 14, 3, BEAM)
	for xx in range(314, 325, 3):
		_rect(img, xx, 284, 1, 1, IRON_LIT)
	# 台灯:夹在台子右头,鹅颈弯下来,灯罩朝下 —— 没点
	_rect(img, 329, 284, 3, 2, IRON)
	_rect(img, 330, 270, 1, 14, IRON)
	_rect(img, 324, 268, 7, 2, IRON)
	_outlined(img, 320, 268, 6, 5, IRON_LIT)
	_rect(img, 321, 268, 4, 1, STAIN)                        # 灯罩顶上的灰


## 墙上的钉子:吊坠原来挂在这里。钉子下面一块没被晒褪色的印子,吊坠的形状。
func _paint_hook(img: Image) -> void:
	_rect(img, 391, 262, 2, 2, IRON_LIT)
	for p in [Vector2i(390, 265), Vector2i(393, 265), Vector2i(389, 267), Vector2i(394, 267)]:
		_rect(img, p.x, p.y, 1, 1, PATCH)                    # 链子的印
	_rect(img, 389, 269, 6, 6, PATCH)                        # 吊坠的印
	_rect(img, 390, 270, 4, 4, WALL)


## 铁炉:四条腿、炉门的格栅(火在 _paint_room 末尾画)、炉顶上的水壶、烟囱一直通到天花板。
func _paint_stove(img: Image) -> void:
	var r := STOVE
	_rect(img, r.position.x + 13 + 9, WALL_TOP, 4, r.position.y - WALL_TOP, IRON)    # 烟囱
	_rect(img, r.position.x + 13 + 9, WALL_TOP, 1, r.position.y - WALL_TOP, IRON_LIT)
	_rect(img, r.position.x + 20, 230, 8, 2, IRON_LIT)       # 烟囱上的箍
	_outlined(img, r.position.x, r.position.y + 2, r.size.x, r.size.y - 6, IRON)
	_rect(img, r.position.x - 1, r.position.y, r.size.x + 2, 3, IRON_LIT)           # 炉顶板
	_rect(img, r.position.x + 1, r.end.y - 4, 3, 4, IRON)    # 腿
	_rect(img, r.end.x - 4, r.end.y - 4, 3, 4, IRON)
	_outlined(img, GRATE.position.x - 2, GRATE.position.y - 2, GRATE.size.x + 4, GRATE.size.y + 4, IRON_LIT)
	_rect(img, r.end.x - 6, r.position.y + 8, 3, 2, IRON_LIT)   # 炉门把手
	# 水壶:壶身、壶嘴朝左、提手
	_outlined(img, 431, 280, 12, 10, IRON_LIT)
	_rect(img, 427, 283, 4, 2, IRON_LIT)
	_rect(img, 433, 276, 8, 1, IRON)
	_rect(img, 432, 277, 1, 3, IRON)
	_rect(img, 441, 277, 1, 3, IRON)
	_rect(img, 432, 281, 10, 1, TOWER_LIGHT.darkened(0.6))   # 壶身一道反光


## 门边挂钩:Vera 的蓝围巾还挂着。
func _paint_scarf(img: Image) -> void:
	_rect(img, 546, 262, 3, 2, IRON_LIT)                     # 钩子
	_rect(img, 544, 264, 7, 4, SCARF.darkened(0.25))         # 搭在钩子上
	_rect(img, 544, 268, 3, 16, SCARF.darkened(0.15))        # 垂下来的两头
	_rect(img, 548, 268, 3, 12, SCARF.darkened(0.35))
	for x in [544, 546, 548, 550]:                            # 流苏
		_rect(img, x, 284 if x < 547 else 280, 1, 2, SCARF.darkened(0.45))


## 门左边墙上两排身高刻痕:左边一排是 Vera 的,右边一排是 Ryn 的;各自最高那道旁边刻了字母。
## Ryn 最后一道比她现在的头顶低一点 —— 那是去年,姐姐还在的时候量的。
func _paint_height_marks(img: Image) -> void:
	for y in [298, 288, 279, 271, 266]:
		_rect(img, 556, y, 4, 1, SCRATCH)
	for y in [306, 300, 294, 288, 284]:
		_rect(img, 562, y, 4, 1, SCRATCH)
	# 字母刻在各自那一排最高一道的上面(第一版 R 刻在门框边上,右边一列被门框盖掉,读成了 F)
	_letter(img, 556, 259, ["X.X", "X.X", "X.X", "X.X", ".X."])     # V
	_letter(img, 562, 277, ["XX.", "X.X", "XX.", "X.X", "X.X"])     # R


## 3x5 的刻字。`rows` 里 X 是刻痕。
func _letter(img: Image, x: int, y: int, rows: Array) -> void:
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if row[i] == "X":
				_rect(img, x + i, y + j, 1, 1, SCRATCH)


## 矮桌(无碰撞)、半截蜡烛、合影。
func _paint_table(img: Image) -> void:
	_outlined(img, 352, 306, 64, 6, BEAM)
	_rect(img, 353, 306, 20, 1, WOOD_LIT)                    # 烛光一侧的桌面受光
	_outlined(img, 356, 312, 4, 8, BEAM)
	_outlined(img, 408, 312, 4, 8, BEAM)
	# 蜡烛:烧到只剩 6px,火焰 2x2
	_outlined(img, 362, 300, 4, 6, PATCH)
	_rect(img, FLAME.x, FLAME.y, 2, 2, MEMORY)
	# 两只杯子:一只有缺口(Vera 的那只,一直没人用)
	_outlined(img, 399, 300, 5, 6, CERAMIC)
	_rect(img, 404, 302, 1, 2, CERAMIC)
	_outlined(img, 407, 300, 5, 6, CERAMIC)
	_rect(img, 412, 302, 1, 2, CERAMIC)
	_rect(img, 410, 300, 2, 1, WALL)                         # 缺口
	_rect(img, 400, 301, 3, 1, STAIN)                        # 杯里的茶
	# 合影:12x16 立在桌面上,1px 暖边,中间两颗深色人头
	_rect(img, 384, 290, 12, 16, MEMORY)
	_rect(img, 385, 291, 10, 14, PATCH)
	_rect(img, 386, 295, 3, 3, STAIN)
	_rect(img, 391, 294, 3, 3, STAIN)
	_rect(img, 386, 298, 8, 6, STAIN)


## 姐姐留下的东西:针线盒(Ryn 那件外套的袖子是她用这个改长的)、一轴线、小铁罐、细扳手。都不可交互。
func _paint_shelf(img: Image) -> void:
	_outlined(img, 480, 250, 56, 8, BEAM)
	_rect(img, 481, 250, 54, 1, WOOD_LIT)
	_rect(img, 486, 258, 2, 6, STAIN)                        # 托架
	_rect(img, 528, 258, 2, 6, STAIN)
	_outlined(img, 483, 245, 13, 5, IRON_LIT)                # 针线盒(饼干铁盒)
	_rect(img, 484, 245, 11, 1, CERAMIC)
	_rect(img, 498, 243, 4, 7, WOOL)                         # 一轴线
	_rect(img, 498, 243, 4, 1, BEAM)
	_rect(img, 498, 249, 4, 1, BEAM)
	_rect(img, 501, 240, 1, 3, TOWER_LIGHT.darkened(0.4))   # 插在线轴上的针
	_rect(img, 506, 240, 8, 10, STAIN)                       # 铁罐
	_rect(img, 507, 241, 6, 1, BEAM)
	_rect(img, 518, 247, 14, 2, STAIN)                       # 扳手柄
	_rect(img, 530, 244, 4, 5, STAIN)                        # 扳手头
	_rect(img, 531, 244, 2, 2, WALL)                         # 开口


## 敞开的窄门:没有门扇,门楣是一根粗木梁,门外只有一条更冷的竖带。
func _paint_door(img: Image) -> void:
	_rect(img, DOOR.position.x, DOOR.position.y, DOOR.size.x, DOOR.size.y, STREET)
	_outlined(img, DOOR.position.x - 4, DOOR.position.y - 8, DOOR.size.x + 8, 8, BEAM)
	_rect(img, DOOR.position.x - 3, DOOR.position.y - 1, DOOR.size.x + 6, 1, WOOD_LIT)
	_outlined(img, DOOR.position.x - 4, DOOR.position.y, 4, DOOR.size.y, BEAM)


# ---------------------------------------------------------------- 光

## 墙角收到 CORNER:按到最近墙角的距离分 5 级,只压墙面(地板不压)。
## 第一版用全屋椭圆,量化后变成一圈很显眼的大椭圆线,像画了个圈,不像暗角。
## 门洞不压暗 —— 那条冷是要留着的。
func _apply_corners(img: Image) -> void:
	var corners: Array[Vector2] = [Vector2(0, WALL_TOP), Vector2(ROOM_RIGHT, WALL_TOP),
			Vector2(0, FLOOR_Y), Vector2(ROOM_RIGHT, FLOOR_Y)]
	for py in TEX_SIZE.y:
		var wy: int = py + ORIGIN.y
		if wy < WALL_TOP or wy >= FLOOR_Y:
			continue
		for px in TEX_SIZE.x:
			var wx: int = px + ORIGIN.x
			if DOOR.has_point(Vector2i(wx, wy)):
				continue
			var d: float = INF
			for c in corners:
				d = minf(d, Vector2(wx, wy).distance_to(c))
			# 5 级、每级 0.08:台阶够细,远看是渐暗而不是一圈圈弧线。
			var k: float = 0.08 * float(clampi(5 - int(d / 16.0), 0, 5))
			if k > 0.0:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(CORNER, k))


# ---------------------------------------------------------------- 窗洞

## 夜空 + 一座远塔。十字棂的位置留空,让 WindowLight 自己画的窗棂透出来。
func _paint_pane(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(NIGHT)
	# 远塔:14x40,底边贴着窗洞底,偏右
	img.fill_rect(Rect2i(30, size.y - 40, 14, 40), TOWER)
	img.fill_rect(Rect2i(33, size.y - 36, 2, 3), TOWER_LIGHT)
	img.fill_rect(Rect2i(39, size.y - 26, 2, 3), TOWER_LIGHT)
	# 十字棂位置留透明(与 WindowLight._draw 的两条 2px 棂对齐)
	var clear := Color(0, 0, 0, 0)
	img.fill_rect(Rect2i(size.x / 2 - 1, 0, 2, size.y), clear)
	img.fill_rect(Rect2i(0, size.y / 2 - 1, size.x, 2), clear)
	return img


# ---------------------------------------------------------------- 工具

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x - ORIGIN.x, y - ORIGIN.y, w, h).intersection(Rect2i(Vector2i.ZERO, TEX_SIZE))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


## 1px 深色描边,让物件从墙面上分开。
func _outlined(img: Image, x: int, y: int, w: int, h: int, fill: Color) -> void:
	_rect(img, x, y, w, h, STAIN)
	_rect(img, x + 1, y + 1, w - 2, h - 2, fill)
