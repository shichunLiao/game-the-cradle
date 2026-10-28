"""三种守卫的像素精灵表(2026-10-13 精装修,`docs/polish-research.md` §3.4、`design/ideas-backlog.md` G1–G3)。

    python3 assets/art/src/build_guard_sheet.py

输出 `assets/art/guard_sprites.png`(游戏用)和 `assets/art/src/guard_sheet_preview.png`(放大 4 倍、带格子,给人看)。

## 三种造型(研究笔记里的剪影草稿 A / B / C)

    0  C 军帽制服兵「看」  军帽 + 帽徽、露出脸(灰白,冷色里不加暖)、及膝大衣、步枪
    1  A 面罩头盔兵「听」  圆头盔把脸整个封住(看不见)、侧面一个收音耳罩 + 天线、护甲背心、短棍
    2  B 防毒面具兵「追」  头盔 + 防毒面具(镜片、往前凸的滤毒罐)、背上的气瓶、长大衣、手里的蚀侦测器(紫灯)

剪影要一眼分得出来(TF2《Stylization with a Purpose》、像素角色可读性的通行做法):C 有帽檐和斜挎的枪、
A 头是圆的、耳罩和天线、上身短;B 脸前面凸出一块、背上一个罐子、衣摆最长。都比 Ryn 高(Ryn 44px,守卫 48px)。

## 做法

头和上身是手画的像素图(下面的 HEADS / TORSOS,字母对色板);腿和手臂按每一帧的姿势现画(髋 → 膝 → 脚、
肩 → 肘 → 手),所以走路有膝盖、有落脚。最后给轮廓的顶边和背面描一圈冷青的背光(rim light),
让人从暗墙里分出来。这张表以后可以整张交给画师重画 —— 格子大小、行列不变,游戏这边不用改。

## 表的布局(必须与 src/guard/guard_sprite_visual.gd 一致)

每格 40x60,脚底中心在格内 (20, 59),朝右画(朝左由游戏翻转)。每种造型 3 行 x 8 列,三种上下叠:
    行 0  待机呼吸 0-3 | 走 4-7 的前半 → 不:见下
    行 0  待机 0-3、起疑 4-5、发现 6-7
    行 1  走 0-7
    行 2  转身(脸朝镜头)0-1、开柜门 2-3、蹲下低头看扣件 4-5、伸手捡 6、站起来拿着扣件看 7
造型 k 的行号 = k * 3 + 上面的行。

## 查看扣件(2026-10-14,`GuardPursuit` 的 Inspect)

《杀手》系列丢硬币那样:走过去、蹲下低头看、捡起来、站起来拿在眼前看一眼。蹲 = 上身往下沉 8px、
往前倾、头再往前下探;近手往前下方伸到地面。C 的枪、A 的短棍收在身侧(不画),B 的侦测器指着扣件。
"""
from __future__ import annotations

import math
import pathlib

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
ART = HERE.parent
OUT = ART / "guard_sprites.png"
PREVIEW = HERE / "guard_sheet_preview.png"

CELL_W, CELL_H = 40, 60
COLS, ROWS_PER_LOOK = 8, 3
FOOT = (20, 59)

PAL = {
    "K": (11, 18, 32), "D": (20, 31, 49), "B": (26, 42, 68), "L": (36, 52, 79), "H": (47, 69, 102),
    "S": (138, 147, 163), "s": (94, 104, 120), "W": (200, 212, 224),
    "C": (61, 107, 138), "c": (111, 163, 196), "G": (42, 52, 70), "g": (60, 74, 94),
    "M": (16, 22, 31), "V": (122, 88, 160), "v": (74, 63, 107), "X": (168, 130, 220),
}
RIM = (61, 107, 138)

