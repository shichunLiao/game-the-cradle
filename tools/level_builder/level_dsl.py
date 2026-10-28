"""关卡描述语言:用 16px 的格子写关卡,生成 Godot 场景、字符地图、预览图和一条验证用的路线。

    from level_dsl import Level
    lv = Level("tower_1", w=200, h=60)
    lv.solid(0, 52, 199, 59)             # 地面
    lv.ladder(40, top=40, bottom=52)     # 从上层地板(第 40 行)到地面(第 52 行)
    ...

## 坐标

全部用**格子**(16px)。`x` 是列,`y`/`row` 是行,向下增大。说「站在第 r 行」指脚踩在第 r 行
那块实心砖的**顶面**(像素 y = r*16)。

## 字符(字符地图里看得到)

    #  实心砖                     ^  矮天花板:实心,并且往下多伸 8px(钻缝的净空 = 3 格 - 8 = 40px)
    H  梯子(可以穿过地板的洞)   D  地板盖板(可拆;拆了能掉下去)
    F  栅栏(可拆;拆了能走过去) (空格) 空
暗区是单独一层(`shade()`),预览图里画成深蓝。

## Ryn 的能力(验证路线时用;来自 assets/data/ryn_movement.tres)

站立 42px、蹲下 34px、宽 10px;满跳顶点 53px(≈3.3 格);走 105px/s,跑 170px/s。
所以:站着走要净空 ≥ 42(3 格);蹲着钻要 ≥ 34(3 格减 `^` 的 8px = 40);
往上跳最多 3 格;平地跳过的空隙最多 4 格(要跑);往下掉多高都行。
二段跳(2026-10-14)不算进路线 —— 关卡照一段跳设计,`double_jump_bypass_issues` 另查它会不会让谜题被跳过。
"""
from __future__ import annotations

import collections
import dataclasses
import math

TILE = 16
STAND_PX = 42
CROUCH_PX = 34
JUMP_UP_TILES = 3
JUMP_DX_TILES = 3
GAP_TILES = 4
# 二段跳(2026-10-14):第二段 34px,两段加起来顶点 ≈ 90px(5.6 格);跑起来连跳,同高能飞 ~10 格。
# 关卡还是照一段跳设计(上面三个数),这组只给 `double_jump_bypass_issues` 查「谜题会不会被跳过」——
# 往宽了算,宁可多报。
DJ_JUMP_UP_TILES, DJ_JUMP_DX_TILES, DJ_GAP_TILES = 5, 5, 10
SOLID = set("#^DF")
FLOORLIKE = set("#^D")


@dataclasses.dataclass
class Guard:
    name: str
    x0: int
    x1: int
    floor: int
    style: str = "steady"        # steady / scanner / loiterer / sentry
    facing: int = 1
    spawn: int | None = None     # 出生列;默认在巡逻起点
    speed: float = 1.0
    range: float = 1.0
    hearing: float = 1.0
    sense: str = "sight"         # sight 看 / hearing 听 / tracking 追(2026-10-13,见 src/guard/guard.gd 的 Sense)


@dataclasses.dataclass
class Gate:
    x0: int
    x1: int
    floor: int
    h_tiles: int
    red: float = 3.0
    green: float = 2.4
    phase: float = 0.0


@dataclasses.dataclass
class Sweep:
    x: int
    row: int
    span_tiles: int
    length_tiles: int
    period: float = 6.0
    phase: float = 0.0
    width: float = 56.0
    # 每一列光照到第几行为止(第一块实心那一行)。光被地板、平台挡住(2026-10-15),和 SweepLight 的射线同一条规则。
    # finish() 填;length_tiles 只剩画光锥用。
    stop: dict = dataclasses.field(default_factory=dict)


@dataclasses.dataclass
class Mech:
    """谜题房的机关(2026-10-12)。拆掉 `panel` 那块面板就触发。
    kind:shutter(铁卷门,`cells` 开了变空)/ bridge(吊桥,`cells` 放下变实)/ cover(通风口盖板)/
         steam(蒸汽阀门:临时暗区)/ fuse(配电箱:断电 + 临时暗区)。"""
    kind: str
    panel: int
    cells: list
    data: dict


