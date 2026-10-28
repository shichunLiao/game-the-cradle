"""塔1·出生地 —— 教学塔,垂直版(2026-10-12,用户选「塔1 改垂直」,和塔2~4 统一)。

「千万别往亮的地方走。」→ 出口:「姐姐以前修过这种门。……门禁我撬不开,但缝我钻得过。」

和塔2~4 一样从下往上爬五段,每段左右交替。每个守卫只教一件事,旁边一定有一条安全的替代路线:
  1 一楼(往东)  跳 1/2/3 格箱子、蹲着钻缝;A 暗区等时机;B 地面开洞掉进地下通道绕过
  2 二楼(往西)  C 爬上头顶夹层(暗)绕过;D 钻通风管绕过(不钻就躲暗角等他背身)
  3 三楼(往东)  关中旁白;E 从台阶跳上头顶吊桥(暗)绕过;F 走廊没有暗区,只有两个柜子
  4 四楼(往西)  **新:丢扣件**。暗吊桥上捡第一颗扣件(之前不会丢);下面的扫视守卫守着出口梯子。
                可以等他走远,也可以站在桥西头把扣件丢到身后的桥面上,把他引到桥下(Ryn 低声提示一句)
  5 顶楼(往东)  G 综合:暗区 + 柜子 + 矮缝,台阶爬上出口

旧版(200×62 之字形四层)留在 git 历史里(提交 de05b47 之前)。
"""
from level_dsl import Level

SCENE = "tower_1_birthplace"
AMBIENT = "tower_1"
DECOR = "birthplace"   # 背景道具:铁婴儿床、瓦砾、熄了的灯(tools/level_builder/decor.py)
SKYLINE = {"focus_tower": 1, "pan": 0.0, "horizon": 0.5}   # 窗外:下一座是精炼塔
# 塔1 一开始还不会丢扣件:四楼吊桥上捡到第一颗才学会
ROOT = {"throw_unlocked": False, "next_scene": "res://src/levels/pipeline_bridge.tscn"}

W, H = 120, 184
# 2026-10-12 谜题房:顶楼前插了一段(S4..S5),下面四段整体往下挪 28 行
GROUND, S1, S2, S3, S4, S5 = 174, 146, 118, 90, 62, 34


def plat(lv, x0, x1, row, thick=1):
    lv.solid(x0, row, x1, row + thick - 1)


