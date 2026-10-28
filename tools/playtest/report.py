#!/usr/bin/env python3
"""真人试玩报告(2026-10-14,`design/ideas-backlog.md` K7)。

读 `PlaytestLog`(`src/dev/playtest_log.gd`,编辑器里跑游戏时自动开)写的 `user://playtest/*.jsonl`,出:

    production/qa/playtest-<日期>.md          每关:用时、被发现几次 / 被谁 / 当时在干嘛、差点被发现(守卫起疑)、
                                              存档点之间用时、重生后马上又被抓、和机器人体检(pacing-*.json)对照
    production/qa/playtest-<日期>/<场景>.png  热点图:走过的地方(青,越亮待得越久)、被发现(红 ×,细线连到抓人的守卫 / 灯)、
                                              守卫起疑(黄点)、踩到的存档点(绿菱形)、丢扣件(白点)

只出观察,不下结论(CLAUDE.md:helpers emit observations, never verdicts)—— 标出来的是「值得看一眼」,
难不难、要不要改,由试玩的人定。

    python3 tools/playtest/report.py                     # 读全部试玩记录
    python3 tools/playtest/report.py --since 2026-10-14  # 只读这天(含)以后开始的
    python3 tools/playtest/report.py a.jsonl b.jsonl     # 指定文件
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
USER_DIR = Path.home() / "Library/Application Support/Godot/app_userdata/The Cradle/playtest"
TILE = 16
PREVIEW_PX_PER_TILE = 4          # tools/level_builder/build.py preview(scale=4)
MAP_SCALE = 2                    # 热点图:预览图放大 2 倍 → 世界坐标 / 2
HEAT_CELL = 16                   # 走过的地方按 16px(一格)一个方块累计
QUICK_RECATCH_S = 5.0            # 重生后这么快又被抓,单独列出来(K5)
HOTSPOT_CELL = 4 * TILE          # 被发现的位置按 4x4 格归堆

DOING = {"stand": "站着", "walk": "走", "run": "跑", "crouch": "蹲着", "sneak": "蹲着走", "climb": "爬梯",
         "hide": "躲着", "air": "空中", "aim": "瞄准"}
BY = {"guard_sight": "「看」的守卫", "guard_hearing": "「听」的守卫", "guard_tracking": "「追」的守卫",
      "sweep": "探照灯", "gate": "门禁灯", "vera": "Vera", "other": "其他"}
LEAVE = {"next": "过关", "restart": "重开这关", "menu": "回主菜单", "quit": "退出游戏", "other": "换到别的场景"}
ENDING_SCENE = "res://src/levels/old_house_ending.tscn"   # 坑底演完进结局(不在 LevelSequence.ORDER 里)


# ---------------------------------------------------------------- 读

def read_sequence() -> list[tuple[str, str]]:
    src = (ROOT / "src/levels/level_sequence.gd").read_text(encoding="utf-8")
    order = re.findall(r'"(res://[^"]+\.tscn)"', src.split("const ORDER")[1].split("const TITLES")[0])
    titles = re.findall(r'"([^"]+)"', src.split("const TITLES")[1].split("= [")[1].split("]")[0])
    return list(zip(order, titles))


def builder_keys() -> dict[str, str]:
    """场景路径 → tools/level_builder/levels/<key>.py 的 key(有预览图 design/levels/<key>.png)。"""
    out = {}
    for p in (ROOT / "tools/level_builder/levels").glob("*.py"):
        m = re.search(r'^SCENE\s*=\s*"([^"]+)"', p.read_text(encoding="utf-8"), re.M)
        if m:
            out[f"res://src/levels/{m.group(1)}.tscn"] = p.stem
    return out


def latest_pacing() -> tuple[str, dict]:
    files = sorted((ROOT / "production/qa").glob("pacing-*.json"))
    if not files:
        return "", {}
    return files[-1].name, json.loads(files[-1].read_text(encoding="utf-8"))


def load_events(path: Path) -> list[dict]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                pass          # 闪退时最后一行可能只写了一半
    return out


class Visit:
    """进一次关到离开(过关 / 回菜单 / 退出 / 闪退)。"""

    def __init__(self, session: str, scene: str):
        self.session = session
        self.scene = scene
        self.events: list[dict] = []
        self.time = 0.0
        self.how = "quit"

    def of(self, kind: str) -> list[dict]:
        return [e for e in self.events if e.get("ev") == kind]


def split_visits(session: str, events: list[dict], order: list[str]) -> list[Visit]:
    visits: list[Visit] = []
    cur: Visit | None = None
    for e in events:
        ev = e.get("ev")
        if ev == "enter":
            if cur is not None:          # 没写 leave 就换关了(不该发生,保险)
                visits.append(cur)
            cur = Visit(session, e["scene"])
        elif cur is None:
            continue
        elif ev == "leave":
            cur.time = float(e.get("lt", cur.time))
            visits.append(cur)
            cur = None
        else:
            cur.events.append(e)
            cur.time = max(cur.time, float(e.get("lt", 0.0)))
    if cur is not None:                  # 闪退:没有 leave
        visits.append(cur)
    for a, b in zip(visits, visits[1:]):
        if a.session != b.session:
            continue
        if a.scene in order and order.index(a.scene) + 1 < len(order) and order[order.index(a.scene) + 1] == b.scene:
            a.how = "next"
        elif b.scene == ENDING_SCENE:
            a.how = "next"
        elif b.scene == a.scene:
            a.how = "restart"          # 暂停菜单「重来这一关」
        elif b.scene.endswith("main_menu.tscn"):
            a.how = "menu"
        else:
            a.how = "other"
    return [v for v in visits if not v.scene.endswith("main_menu.tscn")]


# ---------------------------------------------------------------- 算

def fmt_t(sec: float) -> str:
    sec = max(0.0, sec)
    return f"{int(sec // 60)}:{int(sec % 60):02d}"


def tile(e: dict) -> str:
    return f"列 {int(e['x']) // TILE}、行 {int(e['y']) // TILE}"


def segments(v: Visit) -> list[dict]:
    """存档点之间:从踩到这个存档点,到踩到下一个(或离开这关)。死了从这个存档点重来,时间也算进这一段。"""
    cps = v.of("cp")
    marks = [("(开场)", 0.0)] + [(c["name"], float(c["lt"])) for c in cps]
    out = []
    for i, (name, t0) in enumerate(marks):
        t1 = marks[i + 1][1] if i + 1 < len(marks) else v.time
        nxt = marks[i + 1][0] if i + 1 < len(marks) else LEAVE[v.how]
        if name == "(开场)" and t1 - t0 < 0.5:
            continue                      # 出生就站在存档点上
        fl = [e for e in v.of("fail") if t0 <= float(e["lt"]) < t1]
        out.append({"from": name, "to": nxt, "time": t1 - t0, "fails": fl})
    return out


def hotspots(fails: list[dict]) -> list[tuple[tuple[int, int], list[dict]]]:
    cells: dict[tuple[int, int], list[dict]] = defaultdict(list)
    for e in fails:
        if "x" in e:
            cells[(int(e["x"]) // HOTSPOT_CELL, int(e["y"]) // HOTSPOT_CELL)].append(e)
    return sorted(((k, v) for k, v in cells.items() if len(v) >= 2), key=lambda kv: -len(kv[1]))


# ---------------------------------------------------------------- 画

def font(size: int):
    for p in ("/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def heatmap(scene: str, title: str, visits: list[Visit], key: str | None, out: Path) -> None:
    pos = [e for v in visits for e in v.of("pos")]
    if key and (ROOT / f"design/levels/{key}.png").exists():
        base = Image.open(ROOT / f"design/levels/{key}.png").convert("RGB")
        base = base.resize((base.width * MAP_SCALE, base.height * MAP_SCALE), Image.NEAREST)
        k = PREVIEW_PX_PER_TILE * MAP_SCALE / TILE           # 世界 px → 图 px
        ox = oy = 0.0
    else:                                                    # 没有生成器预览图(序章、坑底):按走过的范围开一张底
        xs = [float(e["x"]) for e in pos] or [0.0]
        ys = [float(e["y"]) for e in pos] or [0.0]
        k = 1.0 / MAP_SCALE
        ox, oy = min(xs) - 96, min(ys) - 160
        base = Image.new("RGB", (int((max(xs) - ox + 96) * k) + 1, int((max(ys) - oy + 64) * k) + 1), (12, 16, 26))

    def P(x, y):
        return ((float(x) - ox) * k, (float(y) - oy) * k)

    img = base.copy()
    # 压暗底图,让标记跳出来
    img = Image.blend(img, Image.new("RGB", img.size, (8, 10, 16)), 0.35)
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    # 走过的地方:Ryn 的位置在脚底,往上挪半个身高画
    heat = Counter((int(e["x"]) // HEAT_CELL, (int(e["y"]) - 20) // HEAT_CELL) for e in pos)
    if heat:
        top = max(heat.values())
        for (cx, cy), n in heat.items():
            a = int(60 + 170 * math.log1p(n) / math.log1p(top))
            x0, y0 = P(cx * HEAT_CELL, cy * HEAT_CELL)
            x1, y1 = P((cx + 1) * HEAT_CELL, (cy + 1) * HEAT_CELL)
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=(70, 200, 230, a))
    for v in visits:
        for e in v.of("cp"):
            x, y = P(e["x"], e["y"] - 8)
            d.polygon([(x, y - 5), (x + 4, y), (x, y + 5), (x - 4, y)], fill=(120, 230, 120, 255), outline=(10, 30, 10, 255))
        for e in v.of("throw"):
            x, y = P(e["x"], e["y"] - 20)
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(240, 240, 240, 230))
        for e in v.of("alert"):
            x, y = P(e["x"], e["y"] - 20)
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(250, 210, 60, 230), outline=(40, 30, 0, 255))
        for e in v.of("fail"):
            if "x" not in e:
                continue
            x, y = P(e["x"], e["y"] - 20)
            if "sx" in e:
                sx, sy = P(e["sx"], e["sy"] - 20)
                d.line([x, y, sx, sy], fill=(240, 80, 70, 120), width=1)
            for w, c in ((4, (20, 0, 0, 255)), (2, (255, 70, 60, 255))):
                d.line([x - 5, y - 5, x + 5, y + 5], fill=c, width=w)
                d.line([x - 5, y + 5, x + 5, y - 5], fill=c, width=w)
    img = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")
    # 标题条放在地图上面,不盖住塔顶
    fails = sum(len(v.of("fail")) for v in visits)
    label = f"{title}  ·  用时 {fmt_t(sum(v.time for v in visits))}  ·  被发现 {fails}"
    page = Image.new("RGB", (max(img.width, 360), img.height + 24), (8, 10, 16))
    page.paste(img, (0, 24))
    ImageDraw.Draw(page).text((6, 4), label, fill=(220, 226, 236), font=font(14))
    out.parent.mkdir(parents=True, exist_ok=True)
    page.save(out)


# ---------------------------------------------------------------- 写

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--dir", type=Path, default=USER_DIR)
    ap.add_argument("--since", help="只读这天(含)以后开始的,YYYY-MM-DD")
    ap.add_argument("--out", type=Path, default=ROOT / "production/qa")
    ap.add_argument("--date", default=dt.date.today().isoformat(), help="报告文件名里的日期")
    args = ap.parse_args()

    files = args.files or sorted(args.dir.glob("*.jsonl"))
    if args.since:
        files = [f for f in files if f.stem[:10] >= args.since]
    if not files:
        print(f"没有试玩记录(找的是 {args.dir})。在编辑器里跑一次游戏就会有。", file=sys.stderr)
        return 1

    seq = read_sequence()
    order = [s for s, _ in seq]
    titles = dict(seq)
    keys = builder_keys()
    pacing_name, pacing = latest_pacing()

    visits: list[Visit] = []
    sessions = []
    for f in files:
        ev = load_events(f)
        if not ev:
            continue
        sessions.append((f.name, ev[0].get("started", f.stem), float(ev[-1].get("t", 0.0)), ev[-1].get("ev") == "end"))
        visits += split_visits(f.name, ev, order)
    if not visits:
        print("记录里没有进过任何一关。", file=sys.stderr)
        return 1

    by_scene: dict[str, list[Visit]] = defaultdict(list)
    for v in visits:
        by_scene[v.scene].append(v)
    scenes = sorted(by_scene, key=lambda s: order.index(s) if s in order else 99)

    img_dir = args.out / f"playtest-{args.date}"
    md: list[str] = []
    w = md.append
    total_t = sum(v.time for v in visits)
    all_fails = [e for v in visits for e in v.of("fail")]
    all_pos = [e for v in visits for e in v.of("pos")]
    w(f"# 试玩报告 {args.date}")
    w("")
    w(f"`tools/playtest/report.py` 由 `PlaytestLog`(`src/dev/playtest_log.gd`)的记录生成。**只有观察,没有结论** ——")
    w("标出来的是「值得看一眼」,难不难、要不要改由试玩的人定。")
    w("")
    w(f"- 记录 {len(sessions)} 段:" + "、".join(
        f"{s[1]}({fmt_t(s[2])}{'' if s[3] else ',没有正常结束'})" for s in sessions))
    w(f"- 关卡里共 {fmt_t(total_t)}(暂停不算),进了 {len(scenes)} 个场景,被发现 {len(all_fails)} 次,"
      f"守卫起疑 {sum(len(v.of('alert')) for v in visits)} 次")
    if all_pos:
        shade = sum(1 for e in all_pos if e.get("shade")) / len(all_pos)
        mix = Counter(e.get("do", "?") for e in all_pos)
        w(f"- 在暗处的时间 {shade:.0%};动作:" + "、".join(
            f"{DOING.get(k, k)} {n / len(all_pos):.0%}" for k, n in mix.most_common()))
    w("")
    w("热点图图例:青 = 走过的地方(越亮待得越久)· 红 × = 被发现(细线连到抓人的守卫 / 灯)· 黄点 = 守卫起疑 ·")
    w("绿菱形 = 踩到的存档点 · 白点 = 丢扣件。位置写「列 / 行」,和 `tools/level_builder/levels/*.py` 的格子一样。")
    w("")

    # ---- 总表
    w("## 每关一览")
    w("")
    pac_hdr = f"(体检:{pacing_name})" if pacing_name else ""
    w(f"| 场景 | 进了几次 | 结果 | 用时 | 机器人用时{pac_hdr} | 关口 | 被发现 | 每分钟被发现 | 起疑 | 丢扣件 | 躲柜子/管 |")
    w("|---|---|---|---|---|---|---|---|---|---|---|")
    for s in scenes:
        vs = by_scene[s]
        t = sum(v.time for v in vs)
        nf = sum(len(v.of("fail")) for v in vs)
        p = pacing.get(s, {})
        robot = fmt_t(p["ticks"] / 60.0) if p.get("ticks") else "—"
        gates = str(len(p.get("beats", []))) if p else "—"
        how = "、".join(sorted({LEAVE[v.how] for v in vs}))
        per_min = f"{nf / (t / 60.0):.1f}" if t > 0 else "—"
        w(f"| {titles.get(s, s)} | {len(vs)} | {how} | {fmt_t(t)} | {robot} | {gates} | {nf} | {per_min} | "
          f"{sum(len(v.of('alert')) for v in vs)} | {sum(len(v.of('throw')) for v in vs)} | "
          f"{sum(len(v.of('hide')) for v in vs)} |")
    w("")

    # ---- 被谁抓
    if all_fails:
        w("## 被谁发现、当时在干嘛")
        w("")
        by = Counter(e.get("by", "other") for e in all_fails)
        w("| 被谁 | 次数 | 当时在干嘛 | 在暗处 |")
        w("|---|---|---|---|")
        for k, n in by.most_common():
            fe = [e for e in all_fails if e.get("by") == k]
            doing = Counter(DOING.get(e.get("do", "?"), e.get("do", "?")) for e in fe)
            w(f"| {BY.get(k, k)} | {n} | " + "、".join(f"{a} {b}" for a, b in doing.most_common())
              + f" | {sum(1 for e in fe if e.get('shade'))} |")
        w("")
        sight_in_shade = [e for e in all_fails if e.get("by") == "guard_sight" and e.get("shade")]
        if sight_in_shade:
            w(f"- 观察:「看」的守卫抓到人时,Ryn 的躯干中点在暗处 {len(sight_in_shade)} 次(暗处他本来看不见 ——"
              f"多半是刚走进 / 走出暗处的那一下,值得对照热点图看位置)。")
            w("")

    # ---- 重生后马上又被抓
    quick = [(v, e) for v in visits for e in v.of("fail") if 0.0 <= float(e.get("since_respawn", -1)) < QUICK_RECATCH_S]
    w(f"## 重生后 {QUICK_RECATCH_S:.0f} 秒内又被发现(K5)")
    w("")
    if quick:
        w("| 场景 | 存档点 | 重生后几秒 | 被谁 | 体检也标了这个存档点被盯着 |")
        w("|---|---|---|---|---|")
        for v, e in quick:
            cp = next((c for c in pacing.get(v.scene, {}).get("checkpoints", []) if c["name"] == e.get("cp")), None)
            watched = ("是:" + "、".join(cp["watched"])) if cp and cp.get("watched") else ("否" if cp else "—")
            w(f"| {titles.get(v.scene, v.scene)} | {e.get('cp') or '(开场)'} | {float(e['since_respawn']):.1f} | "
              f"{BY.get(e.get('by'), e.get('by'))} {e.get('src', '')} | {watched} |")
    else:
        w("没有。")
    w("")

    # ---- 每关细节
    w("## 每关细节")
    w("")
    for s in scenes:
        vs = by_scene[s]
        title = titles.get(s, s)
        w(f"### {title}")
        w("")
        png = img_dir / f"{Path(s).stem}.png"
        heatmap(s, title, vs, keys.get(s), png)
        w(f"![{title}]({png.relative_to(args.out).as_posix()})")
        w("")
        # 同一关进了几次(退出后接着玩)时,同一段(起点 + 终点都一样)合起来算
        segs: dict[tuple[str, str], dict] = {}
        for v in vs:
            for g in segments(v):
                cur = segs.setdefault((g["from"], g["to"]), {"time": 0.0, "fails": [], "n": 0})
                cur["time"] += g["time"]
                cur["fails"] += g["fails"]
                cur["n"] += 1
        if segs:
            w("| 从存档点 | 到 | 用时 | 被发现 | 被谁 |")
            w("|---|---|---|---|---|")
            longest = max(g["time"] for g in segs.values())
            for (a, b), g in segs.items():
                mark = " ←最长" if g["time"] == longest and len(segs) > 1 else ""
                times = f"(走了 {g['n']} 次)" if g["n"] > 1 else ""
                who = Counter(f"{BY.get(e.get('by'), e.get('by'))} {e.get('src', '')}".strip() for e in g["fails"])
                w(f"| {a} | {b} | {fmt_t(g['time'])}{times}{mark} | {len(g['fails'])} | "
                  + ("、".join(f"{x}×{y}" for x, y in who.most_common()) or "—") + " |")
            w("")
        fl = [e for v in vs for e in v.of("fail")]
        hs = hotspots(fl)
        if hs:
            w("被发现扎堆的地方(4×4 格内 ≥ 2 次):")
            w("")
            for (cx, cy), es in hs[:5]:
                who = Counter(f"{BY.get(e.get('by'), e.get('by'))} {e.get('src', '')}".strip() for e in es)
                doing = Counter(DOING.get(e.get("do", "?"), e.get("do", "?")) for e in es)
                w(f"- 列 {cx * 4}–{cx * 4 + 3}、行 {cy * 4}–{cy * 4 + 3}:{len(es)} 次 —— "
                  + "、".join(f"{a}×{b}" for a, b in who.most_common()) + ";当时 "
                  + "、".join(f"{a} {b}" for a, b in doing.most_common()))
            w("")
        al = [e for v in vs for e in v.of("alert")]
        if al:
            src = Counter(e.get("src", "?") for e in al)
            w("差点被发现(守卫起疑)最多的:" + "、".join(f"{a}×{b}" for a, b in src.most_common(4)))
            w("")

    # ---- 对照待定问题
    w("## 对照点子清单里「试玩再定」的几条")
    w("")
    w("- **L1 放大身高后的潜行难度**:看上面「每关一览」的被发现次数 / 每分钟被发现,和「被谁发现」表。")
    tower_rows = [(titles.get(s, s), sum(v.time for v in by_scene[s]), sum(len(v.of("fail")) for v in by_scene[s]),
                   len(pacing.get(s, {}).get("beats", [])), (pacing.get(s, {}).get("ticks") or 0) / 3600.0)
                  for s in scenes if "tower_" in s]
    if tower_rows:
        w("- **K3 塔4 关口密度比塔2/3 低**:四座塔(体检的关口 / 机器人分钟 → 你的被发现 / 分钟):")
        for t, sec, nf, gates, rm in tower_rows:
            g = f"{gates / rm:.1f}" if rm > 0 else "—"
            r = f"{nf / (sec / 60.0):.1f}" if sec > 0 else "—"
            w(f"  - {t}:关口 {g} / 分钟 → 被发现 {r} / 分钟")
    w(f"- **K5 存档点一重生就被盯着**:见「重生后 {QUICK_RECATCH_S:.0f} 秒内又被发现」那一节。")
    w("")

    out = args.out / f"playtest-{args.date}.md"
    out.write_text("\n".join(md) + "\n", encoding="utf-8")
    def rel(q: Path) -> str:
        try:
            return str(q.resolve().relative_to(ROOT))
        except ValueError:
            return str(q)
    print(f"报告 → {rel(out)}(热点图 {len(scenes)} 张在 {rel(img_dir)}/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
