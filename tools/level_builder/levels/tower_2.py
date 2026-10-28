"""塔2·能源精炼 —— 垂直的塔:从炉底一路爬到塔顶。

「这种扣件……她教过我。拧三下,再撬。」→ 出口:「她还在下面，再去别的塔找找线索吧。」
主题:拆。栅栏拆了能过,盖板拆了能让站在上面的守卫掉下去。

五段(由下往上),每段约 28 行:
  1 熔炉大厅   地面守卫 A;错落平台往上跳,或者西边爬梯上暗吊桥、拆栅栏过去
  2 竖井侧室   地面守卫 B(东边有暗吊桥绕过);西平台守卫 C 站在盖板上;暗室里一条通风管直通上一段
  3 断层楼板   中层楼板有缺口 —— 窄的跑起来跳,宽的只能掉下暗室再爬上来;守卫 D、E;尽头一道栅栏
  4 吊桥网     四层交错的吊桥,梯子相连;守卫 F、G(G 脚下是盖板)
  5 登顶       错落平台往上跳,顶上哨兵 H 和一个柜子,出口在最高处
"""
from level_dsl import Level

SCENE = "tower_2_refinery"
AMBIENT = "tower_2"
BLOCK_STYLE = "plate"   # 铆接钢板
DECOR = "refinery"      # 储罐、油桶、阀门、压力表、立管
SKYLINE = {"focus_tower": 2, "pan": 0.0, "horizon": 0.5}   # 窗外:下一座是登记塔
ROOT = {"next_scene": "res://src/levels/sky_bridge.tscn"}   # 2026-10-12 塔与塔之间加了一段塔外
W, H = 120, 202
# 地面与段间楼板的顶面行。2026-10-12 谜题房:登顶前插了一段(S4..S5),下面四段整体往下挪 28 行
GROUND, S1, S2, S3, S4, S5 = 198, 167, 139, 111, 65, 37   # 2026-10-15 为二段跳加高(用户:天花板太低):顶部 +3、吊桥网每 9 行一层、一楼 +3,走的地方头顶都 ≥ 8 行


def plat(lv, x0, x1, row, thick=1):
    lv.solid(x0, row, x1, row + thick - 1)


def stairs(lv, x0, floor, count, w=6, rise=3, gap=2, step=1):
    """错落平台:从 (x0, floor) 起,每块宽 w、比上一块高 rise 行、中间隔 gap 列。step=±1 是方向。"""
    x = x0
    row = floor
    out = []
    for _ in range(count):
        row -= rise
        a, b = (x, x + w - 1) if step > 0 else (x - w + 1, x)
        plat(lv, a, b, row)
        out.append((a, b, row))
        x = (b + gap + 1) if step > 0 else (a - gap - 1)
    return out


