"""贫民窟·屋顶 —— 序章和塔1 之间,第一段塔外(2026-10-12,用户:「塔外的部分,让玩家感受游戏中的美景和艺术风格」)。

Ryn 从旧屋的屋顶出发,一栋一栋往东跳向出生地高塔。背景是塔外夜景(`SkylineBackdrop`):
破碎的大陆、四座发光的塔和中央高塔、地平线上坑口的紫光、一轮冷白的月亮;远处贫民窟里那扇暖窗是家。

节奏是「喘口气」:大多是跑跳,只有两个巡逻,都有地方躲。
  1 旧屋屋顶 → 一栋比一栋高的三连跳
  2 最高那栋:远景点 —— 镜头拉远,第一次看见四座塔(Ryn 说一句,用户定稿)
  3 往下跳,中央的巡逻兵在屋顶来回;两头烟囱边是暗角
  4 再往上,第二个巡逻会停下来张望;屋顶上有个工具柜
  5 跳上矮屋顶、下巷子、爬消防梯 —— 一次往下再往上
  6 出生地高塔的入口

每条巷子都有消防梯(楼的西墙):失手掉进巷子也爬得回来。
"""
from level_dsl import Level

SCENE = "slum_rooftops"
ROOT_NAME = "SlumRooftops"
ROOT = {"entry_line": "", "exit_line": "", "next_scene": "res://src/levels/tower_1_birthplace.tscn",
        "throw_unlocked": False}
AMBIENT = "rooftops"
MUSIC = "outside"
BACKDROP_KIND = "skyline"
BLOCK_STYLE = "roof"
# 往东走,出生地塔(0 号)转到全景的前方
SKYLINE = {"focus_tower": 0, "pan": 0.32}
ATMOSPHERE = {
    "vignette_alpha": "0.38",
    "dust_count": "36",
    "dust_color": "Color(0.784314, 0.831373, 0.878431, 1)",
    "dust_alpha": "0.14",
    "dust_speed": "5.0",
    "seed_value": "71",
}

W, H = 232, 70
STREET = 64


def building(lv, x0, x1, roof, fire_escape=True):
    """一栋楼:屋顶在第 roof 行,一直实到街面;西墙一架消防梯从屋顶通到巷子。"""
    lv.solid(x0, roof, x1, STREET - 1)
    if fire_escape:
        lv.ladder(x0, roof, STREET)


def make() -> Level:
    lv = Level("slum_rooftops", W, H)
    lv.solid(0, 0, 0, H - 1)
    lv.solid(W - 1, 0, W - 1, H - 1)
    lv.solid(1, STREET, W - 2, H - 1)                  # 街面 / 巷子底

    # ================= 1 旧屋屋顶 → 三连跳 =================
    building(lv, 1, 16, 50, fire_escape=False)         # 旧屋
    lv.warm_window(10, 52)                             # 家里的灯还亮着(全游戏少有的暖色)
    lv.start(4, 50)
    building(lv, 19, 32, 47)
    building(lv, 35, 50, 44)

    # ================= 2 最高那栋:远景点 =================
    building(lv, 53, 68, 41)
    lv.solid(64, 39, 65, 40)                           # 烟囱
    lv.checkpoint(56, 41)
    lv.vista(54, 38, 63, 40, zoom=1.0, offset=(160, -150), text="「有四座塔。那就先去最近的吧。」")

    # ================= 3 中央的巡逻兵 =================
    building(lv, 72, 84, 46)
    building(lv, 88, 118, 48)
    lv.checkpoint(89, 48)
    lv.solid(90, 46, 91, 47)                           # 西头烟囱
    lv.shade(88, 42, 92, 47)
    lv.guard(94, 112, 48, style="steady", name="GuardA")
    lv.solid(115, 46, 116, 47)                         # 东头烟囱
    lv.shade(114, 42, 118, 47)

    # ================= 4 第二个巡逻 + 工具柜 =================
    building(lv, 121, 138, 45)
    building(lv, 141, 168, 42)
    lv.checkpoint(142, 42)
    lv.shade(141, 36, 144, 41)
    lv.guard(147, 165, 42, style="loiterer", name="GuardB")
    lv.locker(155, 42)

    # ================= 5 往下再往上:矮屋顶 → 巷子 → 消防梯 =================
    building(lv, 172, 184, 48)
    lv.shade(185, STREET - 6, 190, STREET - 1)         # 巷子里黑
    building(lv, 191, 214, 46)                         # 西墙的消防梯就是路
    lv.checkpoint(194, 46)

    # ================= 6 出生地高塔的入口 =================
    building(lv, 217, 230, 44)
    lv.exit(225, 44)
    return lv
