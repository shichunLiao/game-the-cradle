"""塔外·输油管桥 —— 塔1 和塔2 之间(2026-10-12,用户选「其他三段塔外」)。

从出生地塔的阳台出来,沿着架在半空的输油管往东走到精炼塔脚下。管子高高低低,接头冒蒸汽;
中间一座泵站有一个守卫和一个工具柜,头顶龙门架上吊着一盏探照灯扫泵站;最高那段管子是远景点;
最后顺着立管的检修梯下到精炼塔的门口。

掉下去不会白掉:管子下面是精炼厂的院子,每一段都有检修梯爬回去;院子被管子的支墩隔成一段一段,
不能顺着院子一路走到门口。
"""
from level_dsl import Level

SCENE = "pipeline_bridge"
ROOT_NAME = "PipelineBridge"
ROOT = {"entry_line": "", "exit_line": "", "next_scene": "res://src/levels/tower_2_refinery.tscn"}
AMBIENT = "rooftops"
MUSIC = "outside"
BACKDROP_KIND = "skyline"
BLOCK_STYLE = "pipe"
SKYLINE = {"focus_tower": -1, "pan": 0.25, "horizon": 0.6}
ATMOSPHERE = {
    "vignette_alpha": "0.4",
    "dust_count": "30",
    "dust_color": "Color(0.784314, 0.831373, 0.878431, 1)",
    "dust_alpha": "0.12",
    "dust_speed": "6.0",
    "seed_value": "81",
}

W, H = 190, 80
YARD = 76


def pipe(lv, x0, x1, row):
    """一段横着的输油管(两格粗),站在第 row 行上。"""
    lv.solid(x0, row, x1, row + 1)


def make() -> Level:
    lv = Level("pipeline_bridge", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(1, YARD, W - 2, H - 1)                     # 精炼厂的院子

    # 出生地塔的外墙和阳台
    lv.solid(1, 0, 6, YARD - 1)
    lv.solid(7, 30, 12, 31)
    lv.style(1, 0, 12, YARD - 1, "masonry")
    lv.start(9, 30)

    # P1 / P2:一低一高两段管子,接头冒汽
    pipe(lv, 13, 55, 30)
    lv.steam(24, 26, 30, rise_tiles=5)
    lv.solid(56, 32, 57, YARD - 1)                      # 支墩(把院子隔开)
    lv.ladder(30, 30, YARD)                             # 掉下去的检修梯
    pipe(lv, 58, 80, 27)
    lv.checkpoint(60, 27)
    lv.ladder(70, 27, YARD)
    lv.solid(82, 31, 83, YARD - 1)

    # 泵站:守卫来回,中间一个工具柜,两头暗角;头顶龙门架吊一盏探照灯
    lv.solid(84, 30, 118, 31)
    lv.style(84, 30, 118, 31, "girder")
    lv.checkpoint(85, 30)
    lv.shade(84, 24, 88, 29)
    lv.guard(90, 112, 30, style="steady", name="GuardA", sense="hearing")
    lv.locker(100, 30)
    lv.shade(114, 24, 118, 29)
    lv.solid(84, 16, 118, 17)                           # 龙门架
    lv.style(84, 16, 118, 17, "girder")
    lv.sweep(88, 18, 26, 12, period=6.5, phase=0.3)
    lv.ladder(86, 30, YARD)
    lv.solid(119, 31, 120, YARD - 1)

    # P3 低一点、冒汽;阀门台;P4 最高:远景点
    pipe(lv, 121, 150, 33)
    lv.checkpoint(126, 33)                             # 跳上 P3 落在 124 往东走(2026-10-13 体检:原来 122 在落点身后)
    lv.steam(132, 134, 33, rise_tiles=6)
    lv.ladder(140, 33, YARD)
    lv.solid(151, 34, 151, YARD - 1)
    pipe(lv, 153, 156, 30)
    pipe(lv, 158, 178, 27)
    lv.checkpoint(159, 27)
    lv.vista(160, 24, 172, 26, zoom=1.0, offset=(0, -140), text="「这些管子好像都是往坑那边延伸的啊。」")

    # 顺着立管的检修梯下到精炼塔门口
    lv.ladder(178, 27, YARD)
    lv.solid(182, 0, 188, YARD - 9)                     # 精炼塔的外墙,底下是门洞(8 行高,2026-10-15 为二段跳加高)
    lv.style(182, 0, 188, YARD - 1, "masonry")
    lv.exit(185, YARD)
    return lv