class Level:
    def __init__(self, key: str, w: int, h: int):
        self.key, self.w, self.h = key, w, h
        self.g = [[" "] * w for _ in range(h)]
        self.sh = [[False] * w for _ in range(h)]
        self.guards: list[Guard] = []
        self.lockers: list[tuple[int, int]] = []
        self.vent_pairs: list[tuple[tuple[int, int], tuple[int, int]]] = []
        self.checkpoints: list[tuple[int, int]] = []
        self.gates: list[Gate] = []
        self.sweeps: list[Sweep] = []
        self.start_at: tuple[int, int] | None = None
        self.exit_at: tuple[int, int] | None = None
        self.labels: list[tuple[int, int, str]] = []   # 预览图上的文字说明
        # 剧情(叙事脚本.md「入塔一句 → 关中 0–1 句 → 出塔一句」之外的那些瞬间)
        self.stories: list[tuple[int, int, int, int, str]] = []     # 关中旁白触发区
        self.pickups: list[tuple[int, int, str]] = []               # 地上的小道具
        self.terminals: list[tuple[int, int, str, int, int]] = []   # 闪字的终端 (x, floor, 词, 触发 x0, x1)
        self.winds: list[tuple[int, int, int, int, bool]] = []      # 格栅 + 黑雾 (x0, x1, row, 高几格, 画格栅)
        self.fall_text: str | None = None                           # 拆盖板摔下守卫后的那一句
        # 蚀(坑底「下行」):粘鞋底,走得慢、跑不起来
        self.corrosions: list[tuple[int, int, int, float, float]] = []   # (x0, x1, floor, drag, haze)
        self.corr: set[tuple[int, int]] = set()                           # 被蚀糊住的落脚点
        self.haze_text: str | None = None                                 # 第一次踩进深蚀时的那一句
        self.pool_depths: dict[int, int] = {}                             # 蚀池的深度 px(第几滩 → 深度)
        self.bolts: list[tuple[int, int]] = []                            # 地上可捡的扣件
        # 塔外的景(2026-10-12):墙上的窗 / 破口、远景镜头点
        self.windows: list[tuple[int, int, int, int, str]] = []           # (x0, y0, x1, y1, "window"/"breach")
        self.vistas: list[tuple[int, int, int, int, float, tuple, str]] = []
        self.warm_windows: list[tuple[int, int]] = []                     # 旧屋外墙上的暖窗(全游戏唯一的暖色窗)
        # 实心块的样子按区域改(管子、钢架);区域里的实心块都用这个样子。后加的盖先加的。
        self.styles: list[tuple[int, int, int, int, str]] = []
        self.steams: list[tuple[int, int, int, int]] = []                 # 管子接头冒的蒸汽(只是景)
        self.no_decor_areas: list[tuple[int, int, int, int]] = []         # 不摆背景道具的区域(`decor.py`)
        self.decor_props: list[tuple[str, int, int, int, int]] = []       # 摆好的背景道具(build 时填)
        self.props: list[tuple[str, int, int, int, int]] = []             # 手摆的背景道具 (种类, x px, y px, w, h)
        # 线索链(2026-10-12):姐姐的下落
        self.terminal_records: dict[int, tuple[list[str], tuple[int, int]]] = {}   # 档案终端:第几个终端 → (几行, 屏幕 w×h px)
        self.broadcasts: list[tuple[int, int, str, tuple]] = []           # 广播喇叭 (x, row, 那一句, 触发区格子 (x0, y0, x1, y1))
        self.chats: list[dict] = []                                       # 守卫停下来聊天
        # 谜题房(2026-10-12):墙上的机关面板、它们控制的东西
        self.panels: list[tuple[str, int, int, tuple]] = []               # (样子, x, floor 站的位置, 矩形 px (x, y, w, h))
        self.mechs: list[Mech] = []
        self.mech_open: set[int] = set()                                  # 路线搜索时:已经拆开的机关
        self._dyn: dict[tuple[int, int], int] = {}                        # 铁卷门 / 吊桥的格子 → 机关
        self._fold_slab: set[tuple[int, int]] = set()                      # 收折梯穿过楼板的那几格:锁着时是盖板(实心)
        self.temp_shade: set[tuple[int, int]] = set()                     # 蒸汽、断电造出来的临时暗处(格子)
        # 梯子、盖板、栅栏是「盖章」:先记下来,所有地形画完后再统一盖上去(`finish()`),
        # 这样后画的平台不会把梯子顶那一格又填回实心。
        self._stamps: list[tuple[int, int, int, int, str]] = []

    # ------------------------------------------------------------ 地形
    def _set(self, x0, y0, x1, y1, ch):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.g[y][x] = ch

    def solid(self, x0, y0, x1, y1):
        """实心矩形(含两端)。"""
        self._set(x0, y0, x1, y1, "#")

    def clear(self, x0, y0, x1, y1):
        self._set(x0, y0, x1, y1, " ")

    def low(self, x0, x1, row):
        """矮天花板:第 row 行这一段是实心,并往下多伸 8px。下面 3 格只能蹲着钻(净空 40)。"""
        self._set(x0, row, x1, row, "^")

    def fold_ladder(self, x, top, bottom, panel, noise=220):
        """收折梯(2026-10-15 用户:新加的替代路线梯子「要有一定的解谜环节才能用」):和 `ladder` 一样从第 top 行到
        第 bottom 行,但平时收在上面 —— 楼板上的洞口盖着盖板,梯子折在盖板底下,链子拉到 `panel`(链条锚)。
        拆锚 → 盖板打开、梯子放下来,砸到地上的声音传 noise px。返回机关编号。"""
        m = len(self.mechs)
        r = top
        while r < bottom and self.g[r][x] in SOLID:
            self._fold_slab.add((x, r))
            r += 1
        cells = [(x, y) for y in range(top, bottom)]
        self.mechs.append(Mech("ladder", panel, cells, {"x": x, "top": top, "bottom": bottom,
                                                         "slab": r - top, "noise": noise, "optional": True}))
        self._stamps.append((x, top, x, bottom - 1, "K"))
        self._set(x, top, x, bottom - 1, "K")
        for c in cells:
            self._dyn[c] = m
        return m

    def ladder(self, x, top, bottom):
        """梯子:从第 top 行(上层地板顶面)到第 bottom 行(下层地板顶面)。
        上层地板在这一列会被挖成洞,梯子顶的单向平台盖在洞口上。"""
        self._stamps.append((x, top, x, bottom - 1, "H"))
        self._set(x, top, x, bottom - 1, "H")

    def hatch(self, x0, x1, row):
        """地板盖板(可拆)。"""
        self._stamps.append((x0, row, x1, row, "D"))
        self._set(x0, row, x1, row, "D")

    def fence(self, x, r0, r1):
        """栅栏(可拆),第 r0..r1 行。"""
        self._stamps.append((x, r0, x, r1, "F"))
        self._set(x, r0, x, r1, "F")

    def finish(self):
        """把梯子、盖板、栅栏重新盖一遍(盖板、栅栏先,梯子最后)。build 在 make() 之后调用。"""
        for kind in ("D", "F", "S", "B", "H", "K"):
            for (x0, y0, x1, y1, ch) in self._stamps:
                if ch == kind:
                    self._set(x0, y0, x1, y1, ch)
        for sw in self.sweeps:
            lo, hi = sorted((sw.x, sw.x + sw.span_tiles))
            pad = int(sw.width / 2 / TILE) + 2
            for c in range(max(0, lo - pad), min(self.w - 1, hi + pad) + 1):
                r = sw.row
                while r < self.h and not self.is_solid(c, r):
                    r += 1
                sw.stop[c] = r
        return self

    def shade(self, x0, y0, x1, y1):
        """暗区(格子,含两端)。"""
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.sh[y][x] = True

    # ------------------------------------------------------------ 物件
    def start(self, x, floor):
        self.start_at = (x, floor)
        self.checkpoints.insert(0, (x, floor))

    def exit(self, x, floor):
        self.exit_at = (x, floor)

    def checkpoint(self, x, floor):
        self.checkpoints.append((x, floor))

    def locker(self, x, floor):
        self.lockers.append((x, floor))

    def vents(self, a, b, cover=None):
        """一对通风管口 a=(x, floor), b=(x, floor)。cover="a"/"b":那一头盖着螺栓盖板,要先长按 E 拆掉
        才钻得进去(只挡从那头进,从另一头钻过来照样出得来)。"""
        self.vent_pairs.append((a, b))
        if cover in ("a", "b"):
            x, f = a if cover == "a" else b
            pid = self.panel("vent_cover", x, f, rect=(x * TILE - 2, f * TILE - 14, 20, 14))
            self.mechs.append(Mech("cover", pid, [], {"mouth": (x, f), "pair": len(self.vent_pairs) - 1}))

    # ------------------------------------------------------------ 谜题房(2026-10-12)
    def panel(self, look, x, floor, rect=None):
        """墙上一块机关面板,Ryn 站在第 x 列第 floor 行上长按 E 拆。look:chain / valve / fuse / control /
        vent_cover。默认 16×16 挂在胸口高度。返回面板编号(给 shutter / drawbridge 用)。"""
        if rect is None:
            rect = (x * TILE, floor * TILE - 36, 16, 16)
        self.panels.append((look, x, floor, tuple(rect)))
        return len(self.panels) - 1

    def shutter(self, x, top, bottom, panel, optional=False):
        """拆不动的铁卷门:第 x 列第 top..bottom 行(含两端)。拆掉 `panel` 那块面板才卷上去。
        optional:只是替代路线上的门(主路线不用开),`find_route` 找主路线时最后才考虑它。"""
        m = len(self.mechs)
        cells = [(x, y) for y in range(top, bottom + 1)]
        self.mechs.append(Mech("shutter", panel, cells, {"x": x, "top": top, "bottom": bottom, "optional": optional}))
        self._stamps.append((x, top, x, bottom, "S"))
        self._set(x, top, x, bottom, "S")
        for c in cells:
            self._dyn[c] = m
        return m

    def drawbridge(self, x0, x1, row, panel, hinge="left", noise=260):
        """吊桥:放下来是第 row 行 x0..x1 的桥面;平时竖在铰链那头(hinge="left" = x0、"right" = x1),
        链条拉到 `panel`(链条锚)。拆锚 → 桥倒下来,砸下来的声音传 noise px。竖着的高度 = 桥长,头顶要留够空。"""
        m = len(self.mechs)
        cells = [(x, row) for x in range(x0, x1 + 1)]
        self.mechs.append(Mech("bridge", panel, cells, {"x0": x0, "x1": x1, "row": row, "hinge": hinge, "noise": noise}))
        self._stamps.append((x0, row, x1, row, "B"))
        self._set(x0, row, x1, row, "B")
        for c in cells:
            self._dyn[c] = m
        return m

    def steam_valve(self, x, floor, cloud, duration=6.0):
        """蒸汽阀门:Ryn 站在第 x 列第 floor 行拧开,白汽罩住 cloud=(x0, y0, x1, y1)(格子,含两端)
        duration 秒,这段时间里那一片算暗处。阀门自己会关上,能再拧。"""
        pid = self.panel("valve", x, floor)
        x0, y0, x1, y1 = cloud
        self.mechs.append(Mech("steam", pid, [], {"cloud": tuple(cloud), "duration": duration}))
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                self.temp_shade.add((xx, yy))

    def fuse_box(self, x, floor, blackout, technician, repair, sweeps=(), gates=(), repair_time=3.0, backup=20.0):
        """配电箱:Ryn 站在第 x 列第 floor 行拆开 → sweeps / gates(探照灯、门禁的编号)断电,blackout=(x0, y0, x1, y1)
        那一片变暗;守卫 technician 走到 repair=(x, floor) 的电闸修 repair_time 秒就来电(没人修 backup 秒后来电)。"""
        pid = self.panel("fuse", x, floor)
        x0, y0, x1, y1 = blackout
        self.mechs.append(Mech("fuse", pid, [], {"blackout": tuple(blackout), "technician": technician,
                                                 "repair": tuple(repair), "sweeps": list(sweeps),
                                                 "gates": list(gates), "repair_time": repair_time, "backup": backup}))
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                self.temp_shade.add((xx, yy))

    def drain(self, x, floor, pools, grate, noise=420, drain_time=4.0):
        """蚀池的排放阀:Ryn 站在第 x 列第 floor 行拆掉阀门 → pools(`lv.corrosion` 返回的编号)里的蚀往
        第 grate 列的排水格栅流,drain_time 秒排干;声音从格栅传 noise px。一次性。"""
        pid = self.panel("valve", x, floor)
        self.mechs.append(Mech("drain", pid, [], {"pools": list(pools), "grate": grate, "noise": noise,
                                                  "drain_time": drain_time}))
        return pid

    def vent_open(self, mouth):
        """这个管口现在钻不钻得进去(盖板拆了没有)。"""
        for i, m in enumerate(self.mechs):
            if m.kind == "cover" and m.data["mouth"] == mouth and i not in self.mech_open:
                return False
        return True

    def panel_stand(self, pid):
        _, x, f, _ = self.panels[pid]
        return (x, f)

    def guard(self, x0, x1, floor, **kw):
        name = kw.pop("name", f"Guard{len(self.guards) + 1}")
        self.guards.append(Guard(name, x0, x1, floor, **kw))

    def gate(self, x0, x1, floor, h_tiles, **kw):
        self.gates.append(Gate(x0, x1, floor, h_tiles, **kw))

    def sweep(self, x, row, span_tiles, length_tiles, **kw):
        self.sweeps.append(Sweep(x, row, span_tiles, length_tiles, **kw))

    def label(self, x, y, text):
        self.labels.append((x, y, text))

    # ------------------------------------------------------------ 剧情
    def story(self, x0, y0, x1, y1, text):
        """关中一句旁白:Ryn 走进第 x0..x1 列、第 y0..y1 行(含两端)时出字幕,只出一次。
        站在第 f 行的 Ryn,身体在第 f-3..f-1 行 —— 触发区盖住这几行就行。"""
        self.stories.append((x0, y0, x1, y1, text))

    def pickup(self, x, floor, text):
        """地上一小件东西(站在第 floor 行),走过去捡起来,出一句话。"""
        self.pickups.append((x, floor, text))

    def terminal(self, x, floor, word, trigger, lines=None, screen=None):
        """墙边终端(站在第 floor 行,占 x..x+2 列);Ryn 走进 trigger=(x0, x1) 列时闪出 word 再灭。
        lines=[...]:档案模式,一行行打出来(word 那个词亮起来,「█」涂黑);screen=(w, h) 屏幕大小 px。"""
        self.terminals.append((x, floor, word, trigger[0], trigger[1]))
        if lines:
            self.terminal_records[len(self.terminals) - 1] = (list(lines), tuple(screen or (112, 44)))

    def broadcast(self, x, row, text, trigger):
        """墙上的广播喇叭挂在第 x 列第 row 行;Ryn 走进 trigger=(x0, y0, x1, y1)(格子,含两端)就播一次。
        字幕是冷青色(不是 Ryn 的话)。"""
        self.broadcasts.append((x, row, text, tuple(trigger)))

    def prop(self, kind, x, row, w, h):
        """手摆一件背景道具:左上角在第 x 列第 row 行,大小 w×h px。kind 可以带参数,如 "number_board:17"。
        自动摆的道具会绕开它。"""
        self.props.append((kind, x * TILE, row * TILE, w, h))

    def guard_chat(self, a, b, meet, approach, lines, hear=240):
        """两个守卫(名字 a、b)停下来聊天,Ryn 躲在附近才听得到。meet=(a 停在第几列, b 停在第几列),
        一般是两人巡逻线挨着的那两头;approach=(x0, y0, x1, y1) 格子,Ryn 一进来两人开始往那里走;
        lines=["0|……", "1|……"](0 = a 说、1 = b 说,「\n」换行);hear = 离两人中点多近听得到(px)。"""
        self.chats.append(dict(a=a, b=b, meet=tuple(meet), approach=tuple(approach), lines=list(lines), hear=hear))

    def pit_wind(self, x0, x1, row, rise_tiles=6, grate=True):
        """第 row 行地面上 x0..x1 一道格栅,黑雾往上飘 rise_tiles 格。只是氛围。
        grate=False:不画格栅(坑壁裂缝里冒出来的雾)。"""
        self.winds.append((x0, x1, row, rise_tiles, grate))

    def corrosion(self, x0, x1, floor, drag=0.5, haze=0.4, depth=0):
        """第 floor 行地面上 x0..x1 一滩蚀。drag 乘在地面速度上;haze ≥ 0.8 算深蚀(第一次踩进去会恍惚 + 出字)。
        路线搜索里:站在蚀上不能助跑跳空隙,往上跳水平最多 2 格(跑不起来)。"""
        self.corrosions.append((x0, x1, floor, drag, haze))
        if depth:
            self.pool_depths[len(self.corrosions) - 1] = depth
        for x in range(x0, x1 + 1):
            self.corr.add((x, floor))
        return len(self.corrosions) - 1

    def window(self, x0, y0, x1, y1, kind="window"):
        """墙上一扇窗(kind="window",石框 + 铁栏)或一个破口(kind="breach",边缘参差),第 x0..x1 列、
        第 y0..y1 行(含两端)。透过它看到塔外的夜景。只是背景,不挡路、不算暗区。"""
        self.windows.append((x0, y0, x1, y1, kind))

    def vista(self, x0, y0, x1, y1, zoom=1.0, offset=(0, -120), text=""):
        """远景点:Ryn 站进第 x0..x1 列、第 y0..y1 行(含两端),镜头慢慢拉到 zoom(1 = 看到四倍的面积),
        中心往 offset 偏(世界像素);第一次站够了说 text。只放在安全的地方(没有守卫看得到)。"""
        self.vistas.append((x0, y0, x1, y1, zoom, offset, text))

    def style(self, x0, y0, x1, y1, kind):
        """第 x0..x1 列、y0..y1 行里的实心块画成 kind("pipe"/"girder"/"roof"/"masonry")。
        生成时实心块按矩形合并,一块的左上角落在哪个区域就用哪个样子。"""
        self.styles.append((x0, y0, x1, y1, kind))

    def steam(self, x0, x1, row, rise_tiles=5):
        """第 row 行地面上 x0..x1 冒的白色蒸汽(管子接头、阀门)。只是景。"""
        self.steams.append((x0, x1, row, rise_tiles))

    def no_decor(self, x0, y0, x1, y1):
        """第 x0..x1 列、y0..y1 行(含两端)不摆背景道具(`decor.py` 自动摆的那些)。"""
        self.no_decor_areas.append((x0, y0, x1, y1))

    def warm_window(self, x, row):
        """旧屋外墙上一扇亮着暖光的窗,左上角在第 x 列第 row 行。只给旧屋用(美术规格:暖色只给旧屋等)。"""
        self.warm_windows.append((x, row))

    def bolt(self, x, floor):
        """地上一颗可捡的扣件(站在第 floor 行),捡起来身上多一个。"""
        self.bolts.append((x, floor))

    def haze_line(self, text):
        """第一次踩进深蚀(haze ≥ 0.8)时说的那一句。"""
        self.haze_text = text

    def fall_line(self, text):
        """拆地板盖板、真有守卫掉下去时说的那一句(整关一次)。"""
        self.fall_text = text

    # ------------------------------------------------------------ 查询
    def cell(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            c = self.g[y][x]
            if c == "S":      # 铁卷门:关着是墙
                return " " if self._dyn.get((x, y)) in self.mech_open else "#"
            if c == "B":      # 吊桥:放下来才是地
                return "#" if self._dyn.get((x, y)) in self.mech_open else " "
            if c == "K":      # 收折梯:放下来才是梯子;没放时楼板那几格是盖板,底下是空的
                if self._dyn.get((x, y)) in self.mech_open:
                    return "H"
                return "#" if (x, y) in self._fold_slab else " "
            return c
        return "#"

    def is_solid(self, x, y, open_fences=False):
        c = self.cell(x, y)
        if c == "F" and open_fences:
            return False
        return c in SOLID

    def ceiling_px(self, x, floor):
        """第 x 列、站在第 floor 行时,头顶最近那块实心的底边(像素)。"""
        for y in range(floor - 1, -1, -1):
            c = self.cell(x, y)
            if c in SOLID:
                return (y + 1) * TILE + (8 if c == "^" else 0)
        return -10 ** 6

    def clearance(self, x, floor):
        return floor * TILE - self.ceiling_px(x, floor)

    def is_floor(self, x, floor):
        """能不能站在第 x 列第 floor 行上(脚下是实心或梯子顶)。"""
        c = self.cell(x, floor)
        if c in FLOORLIKE:
            return True
        return c == "H" and self.cell(x, floor - 1) != "H"

    def standable(self, x, floor):
        return self.is_floor(x, floor) and self.clearance(x, floor) >= CROUCH_PX

    def stand_mode(self, x, floor):
        return "stand" if self.clearance(x, floor) >= STAND_PX else "crawl"

    def ascii(self):
        rows = []
        for y in range(self.h):
            row = []
            for x in range(self.w):
                c = self.g[y][x]
                if c == " " and self.sh[y][x]:
                    c = "~"
                row.append(c)
            rows.append("".join(row))
        marks = {}
        for (x, f) in self.checkpoints[1:]:
            marks[(x, f - 1)] = "C"
        for (x, f) in self.lockers:
            marks[(x, f - 1)] = "L"
        for i, (a, b) in enumerate(self.vent_pairs):
            marks[(a[0], a[1] - 1)] = str(i + 1)
            marks[(b[0], b[1] - 1)] = str(i + 1)
        for gd in self.guards:
            for x in range(gd.x0, gd.x1 + 1):
                marks.setdefault((x, gd.floor - 1), "-")
            marks[((gd.spawn if gd.spawn is not None else gd.x0), gd.floor - 1)] = "G"
        if self.start_at:
            marks[(self.start_at[0], self.start_at[1] - 1)] = "S"
        if self.exit_at:
            marks[(self.exit_at[0], self.exit_at[1] - 1)] = "E"
        rows = [list(r) for r in rows]
        for (x, y), m in marks.items():
            if 0 <= y < self.h and 0 <= x < self.w:
                rows[y][x] = m
        return "\n".join("".join(r) for r in rows)


# ---------------------------------------------------------------- 路线搜索

Step = collections.namedtuple("Step", "x floor action")


def find_route(lv: Level, allow_vents: bool = True):
    """从出生点到出口的一条路线(BFS,按 Ryn 的能力)。返回 (路线, 可达格子集合)。
    allow_vents=False 时不走通风管 —— 用来验证「不抄近路的主路线」也走得通。

    动作:walk / crawl / jump / gap / drop / climb_up / climb_down / vent / dismantle_hatch / dismantle_fence /
    panel(站在原地拆墙上的机关面板)

    谜题房(2026-10-12):铁卷门、吊桥、通风口盖板一开始是关着的。走不到出口时,找一块走得到、还没拆的
    机关面板(按 BFS 先碰到的那块),走过去拆掉(地图跟着变),再接着找 —— 路线里会依次经过这些面板。
    跑完之后 `lv.mech_open` 是「路线上拆开过的机关」。蒸汽、配电箱不改地形,不在这里。
    """
    start = lv.start_at
    goal = lv.exit_at
    vent_link = {}
    for a, b in (lv.vent_pairs if allow_vents else []):
        vent_link[a] = b
        vent_link[b] = a
    lv.mech_open = set()
    geo = [i for i, m in enumerate(lv.mechs) if m.kind in ("shutter", "bridge", "cover", "ladder")]
    pos = start
    route = [Step(start[0], start[1], "start")]
    reach_all = set()
    while True:
        prev = _bfs(lv, pos, goal, vent_link)
        reach_all |= set(prev)
        if goal in prev:
            return route + _path(prev, goal), reach_all
        order = {node: k for k, node in enumerate(prev)}
        cands = [i for i in geo if i not in lv.mech_open and lv.panel_stand(lv.mechs[i].panel) in order]
        # 替代路线上的机关(收折梯、optional 的铁卷门)主路线不用:先只看别的,实在没有才拆它们(比如掉进坑里)
        main = [i for i in cands if not lv.mechs[i].data.get("optional")]
        cands = main or cands
        if not cands:
            return None, reach_all
        i = min(cands, key=lambda m: order[lv.panel_stand(lv.mechs[m].panel)])
        stand = lv.panel_stand(lv.mechs[i].panel)
        route += _path(prev, stand)
        route.append(Step(stand[0], stand[1], "panel"))
        lv.mech_open.add(i)
        pos = stand


def _bfs(lv: Level, start, goal, vent_link):
    """BFS 从 start 出发;返回 prev 字典(按发现顺序),到 goal 就停。"""
    prev = {start: None}
    queue = collections.deque([start])
    while queue:
        node = queue.popleft()
        if node == goal:
            break
        for nxt, action in _moves(lv, node, vent_link):
            if nxt not in prev:
                prev[nxt] = (node, action)
                queue.append(nxt)
    return prev


def _path(prev, goal):
    path = []
    n = goal
    while prev[n] is not None:
        p, action = prev[n]
        path.append(Step(n[0], n[1], action))
        n = p
    path.reverse()
    return path


def _moves(lv: Level, node, vent_link):
    x, f = node
    standing = lv.clearance(x, f) >= STAND_PX
    # 走 / 蹲着走(含推开栅栏)
    for d in (-1, 1):
        nx = x + d
        if lv.standable(nx, f):
            yield (nx, f), ("walk" if lv.clearance(nx, f) >= STAND_PX and standing else "crawl")
        elif lv.is_floor(nx, f) and any(lv.cell(nx, y) == "F" for y in range(f - 3, f)):
            # 栅栏挡着:拆开后能走(只看栅栏格之外的净空)
            if _clear_after_fence(lv, nx, f):
                yield (nx, f), "dismantle_fence"
    # 掉下去:旁边一列没有地面,往下找第一块地面
    for d in (-1, 1):
        nx = x + d
        if lv.is_floor(nx, f) or _body_blocked(lv, nx, f):
            continue
        for y in range(f, lv.h):
            if lv.is_floor(nx, y):
                if lv.standable(nx, y):
                    yield (nx, y), "drop"
                break
            if lv.is_solid(nx, y):
                break
    # 往上跳:最多 3 格,水平 0..3 格(站在蚀上跑不起来:水平最多 2 格,不能跳空隙)
    corroded = (x, f) in lv.corr
    if standing:
        for k in range(1, JUMP_UP_TILES + 1):
            for d in [dd for dd in range(-JUMP_DX_TILES, JUMP_DX_TILES + 1) if dd]:
                if corroded and abs(d) > 2:
                    continue
                nx, nf = x + d, f - k
                if not lv.standable(nx, nf) or lv.clearance(nx, nf) < STAND_PX:
                    continue
                if lv.clearance(x, f) < STAND_PX + k * TILE:
                    continue
                if _arc_clear(lv, x, f, nx, nf):
                    yield (nx, nf), "jump"
        # 跳过空隙(同高或往下)
        for d in ([] if corroded else list(range(-GAP_TILES, -1)) + list(range(2, GAP_TILES + 1))):
            nx = x + d
            step = 1 if d > 0 else -1
            if lv.is_floor(x + step, f):
                continue          # 不是空隙,走过去就行
            for k in range(0, 7):
                nf = f + k
                if lv.standable(nx, nf) and lv.clearance(nx, nf) >= STAND_PX and _arc_clear(lv, x, f, nx, nf):
                    yield (nx, nf), "gap"
                    break
    # 梯子:站在梯子脚下往上爬,或站在梯子顶往下爬
    if lv.cell(x, f - 1) == "H":
        top = f - 1
        while lv.cell(x, top - 1) == "H":
            top -= 1
        if lv.standable(x, top):
            yield (x, top), "climb_up"
    if lv.cell(x, f) == "H" and lv.cell(x, f - 1) != "H":
        bottom = f
        while lv.cell(x, bottom) == "H":
            bottom += 1
        if lv.standable(x, bottom):
            yield (x, bottom), "climb_down"
    # 通风管(盖着螺栓盖板的管口要先拆)
    if (x, f) in vent_link and lv.vent_open((x, f)):
        yield vent_link[(x, f)], "vent"
    # 拆盖板掉下去
    if lv.cell(x, f) == "D":
        for y in range(f + 1, lv.h):
            if lv.is_floor(x, y) and lv.standable(x, y):
                yield (x, y), "dismantle_hatch"
                break
            if lv.is_solid(x, y):
                break


def _body_blocked(lv: Level, x, f):
    """第 x 列在 Ryn 身体那几行(f-3..f-1)有没有实心(墙)。"""
    return any(lv.is_solid(x, y) for y in range(f - 3, f))


def _clear_after_fence(lv: Level, x, f):
    return all(not lv.is_solid(x, y, open_fences=True) for y in range(f - 3, f))


def _arc_clear(lv: Level, x0, f0, x1, f1):
    """跳跃弧线经过的格子是空的。起点列看到起点地面之上,落点列看到落点地面之上,
    中间各列看到两块地面里较高那块之上;往上看 4 格(身高 3 格 + 余量)。"""
    top = max(min(f0, f1) - 4, 0)
    lo, hi = (x0, x1) if x0 <= x1 else (x1, x0)
    for x in range(lo, hi + 1):
        if x == x0:
            bottom = f0 - 1
        elif x == x1:
            bottom = f1 - 1
        else:
            bottom = min(f0, f1) - 1
        for y in range(top, bottom + 1):
            if lv.is_solid(x, y):
                return False
    return True


# ---------------------------------------------------------------- 检查

def check(lv: Level):
    """返回问题清单(字符串)。空 = 没发现问题。观察,不是判决。"""
    issues = []
    if lv.start_at is None or lv.exit_at is None:
        return ["缺出生点或出口"]
    for name, (x, f) in [("出生点", lv.start_at), ("出口", lv.exit_at)]:
        if not lv.standable(x, f):
            issues.append(f"{name} ({x},{f}) 站不住")
    for gd in lv.guards:
        for x in range(gd.x0, gd.x1 + 1):
            if not lv.is_floor(x, gd.floor):
                issues.append(f"{gd.name} 巡逻线第 {x} 列脚下没地")
                break
            if lv.clearance(x, gd.floor) < 48:
                issues.append(f"{gd.name} 巡逻线第 {x} 列净空 {lv.clearance(x, gd.floor)} < 守卫 48")
                break
        for x in (gd.x0 - 1, gd.x1 + 1):
            pass
        holes = [x for x in range(gd.x0, gd.x1 + 1) if lv.cell(x, gd.floor) == "H"]
        if holes:
            issues.append(f"{gd.name} 巡逻线经过梯子口(第 {holes[0]} 列)—— 守卫会掉下去")
    issues += _blocking_guards(lv)
    for (x, f) in lv.lockers:
        if not lv.is_floor(x, f):
            issues.append(f"柜子 ({x},{f}) 脚下没地")
        if lv.clearance(x, f) < 48:
            issues.append(f"柜子 ({x},{f}) 净空不够 48")
    for a, b in lv.vent_pairs:
        for (x, f) in (a, b):
            if not lv.is_floor(x, f):
                issues.append(f"通风管口 ({x},{f}) 脚下没地")
    for (x, f) in lv.checkpoints:
        if not lv.standable(x, f):
            issues.append(f"存档点 ({x},{f}) 站不住")
    for (x, f, _) in lv.pickups:
        if not lv.is_floor(x, f):
            issues.append(f"道具 ({x},{f}) 脚下没地")
    for i, (x, f, _, _, _) in enumerate(lv.terminals):
        w = math.ceil(lv.terminal_records[i][1][0] / TILE) if i in lv.terminal_records else 3
        if not all(lv.is_floor(xx, f) for xx in range(x, x + w)):
            issues.append(f"终端 ({x},{f}) 脚下没地")
    for (look, x, f, _r) in lv.panels:
        if look != "vent_cover" and not lv.standable(x, f):
            issues.append(f"机关面板({look}) ({x},{f}) 站不住")
    for m in lv.mechs:
        if m.kind == "bridge":
            d = m.data
            hx = d["x0"] if d["hinge"] == "left" else d["x1"]
            n = d["x1"] - d["x0"] + 1
            if any(lv.g[y][hx] not in " B" for y in range(max(d["row"] - n, 0), d["row"])):
                issues.append(f"吊桥 ({d['x0']}..{d['x1']},{d['row']}) 竖起来会撞到东西(铰链那一列往上 {n} 格要空)")
    names = {gd.name: gd for gd in lv.guards}
    for ch in lv.chats:
        for who, mx in ((ch["a"], ch["meet"][0]), (ch["b"], ch["meet"][1])):
            gd = names.get(who)
            if gd is None:
                issues.append(f"守卫聊天:没有叫 {who} 的守卫")
            elif mx not in (gd.x0, gd.x1):
                issues.append(f"守卫聊天:{who} 的碰头点 {mx} 不在巡逻线两头({gd.x0}/{gd.x1}),走不到会一直等")
    for (x0, x1, row, _, _) in lv.winds:
        if not all(lv.cell(xx, row) in FLOORLIKE for xx in range(x0, x1 + 1)):
            issues.append(f"格栅 ({x0}..{x1},{row}) 不在地面上")
    for (x, f) in lv.bolts:
        if not lv.is_floor(x, f):
            issues.append(f"扣件 ({x},{f}) 脚下没地")
    for (x0, x1, f, _, _) in lv.corrosions:
        if not all(lv.is_floor(x, f) for x in range(x0, x1 + 1)):
            issues.append(f"蚀 ({x0}..{x1},{f}) 不全在地面上")
    if lv.haze_text and not any(h >= 0.8 for (_, _, _, _, h) in lv.corrosions):
        issues.append("有恍惚那一句,但没有深蚀(haze ≥ 0.8)")
    if lv.fall_text and not any(lv.cell(x, gd.floor) == "D" for gd in lv.guards
                                for x in range(gd.x0, gd.x1 + 1)):
        issues.append("有「守卫摔下去」那一句,但没有守卫走在盖板上")
    return issues


def checkpoint_route_issues(lv: Level, route, route_alt=None):
    """存档点在不在路线上(2026-10-13 全流程体检)。存档点的感应框只有 28px 宽(不到两格),放在梯子口、
    落点旁边一两格,玩家下来就往前走了,根本碰不到 —— 体检时 10 个存档点是这样漏掉的。

    规则:同一层、离路线站过的格子不超过 1 格(Ryn 的身子碰得到感应框)。两条路线(走 / 不走通风管)
    有一条经过就算数。"""
    if not route:
        return []
    feet = {(st.x, st.floor) for st in route if st.action != "panel"}
    if route_alt:
        feet |= {(st.x, st.floor) for st in route_alt if st.action != "panel"}
    issues = []
    for (x, f) in lv.checkpoints:
        same = [xx for (xx, ff) in feet if ff == f]
        gap = min((abs(xx - x) for xx in same), default=None)
        if gap is None:
            issues.append(f"存档点 ({x},{f}) 不在路线经过的任何一层 —— 照路线走碰不到")
        elif gap > 1:
            near = min(same, key=lambda xx: abs(xx - x))
            issues.append(f"存档点 ({x},{f}) 离路线 {gap} 格(路线最近站在第 {near} 列)—— 照路线走碰不到")
    return issues


def story_reach_issues(lv: Level, reach):
    """剧情触发点走不走得到(用 find_route 的可达落脚点)。"""
    issues = []
    feet = set(reach)
    for (x0, y0, x1, y1, text) in lv.stories:
        if not any(x0 <= x <= x1 and y0 <= f - 1 <= y1 for (x, f) in feet):
            issues.append(f"旁白触发区 ({x0},{y0})-({x1},{y1}) 走不到:{text}")
    for (x, f, text) in lv.pickups:
        if (x, f) not in feet:
            issues.append(f"道具 ({x},{f}) 走不到:{text}")
    for (x, f, word, t0, t1) in lv.terminals:
        if not any(t0 <= xx <= t1 and ff == f for (xx, ff) in feet):
            issues.append(f"终端「{word}」的触发区 ({t0}..{t1},{f}) 走不到")
    for (x, f) in lv.bolts:
        if (x, f) not in feet:
            issues.append(f"扣件 ({x},{f}) 走不到")
    for (x0, y0, x1, y1, _, _, _) in lv.vistas:
        if not any(x0 <= x <= x1 and y0 <= f - 1 <= y1 for (x, f) in feet):
            issues.append(f"远景点 ({x0},{y0})-({x1},{y1}) 走不到")
    for (_, _, text, (x0, y0, x1, y1)) in lv.broadcasts:
        if not any(x0 <= x <= x1 and y0 <= f - 1 <= y1 for (x, f) in feet):
            issues.append(f"广播触发区 ({x0},{y0})-({x1},{y1}) 走不到:{text}")
    for ch in lv.chats:
        x0, y0, x1, y1 = ch["approach"]
        if not any(x0 <= x <= x1 and y0 <= f - 1 <= y1 for (x, f) in feet):
            issues.append(f"守卫聊天的靠近区 ({x0},{y0})-({x1},{y1}) 走不到")
    if lv.haze_text:
        deep = {(x, f) for (x0, x1, f, _, h) in lv.corrosions if h >= 0.8 for x in range(x0, x1 + 1)}
        if not deep & feet:
            issues.append("深蚀走不到(恍惚那一句不会出)")
    return issues


# ---------------------------------------------------------------- 探照灯时序(2026-10-14)

SWEEP_DWELL = 0.18              # sweep_light.gd 的默认停留比例(生成器不改它)
TORSO_PX = STAND_PX / 2         # 灯和守卫都采样躯干中点
WALK_PX_S, SPRINT_PX_S, CRAWL_PX_S, CLIMB_PX_S = 105.0, 170.0, 44.0, 40.0   # 爬速跟 ryn_movement.tres(2026-10-15 56 → 40)
GRAVITY, FALL_GRAVITY, MAX_FALL, JUMP_PX = 900.0, 1215.0, 380.0, 56.0
BEAM_MARGIN = 8.0               # 人不是逐帧操作:灯柱两边各多算 8px
HIDE_S, UNHIDE_S = 0.2, 0.1     # 走到柜子前停下、按 E 躲进去 / 按 E 出来:这段时间人还露在外面
SWEEP_HORIZON = 40.0            # 每段最多算 40 秒
_DT = TILE / WALK_PX_S / 3      # 时间步:走一格正好 3 步


def sweep_offset(sw: Sweep, t: float) -> float:
    """第 t 秒灯柱相对灯座的 x 偏移(px)。照抄 `SweepLight._offset_at`:两端停留的三角波 + smoothstep。"""
    period = max(sw.period, 0.0001)
    u = math.fmod(sw.phase * period + t, period) / period
    d, half = SWEEP_DWELL, 0.5
    if u < d:
        f = 0.0
    elif u < half:
        f = (u - d) / (half - d)
    elif u < half + d:
        f = 1.0
    else:
        f = 1.0 - min(max((u - half - d) / (half - d), 0.0), 1.0)
    return f * f * (3.0 - 2.0 * f) * sw.span_tiles * TILE


def _in_sweep_band(sw: Sweep, x, f, extra=0.0):
    """站在第 x 列第 f 行时,躯干在不在这盏灯扫得到的范围里(整段扫程)。"""
    px, py = x * TILE + 8, f * TILE - TORSO_PX
    sx = sw.x * TILE + 8
    lo, hi = sorted((sx, sx + sw.span_tiles * TILE))
    return lo - sw.width / 2 - extra <= px <= hi + sw.width / 2 + extra and \
        sw.row * TILE <= py <= sw.stop.get(int(px // TILE), sw.row) * TILE


def _move_time(a, b, action, sprint):
    (x0, f0), (x1, f1) = a, b
    dx = abs(x1 - x0) * TILE
    if action == "walk":
        return TILE / (SPRINT_PX_S if sprint else WALK_PX_S)
    if action == "crawl":
        return TILE / CRAWL_PX_S
    if action in ("climb_up", "climb_down"):
        return abs(f1 - f0) * TILE / CLIMB_PX_S
    t_up = math.sqrt(2 * JUMP_PX / GRAVITY)
    if action == "jump":
        fall = max(JUMP_PX - (f0 - f1) * TILE, 0.0)
        return max(t_up + math.sqrt(2 * fall / FALL_GRAVITY), dx / WALK_PX_S)
    if action == "gap":
        fall = JUMP_PX + (f1 - f0) * TILE
        return max(t_up + math.sqrt(2 * fall / FALL_GRAVITY), dx / SPRINT_PX_S)
    if action == "drop":
        h = (f1 - f0) * TILE
        t_cap = MAX_FALL / FALL_GRAVITY
        h_cap = 0.5 * FALL_GRAVITY * t_cap * t_cap
        t = math.sqrt(2 * h / FALL_GRAVITY) if h <= h_cap else t_cap + (h - h_cap) / MAX_FALL
        return 0.1 + t
    if action == "vent":
        return 0.8
    return 1.0


def _sweep_passable(lv: Level, sweeps, nodes, a, b, sprint, margin):
    """(落脚点, 时刻) 上的 BFS:从 a 出发(时刻任选 —— a 在灯带外,可以一直等)走得到 b 吗。"""
    steps = int(SWEEP_HORIZON / _DT)
    cx = [[sw.x * TILE + 8 + sweep_offset(sw, k * _DT) for k in range(steps + 1)] for sw in sweeps]
    lit_cache = {}

    def lit(px, py, mg=margin):
        key = (round(px), round(py), mg)
        row = lit_cache.get(key)
        if row is None:
            row = bytearray(steps + 1)
            for i, sw in enumerate(sweeps):
                if not sw.row * TILE <= py <= sw.stop.get(int(px // TILE), sw.row) * TILE:
                    continue
                c, w = cx[i], sw.width / 2 + mg
                for k in range(steps + 1):
                    if abs(px - c[k]) <= w:
                        row[k] = 1
            lit_cache[key] = row
        return row

    lockers = set(lv.lockers)
    vent_link = {}
    for p, q in lv.vent_pairs:
        vent_link[p], vent_link[q] = q, p
    torso = lambda n: (n[0] * TILE + 8, n[1] * TILE - TORSO_PX)
    edges = {}
    for n in nodes:
        out = []
        for nxt, action in _moves(lv, n, vent_link):
            if nxt not in nodes:
                continue
            m = max(1, round(_move_time(n, nxt, action, sprint) / _DT))
            (x0, y0), (x1, y1) = torso(n), torso(nxt)
            rows = [] if action == "vent" else \
                [lit(x0 + (x1 - x0) * j / m, y0 + (y1 - y0) * j / m) for j in range(1, m + 1)]
            out.append((nxt, m, rows))
        # 灯永远照不到的格子(不加余量算)站着等就是安全的 —— 余量只给「赶时间」用
        safe_spot = not any(lit(*torso(n), 0.0))
        edges[n] = (lit(*torso(n)), safe_spot, n in lockers, out)
    hide_m, unhide_m = round(HIDE_S / _DT), round(UNHIDE_S / _DT)
    # 状态 = (落脚点, 时刻, 躲着没);seen[n] 前一半记没躲、后一半记躲着
    seen = {n: bytearray(2 * (steps + 1)) for n in nodes}
    seen[a][0] = 1
    queue = collections.deque([(a, 0, 0)])

    def push(n, k, h):
        if k <= steps and not seen[n][h * (steps + 1) + k]:
            seen[n][h * (steps + 1) + k] = 1
            queue.append((n, k, h))

    while queue:
        n, k, h = queue.popleft()
        if n == b:
            return True
        here, safe_spot, is_locker, out = edges[n]
        if h:
            push(n, k + 1, 1)
            # 出柜子:这几步人已经露出来了
            if k + unhide_m <= steps and not any(here[k + 1:k + unhide_m + 1]):
                push(n, k + unhide_m, 0)
            continue
        if k < steps and (safe_spot or not here[k + 1]):
            push(n, k + 1, 0)
        # 进柜子:要先停下来、按 E,这几步还露在外面
        if is_locker and k + hide_m <= steps and not any(here[k + 1:k + hide_m + 1]):
            push(n, k + hide_m, 1)
        for nxt, m, rows in out:
            if k + m > steps or seen[nxt][k + m]:
                continue
            if any(r[k + j + 1] for j, r in enumerate(rows)):
                continue
            push(nxt, k + m, 0)
    return False


def sweep_timing_issues(lv: Level, route, reach):
    """探照灯过不过得去(2026-10-14 真人试玩:高空栈桥后半截怎么走都会被照到)。

    灯柱照得穿暗处,只有柜子挡得住(`sweep_light.gd`)。灯柱一路照到地面时,要从灯的一边走到另一边,
    中途一定会和灯柱重叠 —— 那一刻不在柜子里就被抓。所以光有柜子不够,还要来得及躲:灯扫得比人走得快。

    做法:扫到路线的灯按灯带分组(路线上连着的几盏算一组),取路线进灯带前最后一个落脚点 A、出来后
    第一个 B,在灯带附近的格子上做「(落脚点, 时刻)」的 BFS。每一步按 Ryn 的速度花时间(走、爬梯、跳、掉),
    途中每个时刻躯干都不能在灯柱里(灯柱两边各多算 BEAM_MARGIN);停下来等:柜子里、灯永远照不到的格子
    (这里不加余量 —— 站着不动不用抢时间),或这一刻照不到的格子。到得了 B 才算过得去。

    只看灯,不看守卫(守卫是 `_blocking_guards` 的事)。整组都接在配电箱上的灯跳过(断电就是那一关的解法)。
    标准是用户定的「用走的就过得去」:要按 Shift 跑才过得去也报。观察,不是判决。"""
    if not route or not lv.sweeps:
        return []
    fused = set()
    for m in lv.mechs:
        if m.kind == "fuse":
            fused |= set(m.data.get("sweeps", []))
    issues, done = [], set()
    for i in range(len(lv.sweeps)):
        if i in done:
            continue
        idx = [k for k, st in enumerate(route) if _in_sweep_band(lv.sweeps[i], st.x, st.floor)]
        if not idx:
            done.add(i)
            continue
        group, lo, hi = {i}, idx[0], idx[-1]
        while True:
            a, b = max(lo - 1, 0), min(hi + 1, len(route) - 1)
            grown = {j for j, sw in enumerate(lv.sweeps)
                     if any(_in_sweep_band(sw, st.x, st.floor) for st in route[a:b + 1])}
            span = [k for k, st in enumerate(route)
                    if any(_in_sweep_band(lv.sweeps[j], st.x, st.floor) for j in grown)
                    and lo - 1 <= k <= hi + 1]
            nlo, nhi = min(span + [lo]), max(span + [hi])
            if grown == group and (nlo, nhi) == (lo, hi):
                break
            group, lo, hi = grown, nlo, nhi
        done |= group
        names = "/".join(f"Sweep{j:02d}" for j in sorted(group))
        if group <= fused:
            continue
        a, b = max(lo - 1, 0), min(hi + 1, len(route) - 1)
        A, B = (route[a].x, route[a].floor), (route[b].x, route[b].floor)
        sws = [lv.sweeps[j] for j in sorted(group)]
        x_lo = min(min(sw.x, sw.x + sw.span_tiles) for sw in sws) - 8
        x_hi = max(max(sw.x, sw.x + sw.span_tiles) for sw in sws) + 8
        nodes = {n for n in reach if x_lo <= n[0] <= x_hi} | {A, B}
        if _sweep_passable(lv, sws, nodes, A, B, sprint=False, margin=BEAM_MARGIN):
            continue
        if _sweep_passable(lv, sws, nodes, A, B, sprint=True, margin=BEAM_MARGIN):
            issues.append(f"探照灯 {names}:路线 {A}→{B} 要按 Shift 跑才过得去(用走的来不及躲)")
        else:
            issues.append(f"探照灯 {names}:路线 {A}→{B} 过不去 —— 灯柱照到地面、扫过整段,"
                          "中间没有来得及躲进去的柜子")
    return issues


def double_jump_bypass_issues(lv: Level):
    """二段跳会不会让谜题房被跳过(2026-10-14 用户加二段跳)。

    一段跳的路线拆开过的机关(铁卷门、吊桥、通风口盖板 —— 改地形的那几种),一个一个拿掉:
    这个关着、别的照旧拆开,一段跳到不了出口、二段跳(往上 5 格、跳远 10 格,往宽了算)到得了,
    就说明这个机关可以不解、直接跳过去。路线会顺手拆掉不是非拆不可的面板(BFS 先碰到哪块拆哪块),
    所以一段跳本来就绕得过的不算。蒸汽、断电不改地形,不在这里。"""
    global JUMP_UP_TILES, JUMP_DX_TILES, GAP_TILES
    route, _ = find_route(lv)
    if route is None or not lv.mech_open:
        return []
    needed = set(lv.mech_open)
    saved = (JUMP_UP_TILES, JUMP_DX_TILES, GAP_TILES)
    issues = []
    names = {"shutter": "铁卷门", "bridge": "吊桥", "cover": "通风口盖板", "ladder": "收折梯"}
    try:
        for i in sorted(needed):
            lv.mech_open = needed - {i}
            JUMP_UP_TILES, JUMP_DX_TILES, GAP_TILES = saved
            if _reachable_without(lv, set()):
                continue          # 一段跳就绕得过:这块本来就不是非拆不可
            JUMP_UP_TILES, JUMP_DX_TILES, GAP_TILES = DJ_JUMP_UP_TILES, DJ_JUMP_DX_TILES, DJ_GAP_TILES
            if _reachable_without(lv, set()):
                m = lv.mechs[i]
                px, pf = lv.panel_stand(m.panel) or ("?", "?")
                issues.append(f"二段跳能跳过{names.get(m.kind, m.kind)}(面板在 {px},{pf}):不拆也到得了出口")
    finally:
        JUMP_UP_TILES, JUMP_DX_TILES, GAP_TILES = saved
        lv.mech_open = needed
    return issues


def _blocking_guards(lv: Level):
    """守卫挡在必经之路上、却没有地方躲 —— 用户说的「巡逻卡住」。

    把一个守卫的巡逻段(那一层的那几格)从地图上拿掉,如果出生点因此到不了出口,这段就是
    必经之路。必经之路上的守卫,巡逻范围(含两端各 2 格)里必须有地方躲 —— 一维走廊里
    守卫走回来时,玩家只能躲,不能绕。「地方躲」按守卫怎么发现人来算(2026-10-13 三种守卫):
      - 看(sight):暗区或柜子(谜题房的临时暗处也算);
      - 听(hearing):暗处没用(他会撞上你)—— 柜子或通风管口;
      - 追(tracking):躲着不动会被顺着痕迹找到 —— 要一路走到这一层的出口(梯子、往下的口子、通风管口、蚀)
        甩掉痕迹,中间不能有逼人停下来的门禁 / 面板(他追得比 Ryn 走得慢)。"""
    issues = []
    route, _ = find_route(lv)
    if route is None:
        return issues
    for gd in lv.guards:
        blocked = {(x, gd.floor) for x in range(gd.x0, gd.x1 + 1)}
        if _reachable_without(lv, blocked):
            continue
        lo, hi = gd.x0 - 2, gd.x1 + 2
        cols = range(max(lo, 0), min(hi, lv.w - 1) + 1)
        locker = any(lo <= x <= hi and f == gd.floor for (x, f) in lv.lockers)
        vent = any(lo <= x <= hi and f == gd.floor for a, b in lv.vent_pairs for (x, f) in (a, b))
        if gd.sense == "hearing":
            if not (locker or vent):
                issues.append(f"{gd.name}(听)挡在必经之路上(第 {gd.floor} 行 {gd.x0}..{gd.x1}),"
                              "巡逻范围里没有柜子或通风管口 —— 暗处躲不过听的守卫")
            continue
        if gd.sense == "tracking":
            # 顺着痕迹追的速度(46 × 1.9 ≈ 87 px/s)比 Ryn 走路(105 px/s)慢:只要一直往前走,一定比他先到
            # 这一层的出口(梯子、往下的口子、通风管口)。所以要查的不是「出口近不近」,而是「从他到出口
            # 这一段,有没有逼 Ryn 停下来的东西」—— 门禁要等、机关面板要长按。都没有才公平。
            exits = [x for x in range(lv.w) if lv.cell(x, gd.floor) in ("H", " ") or lv.cell(x, gd.floor - 1) == "H"]
            exits += [x for a, b in lv.vent_pairs for (x, f) in (a, b) if f == gd.floor]
            exits += [x0 for (x0, x1, f, *_r) in lv.corrosions if f == gd.floor] + \
                     [x1 for (x0, x1, f, *_r) in lv.corrosions if f == gd.floor]
            def clear_between(ex):
                a, b = min(gd.x0, ex), max(gd.x1, ex)
                if any(gt.floor == gd.floor and gt.x1 >= a and gt.x0 <= b for gt in lv.gates):
                    return False
                return not any(f == gd.floor and a <= x <= b for (_look, x, f, _r) in lv.panels)
            if not any(clear_between(ex) for ex in exits):
                issues.append(f"{gd.name}(追)挡在必经之路上(第 {gd.floor} 行 {gd.x0}..{gd.x1}),"
                              "这一层到出口之间有逼人停下的门禁 / 面板 —— 甩不掉痕迹")
            continue
        hide = locker or any(lv.sh[gd.floor - 2][x] for x in cols)
        # 谜题房:蒸汽 / 断电造出来的临时暗处也算(那就是这一关的解法)
        hide = hide or any((x, gd.floor - 2) in lv.temp_shade for x in range(lo, hi + 1))
        if not hide:
            issues.append(f"{gd.name} 挡在必经之路上(第 {gd.floor} 行 {gd.x0}..{gd.x1}),巡逻范围里没有暗区或柜子可躲")
    return issues


def _reachable_without(lv: Level, blocked):
    vent_link = {}
    for a, b in lv.vent_pairs:
        vent_link[a] = b
        vent_link[b] = a
    seen = {lv.start_at}
    queue = collections.deque([lv.start_at])
    while queue:
        node = queue.popleft()
        if node == lv.exit_at:
            return True
        for nxt, _ in _moves(lv, node, vent_link):
            if nxt not in seen and nxt not in blocked:
                seen.add(nxt)
                queue.append(nxt)
    return False


def area_tiles(lv: Level):
    return lv.w * lv.h
