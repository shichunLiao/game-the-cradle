"""塔4·军事防御 —— 垂直的塔,主题是「探照灯」:灯照得穿暗处,只有柜子挡得住。

「千万别出声。嘘。」→ 出口:「有危险物质，非工作人员禁止靠近。看来她一定就在那下面了。」

五段(由下往上):
  1 营区       探照灯 A 扫院子,两个柜子在它的扫动线上;哨兵 A;东边台阶(探照灯 B 扫台阶)
  2 瞭望梯     地面守卫 B;西边三层平台靠梯子相连,探照灯 C 从上往下扫 —— 平台上有柜子
  3 军械库     吊桥上两个守卫;地面一段货箱夹出来的矮缝(守卫看不进来);东边探照灯 D 扫地面
  4 城垛       高处窄道,缺口要跑起来跳(跑步声大);哨兵 E;探照灯 E 扫城垛
  5 指挥台     两盏探照灯各扫半段台阶(中间一级喘口气,每半段一个柜子);顶上哨兵 F;出口
"""
from level_dsl import Level

SCENE = "tower_4_military"
AMBIENT = "tower_4"
BLOCK_STYLE = "bunker"   # 浇筑混凝土
DECOR = "military"       # 沙袋、弹药箱、枪架、铁丝网、警示牌
SKYLINE = {"focus_tower": 4, "pan": 0.0, "horizon": 0.5}   # 窗外:中央高塔和坑口
ROOT = {"next_scene": "res://src/levels/pit_descent.tscn"}   # 2026-10-11 塔4 和坑底之间加了下行关
W, H = 120, 187
# 2026-10-12 谜题房:指挥台前插了一段(S4..S5),下面四段整体往下挪 28 行
GROUND, S1, S2, S3, S4, S5 = 183, 155, 118, 90, 62, 34   # 2026-10-15:S1 以下整体下移 9 行,瞭望梯三层平台每层头顶 8 行(用户:要能二段跳)


def plat(lv, x0, x1, row, thick=1):
    lv.solid(x0, row, x1, row + thick - 1)


def stairs(lv, x0, floor, count, w=6, rise=3, gap=2, step=1):
    x, row = x0, floor
    for _ in range(count):
        row -= rise
        a, b = (x, x + w - 1) if step > 0 else (x - w + 1, x)
        plat(lv, a, b, row)
        x = (b + gap + 1) if step > 0 else (a - gap - 1)
    return row, x