# ---------------------------------------------------------------- 头(朝右,14 宽 12 高;第 0 行 = 头顶)
HEADS = {
    "C": [
        "..............",
        ".....KKKKKK...",
        "....KLLLLHHK..",
        "...KBBBBBBLLK.",
        "...KDDDDDWDDK.",
        "...KKKKKKKKKKK",
        "...KsSSSSSSK..",
        "...KsSSSSSKSK.",
        "...KssSSSSSSSK",
        "...KssSSSSSK..",
        "....KsSSSSK...",
        "....KDDKKKK...",
    ],
    "A": [   # 耳罩在后脑(左边),深色,只有一颗小指示灯;脸那一面(右边)是整块的面甲,没有眼睛
        "......K.......",
        ".....KKKKKK...",
        "....KLLLLHHK..",
        "...KBBBBBBLLK.",
        "..KKKKBBBBBBK.",
        "..KgGgKBBBBBK.",
        "..KGcGKBBBBDK.",
        "..KgGgKBBBBDK.",
        "..KKKKBBBBDDK.",
        "...KDDDDDDDK..",
        "....KDDKKK....",
        "....KDDDDK....",
    ],
    "B": [
        "..............",
        ".....KKKKK....",
        "...KKLLLLHK...",
        "..KBBBBBBLLK..",
        "..KKKKKKKKKKK.",
        "..KBBBMMKKKK..",
        "..KBBMKccCK...",
        "..KBBMKCCCKKK.",
        "..KBBMMKKGgGK.",
        "..KDBMMMMKGGGK",
        "...KDDMMMMKKK.",
        "....KDDKKK....",
    ],
}
# 转身那一下:脸朝镜头(左右对称,14 宽)
HEADS_FRONT = {
    "C": [
        "..............",
        "....KKKKKK....",
        "...KLLLLLLK...",
        "..KBBBBBBBBK..",
        "..KDDDDWDDDK..",
        ".KKKKKKKKKKKK.",
        "..KSSSSSSSSK..",
        "..KSKSSSSKSK..",
        "..KSSSSSSSSK..",
        "..KsSSKKSSsK..",
        "...KsSSSSsK...",
        "....KDDDDK....",
    ],
    "A": [
        "......KK......",
        "....KKKKKK....",
        "...KLLLLLLK...",
        "..KBBBBBBBBK..",
        ".KgKBBBBBBKgK.",
        ".KcKBBBBBBKcK.",
        ".KgKBBBBBBKgK.",
        "..KBBBBBBBBK..",
        "..KDBBBBBBDK..",
        "...KDDDDDDK...",
        "....KDDDDK....",
        "....KDDDDK....",
    ],
    "B": [
        "..............",
        "....KKKKKK....",
        "...KLLLLLLK...",
        "..KBBBBBBBBK..",
        ".KKKKKKKKKKKK.",
        "..KMMMMMMMMK..",
        "..KMccMMccMK..",
        "..KMCCMMCCMK..",
        "..KMMKGGKMMK..",
        "...KMKggKMK...",
        "....KKGGKK....",
        "....KDDDDK....",
    ],
}
# ---------------------------------------------------------------- 上身(朝右,16 宽;背在左、胸在右)
TORSOS = {
    "C": [   # 及膝大衣、腰带、两颗扣子
        "....KKKKKKKK....",
        "...KLLLLLLHHK...",
        "..KBBBBBBBBLLK..",
        "..KBBBBBBBBBLK..",
        "..KBBBBBBBWBLK..",
        "..KBBBBBBBBBLK..",
        "..KDBBBBBBBBLK..",
        "..KDBBBBBBWBBK..",
        "..KDBBBBBBBBBK..",
        "..KKKKKKKKKKKK..",
        "..KDGgGGGGGGGK..",
        "..KDBBBBBBBBBK..",
        "..KDBBBBBBBBBK..",
        ".KDDBBBBBBBBBBK.",
        ".KDDBBBBBBBBBBK.",
        ".KDDBBBBBBBBBBK.",
        ".KDDDBBBBBBBBBK.",
        ".KKKKKKKKKKKKKK.",
    ],
    "A": [   # 护甲背心、短外套
        "....KKKKKKKK....",
        "...KHLLLLLLHK...",
        "..KLGGGGGGGGLK..",
        "..KBGgggggggBK..",
        "..KBGgGGGGGgBK..",
        "..KBGgGGGGGgBK..",
        "..KBGgggggggBK..",
        "..KBGGGGGGGGBK..",
        "..KDBBBBBBBBBK..",
        "..KKKKKKKKKKKK..",
        "..KDGgGGGGGGGK..",
        "..KDBBBBBBBBBK..",
        "..KDBBBBBBBBBK..",
        "..KKKKKKKKKKKK..",
    ],
    "B": [   # 背上的气瓶(左边)、最长的大衣
        "....KKKKKKKK....",
        "...KLLLLLLHHK...",
        "KKKBBBBBBBBLLK..",
        "KgKBBBBBBBBBLK..",
        "KgKBBBBBBBBBLK..",
        "KgKBBBBBBBBBLK..",
        "KgKDBBBBBBBBLK..",
        "KGKDBBBBBBBBBK..",
        "KKKDBBBBBBBBBK..",
        "..KKKKKKKKKKKK..",
        "..KDGgGGGGGGGK..",
        "..KDBBBBBBBBBK..",
        ".KDDBBBBBBBBBBK.",
        ".KDDBBBBBBBBBBK.",
        ".KDDBBBBBBBBBBK.",
        ".KDDDBBBBBBBBBK.",
        ".KDDDBBBBBBBBBK.",
        ".KDDDDBBBBBBBBK.",
        ".KKKKKKKKKKKKKK.",
    ],
}
LOOKS = ["C", "A", "B"]
HEAD_TOP = 12                  # 头顶在格内第几行(脚在 59:身高 48)
TORSO_TOP = 24