def make() -> Level:
    lv = Level("tower_2", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(0, 0, W - 1, 1)                       # 塔顶穹顶
    # 塔身外壳(两侧外墙、穹顶)保持石砌;里面的结构换成这座塔的材质(2026-10-12 塔内换装)
    for (x0, y0, x1, y1) in ((0, 0, 0, H - 1), (W - 1, 0, W - 1, H - 1), (0, 0, W - 1, 1)):
        lv.style(x0, y0, x1, y1, "masonry")
    lv.solid(1, GROUND, W - 2, H - 1)
    for s in (S1, S2, S3, S4, S5):
        lv.solid(1, s, W - 2, s + 1)

    # ================= 1 熔炉大厅 =================
    lv.start(4, GROUND)
    lv.shade(12, GROUND - 6, 16, GROUND - 1)
    lv.guard(20, 54, GROUND, style="steady", name="GuardA")
    lv.locker(38, GROUND)
    # 错落平台往东上升,一直到东边台子
    stairs(lv, 58, GROUND, 6, w=6, rise=3, gap=2)
    plat(lv, 106, 117, GROUND - 21)                 # 东台子(第 125 行)
    lv.shade(108, GROUND - 27, 117, GROUND - 22)
    # 另一条路:西边爬梯上暗吊桥,拆栅栏过去,再跳到平台链上
    lv.ladder(8, GROUND - 18, GROUND)
    plat(lv, 2, 56, GROUND - 18)                    # 吊桥(第 128 行;东头掉下去落在守卫 A 巡逻线外)
    lv.shade(2, GROUND - 24, 46, GROUND - 19)
    lv.fence(36, GROUND - 21, GROUND - 19)
    lv.checkpoint(110, GROUND - 21)
    lv.ladder(114, S1, GROUND - 21)

    # ================= 2 竖井侧室 =================
    lv.checkpoint(110, S1)
    lv.guard(74, 104, S1, style="scanner", facing=-1, name="GuardB")
    lv.shade(66, S1 - 6, 70, S1 - 1)
    # 东边暗吊桥:梯子上去,在守卫头顶往西走
    lv.ladder(116, S1 - 10, S1)
    plat(lv, 70, 117, S1 - 10)
    lv.shade(72, S1 - 16, 115, S1 - 11)
    # 竖井梯子到西平台
    lv.ladder(58, S1 - 14, S1)
    plat(lv, 16, 57, S1 - 14)                       # 西平台(第 104 行;西端托住上楼的梯子)
    lv.hatch(38, 41, S1 - 14)
    # 叙事脚本.md 塔2 关键事件:拆地板 → 守卫跌落。真有守卫掉下去才说
    lv.fall_line("「啊，对不起。……不对，我干嘛道歉呢。」")
    lv.guard(24, 54, S1 - 14, style="loiterer", name="GuardC")
    # 西平台下面是暗室;暗室里一条通风管直通第 3 段
    lv.shade(1, S1 - 8, 56, S1 - 1)
    lv.vents((6, S1), (6, S2))
    lv.checkpoint(26, S1 - 14)
    lv.ladder(20, S2, S1 - 14)

    # ================= 3 断层楼板 =================
    MID = S2 - 10                                    # 中层楼板(第 80 行)
    lv.checkpoint(22, S2)                            # 梯子 20 上来、梯子 24 上去之间(2026-10-13 体检:原来 16 碰不到)
    # 线索链(2026-10-12):上到第 3 段,墙上的喇叭播调配广播。之后捡到的工装上是 V-17 —— 就在这批里
    lv.broadcast(10, S2 - 6, "〔广播〕V-11 到 V-20 号，零点到坑口转运站集合。", trigger=(4, S2 - 3, 22, S2 - 1))
    lv.ladder(24, MID, S2)
    plat(lv, 1, 117, MID, thick=2)
    lv.clear(31, MID, 33, MID + 1)                  # 窄缺口:跑起来跳过去
    lv.clear(51, MID, 56, MID + 1)                  # 宽缺口:只能掉下去
    lv.shade(40, S2 - 8, 70, S2 - 1)                # 下层暗室
    lv.ladder(36, MID, S2)                          # 掉下窄缺口也能爬回来
    lv.ladder(60, MID, S2)
    lv.guard(72, 104, S2, style="loiterer", name="GuardE", sense="hearing")
    lv.guard(64, 98, MID, style="scanner", name="GuardD")
    lv.shade(62, MID - 6, 66, MID - 1)
    lv.fence(104, MID - 3, MID - 1)
    lv.checkpoint(44, MID)
    lv.ladder(112, S3, MID)

    # ================= 4 吊桥网 =================
    # 吊桥从下往上每 9 行一层:C1 102 / C2 93 / C3 84 / C4 75,每层头顶空 8 行,二段跳(85px)跳得满
    C1, C2, C3, C4 = S3 - 9, S3 - 18, S3 - 27, S3 - 36
    lv.checkpoint(110, S3)                           # 梯子 112 上来、梯子 108 上去之间(原来 104 碰不到)
    lv.ladder(108, C1, S3)
    plat(lv, 72, 112, C1)
    lv.shade(90, C1 - 5, 112, C1 - 1)
    lv.ladder(74, C2, C1)
    plat(lv, 40, 78, C2)
    lv.guard(44, 70, C2, style="scanner", name="GuardF")
    lv.shade(40, C2 - 5, 48, C2 - 1)
    lv.locker(58, C2)
    lv.ladder(42, C3, C2)
    plat(lv, 6, 48, C3)
    lv.shade(6, C3 - 5, 30, C3 - 1)
    lv.ladder(48, C4, C3)
    plat(lv, 48, 104, C4)
    lv.hatch(70, 73, C4)
    lv.guard(56, 96, C4, style="steady", name="GuardG")
    lv.shade(49, C4 - 3, 54, C4 - 1)
    lv.checkpoint(52, C4)
    lv.ladder(100, S4, C4)

    # ================= 谜题房「蒸汽廊」(2026-10-12):拆阀门放蒸汽,趁白汽罩着走过哨兵 =================
    # 从吊桥网的梯子(x 100)上来,落在下层,往西走到头爬梯子(x 6)上蒸汽廊。廊上两个哨兵面朝西站着不动、
    # 没有暗处 —— 正面走过去一定被看见。墙上两个阀门:拧开(长按 E)白汽罩住哨兵那一段 6 秒,算暗处;
    # 阀门离哨兵都在他看得到的范围外(17 / 22 格)。第一团汽里走过哨兵 1,到他背后拧第二个阀门,再走过哨兵 2,
    # 出口梯子(x 104)在哨兵 2 背后。汽会散、阀门会自己关上,可以再拧;别跑(跑步声会把哨兵引过来)。
    U = S4 - 13                                          # 蒸汽廊(第 49 行)
    lv.checkpoint(96, S4)
    lv.guard(40, 80, S4, style="loiterer", name="GuardV1", sense="hearing")   # 下层:走廊上一个守卫,两头暗角、中间一个柜子
    lv.shade(30, S4 - 6, 35, S4 - 1)
    lv.locker(60, S4)
    lv.shade(84, S4 - 6, 89, S4 - 1)
    plat(lv, 1, W - 2, U, thick=2)
    lv.ladder(6, U, S4)
    lv.checkpoint(10, U)
    lv.guard(50, 50, U, style="steady", facing=-1, name="GuardS1")
    lv.steam_valve(33, U, cloud=(36, U - 6, 54, U - 1), duration=6.0)
    lv.guard(94, 94, U, style="steady", facing=-1, name="GuardS2")
    lv.steam_valve(72, U, cloud=(80, U - 6, 98, U - 1), duration=6.0)
    lv.ladder(104, S5, U)

    # ================= 5 登顶 =================
    lv.checkpoint(104, S5)
    stairs(lv, 92, S5, 5, w=6, rise=3, gap=2, step=-1)
    plat(lv, 8, 52, S5 - 18)                        # 顶台(第 16 行)
    lv.shade(40, S5 - 24, 50, S5 - 19)
    lv.guard(12, 36, S5 - 18, style="sentry", name="GuardH", sense="hearing")
    lv.locker(30, S5 - 18)
    lv.ladder(44, S5 - 27, S5 - 18)
    # 叙事脚本.md 塔2 出塔:捡到一小片工装布料。放在哨兵身边的暗角里、最后一架梯子脚下 ——
    # 躲着等哨兵转身时捡到;爬梯 + 走到出口约 4 秒,这句念完才轮到出塔句
    # 2026-10-12 线索链:工装是叠好的(Vera 留给妹妹的),上面的工号 V-17 对上前面的调配广播
    lv.pickup(48, S5 - 18, "「这不是她的工装V-17吗。」")
    plat(lv, 44, 70, S5 - 27)                       # 最高处(第 10 行,头顶空 8 行)
    lv.exit(62, S5 - 27)
    # 塔外的景:最高处后面的墙塌了;碰到出口时镜头拉远
    lv.window(24, 2, 110, S5 - 19, kind="breach")
    lv.vista(56, S5 - 30, 69, S5 - 28, zoom=1.0, offset=(0, -100))
    lv.window(96, S1 - 9, 99, S1 - 4)
    lv.window(20, S3 - 9, 23, S3 - 4)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(6, S4 + 19, S3, lv.panel("chain", 11, S3))   # 收折梯:死路 y111 x1-107
    lv.ladder(118, S3, S2)   # 铁卷门挡住梯子口:死路 y139 x61-118
    lv.shutter(117, S2 - 8, S2 - 1, lv.panel("control", 110, S2), optional=True)
    lv.ladder(1, S2, S1)   # 门禁守着梯子口(绿灯时爬上去):死路 y167 x1-57
    lv.gate(1, 2, S1, 5, red=2.6, green=2.8, phase=0.45)
    lv.fold_ladder(117, S1 + 10, GROUND, lv.panel("chain", 112, GROUND))   # 收折梯:死路 y198 x64-118
    lv.ladder(50, S2 - 10, S2)   # 铁卷门挡住梯子口:死路 y139 x25-50
    lv.shutter(49, S2 - 8, S2 - 1, lv.panel("control", 42, S2), optional=True)
    return lv