def make() -> Level:
    lv = Level("tower_1", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(0, 0, W - 1, 1)
    lv.solid(1, GROUND, W - 2, H - 1)               # 一楼地面以下全实,地道另挖
    for s in (S1, S2, S3, S4, S5):
        lv.solid(1, s, W - 2, s + 1)

    # ================= 1 一楼(往东)=================
    lv.start(4, GROUND)
    # 跳跃教学:1 格、2 格、3 格高的箱子
    lv.solid(10, GROUND - 1, 12, GROUND - 1)
    lv.solid(16, GROUND - 2, 18, GROUND - 1)
    lv.solid(22, GROUND - 3, 24, GROUND - 1)
    lv.style(10, GROUND - 3, 24, GROUND - 1, "crate")   # 本来就是箱子
    # 钻缝教学:矮天花板,底下是暗区
    lv.solid(28, S1 + 2, 40, GROUND - 5)
    lv.low(28, 40, GROUND - 4)
    lv.shade(28, GROUND - 3, 40, GROUND - 1)
    lv.checkpoint(44, GROUND)
    # A:暗区等时机。两头各一块暗区
    lv.shade(46, GROUND - 6, 51, GROUND - 1)
    lv.guard(52, 72, GROUND, style="steady", name="GuardA")
    lv.shade(74, GROUND - 6, 78, GROUND - 1)
    # B:地下通道。地面开一个 3 格的洞掉下去,通道全暗,东头爬梯子上来
    lv.clear(82, GROUND, 84, GROUND + 4)
    lv.clear(82, GROUND + 1, 110, GROUND + 4)
    lv.shade(82, GROUND + 1, 110, GROUND + 4)
    lv.ladder(109, GROUND, GROUND + 5)
    lv.guard(86, 104, GROUND, style="scanner", name="GuardB")
    lv.checkpoint(113, GROUND)
    lv.ladder(116, S1, GROUND)

    # ================= 2 二楼(往西)=================
    lv.checkpoint(112, S1)
    # C:头顶夹层。梯子上去,夹层整段在暗处,从西头跳下
    MEZZ = S1 - 6
    lv.ladder(104, MEZZ, S1)
    plat(lv, 70, 103, MEZZ)
    lv.shade(70, MEZZ - 4, 103, MEZZ - 1)
    lv.guard(72, 100, S1, style="loiterer", name="GuardC")
    lv.checkpoint(66, S1)
    # D:通风管。管口在守卫巡逻线两头外面,钻过去就绕开了;不钻就躲在东头暗角等他背身
    lv.vents((62, S1), (24, S1))
    lv.guard(30, 58, S1, style="steady", facing=-1, name="GuardD")
    lv.shade(57, S1 - 6, 63, S1 - 1)
    lv.shade(18, S1 - 6, 26, S1 - 1)
    lv.checkpoint(12, S1)
    lv.ladder(6, S2, S1)

    # ================= 3 三楼(往东)=================
    lv.checkpoint(9, S2)
    # 关中旁白(2026-10-11 用户定稿;叙事脚本.md 塔1 没写关中句):爬到一半
    lv.story(4, S2 - 3, 14, S2 - 1, "「这个塔这么高，我要怎么找到她啊」")
    # E:头顶吊桥。两级台阶跳上去,吊桥在暗处,守卫在下面走;东头跳下
    plat(lv, 14, 18, S2 - 3)
    plat(lv, 20, 24, S2 - 6)
    CW3 = S2 - 8
    plat(lv, 26, 70, CW3)
    lv.shade(26, CW3 - 4, 70, CW3 - 1)
    lv.guard(30, 68, S2, style="scanner", name="GuardE")
    # F:柜子。走廊没有暗区,只有两个柜子
    lv.guard(76, 106, S2, style="steady", name="GuardF")
    lv.locker(84, S2)
    lv.locker(98, S2)
    lv.checkpoint(110, S2)
    lv.ladder(114, S3, S2)

    # ================= 4 四楼(往西):丢扣件 =================
    # 暗吊桥只盖住守卫巡逻线的东半段,离地 6 格(守卫在桥下走得过去)。桥上捡第一颗扣件 = 学会丢。
    # 下面的扫视守卫在出口梯子这头来回;吊桥西头跳下来、走 23 格到梯子 —— 他在西半段时看得见你。
    # 两个办法:等他走到桥下那头(扫视型到端点还要左右看);或者站在桥西头,把扣件丢到身后的桥面上,
    # 他会走到桥下去查看 —— 这时跳下去走掉,他背后看不见(查看时的锥只有 140px)。
    lv.checkpoint(110, S3)
    plat(lv, 100, 104, S3 - 3)
    CW4 = S3 - 6
    plat(lv, 30, 98, CW4)
    lv.shade(30, CW4 - 4, 98, CW4 - 1)
    lv.bolt(92, CW4)
    lv.story(86, CW4 - 3, 96, CW4 - 1, "「我有一些螺母，扔出应该能吸引他们的注意吧」")
    lv.guard(14, 48, S3, style="scanner", name="GuardT")
    lv.shade(3, S3 - 6, 13, S3 - 1)                     # 梯子脚边的暗角(规则:必经之路上的守卫要有地方躲)
    lv.ladder(6, S4, S3)

    # ================= 谜题房「断桥」(2026-10-12):教「拆东西能改变场景,也会把人引过来」 =================
    # 从四楼的梯子(x 6)上来,落在下层。往东走、爬梯子(x 72)上东边的上层平台;西边上层平台(出口梯子 x 10)
    # 隔着 12 格的缺口过不去。缺口那头的吊桥被链条拉着竖起来,链条锚在这边(x 56)。长按 E 拆锚 → 桥倒下来,
    # 砸下来那一声很响:西平台上的守卫会走过来查看(走上桥)—— 躲在桥头的暗角里等他走回去,再跟在他身后过桥;
    # 他在西头掉头时躲进柜子,等他走开再去梯子。掉进缺口只会落回下层,爬梯子再来。
    U = S4 - 13                                          # 上层平台(第 49 行)
    lv.checkpoint(10, S4)
    plat(lv, 1, 40, U, thick=2)                          # 西边上层平台(出口那边)
    plat(lv, 53, W - 2, U, thick=2)                      # 东边上层平台
    lv.solid(77, U + 2, W - 2, S4 - 1)                   # 下层东半截是实心的:下层只是一间房
    lv.ladder(72, U, S4)
    lv.checkpoint(66, U)
    chain = lv.panel("chain", 56, U)
    lv.drawbridge(41, 52, U, chain, hinge="left", noise=480)   # 很响:西平台上哪里都听得见
    lv.shade(53, U - 6, 58, U - 1)                       # 桥头暗角:桥砸下来,守卫走上桥来看,躲这里
    lv.guard(16, 36, U, style="steady", name="GuardP")
    lv.locker(30, U)
    lv.shade(3, U - 6, 12, U - 1)                         # 出口梯子边的暗角
    lv.ladder(10, S5, U)
    lv.window(96, U - 9, 99, U - 4)

    # ================= 5 顶楼(往东):综合 =================
    lv.checkpoint(10, S5)
    lv.shade(8, S5 - 6, 14, S5 - 1)
    # G:综合。暗区 → 柜子 → 暗区 → 矮缝
    lv.guard(22, 70, S5, style="scanner", name="GuardG", sense="hearing")
    # G4(2026-10-14 用户定稿):全游戏第一个「听」的守卫。从梯子上来站进暗角就出字 —— 在安全的地方先教
    lv.story(4, S5 - 3, 16, S5 - 1, "「他的头盔怎么连条缝都没有。」")
    lv.locker(40, S5)
    lv.shade(52, S5 - 6, 58, S5 - 1)
    lv.solid(76, 2, 90, S5 - 5)
    lv.low(76, 90, S5 - 4)
    lv.shade(76, S5 - 3, 90, S5 - 1)
    lv.checkpoint(93, S5)
    plat(lv, 96, 100, S5 - 3)
    plat(lv, 102, 106, S5 - 6)
    plat(lv, 108, 117, S5 - 9)
    lv.exit(113, S5 - 9)
    # 塔外的景:顶楼出口后面的墙塌了一大块;碰到出口时镜头拉远看全景(出塔句同时出来)
    lv.window(88, 2, 117, S5 - 1, kind="breach")
    lv.vista(108, S5 - 12, 117, S5 - 10, zoom=1.0, offset=(-160, -140))
    # 中间几层墙上的窗
    lv.window(100, GROUND - 9, 103, GROUND - 4)
    lv.window(56, S2 - 18, 59, S2 - 13)
    lv.window(104, S3 - 9, 107, S3 - 4)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(98, S3 - 6, S3, lv.panel("chain", 93, S3))   # 收折梯:死路 y90 x27-99
    lv.ladder(20, S2 - 6, S2)   # 铁卷门挡住梯子口:死路 y118 x19-70
    lv.shutter(21, S2 - 5, S2 - 1, lv.panel("control", 28, S2), optional=True)
    lv.ladder(70, S1 - 6, S1)   # 门禁守着梯子口(绿灯时爬上去):死路 y146 x67-103
    lv.gate(69, 71, S1, 5, red=2.6, green=2.8, phase=0.45)
    lv.fold_ladder(110, GROUND, GROUND + 5, lv.panel("chain", 105, GROUND + 5))   # 收折梯:死路 y179 x82-110
    return lv