def paste_grid(img: Image.Image, grid, x0: int, y0: int, mirror=False):
    for j, row in enumerate(grid):
        w = len(row)
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            x = x0 + (w - 1 - i if mirror else i)
            y = y0 + j
            if 0 <= x < img.width and 0 <= y < img.height:
                img.putpixel((x, y), PAL[ch] + (255,))


def limb(d: ImageDraw.ImageDraw, pts, fill, width=4):
    """一节手臂 / 腿:先画粗一圈的墨色轮廓,再画里面的颜色。"""
    for p0, p1 in zip(pts, pts[1:]):
        d.line([p0, p1], fill=PAL["K"] + (255,), width=width + 2)
    for p in pts:
        r = (width + 2) / 2
        d.ellipse([p[0] - r + 0.5, p[1] - r + 0.5, p[0] + r - 0.5, p[1] + r - 0.5], fill=PAL["K"] + (255,))
    for p0, p1 in zip(pts, pts[1:]):
        d.line([p0, p1], fill=fill + (255,), width=width)


def boot(d, x, y, lift=0):
    """靴子:脚尖朝右。(x, y) = 脚底中心。"""
    y -= lift
    d.rectangle([x - 3, y - 3, x + 3, y], fill=PAL["K"] + (255,))
    d.rectangle([x - 2, y - 2, x + 2, y - 1], fill=PAL["D"] + (255,))
    d.point((x + 2, y - 2), fill=PAL["L"] + (255,))


def hip_y(look):
    return TORSO_TOP + len(TORSOS[look]) - 1


