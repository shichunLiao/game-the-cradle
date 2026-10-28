"""塔3·人口登记 —— 垂直的塔,主题是「等」:定时门禁、柜子、通风管。

「这是登记表吗，那年他们就是把我漏了。」→ 出口:「缓蚀者？那是什么东西。」

五段(由下往上):
  1 登记大厅   第一道门禁教「等绿灯」;守卫 A 和一个柜子;东边阶梯上楼(或通风管直达楼梯平台)
  2 档案架     一层层书架,梯子相连;地面守卫 B、书架守卫 C;门禁 + 柜子;通风管绕过地面
  3 电梯井     窄井两侧错开的小平台,左右交替往上跳;井中段横着一道门禁;通风管直达井上半段
  4 办公室     门口一道门禁;楼下守卫 D、楼上守卫 E;柜子当掩护
  5 档案库     往上爬到顶;库门门禁 + 哨兵 F
"""
from level_dsl import Level

SCENE = "tower_3_registry"
AMBIENT = "tower_3"
BLOCK_STYLE = "panel"   # 办公墙板
DECOR = "registry"      # 档案矮柜、办公桌、灯管、叫号牌
SKYLINE = {"focus_tower": 3, "pan": 0.0, "horizon": 0.5}   # 窗外:下一座是军事塔
ROOT = {"next_scene": "res://src/levels/scaffold_descent.tscn"}   # 2026-10-12 塔与塔之间加了一段塔外
W, H = 120, 178
# 2026-10-12 谜题房:档案库前插了一段(S4..S5),下面四段整体往下挪 28 行
GROUND, S1, S2, S3, S4, S5 = 174, 146, 118, 90, 62, 34


def plat(lv, x0, x1, row, thick=1):
    lv.solid(x0, row, x1, row + thick - 1)


def stairs(lv, x0, floor, count, w=6, rise=3, gap=2, step=1):
    x, row = x0, floor
    for _ in range(count):
        row -= rise
        a, b = (x, x + w - 1) if step > 0 else (x - w + 1, x)
        plat(lv, a, b, row)
        x = (b + gap + 1) if step > 0 else (a - gap - 1)
    return row