def make() -> Level:
    lv = Level("tower_4", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(0, 0, W - 1, 1)
    # 塔身外壳(两侧外墙、穹顶)保持石砌;里面的结构换成这座塔的材质(2026-10-12 塔内换装)
    for (x0, y0, x1, y1) in ((0, 0, 0, H - 1), (W - 1, 0, W - 1, H - 1), (0, 0, W - 1, 1)):
        lv.style(x0, y0, x1, y1, "masonry")
    lv.solid(1, GROUND, W - 2, H - 1)
    for s in (S1, S2, S3, S4, S5):
        lv.solid(1, s, W - 2, s + 1)

    # ================= 1 营区 =================
    lv.start(4, GROUND)
    lv.sweep(22, GROUND - 18, 42, 18, period=6.0, phase=0.0)
    lv.locker(34, GROUND)
    lv.locker(56, GROUND)
    # 2026-10-14 探照灯时序检查:柜子 34 → 56 隔 22 格,算上停下来按 E 的时间,用走的来不及(要按 Shift 跑)。
    # 中间补一个,每段 11 格。加在最后,Locker00 / 01 还是 34 / 56(hiding_check、sweep_check 按名字找)
    lv.locker(45, GROUND)
    lv.guard(68, 72, GROUND, style="sentry", facing=-1, name="GuardA")
    lv.shade(74, GROUND - 6, 77, GROUND - 1)
    top, _ = stairs(lv, 79, GROUND, 4, w=6, rise=3, gap=2)
    plat(lv, 110, 117, top - 3)                       # 台阶顶平台(第 131 行)
    lv.sweep(80, S1 + 2, 26, GROUND - S1 - 2, period=5.0, phase=0.5)
    lv.locker(90, GROUND - 6)                         # 第二级台阶:灯扫满整段台阶,没有它过不去(2026-10-14)
    lv.checkpoint(112, top - 3)
    lv.ladder(114, S1, top - 3)

    # ================= 2 瞭望梯 =================
    lv.checkpoint(110, S1)
    lv.shade(104, S1 - 6, 110, S1 - 1)
    lv.guard(60, 100, S1, style="loiterer", facing=-1, name="GuardB", sense="hearing")
    lv.locker(80, S1)
    lv.shade(58, S1 - 6, 62, S1 - 1)
    lv.shade(50, S1 - 6, 56, S1 - 1)
    P1, P2, P3 = S1 - 9, S1 - 18, S1 - 27              # 146 / 137 / 128,每层头顶空 8 行(原来 7 行一层、顶层离楼板只有 4 行)
    plat(lv, 4, 30, P1)
    plat(lv, 4, 30, P2)
    plat(lv, 4, 30, P3)
    lv.ladder(28, P1, S1)
    lv.ladder(6, P2, P1)
    lv.ladder(28, P3, P2)
    lv.locker(14, P1)
    lv.locker(18, P2)
    lv.locker(16, P3)
    # 灯只扫两头梯子之间(11..25):爬一层梯子要 2 秒多,原来扫到 6 / 32、停在梯子上,爬到一半一定被照到;
    # 顶层原来也没有柜子。每层「梯子口安全 → 等灯 → 躲柜子 → 另一头梯子口」(2026-10-14 探照灯时序检查)
    lv.sweep(11, S2 + 2, 14, S1 - S2 - 2, period=6.5, phase=0.25)
    lv.checkpoint(20, P3)
    lv.ladder(8, S2, P3)

    # ================= 3 军械库 =================
    CW = S2 - 9                                        # 吊桥(2026-10-15 上提 1 行:底下空 8 行,二段跳跳得满)
    lv.checkpoint(10, S2)
    lv.ladder(14, CW, S2)
    plat(lv, 12, 102, CW)
    lv.guard(18, 58, CW, style="steady", name="GuardC", sense="tracking")
    lv.guard(64, 98, CW, style="scanner", facing=-1, name="GuardD")
    # 线索链(2026-10-12,用户定稿 A):Ryn 爬上第 2 段顶层平台(P3)起,C、D 就往巡逻线挨着的两头(58 / 64)
    # 走,停下聊天(两人碰头最多要十几秒,所以提前一层开始);从吊桥下面货箱夹出来的暗缝爬过去
    # (或者在吊桥上躲在 C 身后)才听得到。东边探照灯 D 扫地面,出缝前本来就要在暗处等一下
    lv.guard_chat("GuardC", "GuardD", meet=(58, 64), approach=(1, CW - 3, 63, P3),
                  lines=["0|上个月押下去那个女修理工，\n一路上都在说，会有人来找她。", "1|谁会下坑找人啊。", "0|也对。"],
                  hear=240)
    # 吊桥下面一段货箱:箱子顶着吊桥,底下留 40px 的矮缝(守卫在吊桥上看不进来)
    lv.solid(40, CW + 1, 62, S2 - 5)
    lv.low(40, 62, S2 - 4)
    lv.style(40, CW + 1, 62, S2 - 4, "crate")         # 本来就是货箱
    lv.shade(40, S2 - 3, 62, S2 - 1)
    lv.sweep(66, CW + 2, 36, S2 - CW - 2, period=5.5, phase=0.6)
    lv.locker(84, S2)
    plat(lv, 104, 117, S2 - 16)                        # 东边平台(第 74 行)
    lv.ladder(112, S2 - 16, S2)
    lv.checkpoint(108, S2 - 16)
    lv.ladder(106, S3, S2 - 16)

    # ================= 4 城垛 =================
    WALK = S3 - 9                                      # 城垛走道(第 53 行)
    lv.checkpoint(105, S3)                             # 梯子 106 上来往西(2026-10-13 体检:原来 108 在身后)
    # 关中旁白(2026-10-11 用户定稿):爬上城垛那一层
    lv.story(100, S3 - 3, 116, S3 - 1, "「她之前经过过这里吗，貌似有点她留下的痕迹？」")
    lv.solid(84, WALK + 1, 94, S3 - 1)                  # 挡住地面的墙,只能从上面走
    plat(lv, 101, 104, S3 - 3)                         # 台阶(不在走道正下方,头顶有空)
    plat(lv, 96, 99, S3 - 6)
    plat(lv, 30, 94, WALK)
    lv.clear(70, WALK, 72, WALK)                        # 缺口:要跑起来跳
    lv.clear(48, WALK, 50, WALK)
    # 哨兵站在 40 原地转身;身边暗角,等他朝西时从他身后溜到梯子(x 32)
    lv.guard(40, 40, WALK, style="sentry", facing=1, name="GuardE")
    lv.shade(36, WALK - 6, 43, WALK - 1)
    lv.locker(60, WALK)
    lv.locker(76, WALK)                                 # 缺口东边:从东头进灯底下,先在这里让灯扫过去(2026-10-14)
    lv.sweep(52, S4 + 2, 40, WALK - S4 - 2, period=6.0, phase=0.3)
    lv.checkpoint(88, WALK)
    lv.ladder(32, S4, WALK)

    # ================= 谜题房「配电室」(2026-10-12):断电 + 通风口 + 吊桥 =================
    # 从城垛的梯子(x 32)上来,落在下层的院子西头。院子很亮:两盏探照灯从上层平台底下扫,东头梯子(x 112)
    # 前站着技工守卫,没有暗处 —— 亮着过不去。院子西头的管口(x 36)螺栓封着,拆开钻进去是配电室(封死的
    # 小屋)。拆配电箱 → 灯全灭、院子变暗;技工往西走到电闸(x 44)去修,修 6 秒来电。趁黑钻回来、过院子、
    # 爬东头梯子上上层平台;再拆链条锚(x 60)放下吊桥,过桥到西边平台,爬出口梯子(x 34)。
    U = S4 - 13                                          # 上层平台(第 49 行)
    plat(lv, 1, 44, U, thick=2)                          # 西边平台(出口)
    plat(lv, 57, W - 2, U, thick=2)                      # 东边平台
    lv.solid(27, U + 2, 27, S4 - 1)                      # 配电室(1..26,封死)
    lv.checkpoint(38, S4)
    lv.vents((36, S4), (16, S4), cover="a")
    sa = len(lv.sweeps)
    lv.sweep(40, U + 2, 36, S4 - U - 2, period=4.6, phase=0.0)
    sb = len(lv.sweeps)
    lv.sweep(112, U + 2, -36, S4 - U - 2, period=4.6, phase=0.5)
    lv.guard(100, 110, S4, style="steady", facing=-1, name="GuardT")   # 技工
    # 电闸在 44(梯子口 32、管口 36 的东边 —— 守卫查看时不走过梯子口,放在西边他到不了)
    lv.fuse_box(8, S4, blackout=(28, U + 2, W - 2, S4 - 1), technician="GuardT", repair=(44, S4),
                sweeps=[sa, sb], repair_time=6.0, backup=25.0)
    # 院子顶上(东边平台底下)两盏罩灯:接在配电箱上,断电时和探照灯一起灭(2026-10-13 精装修)
    lv.prop("cage_lamp:lit", 70, U + 2, 8, 18)
    lv.prop("cage_lamp:lit", 92, U + 2, 8, 18)
    lv.ladder(112, U, S4)
    lv.checkpoint(108, U)
    chain = lv.panel("chain", 60, U)
    lv.drawbridge(45, 56, U, chain, hinge="left", noise=260)
    lv.shade(3, U - 6, 12, U - 1)
    lv.shade(28, U - 6, 40, U - 1)
    lv.ladder(34, S5, U)

    # ================= 5 指挥台 =================
    lv.checkpoint(34, S5)
    top, nx = stairs(lv, 38, S5, 6, w=6, rise=3, gap=2)
    plat(lv, nx - 3 + 3, 117, top - 3)                  # 顶上平台
    # 两盏灯从穹顶往下照,光柱一直到最低一级台阶(第 31 行),各扫半段台阶;中间那一级(62..67)两盏都照不到。
    # 2026-10-14 探照灯时序检查:原来两盏各扫 30 格、交叠在中间,一起往同一边扫 —— 夹在两盏中间的空档
    # 跑得比人快,加几个柜子都过不去。改成各扫 18 格,每半段一个柜子
    lv.sweep(40, 4, 18, S5 - 3 - 4, period=5.0, phase=0.0)
    lv.sweep(92, 4, -18, S5 - 3 - 4, period=5.0, phase=0.5)
    lv.locker(48, S5 - 6)                               # 第二级台阶
    lv.locker(80, S5 - 18)                              # 第六级台阶
    lv.locker(nx + 4, top - 3)
    lv.guard(100, 100, top - 3, style="sentry", facing=-1, name="GuardF")
    lv.shade(96, top - 9, 104, top - 4)
    # 叙事脚本.md 塔4 出塔·靠近坑口:风从下方上来,带黑雾感
    lv.pit_wind(105, 109, top - 3, rise_tiles=7)
    lv.exit(112, top - 3)
    # 塔外的景:指挥台后面整片敞着;碰到出口时镜头拉远 —— 第一次看见中央高塔和坑口的紫光
    lv.window(60, 2, 117, top + 6, kind="breach")
    lv.vista(106, top - 6, 117, top - 4, zoom=1.0, offset=(-200, -80))
    # 城垛那一层本来就在外墙上:一大片破口
    lv.window(34, S4 + 2, 80, WALK - 4, kind="breach")
    lv.window(40, S1 - 9, 43, S1 - 4)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(83, S3 - 9, S3, lv.panel("chain", 78, S3))   # 收折梯:掉下去会卡关,修(链条锚在坑里,掉下去的人自己能放梯子出来)
    lv.ladder(111, S5 - 21, S5)   # 铁卷门挡住梯子口:死路 y34 x44-111
    lv.shutter(110, S5 - 20, S5 - 1, lv.panel("control", 103, S5), optional=True)
    lv.ladder(118, S1, GROUND)   # 门禁守着梯子口(绿灯时爬上去):死路 y183 x85-118
    lv.gate(117, 118, GROUND, 5, red=2.6, green=2.8, phase=0.45)
    lv.fold_ladder(1, S5, S4 - 13, lv.panel("chain", 6, S4 - 13))   # 收折梯:死路 y49 x1-33
    lv.ladder(4, S1 - 9, S1)   # 铁卷门挡住梯子口:死路 y155 x1-27
    lv.shutter(5, S1 - 8, S1 - 1, lv.panel("control", 12, S1), optional=True)
    return lv