# ---------------------------------------------------------------- 一帧
def frame(look: str, pose: dict) -> Image.Image:
    """pose 的键:
        bob(上身下沉 px)、lean(上身往前 px)、head_dx / head_dy、front(脸朝镜头)
        feet = [(远脚 dx, 抬起), (近脚 dx, 抬起)](相对 x=20)、knee(膝盖往前多少)
        arm_near / arm_far = [(肘 dx, dy), (手 dx, dy)](相对肩)、item = 'rifle' / 'rifle_aim' / 'rifle_low' /
        'baton' / 'baton_up' / 'detector' / 'detector_up' / 'detector_out' / None、waves(耳边声波)
    """
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bob = pose.get("bob", 0)
    lean = pose.get("lean", 0)
    hx, hy = 20 + lean, hip_y(look) + bob
    # 腿:远的那条先画、颜色深
    feet = pose.get("feet", [(-2, 0), (2, 0)])
    knee = pose.get("knee", 1)
    for k, (fdx, lift) in enumerate(feet):
        fill = PAL["D"] if k == 0 else PAL["B"]
        hipx = hx + (-2 if k == 0 else 1)
        foot = (20 + fdx, FOOT[1] - 3 - lift)
        kn = ((hipx + foot[0]) / 2 + knee + (1 if lift else 0), (hy + foot[1]) / 2 - (1 if lift else 0))
        limb(d, [(hipx, hy - 1), kn, foot], fill, width=3)
        boot(d, foot[0] + 1, FOOT[1], lift)
    # 远手臂(在身子后面)
    sh = (20 + lean + 1, TORSO_TOP + 3 + bob)
    far = pose.get("arm_far", [(-1, 7), (-1, 13)])
    limb(d, [sh, (sh[0] + far[0][0], sh[1] + far[0][1]), (sh[0] + far[1][0], sh[1] + far[1][1])], PAL["D"], width=3)
    # 上身、头
    paste_grid(img, TORSOS[look], 20 + lean - 8, TORSO_TOP + bob)
    heads = HEADS_FRONT if pose.get("front") else HEADS
    paste_grid(img, heads[look], 20 + lean - 7 + pose.get("head_dx", 0), HEAD_TOP + bob + pose.get("head_dy", 0))
    # 近手臂 + 手里的东西
    near = pose.get("arm_near", [(2, 7), (6, 11)])
    elbow = (sh[0] + 2 + near[0][0], sh[1] + near[0][1])
    hand = (sh[0] + 2 + near[1][0], sh[1] + near[1][1])
    item = pose.get("item")
    _item_back(d, look, item, hand)
    limb(d, [(sh[0] + 2, sh[1]), elbow, hand], PAL["B"], width=3)
    glove = PAL["S"] if look == "C" else PAL["G"]
    d.rectangle([hand[0] - 1, hand[1] - 1, hand[0] + 1, hand[1] + 1], fill=PAL["K"] + (255,))
    d.point(hand, fill=glove + (255,))
    _item_front(d, look, item, hand)
    if pose.get("waves"):
        # 耳边的声波:两道冷青的弧(听的守卫起疑时)
        ex, ey = 20 + lean + pose.get("head_dx", 0) - 3, HEAD_TOP + bob + 5
        for r, a in ((3, 255), (5, 170)):
            d.arc([ex - r, ey - r, ex + r, ey + r], 120, 240, fill=PAL["c"] + (a,), width=1)
    _rim(img)
    return img


def _item_back(d, look, item, hand):
    """在手臂之前画的(被手臂挡住的那一截)。"""
    if item in ("rifle", "rifle_low", "rifle_aim"):
        if item == "rifle":
            a, b = (hand[0] - 7, hand[1] + 4), (hand[0] + 7, hand[1] - 3)
        elif item == "rifle_low":
            a, b = (hand[0] - 7, hand[1] - 1), (hand[0] + 8, hand[1] + 3)
        else:
            a, b = (hand[0] - 8, hand[1] + 1), (hand[0] + 9, hand[1])
        d.line([a, b], fill=PAL["K"] + (255,), width=4)
        d.line([a, b], fill=PAL["G"] + (255,), width=2)
        d.point(b, fill=PAL["g"] + (255,))