def make() -> Level:
    lv = Level("tower_3", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(0, 0, W - 1, 1)
    # 塔身外壳(两侧外墙、穹顶)保持石砌;里面的结构换成这座塔的材质(2026-10-12 塔内换装)
    for (x0, y0, x1, y1) in ((0, 0, 0, H - 1), (W - 1, 0, W - 1, H - 1), (0, 0, W - 1, 1)):
        lv.style(x0, y0, x1, y1, "masonry")
    lv.solid(1, GROUND, W - 2, H - 1)
    for s in (S1, S2, S3, S4, S5):
        lv.solid(1, s, W - 2, s + 1)

    # ================= 1 登记大厅 =================
    lv.start(4, GROUND)
    lv.shade(8, GROUND - 6, 13, GROUND - 1)
    lv.gate(18, 22, GROUND, 5, red=3.0, green=2.6, phase=0.0)
    plat(lv, 30, 36, GROUND - 2, thick=2)            # 登记台
    # 线索链(2026-10-12):登记台上方的叫号牌停在 17 —— 到档案库看到 V-17 时接上
    lv.prop("number_board:17", 31, GROUND - 8, 24, 10)
    lv.guard(40, 70, GROUND, style="steady", name="GuardA")
    lv.locker(54, GROUND)
    lv.shade(72, GROUND - 6, 76, GROUND - 1)
    stairs(lv, 78, GROUND, 4, w=6, rise=3, gap=2)
    plat(lv, 110, 117, GROUND - 15)                   # 楼梯平台(第 131 行)
    lv.vents((74, GROUND), (114, GROUND - 15))
    lv.checkpoint(115, GROUND - 15)                   # 管口 114 出来、梯子 116 之间(2026-10-13 体检:原来 112 碰不到)
    lv.ladder(116, S1, GROUND - 15)

    # ================= 2 档案架 =================
    lv.checkpoint(112, S1)
    lv.shade(104, S1 - 6, 110, S1 - 1)
    lv.guard(62, 100, S1, style="loiterer", facing=-1, name="GuardB", sense="tracking")
    # G4(2026-10-14 用户定稿):全游戏第一个「追」的守卫。梯子上来(走路线、通风管路线都从 116 上来)就出字;
    # 不说破脚印为什么是紫的 —— 出塔时终端闪「缓蚀者」
    lv.story(104, S1 - 3, 117, S1 - 1, "「他怎么盯着地上看。不对，他是在找我的脚印吗？」")
    lv.gate(40, 43, S1, 5, red=2.8, green=2.4, phase=0.4)
    plat(lv, 4, 36, S1 - 8)                           # 书架 A(第 110 行)
    lv.style(4, S1 - 8, 36, S1 - 8, "shelf")
    lv.ladder(34, S1 - 8, S1)
    lv.locker(16, S1 - 8)
    plat(lv, 20, 70, S1 - 16)                         # 书架 B(第 102 行)
    lv.style(20, S1 - 16, 70, S1 - 16, "shelf")
    lv.ladder(22, S1 - 16, S1 - 8)
    lv.guard(26, 64, S1 - 16, style="scanner", name="GuardC")
    lv.shade(20, S1 - 21, 25, S1 - 17)
    plat(lv, 72, 92, S1 - 18)                         # 书架 C(头顶空 8 行,2026-10-15 为二段跳下移 1 行)
    lv.style(72, S1 - 18, 92, S1 - 18, "shelf")
    lv.vents((112, S1), (68, S1 - 16))
    lv.checkpoint(84, S1 - 18)
    # 关中旁白(2026-10-11 用户定稿):书架 C,走路线和通风管路线都经过这里
    lv.story(74, S1 - 21, 92, S1 - 19, "「让我看看，不过上面应该没写我的名字。」")
    lv.ladder(90, S2, S1 - 18)

    # ================= 3 电梯井 =================
    # 到达在东边(x 90)。守卫 D 在到达点和井口之间来回,柜子在他巡逻线中间。
    # 井在西边(x 40..49):西墙到底、东墙底部留 4 行口子进出。
    # 三段梯子,中间一块休息平台;门禁横在第二段梯子中间 —— 在平台上等绿灯,一口气爬过去。
    # (试过左右交替跳的小平台:同侧上一块挡在头顶,起跳会撞头,真实物理也上不去。)
    lv.checkpoint(90, S2)
    lv.shade(84, S2 - 6, 96, S2 - 1)
    lv.guard(56, 80, S2, style="steady", facing=-1, name="GuardD", sense="hearing")
    lv.locker(68, S2)
    REST, TOPL = S2 - 12, S3 + 5                      # 休息平台(第 78 行)、井顶平台(第 67 行,离楼板 3 行)
    lv.solid(39, S3 + 2, 39, S2 - 1)
    lv.solid(50, S3 + 2, 50, S2 - 5)
    plat(lv, 40, 48, REST)
    plat(lv, 44, 49, TOPL)
    lv.ladder(48, REST, S2)
    lv.ladder(46, TOPL, REST)
    lv.ladder(48, S3, TOPL)
    lv.shade(40, REST - 4, 44, REST - 1)
    lv.gate(40, 49, REST - 3, 6, red=2.4, green=3.0, phase=0.2)
    lv.vents((104, S2), (45, TOPL))

    # ================= 4 办公室 =================
    UP = S3 - 14                                      # 楼上办公室(第 48 行)
    lv.checkpoint(52, S3)
    lv.guard(68, 100, S3, style="loiterer", name="GuardD2")
    lv.solid(30, UP + 2, 30, S3 - 5)                  # 隔墙(留门洞)
    lv.solid(102, UP + 2, 102, S3 - 5)
    lv.gate(100, 104, S3, 5, red=2.6, green=2.6, phase=0.6)
    lv.locker(84, S3)
    lv.shade(106, S3 - 6, 116, S3 - 1)
    plat(lv, 1, 117, UP, thick=2)
    lv.ladder(112, UP, S3)
    lv.checkpoint(108, UP)
    lv.guard(18, 96, UP, style="scanner", facing=-1, name="GuardE")
    lv.locker(76, UP)
    lv.locker(40, UP)
    lv.shade(4, UP - 6, 12, UP - 1)
    lv.ladder(6, S4, UP)

    # ================= 谜题房「控制室」(2026-10-12):通风管网 =================
    # 从办公室的梯子(x 6)上来,落在下层西头。爬梯子(x 40)上维修走廊 —— 往西一道铁卷门(x 32)挡住出口
    # 那边(门旁红灯 = 别处控制的,拆不动)。走廊地上三个管口,站在管口前小地图画出通到哪:
    #   56 → 回到下层西头(白绕一圈);80(螺栓封着)→ 守卫室(有人巡逻,出口在暗角,可以钻回来);
    #   100(螺栓封着)→ 控制室(下层中间一间封死的屋子)。控制室里拆掉控制面板 → 铁卷门卷上去,
    #   钻回走廊,往西过门,爬出口梯子(x 8)。走廊上一个守卫来回,管口边都有暗角;拆盖板有声音。
    U = S4 - 13                                          # 维修走廊(第 49 行)
    lv.checkpoint(10, S4)
    plat(lv, 1, W - 2, U, thick=2)
    lv.ladder(40, U, S4)
    lv.solid(49, U + 2, 49, S4 - 1)                      # 控制室(49..71 之间,封死)
    lv.solid(71, U + 2, 71, S4 - 1)
    lv.checkpoint(62, S4)                                # 控制室:管口 60 出来、面板 64 之间(原来 58 碰不到)
    control = lv.panel("control", 64, S4)
    lv.shutter(32, S5 + 2, U - 1, control)
    lv.checkpoint(44, U)
    lv.guard(60, 112, U, style="steady", name="GuardK", sense="tracking")
    lv.shade(76, U - 6, 84, U - 1)
    lv.shade(96, U - 6, 104, U - 1)
    lv.vents((56, U), (20, S4))                          # 绕回来
    lv.vents((80, U), (100, S4), cover="a")              # 守卫室
    lv.vents((100, U), (60, S4), cover="a")              # 控制室
    lv.guard(76, 112, S4, style="loiterer", name="GuardR")   # 守卫室
    lv.shade(94, S4 - 6, 106, S4 - 1)
    lv.shade(3, U - 6, 14, U - 1)                         # 出口梯子边
    lv.ladder(8, S5, U)
    lv.prop("number_board:17", 90, U - 9, 24, 10)        # 走廊墙上的叫号牌也停在 17

    # ================= 5 档案库 =================
    lv.checkpoint(10, S5)
    top = stairs(lv, 12, S5, 6, w=6, rise=3, gap=2)
    plat(lv, 60, 117, top - 3)                        # 库房平台(接在最后一级台阶旁)
    lv.gate(84, 88, top - 3, 5, red=3.0, green=2.4, phase=0.3)
    # 哨兵:站在 100 原地转身(巡逻范围只占一格),身边一块暗区,等他转身时溜过去
    lv.guard(100, 100, top - 3, style="sentry", facing=-1, name="GuardF")
    lv.shade(96, top - 9, 104, top - 4)
    lv.locker(80, top - 3)
    # 叙事脚本.md 塔3 出塔:终端闪过「缓蚀者」又灭。
    # 2026-10-12 线索链:改成一页档案(工号、体质、去向),挂在库门门禁前 —— 等绿灯的时候正好读完。
    # 原来在出口前 6 格,远景点一拉镜头就看不清,来不及读
    lv.terminal(66, top - 3, "缓蚀者", trigger=(62, 83),
                lines=["工号  V-17 · 维修工", "体质  缓蚀者", "去向  坑底 ███"], screen=(112, 44))
    lv.exit(112, top - 3)
    # 塔外的景:档案库后面的墙塌了;碰到出口时镜头拉远
    lv.window(58, 2, 117, top + 6, kind="breach")
    lv.vista(106, top - 6, 117, top - 4, zoom=1.0, offset=(-160, -80))
    lv.window(96, S1 - 9, 99, S1 - 4)
    lv.window(40, S3 - 10, 43, S3 - 5)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(4, S1 - 8, S1, lv.panel("chain", 9, S1))   # 收折梯:死路 y146 x1-111
    lv.ladder(111, S5 - 21, S5)   # 铁卷门挡住梯子口:死路 y34 x18-111
    lv.shutter(110, S5 - 20, S5 - 1, lv.panel("control", 103, S5), optional=True)
    lv.ladder(40, S2 - 12, S2)   # 门禁守着梯子口(绿灯时爬上去):死路 y118 x40-89
    lv.gate(39, 41, S2, 5, red=2.6, green=2.8, phase=0.45)
    lv.fold_ladder(118, S4 - 13, S4, lv.panel("chain", 113, S4))   # 收折梯:死路 y62 x72-118
    lv.ladder(118, S1, GROUND)   # 铁卷门挡住梯子口:死路 y174 x84-118
    lv.shutter(117, GROUND - 14, GROUND - 1, lv.panel("control", 110, GROUND), optional=True)
    return lv
