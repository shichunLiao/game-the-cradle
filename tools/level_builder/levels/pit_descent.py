"""坑口·下行 —— 从坑口一路往下,下到坑底(Vera 在下面)。塔4 和坑底之间。

叙事脚本.md 终局 A·下行:「蚀开始粘鞋底。Ryn 短暂恍惚,但未失忆。」
——「头好沉……身体快撑不住了。不过我身上好像还有什么东西。」(第一次踩进深蚀时说;原来是坑底的入场句,挪到这里)

蚀:踩在上面走得慢、跑不起来(不能助跑跳);深的那滩第一次踩进去会恍惚。不扣命,不算被发现。

结构:一层层**墙到墙**的吊板,每层只有一个口子(梯子或塌洞),左右交替 —— 每层都得走完,
不会从边上一路掉到底(试过散放的脚手架:路线从吊架边上直接掉过守卫和深蚀)。最后三层是半截的
坑壁平台,从边上往下掉。

四段(由上往下):
  1 坑口     塔4 出来的风台,格栅冒黑雾;吊板 1 上守卫 A(柜子、两头暗角);东头梯子下去
  2 脚手架   吊板 2 第一次碰到蚀(浅:只是走得慢,没有守卫);西头塌洞掉下去;吊板 3 守卫 B;东头梯子
  3 蚀层     吊板 4 中段一滩深蚀:恍惚 + 那句话;西头梯子;吊板 5「蚀池放流」(2026-10-12 谜题):一整池蚀 +
             两盏探照灯 + 四个柜子,排放阀在吊板底下封死的泵房里(拆盖板钻下去);东头塌洞
  4 坑壁     三截坑壁平台,没有守卫,只有黑和蚀;从边上一层层往下掉,到底往东是出口(→ 坑底)
"""
from level_dsl import Level

SCENE = "pit_descent"
AMBIENT = "descent"
DECOR = "descent"      # 背景道具:岩石、被蚀糊住的旧设备、断掉的吊缆(2026-10-12)
SKYLINE = {"focus_tower": 4, "pan": 0.0, "horizon": 0.5}
ROOT_NAME = "PitDescent"
ROOT = {"entry_line": "", "exit_line": "", "next_scene": "res://src/levels/pit_bottom.tscn"}
# 颜色从塔4 的蓝过渡到坑底的紫(坑底:stone 0E0A16、glow 4A3F6B)
BACKDROP = {
    "seed_value": "61",
    "stone_color": "Color(0.0431373, 0.0431373, 0.0784314, 1)",
    "mortar_color": "Color(0.0196078, 0.0196078, 0.0431373, 1)",
    "depth_color": "Color(0.0196078, 0.027451, 0.0509804, 1)",
    "glow_color": "Color(0.290196, 0.247059, 0.419608, 0.12)",
    "layer_darken": "0.34",
    "breaches": "10",
    "arches": "1",
    "slits": "0",
    "niches": "2",
    "pipes": "2",
    "course_every": "0",
}
ATMOSPHERE = {
    "vignette_alpha": "0.56",
    "dust_count": "34",
    "dust_color": "Color(0.290196, 0.247059, 0.419608, 1)",
    "dust_speed": "12.0",
    "seed_value": "61",
}

W, H = 90, 140
RIM, D1, D2, D3, D4, D5, D6, D7, D8, BOTTOM = 12, 22, 34, 46, 58, 72, 86, 100, 116, 136


def plat(lv, x0, x1, row, thick=1):
    lv.solid(x0, row, x1, row + thick - 1)