def _item_front(d, look, item, hand):
    """在手臂之后画的(握在手里、在最前面的)。"""
    if item == "baton":
        d.line([hand, (hand[0] + 2, hand[1] + 8)], fill=PAL["K"] + (255,), width=3)
        d.line([hand, (hand[0] + 2, hand[1] + 7)], fill=PAL["G"] + (255,), width=1)
        d.point((hand[0] + 2, hand[1] + 7), fill=PAL["C"] + (255,))
    elif item == "baton_up":
        d.line([hand, (hand[0] + 6, hand[1] - 6)], fill=PAL["K"] + (255,), width=3)
        d.line([hand, (hand[0] + 5, hand[1] - 5)], fill=PAL["G"] + (255,), width=1)
        d.point((hand[0] + 5, hand[1] - 5), fill=PAL["c"] + (255,))
    elif item in ("detector", "detector_up", "detector_out"):
        lit = item != "detector"
        x, y = hand[0] + 1, hand[1] - 2
        d.rectangle([x - 1, y - 2, x + 4, y + 2], fill=PAL["K"] + (255,))
        d.rectangle([x, y - 1, x + 3, y + 1], fill=PAL["G"] + (255,))
        d.point((x + 3, y - 1), fill=(PAL["X"] if lit else PAL["v"]) + (255,))
        d.line([(x + 1, y - 2), (x + 1, y - 5)], fill=PAL["K"] + (255,), width=1)   # 天线
        if lit:
            d.point((x + 1, y - 6), fill=PAL["V"] + (200,))
    elif item == "bolt":
        # 捡起来的扣件:手里一颗灰色小六角(和游戏里的扣件同色)
        x, y = hand[0] + 1, hand[1] - 2
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(140, 152, 168, 255))
        d.point((x, y), fill=PAL["K"] + (255,))
        d.point((x - 1, y - 1), fill=(216, 226, 236, 255))
    elif item == "detector_down":
        # 平时(待机、走路):侦测器垂着、探头斜指地面,探头一点暗紫 —— 「一直低头看地」(G4)
        x, y = hand[0], hand[1] - 1
        d.rectangle([x - 1, y - 2, x + 4, y + 2], fill=PAL["K"] + (255,))
        d.rectangle([x, y - 1, x + 3, y + 1], fill=PAL["G"] + (255,))
        d.line([(x + 4, y + 2), (x + 6, y + 4)], fill=PAL["K"] + (255,), width=1)
        d.point((x + 6, y + 4), fill=PAL["v"] + (255,))


def _rim(img: Image.Image):
    """背光:轮廓上沿和背面(朝右画,背在左)那一圈墨色像素换成冷青。"""
    px = img.load()
    w, h = img.size
    change = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 or px[x, y][:3] != PAL["K"]:
                continue
            up = y == 0 or px[x, y - 1][3] == 0
            back = x == 0 or px[x - 1, y][3] == 0
            if (up or (back and y < 46)) and y < 50:
                change.append((x, y))
    for (x, y) in change:
        px[x, y] = RIM + (255,)


