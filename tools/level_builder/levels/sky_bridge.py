"""塔外·高空栈桥 —— 塔2 和塔3 之间(2026-10-12)。

从精炼塔顶出来,走一座断了几截的钢架栈桥往东:跑跳过一道缺口、跳下一截塌下来的桥面再爬回去;
中段一座吊塔下面是远景点(脚下是整座城);后半截桥上有守卫,登记塔的探照灯扫桥面(灯底下两个检修柜);
最后顺着登记塔外墙的脚手架一层层爬下到塔底的门。

桥下是城里的空地,掉下去有检修梯爬回桥上;空地用墙隔开,不能从地面绕到终点。
"""
from level_dsl import Level

SCENE = "sky_bridge"
ROOT_NAME = "SkyBridge"
ROOT = {"entry_line": "", "exit_line": "", "next_scene": "res://src/levels/tower_3_registry.tscn"}
AMBIENT = "tower_4"
MUSIC = "outside"
BACKDROP_KIND = "skyline"
BLOCK_STYLE = "girder"
SKYLINE = {"focus_tower": -1, "pan": 0.12, "horizon": 0.55, "convoy": True}   # 远处一列车往坑口开(线索链)
ATMOSPHERE = {
    "vignette_alpha": "0.42",
    "dust_count": "40",
    "dust_color": "Color(0.784314, 0.831373, 0.878431, 1)",
    "dust_alpha": "0.14",
    "dust_speed": "9.0",
    "seed_value": "91",
}

W, H = 200, 90
GROUND = 86
DECK = 20


def deck(lv, x0, x1, row):
    lv.solid(x0, row, x1, row + 1)


def make() -> Level:
    lv = Level("sky_bridge", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(1, GROUND, W - 2, H - 1)

    # 精炼塔顶的边
    lv.solid(1, DECK, 12, GROUND - 1)
    lv.style(1, DECK, 12, GROUND - 1, "masonry")
    lv.start(6, DECK)

    # D1 → 缺口(跑跳)→ D2
    deck(lv, 14, 50, DECK)
    lv.ladder(30, DECK, GROUND)
    deck(lv, 54, 90, DECK)
    lv.checkpoint(56, DECK)
    # 吊塔:桥面上方一截(留出走路的净空)、下方一截支墩
    lv.solid(70, 4, 71, DECK - 5)
    lv.solid(70, DECK + 2, 71, GROUND - 1)
    lv.ladder(72, DECK, GROUND)
    lv.vista(56, DECK - 3, 66, DECK - 1, zoom=1.0, offset=(80, -40), text="「上面风好大啊。好高啊，千万不要别往下看啊。」")
    lv.solid(52, DECK + 2, 52, GROUND - 1)              # 把桥下的空地隔开

    # 塌下来的一截:跳下去,再爬回桥面
    deck(lv, 92, 100, DECK + 5)
    lv.solid(91, DECK + 7, 91, GROUND - 1)
    deck(lv, 103, 142, DECK + 2)
    lv.checkpoint(104, DECK + 2)
    lv.ladder(105, DECK + 2, GROUND)
    # 后半截:守卫来回,两头暗角;登记塔的探照灯扫桥面
    # 灯照得穿暗处,灯柱又扫满整段桥面、停在出口梯子上 —— 中间两个检修柜是唯一躲得过灯的地方
    # (2026-10-14 真人试玩:原来没有柜子,怎么走都会被照到)
    lv.shade(103, DECK - 4, 107, DECK + 1)
    lv.guard(110, 134, DECK + 2, style="steady", name="GuardA")
    lv.locker(120, DECK + 2)
    lv.locker(132, DECK + 2)
    lv.shade(136, DECK - 4, 140, DECK + 1)
    lv.sweep(142, 8, -30, 14, period=6.0, phase=0.4)
    lv.solid(139, DECK + 4, 139, GROUND - 1)            # 桥下空地和脚手架那边隔开(脚手架贴着这道墙,中间没有缝)

    # 登记塔外墙的脚手架:一层层往下
    lv.solid(152, 8, 198, GROUND - 9)
    lv.style(152, 0, 198, GROUND - 1, "masonry")
    lv.ladder(142, DECK + 2, 34)
    deck(lv, 140, 151, 34)
    lv.checkpoint(146, 34)
    lv.ladder(150, 34, 48)
    deck(lv, 140, 151, 48)
    lv.ladder(142, 48, 62)
    deck(lv, 140, 151, 62)
    lv.ladder(150, 62, 74)
    deck(lv, 140, 151, 74)
    lv.ladder(142, 74, GROUND)
    lv.checkpoint(146, GROUND)
    lv.exit(156, GROUND)
    # 另一条路(2026-10-15 用户:「没有功能的留白区块」→ 选「改成替代路线」):主路线用不到的死路远端加梯子通上一层;
    # 每架都要先解一道机关才能用(用户:「要有一定的解谜环节」→ 选「不同梯子用不同机关」):收折梯 / 铁卷门 / 门禁轮着来。
    # 每架都验过:主路线不变短(不是抄近路)、存档点照样碰得到、不开在巡逻线上、必解的机关还是必解、探照灯时序没问题。
    lv.fold_ladder(54, DECK, GROUND, lv.panel("chain", 59, GROUND))   # 收折梯:掉下去会卡关,修(链条锚在坑里,掉下去的人自己能放梯子出来)
    return lv