def make() -> Level:
    lv = Level("pit_descent", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(0, 0, W - 1, 1)
    lv.solid(1, BOTTOM, W - 2, H - 1)
    for d in (D1, D2, D3, D4, D5):
        plat(lv, 1, W - 2, d)                          # 吊板:墙到墙
        lv.style(1, d, W - 2, d, "girder")             # 吊板是钢架(坑壁平台还是石头)

    # ================= 1 坑口 =================
    plat(lv, 1, 30, RIM, thick=2)                      # 风台(走下东头就落在吊板 1 上)
    lv.start(4, RIM)
    lv.pit_wind(22, 29, RIM, rise_tiles=8)             # 接塔4 出口的黑雾
    lv.shade(31, D1 - 6, 40, D1 - 1)
    lv.checkpoint(34, D1)
    lv.guard(46, 76, D1, style="steady", name="GuardA")
    lv.locker(62, D1)
    lv.shade(79, D1 - 6, 88, D1 - 1)
    lv.ladder(84, D1, D2)

    # ================= 2 脚手架 =================
    lv.checkpoint(82, D2)                              # 梯子(84)下来往西走(2026-10-13 体检:原来 86 在身后)
    lv.corrosion(56, 68, D2, drag=0.6, haze=0.3)       # 第一次碰到蚀:浅,只是走得慢(这层没有守卫)
    lv.clear(4, D2, 6, D2)                             # 西头塌洞
    lv.shade(1, D2 - 6, 12, D2 - 1)
    lv.checkpoint(10, D3)
    lv.shade(1, D3 - 6, 14, D3 - 1)
    lv.guard(30, 60, D3, style="scanner", facing=-1, name="GuardB", sense="tracking")
    lv.locker(44, D3)
    lv.shade(58, D3 - 6, 66, D3 - 1)
    lv.ladder(82, D3, D4)

    # ================= 3 蚀层 =================
    lv.checkpoint(80, D4)
    lv.pit_wind(50, 56, D4, rise_tiles=6, grate=False)
    lv.corrosion(30, 40, D4, drag=0.5, haze=1.0)       # 深蚀:恍惚 + 那句话(整层必经)
    lv.haze_line("「头好沉……身体快撑不住了。不过我身上好像还有什么东西。」")
    lv.ladder(3, D4, D5)
    lv.checkpoint(6, D5)
    # ---- 谜题「蚀池放流」(2026-10-12,用户选):吊板 5 整片是一池蚀,两盏探照灯来回扫,池里四个柜子。
    # 蚀里走得只有平时的 1/4:从一个柜子挪到下一个要 8 秒多,灯一定扫到。排放阀在吊板底下一间封死的
    # 泵房里 —— 管口(x 10)螺栓封着,拆开钻下去;拆掉阀门,蚀往中间的格栅(x 46)流下坑,4 秒排干,
    # 地面露出来:柜子之间 2 秒多,算好灯的时间就过得去。排放的声音很大,东头的守卫会走过来看。
    pool = lv.corrosion(14, 78, D5, drag=0.25, haze=0.5, depth=8)
    for x in (26, 40, 54, 68):
        lv.locker(x, D5)
    lv.sweep(14, D4 + 2, 31, D5 - D4 - 2, period=5.6, phase=0.0)
    lv.sweep(78, D4 + 2, -31, D5 - D4 - 2, period=6.2, phase=0.5)
    ROOM = D5 + 9                                      # 泵房地面(第 81 行):吊板 5 底下西头,封死
    lv.solid(1, ROOM, 18, ROOM)
    lv.solid(18, D5 + 1, 18, ROOM)
    lv.shade(1, ROOM - 6, 17, ROOM - 1)
    lv.vents((10, D5), (8, ROOM), cover="a")
    lv.drain(4, ROOM, pools=[pool], grate=46, noise=420)
    lv.guard(66, 80, D5, style="steady", facing=-1, name="GuardP5", sense="tracking")
    lv.shade(64, D5 - 6, 88, D5 - 1)
    lv.clear(84, D5, 86, D5)                           # 东头塌洞

    # ================= 4 坑壁 =================
    plat(lv, 40, W - 2, D6)                            # 坑壁平台 1(西边悬空)
    lv.checkpoint(80, D6)
    lv.corrosion(50, 62, D6, drag=0.6, haze=0.4)
    lv.pit_wind(64, 70, D6, rise_tiles=10, grate=False)
    lv.shade(40, D6 - 6, 48, D6 - 1)
    plat(lv, 1, 60, D7)                                # 坑壁平台 2(东边悬空)
    lv.checkpoint(41, D7)                              # 从平台 1 西头掉下来落在 39,往东走
    lv.corrosion(44, 56, D7, drag=0.6, haze=0.5)
    lv.shade(1, D7 - 6, 16, D7 - 1)
    plat(lv, 30, W - 2, D8)                            # 坑壁平台 3(西边悬空)
    lv.checkpoint(59, D8)                              # 从平台 2 东头掉下来落在 61,往西走
    lv.corrosion(34, 48, D8, drag=0.6, haze=0.5)
    lv.pit_wind(50, 58, D8, rise_tiles=8, grate=False)
    lv.checkpoint(31, BOTTOM)                          # 从平台 3 西头掉下来落在 29,往东走
    lv.corrosion(60, 78, BOTTOM, drag=0.6, haze=0.6)   # 坑底:蚀铺满
    lv.pit_wind(4, 20, BOTTOM, rise_tiles=12, grate=False)
    lv.pit_wind(64, 76, BOTTOM, rise_tiles=10, grate=False)
    lv.shade(1, BOTTOM - 8, 22, BOTTOM - 1)
    lv.exit(84, BOTTOM)
    # 塔外的景:坑口上面就是夜空;走上风台时镜头拉远,回头看一眼四座塔
    lv.window(1, 2, 88, D1 - 1, kind="breach")
    lv.vista(10, RIM - 3, 22, RIM - 1, zoom=1.0, offset=(240, -60))
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(1, RIM, D1, lv.panel("chain", 6, D1))   # 收折梯:死路 y22 x1-30
    return lv