# ---------------------------------------------------------------- 动作
def poses(look: str):
    item = {"C": "rifle", "A": "baton", "B": "detector"}[look]
    hold = {"C": [(3, 6), (6, 9)], "A": [(1, 7), (2, 13)], "B": [(3, 7), (7, 9)]}[look]
    far_hold = [(2, 6), (5, 9)] if look == "C" else [(-1, 7), (-1, 13)]
    # B 平时就低着头、侦测器垂向地面(他读的是地上的痕迹;Ryn 第一次见他那句「他一直低头看地」)
    base = dict(lean=1, head_dx=1, head_dy=1) if look == "B" else {}
    if look == "B":
        item, hold = "detector_down", [(3, 8), (6, 13)]
    rows = [[], [], []]
    # 行 0:待机呼吸 4(第 2、3 帧吸气 —— 肩往下沉 1px 是呼气,这里用上身下沉表示一呼一吸)
    for b in (0, 0, 1, 1):
        rows[0].append(dict(base, bob=b, arm_near=hold, arm_far=far_hold, item=item))
    # 起疑 2:前倾、头往前探;C 枪口压低,A 手放到耳边 + 声波,B 侦测器举到脸前、紫灯亮
    for k in range(2):
        if look == "C":
            p = dict(lean=1, head_dx=2, head_dy=1, arm_near=[(3, 7), (7, 11)], arm_far=[(2, 7), (5, 11)], item="rifle_low")
        elif look == "A":
            p = dict(lean=1, head_dx=1, head_dy=1, arm_near=[(1, 3), (-2, -6)], arm_far=[(-1, 7), (-1, 13)],
                     item=None, waves=k == 1)
        else:
            p = dict(lean=1, head_dx=1, head_dy=2, arm_near=[(4, 2), (8, -2)], arm_far=[(-1, 7), (-1, 13)],
                     item="detector_up")
        p["feet"] = [(-2, 0), (3, 0)]
        rows[0].append(p)
    # 发现 2:两脚分开站稳;C 举枪到眼睛高度,A 短棍举起来,B 侦测器往前一伸、另一只手指过去
    for k in range(2):
        if look == "C":
            p = dict(arm_near=[(4, -1), (8, -4)], arm_far=[(4, 0), (9, -3)], item="rifle_aim")
        elif look == "A":
            p = dict(arm_near=[(3, -3), (6, -8)], arm_far=[(-1, 7), (-1, 12)], item="baton_up")
        else:
            p = dict(arm_near=[(4, 0), (9, -1)], arm_far=[(3, 1), (8, 0)], item="detector_out")
        p["feet"] = [(-5, 0), (5, 0)]
        p["bob"] = k
        rows[0].append(p)
    # 行 1:走 8(近脚 dx 4 2 0 -2 -4 -2 0 2;往前迈的那只脚抬起来;触地帧上身下沉)
    near_dx = [4, 2, 0, -2, -4, -2, 0, 2]
    for i in range(8):
        n = near_dx[i]
        f = -n
        near_lift = 2 if i in (5, 6, 7) and n > -4 else 0
        far_lift = 2 if i in (1, 2, 3) else 0
        bob = 1 if i in (0, 4) else 0
        swing = -n // 2                         # 空着的那只手跟着反方向摆
        far_arm = far_hold if look == "C" else [(-1 + swing // 2, 7), (-1 + swing, 13)]
        rows[1].append(dict(base, bob=bob, feet=[(f, far_lift), (n, near_lift)], arm_near=hold, arm_far=far_arm,
                            item=item))
    # 行 2:转身 2(脸朝镜头,东西收在身前)、开柜门 2(手往前伸、拉)
    for _ in range(2):
        rows[2].append(dict(front=True, arm_near=[(1, 7), (2, 12)], arm_far=[(-1, 7), (-1, 12)],
                            item="detector" if look == "B" else None, feet=[(-2, 0), (2, 0)]))
    for k in range(2):
        rows[2].append(dict(lean=1, arm_near=[(5, 1), (10 - k * 2, 1)], arm_far=far_hold,
                            item=None if look != "B" else None, feet=[(-2, 0), (3, 0)]))
    # 蹲下低头看 2(头一点一点:第二帧头再低 1px、手往前 1px)、伸手捡 1、站起来拿着看 1
    low_item = "detector_down" if look == "B" else None
    for k in range(2):
        rows[2].append(dict(bob=8, lean=3, head_dx=2, head_dy=2 + k, knee=4, feet=[(-5, 0), (4, 0)],
                            arm_near=[(4, 6), (9 + k, 10)], arm_far=[(1, 6), (3, 10)], item=low_item))
    rows[2].append(dict(bob=9, lean=4, head_dx=2, head_dy=3, knee=4, feet=[(-5, 0), (4, 0)],
                        arm_near=[(5, 7), (10, 13)], arm_far=[(1, 6), (3, 10)], item=None))
    rows[2].append(dict(head_dx=1, head_dy=1, feet=[(-2, 0), (2, 0)],
                        arm_near=[(3, 3), (7, -2)], arm_far=far_hold if look == "C" else [(-1, 7), (-1, 13)],
                        item="bolt"))
    return rows


def main():
    sheet = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS_PER_LOOK * len(LOOKS)), (0, 0, 0, 0))
    for li, look in enumerate(LOOKS):
        for r, row in enumerate(poses(look)):
            for c, p in enumerate(row):
                sheet.alpha_composite(frame(look, p), (c * CELL_W, (li * ROWS_PER_LOOK + r) * CELL_H))
    sheet.save(OUT)
    # 预览:放大 4 倍,暗砖色底,格子线
    z = 4
    pv = Image.new("RGB", (sheet.width * z, sheet.height * z), (24, 22, 30))
    big = sheet.resize((sheet.width * z, sheet.height * z), Image.NEAREST)
    pv.paste(big, (0, 0), big)
    dr = ImageDraw.Draw(pv)
    for c in range(COLS + 1):
        dr.line([c * CELL_W * z, 0, c * CELL_W * z, pv.height], fill=(40, 44, 60))
    for r in range(ROWS_PER_LOOK * len(LOOKS) + 1):
        dr.line([0, r * CELL_H * z, pv.width, r * CELL_H * z], fill=(40, 44, 60) if r % 3 else (90, 96, 120))
    pv.save(PREVIEW)
    print(f"guard sheet → {OUT.relative_to(ART.parent.parent)} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
