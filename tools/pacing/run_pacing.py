#!/usr/bin/env python3
"""全流程体检(2026-10-12):让路线机器人按 `LevelSequence.ORDER` 跑每一关,收集节奏数据,出报告。

每关跑 `--demo=route --pace`(`src/dev/demo_state.gd` + `src/dev/pace_probe.gd`):守卫和灯都关掉,
机器人沿关卡生成器搜出的路线走到出口,一路记下

  - 存档点踩到的时间;
  - 「关口」:Ryn 站的地方被某个守卫的巡逻范围(任一位置、会有的朝向)看得到,或在探照灯 / 门禁灯
    的范围里。连续一段算一个关口 —— 玩家要在这里看时机、躲、或者引开。

量的是关卡摆法,不是机器人会不会被抓。报告里的「粗估玩家用时」只是估计(公式见报告),
真实数字要靠试玩。只出观察,不下结论:标出来的是「值得看一眼」,不是「有问题」。

    python3 tools/pacing/run_pacing.py              # 跑全部、写报告
    python3 tools/pacing/run_pacing.py --reuse      # 不重跑,用上次的 json 重出报告

输出:
    production/qa/pacing-<日期>.md / .json / .png
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/Users/shihtsun/Library/Mobile Documents/com~apple~CloudDocs/2-创作/03-Godot工程/Godot.app/Contents/MacOS/Godot")
TPS = 60.0

# ---- 估计用的数(都写在报告里)
HUMAN_MOVE_FACTOR = 1.3      # 玩家走得没机器人利索
WATCHER_WAIT = 5.0           # 原地盯梢的守卫等不走:要引开 / 绕,先按 5 秒算
# ---- 标记阈值(观察,不是判决)
SEG_LONG_S = 45.0            # 两个存档点之间机器人要走这么久以上
SEG_BEATS = 3                # 两个存档点之间关口这么多以上
MERGE_GAP_S = 0.75           # 与 pace_probe.gd 的 MERGE_TICKS 一致


def read_sequence() -> list[tuple[str, str]]:
    src = (ROOT / "src/levels/level_sequence.gd").read_text(encoding="utf-8")
    order = re.findall(r'"(res://[^"]+\.tscn)"', src.split("const ORDER")[1].split("const TITLES")[0])
    titles = re.findall(r'"([^"]+)"', src.split("const TITLES")[1].split("= [")[1].split("]")[0])
    return list(zip(order, titles))


def has_route(scene: str) -> bool:
    path = ROOT / scene.replace("res://", "")
    return 'name="DevRoute"' in path.read_text(encoding="utf-8")


def scene_layout(scene: str) -> tuple[dict, list]:
    """场景里每个存档点的位置,和 DevRoute 的(点, 动作)。"""
    t = (ROOT / scene.replace("res://", "")).read_text(encoding="utf-8")
    cps = {n: (float(x), float(y)) for n, x, y in re.findall(
        r'\[node name="(Checkpoint\d+)"[^\]]*\]\s*position = Vector2\(([-\d.]+), ([-\d.]+)\)', t)}
    m = re.search(r'\[node name="DevRoute".*?points = PackedVector2Array\(([^)]*)\).*?'
                  r'actions = PackedStringArray\(([^)]*)\)', t, re.S)
    route = []
    if m:
        v = [float(a) for a in m.group(1).split(",")]
        acts = [a.strip().strip('"') for a in m.group(2).split(",")]
        route = list(zip(zip(v[0::2], v[1::2]), acts))
    return cps, route


def route_gap(cp: tuple[float, float], route: list) -> float:
    """存档点离路线在同一层地面上最近多远(px);同一层没有路线经过就是 inf。"""
    best = float("inf")
    for ((ax, ay), _), ((bx, by), act) in zip(route, route[1:]):
        if act in ("vent",):
            continue
        for (x0, x1, y) in ((min(ax, bx), max(ax, bx), by),) if abs(ay - by) < 1 else ((bx, bx, by),):
            if abs(y - cp[1]) > 8:
                continue
            best = min(best, 0.0 if x0 <= cp[0] <= x1 else min(abs(cp[0] - x0), abs(cp[0] - x1)))
    return best


def run_level(scene: str) -> dict:
    cmd = [GODOT, "--path", str(ROOT), "--headless", "--fixed-fps", "60", "--quit-after", "400000",
           scene, "--", "--demo=route", "--pace"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=600).stdout
    except subprocess.TimeoutExpired:
        return {"scene": scene, "verdict": "TIMEOUT"}
    for line in out.splitlines():
        if line.startswith("[pace] "):
            return json.loads(line[7:])
    result = [l for l in out.splitlines() if "TRAVERSE RESULT" in l]
    return {"scene": scene, "verdict": "NO-DATA", "log": result[-1] if result else out[-400:]}


def wait_for(beat: dict, sources: dict) -> tuple[float, bool]:
    """这个关口玩家大概要等多久(秒),以及有没有原地盯梢的守卫。"""
    waits, watcher = [], False
    for s in beat["src"]:
        cyc = sources.get(s, {}).get("cycle", -1.0)
        if cyc is None or cyc < 0:
            watcher = True
            waits.append(WATCHER_WAIT)
        else:
            waits.append(cyc / 2.0)
    return (max(waits) if waits else 0.0), watcher


def analyse(title: str, d: dict) -> dict:
    T = d["ticks"] / TPS
    cps = d["checkpoints"]
    sources = d["sources"]
    seg_start = lambda k: (cps[k - 1]["t"] / TPS) if k >= 1 and k - 1 < len(cps) else 0.0
    beats = []
    for b in d["beats"]:
        t0, t1 = b["t0"] / TPS, b["t1"] / TPS
        wait, watcher = wait_for(b, sources)
        cycles = [sources[s]["cycle"] for s in b["src"] if sources.get(s, {}).get("cycle", -1) > 0]
        long_beat = bool(cycles) and (t1 - t0) > min(cycles) / 2.0
        b.setdefault("puzzle", [])
        beats.append({**b, "t0s": t0, "t1s": t1, "dur": t1 - t0, "wait": wait, "watcher": watcher,
                      "long": long_beat, "redo": t1 - seg_start(b["seg"]),
                      "kinds": sorted({sources.get(s, {}).get("kind", "?") for s in b["src"]})})
    segs = []
    for k in range(1, len(cps) + 1):
        a = cps[k - 1]["t"] / TPS
        z = cps[k]["t"] / TPS if k < len(cps) else T
        sb = [b for b in beats if b["seg"] == k]
        segs.append({"k": k, "from": cps[k - 1]["name"], "start": a, "end": z, "dur": z - a,
                     "beats": len(sb), "redo": max([b["redo"] for b in sb], default=0.0)})
    est = T * HUMAN_MOVE_FACTOR + sum(b["wait"] for b in beats)
    cp_pos, route = scene_layout(d["scene"])
    visited = {c["name"] for c in cps}
    missed = [(n, p, route_gap(p, route)) for n, p in sorted(cp_pos.items()) if n not in visited]
    flags, notes = [], []
    for n, p, gap in missed:
        where = f"x={p[0]:.0f}, y={p[1]:.0f}"
        if gap == float("inf"):
            flags.append(f"存档点 {n}({where})不在路线经过的任何一层 —— 照主路线走碰不到")
        else:
            flags.append(f"存档点 {n}({where})在路线旁 {gap:.0f}px,感应框只有 28px 宽 —— 照主路线走碰不到")
    for s in segs:
        if s["dur"] > SEG_LONG_S:
            flags.append(f"{s['from']} 之后 {s['dur']:.0f} 秒才到下一个存档点(机器人用时)")
        if s["beats"] >= SEG_BEATS:
            flags.append(f"{s['from']} 之后连着 {s['beats']} 个关口,死一次最多重走 {s['redo']:.0f} 秒")
    for c in cps:
        if c.get("watched"):
            notes.append(f"存档点 {c['name']}(x={c['x']:.0f}, y={c['y']:.0f})站的地方 {'/'.join(c['watched'])} 盯得到"
                         " —— 死了在这里重生,要马上找掩护")
    for b in beats:
        where = f"x={b['x']:.0f}, y={b['y']:.0f}"
        if b["puzzle"]:
            notes.append(f"谜题房 {'、'.join(b['puzzle'])}:{'/'.join(b['src'])} 盯着({where},{b['dur']:.1f} 秒)"
                         " —— 设计上要先解机关,机器人没解")
            continue
        if b["watcher"]:
            flags.append(f"{'/'.join(b['src'])} 原地盯梢的守卫看着路线({where}),要引开或靠暗处")
        if b["long"] and "patrol" in b["kinds"]:
            notes.append(f"{'/'.join(b['src'])} 的关口要走 {b['dur']:.1f} 秒,比半个来回长 —— 中途要躲一次({where})")
    return {"title": title, "scene": d["scene"], "verdict": d["verdict"], "T": T, "est": est,
            "distance": d["distance"], "guards": d["guards"], "lights": d["lights"],
            "checkpoints": len(cps), "beats": beats, "segs": segs,
            "per_min": len(beats) / (T / 60.0) if T > 0 else 0.0,
            "max_redo": max([s["redo"] for s in segs], default=0.0),
            "max_seg": max([s["dur"] for s in segs], default=T),
            "shade": d["shade_ticks"] / TPS, "covered": d["covered_ticks"] / TPS,
            "actions": d["actions"], "flags": flags, "notes": notes, "missed": missed}


# ---------------------------------------------------------------- 图
def draw_chart(rows: list[dict], skipped: list[str], out: Path) -> None:
    from PIL import Image, ImageDraw, ImageFont
    font_path = "/System/Library/Fonts/Hiragino Sans GB.ttc"
    f = lambda n: ImageFont.truetype(font_path, n)
    W, LEFT, RIGHT, ROW, TOP = 1600, 230, 300, 58, 96
    H = TOP + ROW * len(rows) + 90
    bg, ink, dim = (14, 20, 32), (214, 222, 232), (110, 124, 146)
    img = Image.new("RGB", (W, H), bg)
    g = ImageDraw.Draw(img)
    g.text((24, 22), "全流程体检 · 每关时间线(机器人用时,守卫和灯关掉)", font=f(26), fill=ink)
    g.text((24, 58), "灰条 = 机器人从入口走到出口;白竖线 = 存档点;色块 = 要看时机的关口"
           "(琥珀 = 守卫,青 = 探照灯 / 门禁灯,红 = 原地盯梢,紫 = 谜题房)", font=f(15), fill=dim)
    tmax = max(r["T"] for r in rows) * 1.02
    span = W - LEFT - RIGHT
    X = lambda t: LEFT + span * t / tmax
    # 刻度
    for s in range(0, int(tmax) + 1, 30):
        x = X(s)
        g.line([(x, TOP - 8), (x, TOP + ROW * len(rows))], fill=(30, 40, 58))
        g.text((x - 10, TOP + ROW * len(rows) + 6), f"{s}s", font=f(13), fill=dim)
    for i, r in enumerate(rows):
        y = TOP + i * ROW
        g.text((24, y + 14), r["title"], font=f(17), fill=ink)
        g.rounded_rectangle([X(0), y + 18, X(r["T"]), y + 36], radius=3, fill=(44, 56, 78))
        for b in r["beats"]:
            col = (150, 110, 210) if b["puzzle"] else (196, 69, 58) if b["watcher"] else ((90, 190, 200) if set(b["kinds"]) <= {"sweep", "gate"}
                                                      else (214, 168, 76))
            x0, x1 = X(b["t0s"]), max(X(b["t1s"]), X(b["t0s"]) + 3)
            g.rectangle([x0, y + 16, x1, y + 38], fill=col)
            if b["long"]:
                g.rectangle([x0, y + 16, x1, y + 38], outline=(255, 255, 255), width=1)
        for k, s in enumerate(r["segs"]):
            x = X(s["start"])
            g.line([(x, y + 10), (x, y + 44)], fill=(235, 240, 248), width=2)
            if s["dur"] > SEG_LONG_S or s["beats"] >= SEG_BEATS:
                g.text((x + 3, y + 40), "!", font=f(14), fill=(240, 120, 100))
        miss = f"(漏 {len(r['missed'])})" if r["missed"] else ""
        g.text((W - RIGHT + 16, y + 6), f"{r['T']:.0f}s · 关口 {len(r['beats'])} · 存档 {r['checkpoints']}{miss}",
               font=f(15), fill=(240, 150, 120) if r["missed"] else ink)
        g.text((W - RIGHT + 16, y + 28), f"粗估 {r['est'] / 60:.1f} 分 · 最长一段 {r['max_seg']:.0f}s",
               font=f(13), fill=dim)
    if skipped:
        g.text((24, H - 40), "没量:" + "、".join(skipped) + "(没有机器人路线:剧情步行 / 结局对峙)",
               font=f(14), fill=dim)
    img.save(out)


# ---------------------------------------------------------------- 报告
def write_report(rows: list[dict], skipped: list[tuple[str, str]], day: str, out: Path) -> None:
    tot_T = sum(r["T"] for r in rows)
    tot_est = sum(r["est"] for r in rows)
    L = []
    L.append(f"# 全流程体检 · {day}\n")
    L.append("> 由 `tools/pacing/run_pacing.py` 生成。路线机器人(`--demo=route --pace`)沿关卡生成器的路线走完每一关,"
             "守卫和灯都关掉;`src/dev/pace_probe.gd` 一路记存档点和「关口」。**只是观察**:标出来的地方值得试玩时看一眼,"
             "不等于有问题。\n")
    L.append("**关口**:Ryn 站的地方被某个守卫巡逻范围里任一位置(它会有的朝向)看得到 —— 不在暗处、没被墙挡 ——"
             "或者在探照灯 / 门禁灯的范围里。连续一段(中间断开不到 0.75 秒)算一个。和守卫当时走到哪、面朝哪无关。\n")
    L.append(f"**粗估玩家用时** = 机器人用时 × {HUMAN_MOVE_FACTOR} + 每个关口等半个来回"
             f"(原地盯梢的守卫按 {WATCHER_WAIT:.0f} 秒算)。不含死亡重来、看风景、读字。\n")
    L.append("## 总览\n")
    L.append(f"量到的 {len(rows)} 关:机器人共 **{tot_T / 60:.1f} 分钟**,粗估玩家 **{tot_est / 60:.0f} 分钟左右**"
             f"(再加死亡重来)。没量:{'、'.join(t for _, t in skipped)}。\n")
    L.append("| 关卡 | 机器人 | 粗估玩家 | 存档点(碰得到 / 总共) | 关口 | 每分钟关口 | 最长一段(存档间) | 死一次最多重走 | 靠暗处躲过 | 守卫 / 灯 |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        L.append(f"| {r['title']} | {r['T']:.0f}s | {r['est'] / 60:.1f} 分 | "
                 f"{r['checkpoints']} / {r['checkpoints'] + len(r['missed'])} | {len(r['beats'])} | "
                 f"{r['per_min']:.1f} | {r['max_seg']:.0f}s | {r['max_redo']:.0f}s | {r['shade']:.0f}s | "
                 f"{r['guards']} / {r['lights']} |")
    L.append("")
    L.append(f"![时间线](pacing-{day}.png)\n")
    L.append("## 这份体检量不到的\n")
    L.append("- 机器人不等时机、不躲、不丢扣件,也不解谜题房(放汽、断电、排干),只拆挡路的机关。"
             "谜题房那几段的用时按「没解」算:下行关的蚀池是用 1/4 速度硬走过去的,实际排干后会快很多。")
    L.append("- 关口是「这个位置被谁盯得到」的范围,不是被抓的次数;探照灯按整段扫射范围算,所以灯的关口偏长。")
    L.append("- 序章(剧情步行)和中央 + 坑底(结局对峙)没有机器人路线,没量。")
    L.append("- 粗估玩家用时只是公式,真实数字要试玩;死亡重来没算进去。\n")
    L.append("## 每关标记\n")
    L.append(f"⚑ = 值得看:主路线碰不到的存档点;两个存档点之间机器人走 > {SEG_LONG_S:.0f} 秒;"
             f"两个存档点之间 ≥ {SEG_BEATS} 个关口;原地盯梢的守卫看着路线(谜题房以外)。\n")
    L.append("ℹ = 记一笔:存档点站的地方被盯得到(重生后要马上躲);谜题房里的关口(要先解机关);"
             "巡逻守卫的关口比半个来回长(中途要躲一次,潜行的常态)。\n")
    for r in rows:
        L.append(f"### {r['title']}  (`{r['scene'].replace('res://', '')}`)\n")
        acts = ", ".join(f"{k} {v}" for k, v in sorted(r["actions"].items()) if k != "start")
        L.append(f"- 结果 {r['verdict']};走了 {r['distance']:.0f}px;路线动作:{acts}")
        for fl in r["flags"]:
            L.append(f"- ⚑ {fl}")
        for nt in r["notes"]:
            L.append(f"- ℹ {nt}")
        if not r["flags"] and not r["notes"]:
            L.append("- 没有标记")
        L.append("")
        L.append("| 存档段 | 起点 | 机器人用时 | 关口 | 死一次最多重走 |")
        L.append("|---|---|---|---|---|")
        for s in r["segs"]:
            L.append(f"| {s['k']} | {s['from']} | {s['dur']:.0f}s | {s['beats']} | {s['redo']:.0f}s |")
        L.append("")
    out.write_text("\n".join(L), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reuse", action="store_true", help="不重跑,用上次的 json")
    ap.add_argument("--date", default=dt.date.today().isoformat())
    args = ap.parse_args()
    qa = ROOT / "production/qa"
    raw_path = qa / f"pacing-{args.date}.json"
    seq = read_sequence()
    measured = [(s, t) for s, t in seq if has_route(s)]
    skipped = [(s, t) for s, t in seq if not has_route(s)]
    if args.reuse:
        raw = json.loads(raw_path.read_text(encoding="utf-8"))
    else:
        with cf.ThreadPoolExecutor(max_workers=4) as ex:
            futures = {s: ex.submit(run_level, s) for s, _ in measured}
            raw = {s: fut.result() for s, fut in futures.items()}
        raw_path.write_text(json.dumps(raw, ensure_ascii=False, indent=1), encoding="utf-8")
    rows, bad = [], []
    for s, t in measured:
        d = raw.get(s, {})
        if d.get("verdict") != "REACHABLE" or "ticks" not in d:
            bad.append(f"{t}: {d.get('verdict')} {d.get('log', '')}")
            continue
        rows.append(analyse(t, d))
    for b in bad:
        print("[pacing] 没跑通:", b, file=sys.stderr)
    draw_chart(rows, [t for _, t in skipped], qa / f"pacing-{args.date}.png")
    write_report(rows, skipped, args.date, qa / f"pacing-{args.date}.md")
    for r in rows:
        print(f"[pacing] {r['title']:<14} bot {r['T']:5.0f}s  est {r['est'] / 60:4.1f}min  beats {len(r['beats']):2d}"
              f"  cps {r['checkpoints']:2d}  maxseg {r['max_seg']:4.0f}s  flags {len(r['flags'])}")
    print(f"[pacing] report → production/qa/pacing-{args.date}.md")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
