"""塔里的背景道具:按格子自动摆(2026-10-12,用户选「塔内换装」)。画的那一半在 `src/levels/tower_decor.gd`。

    DECOR = "refinery"            # 关卡描述里写主题;不写就没有道具
    lv.no_decor(x0, y0, x1, y1)   # 这一块不摆(含两端)

只是景:不挡路。所以摆放的规矩都是为了「不骗人」:
  - 避开一切能互动 / 要看清的东西:梯子(左右各 1 列)、柜子、通风管、存档点、出口、道具、扣件、终端、
    盖板(上方)、栅栏、门禁、探照灯、窗、蒸汽 / 黑雾、蚀;
  - 地上的只摆在站得直的地方(净空 ≥ 3 格),整个脚印下面都是实心砖,不悬空;
  - 墙上的挂在离脚下地面 2~5 格高的地方(眼睛高度附近,看得到);
  - 吊着的只挂在离下面地面 ≥ 6 格的天花板下,最多垂 2 格 —— 不会挂在头顶的高度,看起来像障碍;
  - 道具之间留 1 格空,不挤成一团。
同一个种子每次摆得一样(改关卡描述才会变)。

**会亮的灯**(2026-10-13 精装修,`docs/polish-research.md` §3.3):灯具道具(`LAMPS`)由 `lamps()` 决定亮不亮 ——
光圈碰到暗区(或蒸汽这类临时暗处)的灯一律是坏的、不亮:「画面上的光 = 玩法上的光」(Mark of the Ninja),
暗处之所以暗,是因为那里的灯坏了。整个光圈都在配电室断电范围里的灯接在那个配电箱上,断电一起灭。
塔里只用冷光(用户 2026-10-13 定;美术规格 §2),锈红只给警示 / 应急灯。
"""
from __future__ import annotations

import math
import random

from level_dsl import TILE as T

# 每种道具:(种类, 宽 px 范围, 高 px 范围, 权重)
THEMES = {
    "birthplace": {
        "floor": [("crib", (26, 30), (18, 20), 3), ("rubble", (16, 40), (6, 12), 4), ("chair", (10, 12), (13, 14), 2)],
        "wall": [("plaque", (12, 16), (7, 8), 3), ("sconce", (6, 6), (10, 12), 4), ("crack", (12, 24), (24, 44), 3)],
        "ceiling": [("hang_lamp", (9, 11), (16, 26), 3), ("curtain", (16, 26), (18, 28), 2)],
        "floor_rate": 0.09, "wall_per_band": 9, "ceiling_rate": 0.05, "cable_rate": 0.25, "risers": 1,
    },
    "refinery": {
        "floor": [("tank", (26, 34), (34, 42), 2), ("barrel", (11, 13), (15, 16), 4), ("valve", (12, 14), (16, 20), 3)],
        "wall": [("gauge", (9, 11), (14, 18), 3), ("pipe_run", (64, 160), (6, 6), 3), ("warn_lamp", (7, 8), (9, 10), 2)],
        "ceiling": [("chain", (6, 6), (18, 30), 3), ("work_lamp", (10, 12), (14, 22), 2)],
        "floor_rate": 0.11, "wall_per_band": 10, "ceiling_rate": 0.05, "cable_rate": 0.2, "risers": 5,
    },
    "registry": {
        "floor": [("filing", (18, 22), (20, 22), 4), ("desk", (28, 34), (20, 22), 3), ("papers", (8, 14), (4, 8), 2),
                  ("stanchion", (32, 44), (14, 14), 1)],
        "wall": [("clock", (11, 12), (11, 12), 2), ("number_board", (22, 26), (9, 10), 2), ("notices", (18, 28), (12, 18), 4)],
        "ceiling": [("tube", (24, 32), (8, 12), 4)],
        "floor_rate": 0.12, "wall_per_band": 9, "ceiling_rate": 0.08, "cable_rate": 0.12, "risers": 0,
    },
    "military": {
        "floor": [("sandbags", (24, 40), (10, 20), 4), ("ammo", (14, 18), (8, 10), 3), ("rack", (18, 22), (24, 26), 2),
                  ("hedgehog", (16, 18), (14, 16), 2), ("wire", (24, 44), (8, 8), 2)],
        "wall": [("hazard", (10, 14), (18, 26), 3), ("stencil", (18, 24), (9, 10), 3), ("signal", (8, 9), (10, 12), 2),
                 ("warn_lamp", (7, 8), (9, 10), 2)],
        "ceiling": [("cage_lamp", (7, 8), (14, 22), 3)],
        "floor_rate": 0.11, "wall_per_band": 9, "ceiling_rate": 0.05, "cable_rate": 0.25, "risers": 1,
    },
    # 坑口·下行(2026-10-12):坑壁的岩石、断掉的吊缆、被蚀糊住的旧设备
    "descent": {
        "floor": [("rock", (16, 32), (10, 20), 4), ("machine", (20, 28), (16, 22), 2), ("rubble", (16, 32), (6, 10), 2)],
        "wall": [("drip", (5, 7), (14, 22), 3), ("crack", (12, 24), (24, 40), 2)],
        "ceiling": [("snapped_cable", (6, 6), (16, 30), 3), ("stalactite", (5, 8), (10, 18), 2),
                    ("work_lamp", (10, 12), (14, 22), 2)],
        "floor_rate": 0.1, "wall_per_band": 7, "ceiling_rate": 0.06, "cable_rate": 0.15, "risers": 0,
    },
}
BAND_ROWS = 24          # 墙上道具按这么高一段一段地撒;生成器也按这个高度把道具切成几个节点

