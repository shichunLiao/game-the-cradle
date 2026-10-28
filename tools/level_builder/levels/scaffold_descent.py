"""塔外·外墙脚手架 —— 塔3 和塔4 之间(2026-10-12)。

从登记塔顶出来,顺着登记塔外墙的脚手架一层层往下。军事塔的探照灯一直在扫这面墙:
每层脚手架东半截都在灯底下 —— 等灯扫过去再走,或者躲进检修柜(柜子挡得住灯)。
下到地面,院子里一个守卫,穿过去就是军事塔的门。

脚手架是墙到墙的,每层只有一个口子(梯子 / 塌洞),左右交替,不会从边上一路掉到底。
"""
from level_dsl import Level

SCENE = "scaffold_descent"
ROOT_NAME = "ScaffoldDescent"
ROOT = {"entry_line": "", "exit_line": "", "next_scene": "res://src/levels/tower_4_military.tscn"}
AMBIENT = "tower_4"
MUSIC = "outside"
BACKDROP_KIND = "skyline"
BLOCK_STYLE = "girder"
SKYLINE = {"focus_tower": -1, "pan": -0.1, "horizon": 0.55}
ATMOSPHERE = {
    "vignette_alpha": "0.45",
    "dust_count": "34",
    "dust_color": "Color(0.784314, 0.831373, 0.878431, 1)",
    "dust_alpha": "0.12",
    "dust_speed": "8.0",
    "seed_value": "101",
}

W, H = 110, 150
L1, L2, L3, L4, GROUND = 30, 56, 82, 108, 146
WALL = 20          # 登记塔外墙(西边)


def deck(lv, row):
    lv.solid(WALL + 1, row, W - 2, row + 1)


def make() -> Level:
    lv = Level("scaffold_descent", W, H)
    lv.solid(0, 0, WALL, H - 1)
    lv.style(0, 0, WALL, H - 1, "masonry")
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(WALL + 1, GROUND, W - 2, H - 1)

    # 塔顶出来的阳台:远景点
    lv.solid(WALL + 1, 10, WALL + 20, 11)
    lv.style(WALL + 1, 10, WALL + 20, 11, "masonry")
    lv.start(WALL + 3, 10)
    lv.vista(WALL + 6, 7, WALL + 16, 9, zoom=1.0, offset=(160, -60), text="「等灯过去应该我就能通过了吧，看守还真严格啊。」")
    lv.ladder(WALL + 20, 10, L1)                         # 阳台东头的梯子下第一层

    # 四层脚手架,口子左右交替(东梯 / 西塌洞);每层东半截在探照灯底下,灯底下有检修柜(挡得住灯)
    # 存档点放在每层「下来的地方往前走」那一段(2026-10-13 体检:第一层原来在 WALL + 8,阳台梯子下来往东走碰不到)
    arrive = [WALL + 22, W - 8, WALL + 8, W - 8]
    for i, row in enumerate([L1, L2, L3, L4]):
        deck(lv, row)
        lv.checkpoint(arrive[i], row)
        lv.sweep(W - 6, row - 14, -36, 13, period=6.0 + i * 0.4, phase=0.2 * i)
        lv.locker(76, row)
        lv.locker(92, row)
    lv.ladder(W - 4, L1, L2)                             # 第一层口子在东
    lv.clear(WALL + 3, L2, WALL + 5, L2 + 1)            # 第二层口子在西(塌洞)
    lv.ladder(W - 4, L3, L4)                             # 第三层在东
    lv.clear(WALL + 3, L4, WALL + 5, L4 + 1)            # 第四层在西:塌洞直接掉到院子

    # 院子:一个守卫,两头暗角;东头是军事塔的门
    lv.checkpoint(WALL + 8, GROUND)
    lv.shade(36, GROUND - 6, 44, GROUND - 1)
    lv.guard(46, 86, GROUND, style="steady", facing=-1, name="GuardA")
    lv.shade(88, GROUND - 6, 94, GROUND - 1)
    lv.exit(W - 6, GROUND)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(21, WALL - 10, L1, lv.panel("chain", 26, L1))   # 收折梯:死路 y30 x21-40
    return lv