# 会亮的灯具:光心在道具矩形里的位置(比例)、光半径 px、颜色、闪法、竖直压扁
LAMPS = {
    "sconce":    {"at": (0.5, 0.25), "radius": 40, "color": "cyan", "flicker": "steady", "squash": 1.0},
    "hang_lamp": {"at": (0.5, 1.0), "radius": 48, "color": "cyan", "flicker": "steady", "squash": 1.0},
    "tube":      {"at": (0.5, 1.0), "radius": 60, "color": "white", "flicker": "fluorescent", "squash": 0.55},
    "cage_lamp": {"at": (0.5, 0.7), "radius": 52, "color": "white", "flicker": "steady", "squash": 1.0},
    "work_lamp": {"at": (0.5, 1.0), "radius": 46, "color": "cyan", "flicker": "steady", "squash": 0.8},
    "warn_lamp": {"at": (0.5, 0.45), "radius": 30, "color": "rust", "flicker": "emergency", "squash": 1.0},
}
# 每座塔有多少灯本来就是坏的(塔1「坏掉一半的走廊灯」;美术规格 §4「破路后更暗」)
DEAD_RATE = {"birthplace": 0.5, "refinery": 0.2, "registry": 0.15, "military": 0.1, "descent": 0.35}


def _pick(rng, items):
    total = sum(w for (*_, w) in items)
    roll = rng.uniform(0, total)
    for kind, wr, hr, w in items:
        roll -= w
        if roll <= 0:
            return kind, rng.randint(*wr), rng.randint(*hr)
    kind, wr, hr, _ = items[-1]
    return kind, wr[0], hr[0]


def exclusion(lv) -> set[tuple[int, int]]:
    """不能摆道具的格子。"""
    out: set[tuple[int, int]] = set()

    def box(x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                out.add((x, y))
    for y in range(lv.h):
        for x in range(lv.w):
            c = lv.g[y][x]
            if c in ("H", "K"):   # 收折梯的格子也不放摆设
                box(x - 1, y - 3, x + 1, y)
            elif c == "F":
                box(x - 1, y, x + 1, y)
            elif c == "D":
                box(x - 1, y - 4, x + 1, y - 1)
    for (x, f) in lv.lockers:
        box(x - 2, f - 4, x + 2, f - 1)
    for a, b in lv.vent_pairs:
        for (x, f) in (a, b):
            box(x - 1, f - 2, x + 2, f - 1)
    for (x, f) in lv.checkpoints:
        box(x - 1, f - 4, x + 1, f - 1)
    if lv.exit_at:
        ex, ef = lv.exit_at
        box(ex - 3, ef - 5, ex + 3, ef - 1)
    for (x, f, _) in lv.pickups:
        box(x - 1, f - 3, x + 1, f - 1)
    for (x, f) in lv.bolts:
        box(x - 1, f - 3, x + 1, f - 1)
    for i, (x, f, _, _, _) in enumerate(lv.terminals):
        if i in lv.terminal_records:
            sw, sh = lv.terminal_records[i][1]
            box(x - 1, f - math.ceil((18 + sh) / T) - 1, x + math.ceil(sw / T) + 1, f - 1)
        else:
            box(x - 1, f - 4, x + 3, f - 1)
    for (x, row, _, _) in lv.broadcasts:
        box(x - 1, row - 2, x + 2, row + 2)
    for (_look, x, f, _r) in lv.panels:
        box(x - 1, f - 3, x + 1, f - 1)
    for m in lv.mechs:
        for (x, y) in m.cells:
            box(x - 1, y - 1, x + 1, y + 1)
        if m.kind == "bridge":                 # 竖着的桥占着铰链那一列往上
            d = m.data
            hx = d["x0"] if d["hinge"] == "left" else d["x1"]
            n = d["x1"] - d["x0"] + 1
            box(hx - 1, d["row"] - n - 1, hx + 1, d["row"])
        if m.kind == "fuse":
            rx, rf = m.data["repair"]
            box(rx - 1, rf - 3, rx + 1, rf - 1)
    for (_, px, py, w, h) in lv.props:
        box(px // T - 1, py // T - 1, (px + w) // T + 1, (py + h) // T + 1)
    for gt in lv.gates:
        box(gt.x0 - 1, gt.floor - gt.h_tiles, gt.x1 + 1, gt.floor - 1)
    for sw in lv.sweeps:
        box(sw.x - 2, sw.row - 2, sw.x + 2, sw.row + 2)
    for (x0, y0, x1, y1, _) in lv.windows:
        box(x0 - 1, y0 - 1, x1 + 1, y1 + 1)
    for (x0, x1, row, rise) in lv.steams:
        box(x0, row - rise, x1, row - 1)
    for (x0, x1, row, rise, _) in lv.winds:
        box(x0, row - rise, x1, row - 1)
    for (x0, x1, f, _, _) in lv.corrosions:
        box(x0, f - 3, x1, f - 1)
    for (x0, y0, x1, y1) in lv.no_decor_areas:
        box(x0, y0, x1, y1)
    return out


def _floor_below(lv, x, y, limit=8):
    """第 x 列第 y 行往下,第一块实心砖在第几行(limit 格内找不到返回 None)。"""
    for f in range(y + 1, min(lv.h, y + limit + 1)):
        if lv.cell(x, f) != " ":
            return f if lv.cell(x, f) == "#" else None
    return None


def _drop(lv, x, y):
    """第 x 列从第 y 行往下有几格空(到下一块不是空的格子为止)。"""
    n = 0
    while y + n < lv.h and lv.cell(x, y + n) == " ":
        n += 1
    return n


def place(lv, theme: str, seed: int):
    """返回 [(种类, x, y, w, h)],世界像素。"""
    th = THEMES[theme]
    rng = random.Random(seed)
    blocked = exclusion(lv)
    taken: set[tuple[int, int]] = set()
    out = []

    def free(x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if lv.cell(x, y) != " " or (x, y) in blocked or (x, y) in taken:
                    return False
        return True

    def take(x0, y0, x1, y1, margin=1):
        for y in range(y0 - margin, y1 + margin + 1):
            for x in range(x0 - margin, x1 + margin + 1):
                taken.add((x, y))

    # ---- 立管(先摆:它最长,别的道具绕开它)
    for _ in range(th["risers"] * 6):
        if sum(1 for o in out if o[0] == "riser") >= th["risers"]:
            break
        x = rng.randint(3, lv.w - 4)
        y = rng.randint(2, lv.h - 10)
        if lv.cell(x, y) != " " or lv.cell(x, y - 1) == " ":
            continue
        n = _drop(lv, x, y)
        if n < 8 or lv.cell(x, y + n) != "#" or not free(x, y, x, y + n - 1):
            continue
        out.append(("riser", x * T + 5, y * T, 6, n * T))
        take(x, y, x, y + n - 1)

    # ---- 地上的
    for f in range(2, lv.h):
        x = 1
        while x < lv.w - 1:
            if lv.cell(x, f) == "#" and lv.cell(x, f - 1) == " " and rng.random() < th["floor_rate"]:
                kind, w, h = _pick(rng, th["floor"])
                tw, tht = math.ceil(w / T), math.ceil(h / T)
                cols = range(x, x + tw)
                if (all(lv.cell(c, f) == "#" for c in cols) and free(x, f - tht, x + tw - 1, f - 1)
                        and all(lv.clearance(c, f) >= 3 * T for c in cols)):
                    px = x * T + rng.randint(0, tw * T - w)
                    out.append((kind, px, f * T - h, w, h))
                    take(x, f - tht, x + tw - 1, f - 1)
                    x += tw + rng.randint(2, 6)
                    continue
            x += 1

    # ---- 吊着的(灯、帘子、链子)
    for y in range(1, lv.h - 6):
        for x in range(1, lv.w - 1):
            if lv.cell(x, y - 1) != "#" or lv.cell(x, y) != " " or rng.random() >= th["ceiling_rate"]:
                continue
            if _drop(lv, x, y) < 6:
                continue
            kind, w, h = _pick(rng, th["ceiling"])
            tw, tht = math.ceil(w / T), math.ceil(h / T)
            if not all(lv.cell(c, y - 1) == "#" for c in range(x, x + tw)) or not free(x, y, x + tw - 1, y + tht - 1):
                continue
            out.append((kind, x * T + rng.randint(0, tw * T - w), y * T, w, h))
            take(x, y, x + tw - 1, y + tht - 1, margin=2)

    # ---- 电缆:天花板下一段,两头挂住,中间垂下
    for y in range(1, lv.h - 6):
        x = 1
        while x < lv.w - 1:
            run = 0
            while (x + run < lv.w - 1 and lv.cell(x + run, y - 1) == "#" and lv.cell(x + run, y) == " "
                   and (x + run, y) not in blocked and (x + run, y) not in taken and _drop(lv, x + run, y) >= 5):
                run += 1
            if run >= 8 and rng.random() < th["cable_rate"]:
                span = rng.randint(6, min(run - 1, 14))
                x0 = x + rng.randint(0, run - span - 1)
                out.append(("cable", x0 * T + 8, y * T, span * T, rng.randint(6, 16)))
                take(x0, y, x0 + span, y, margin=0)
            x += max(run, 1)

    # ---- 墙上的:每 BAND_ROWS 行撒几件,挂在离脚下地面 2~5 格高的地方
    for band in range(0, lv.h, BAND_ROWS):
        placed, tries = 0, 0
        while placed < th["wall_per_band"] and tries < th["wall_per_band"] * 40:
            tries += 1
            kind, w, h = _pick(rng, th["wall"])
            tw, tht = math.ceil(w / T), math.ceil(h / T)
            x = rng.randint(2, lv.w - 2 - tw)
            y = rng.randint(band, min(band + BAND_ROWS, lv.h) - 1)
            f = _floor_below(lv, x, y + tht - 1)
            if f is None or not (2 <= f - (y + tht - 1) - 1 <= 5):
                continue
            if lv.cell(x, y - 1) != " ":                       # 头顶贴着天花板的不要
                continue
            if not free(x, y, x + tw - 1, y + tht - 1):
                continue
            out.append((kind, x * T + rng.randint(0, tw * T - w), y * T + rng.randint(0, tht * T - h), w, h))
            take(x, y, x + tw - 1, y + tht - 1)
            placed += 1
    return out


def chunks(props, h_tiles):
    """按高度切成几段(每段 BAND_ROWS 行),每段一个节点 —— 画面外的整段被剔除。"""
    out = []
    for band in range(0, h_tiles, BAND_ROWS):
        lo, hi = band * T, (band + BAND_ROWS) * T
        part = [p for p in props if lo <= p[2] < hi]
        if part:
            out.append(part)
    return out


def lamps(lv, props, theme: str, seed: int):
    """哪些灯亮。返回 (新的 props, 灯列表);亮的灯具种类改成「kind:on」(画成亮的),其余照旧画成熄的。
    手摆的「kind:lit」不吃 `DEAD_RATE`(只要不碰暗区就亮)。
    灯 = (光心 x, 光心 y, 半径, 颜色键, 闪法, 压扁, 配电箱序号或 -1),世界像素。"""
    rng = random.Random(seed ^ 0x5EED)
    fuses = []                                  # (序号, 断电范围格子 x0, y0, x1, y1)
    for m in lv.mechs:
        if m.kind == "fuse":
            fuses.append((len(fuses), *m.data["blackout"]))
    blackout_cells = set()
    for (_i, x0, y0, x1, y1) in fuses:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                blackout_cells.add((x, y))
    out_props, out = [], []
    for (kind, x, y, w, h) in props:
        base, _, arg = kind.partition(":")
        spec = LAMPS.get(base)
        if spec is None or arg not in ("", "lit"):
            out_props.append((kind, x, y, w, h))
            continue
        forced = arg == "lit"                   # 手摆的灯「base:lit」:只要不碰暗区就一定亮
        kind = base
        cx = x + w * spec["at"][0]
        cy = y + h * spec["at"][1]
        r = spec["radius"]
        ry = r * spec["squash"]
        touched, fuse = False, -1
        cells = []
        for ty in range(int((cy - ry) // T), int((cy + ry) // T) + 1):
            for tx in range(int((cx - r) // T), int((cx + r) // T) + 1):
                if not (0 <= tx < lv.w and 0 <= ty < lv.h):
                    continue
                # 格子离光心最近的一点在不在椭圆里
                nx = min(max(cx, tx * T), tx * T + T)
                ny = min(max(cy, ty * T), ty * T + T)
                # 实心格子(墙、地板)不会是暗处,也不用管它在不在断电范围里 —— 光照在墙上没关系
                if ((nx - cx) / r) ** 2 + ((ny - cy) / ry) ** 2 <= 1.0 and lv.cell(tx, ty) != "#":
                    cells.append((tx, ty))
        for c in cells:
            if lv.sh[c[1]][c[0]] or (c in lv.temp_shade and c not in blackout_cells):
                touched = True
                break
        # 断电范围只看灯真照得到的格子:隔着墙 / 平台的那一边照不到(画面上光晕会画过去,
        # 但那一边不是暗区 —— 暗区的检查在上面,用的是全部格子,最严)
        lit = [c for c in cells if not _occluded(lv, cx, cy, c)]
        if not touched and any(c in blackout_cells for c in lit):
            inside = [i for (i, x0, y0, x1, y1) in fuses if all(x0 <= c[0] <= x1 and y0 <= c[1] <= y1 for c in lit)]
            if inside:
                fuse = inside[0]
            else:
                touched = True                  # 半截在断电范围里:断电后一半亮一半暗,会骗人 —— 当坏的
        if touched or (not forced and rng.random() < DEAD_RATE.get(theme, 0.0)):
            out_props.append((kind, x, y, w, h))
            continue
        out_props.append((kind + ":on", x, y, w, h))
        out.append((round(cx), round(cy), r, spec["color"], spec["flicker"], spec["squash"], fuse))
    return out_props, out


def _occluded(lv, cx, cy, cell):
    """光心到格子中心的连线有没有穿过实心格子(不算两头)。"""
    tx, ty = cell
    ex, ey = tx * T + T / 2, ty * T + T / 2
    steps = max(2, int(max(abs(ex - cx), abs(ey - cy)) / 4))
    start = (int(cx // T), int(cy // T))
    for i in range(1, steps):
        k = i / steps
        c = (int((cx + (ex - cx) * k) // T), int((cy + (ey - cy) * k) // T))
        if c != start and c != cell and lv.cell(*c) == "#":
            return True
    return False


def lamp_issues(lv, lamp_list):
    """亮着的灯,光圈有没有碰到暗区(生成器的检查:应该永远是空的)。"""
    issues = []
    for (cx, cy, r, _c, _f, squash, _fuse) in lamp_list:
        ry = r * squash
        for ty in range(int((cy - ry) // T), int((cy + ry) // T) + 1):
            for tx in range(int((cx - r) // T), int((cx + r) // T) + 1):
                if 0 <= tx < lv.w and 0 <= ty < lv.h and lv.sh[ty][tx]:
                    nx = min(max(cx, tx * T), tx * T + T)
                    ny = min(max(cy, ty * T), ty * T + T)
                    if ((nx - cx) / r) ** 2 + ((ny - cy) / ry) ** 2 <= 0.999:
                        issues.append(f"灯 ({cx},{cy}) 的光圈碰到暗区 ({tx},{ty})")
                        break
            else:
                continue
            break
    return issues


# 每片暗处「为什么暗」(2026-10-13 细致化,backlog H1):暗区顶上挂一盏坏掉的灯(各塔自己那种灯)。
# 天花板就贴在暗区顶上 → 吊灯;不然 → 墙上的灯。种类带「:dead」,`lamps()` 不会把它点亮。
SHADE_CAUSE = {
    "birthplace": {"ceiling": ("hang_lamp", 10, 20), "wall": ("sconce", 6, 11)},
    "refinery": {"ceiling": ("work_lamp", 11, 18), "wall": ("warn_lamp", 8, 10)},
    "registry": {"ceiling": ("tube", 28, 10), "wall": None},
    "military": {"ceiling": ("cage_lamp", 8, 18), "wall": ("warn_lamp", 8, 10)},
    "descent": {"ceiling": ("work_lamp", 11, 18), "wall": None},
}


def shade_causes(lv, theme: str, props):
    """在每片暗区的顶上加一盏坏灯(已经有灯具在里面的暗区不加)。返回新增的道具。"""
    spec = SHADE_CAUSE.get(theme)
    if spec is None:
        return []
    blocked = exclusion(lv)
    taken = set()
    for (_k, px, py, w, h) in props:
        for ty in range(py // T, (py + h) // T + 1):
            for tx in range(px // T, (px + w) // T + 1):
                taken.add((tx, ty))
    out = []
    for y in range(1, lv.h - 1):
        x = 0
        while x < lv.w:
            # 暗区最上面一行的一段
            if not (lv.sh[y][x] and not lv.sh[y - 1][x]):
                x += 1
                continue
            x0 = x
            while x < lv.w and lv.sh[y][x] and not lv.sh[y - 1][x]:
                x += 1
            x1 = x - 1
            if x1 - x0 + 1 < 4:
                continue
            already = any(k.split(":")[0] in LAMPS and x0 * T <= px <= (x1 + 1) * T and y * T - 24 <= py <= (y + 6) * T
                          for (k, px, py, _w, _h) in props + out)
            if already:
                continue
            cx = (x0 + x1) // 2
            # 往上找天花板(暗区顶上不一定就贴着天花板;最多找 8 格):吊灯从那里垂下来
            ceil = next((yy for yy in range(y - 1, max(y - 9, 0), -1) if lv.cell(cx, yy) != " "), None)
            if ceil is not None and lv.cell(cx, ceil) == "#" and spec["ceiling"] \
                    and all(lv.cell(cx + d, ceil) == "#" for d in (-1, 1)):
                kind, w, h = spec["ceiling"]
                px, py = cx * T + (T - w) // 2, (ceil + 1) * T
            elif spec["wall"] and lv.cell(cx, y + 1) == " ":
                kind, w, h = spec["wall"]
                px, py = cx * T + (T - w) // 2, y * T + 6
            else:
                continue
            cells = {(tx, ty) for ty in range(py // T, (py + h - 1) // T + 1) for tx in range(px // T, (px + w - 1) // T + 1)}
            if any(lv.cell(tx, ty) != " " or (tx, ty) in blocked or (tx, ty) in taken for (tx, ty) in cells):
                continue
            out.append((kind + ":dead", px, py, w, h))
            taken |= cells
    return out

