"""把 levels/ 里的关卡描述生成成 Godot 场景。

    python3 tools/level_builder/build.py            # 全部
    python3 tools/level_builder/build.py tower_1    # 只建一关

每一关输出:
  - src/levels/<scene>.tscn        生成的场景(不要手改;改 levels/<key>.py 再重建)
  - design/levels/<key>.txt         字符地图(看得懂的版本)
  - design/levels/<key>.png         预览图(地形 + 暗区 + 守卫巡逻 + 路线)
并打印检查结果:路线是否可达、问题清单、面积。

剧情台词、下一关、背景与氛围的参数从现有场景里原样保留(读 root / Backdrop / Atmosphere 三个节点)。
关卡描述里可以覆盖(新关卡没有旧场景时必须写):
    ROOT_NAME = "PitDescent"                              # 根节点名
    ROOT = {"entry_line": "…", "throw_unlocked": False}   # 根节点属性(字符串 / 布尔 / 数字)
    BACKDROP = {"seed_value": "61", ...}                  # Backdrop 属性(tscn 字面量)
    ATMOSPHERE = {"vignette_alpha": "0.56", ...}          # Atmosphere 属性(tscn 字面量)
    AMBIENT = "tower_2"                                   # 环境声(AmbientBank 的键);不写就没有
    MUSIC = "outside"                                     # 配乐(MusicPlayer.TRACKS 的键);塔里不放
    SKYLINE = {"focus_tower": 1, "pan": 0.0, "horizon": 0.5}  # 塔外夜景的参数;horizon = 地平线在画面多高(塔里 0.5 = 眼睛高度)
                                                          # "convoy": True = 远处一列车往坑口开
    BACKDROP_KIND = "skyline"                             # 整关背景用塔外夜景(默认 "tower" = 塔内石墙)
    BLOCK_STYLE = "roof"                                  # 实心块的样子(默认 "masonry" = 石砌)
    DECOR = "refinery"                                    # 塔里的背景道具主题(`decor.py`);不写就没有
"""
from __future__ import annotations

import importlib.util
import pathlib
import re
import sys

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import level_dsl as dsl  # noqa: E402
import decor  # noqa: E402

T = dsl.TILE
STYLE = {"steady": 0, "scanner": 1, "loiterer": 2, "sentry": 3}
SENSE = {"sight": 0, "hearing": 1, "tracking": 2}     # src/guard/guard.gd 的 Sense
# AmbientBed.Profile
AMBIENT = {"prologue": 0, "tower_1": 1, "tower_2": 2, "tower_3": 3, "tower_4": 4, "descent": 5, "pit_bottom": 6,
           "rooftops": 7}

EXT = [
    ("Script", "res://src/levels/tower_level.gd", "1_lvl"),
    ("PackedScene", "res://src/levels/gray_block.tscn", "2_blk"),
    ("PackedScene", "res://src/levels/ladder.tscn", "3_lad"),
    ("PackedScene", "res://src/player/ryn.tscn", "4_ryn"),
    ("Script", "res://src/camera/follow_camera.gd", "5_cam"),
    ("Resource", "res://assets/data/follow_camera.tres", "6_ccfg"),
    ("PackedScene", "res://src/guard/guard.tscn", "7_guard"),
    ("Resource", "res://assets/data/guard_default.tres", "8_gcfg"),
    ("PackedScene", "res://src/reset/checkpoint.tscn", "9_cp"),
    ("Script", "res://src/reset/checkpoint_manager.gd", "10_cpm"),
    ("Script", "res://src/reset/detection_reset.gd", "11_dr"),
    ("Resource", "res://assets/data/detection_reset.tres", "12_drcfg"),
    ("Script", "res://src/reset/fail_overlay.gd", "13_ovl"),
    ("Script", "res://src/reset/ryn_reset_adapter.gd", "14_rra"),
    ("Script", "res://src/reset/guard_reset_adapter.gd", "15_gra"),
    ("PackedScene", "res://src/shadow/shadow_zone.tscn", "16_shz"),
    ("Script", "res://src/shadow/shadow_registry.gd", "17_shr"),
    ("Resource", "res://assets/data/shadow_default.tres", "18_shcfg"),
    ("PackedScene", "res://src/dismantle/dismantlable.tscn", "19_dmz"),
    ("Resource", "res://assets/data/dismantle_default.tres", "20_dmcfg"),
    ("Script", "res://src/levels/tower_subtitle.gd", "21_sub"),
    ("Resource", "res://assets/data/tower_subtitle.tres", "22_subcfg"),
    ("Script", "res://src/levels/tower_exit.gd", "23_exit"),
    ("Script", "res://src/levels/gate_light.gd", "24_gate"),
    ("Script", "res://src/levels/sweep_light.gd", "25_sweep"),
    ("Script", "res://src/dev/dev_route.gd", "26_route"),
    ("Script", "res://src/levels/story_trigger.gd", "27_story"),
    ("Script", "res://src/levels/story_pickup.gd", "28_pick"),
    ("Script", "res://src/levels/terminal_flash.gd", "29_term"),
    ("Script", "res://src/levels/pit_wind.gd", "30_wind"),
    ("Script", "res://src/levels/guard_fall_line.gd", "31_fall"),
    ("Script", "res://src/levels/corrosion_zone.gd", "32_corr"),
    ("Script", "res://src/levels/corrosion_haze.gd", "33_haze"),
    ("Script", "res://src/audio/ambient_bed.gd", "34_amb"),
    ("Script", "res://src/levels/bolt_pickup.gd", "35_bolt"),
    ("Script", "res://src/levels/skyline_backdrop.gd", "36_sky"),
    ("Script", "res://src/levels/skyline_window.gd", "37_win"),
    ("Script", "res://src/levels/vista_zone.gd", "38_vista"),
    ("Script", "res://src/levels/warm_window.gd", "39_warm"),
    ("Script", "res://src/audio/music_player.gd", "40_music"),
    ("Script", "res://src/levels/tower_decor.gd", "41_decor"),
    ("Script", "res://src/levels/broadcast_speaker.gd", "42_pa"),
    ("Script", "res://src/levels/guard_chat.gd", "43_chat"),
    ("Script", "res://src/levels/shutter_door.gd", "44_shut"),
    ("Script", "res://src/levels/drop_bridge.gd", "45_bridge"),
    ("Script", "res://src/levels/fold_ladder.gd", "46_fold"),
    ("Script", "res://src/levels/steam_valve.gd", "46_steam"),
    ("Script", "res://src/levels/fuse_box.gd", "47_fuse"),
    ("Script", "res://src/levels/corrosion_drain.gd", "48_drain"),
    ("Script", "res://src/levels/tower_lamps.gd", "49_lamps"),
    ("Script", "res://src/levels/tower_backdrop.gd", "80_bdrop"),
    ("Script", "res://src/player/ryn_stealth_visual.gd", "81_stealth"),
    ("Script", "res://src/audio/gameplay_audio.gd", "82_ga"),
    ("Script", "res://src/camera/camera_shake.gd", "83_shake"),
    ("Script", "res://src/ui/pause_menu.gd", "84_pause"),
    ("Script", "res://src/ui/scene_transition.gd", "85_trans"),
    ("Script", "res://src/guard/guard_behaviour.gd", "86_beh"),
    ("Script", "res://src/guard/guard_pursuit.gd", "87_pur"),
    ("Script", "res://src/levels/atmosphere.gd", "89_atmo"),
    ("Script", "res://src/levels/particle_burst.gd", "90_part"),
    ("Script", "res://src/ui/minimap.gd", "91_map"),
    ("Script", "res://src/dev/demo_state.gd", "92_demo"),
    ("PackedScene", "res://src/levels/hiding_spot.tscn", "95_hide"),
]


def V(x, y):
    def f(v):
        v = round(v, 3)
        return str(int(v)) if float(v).is_integer() else str(v)
    return f"Vector2({f(x)}, {f(y)})"


def S(text: str) -> str:
    """tscn 里的字符串字面量。"""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def rects(mask, w, h):
    """把布尔格子合并成矩形(行优先贪心)。返回 [(x0, y0, x1, y1)],含两端。"""
    used = [[False] * w for _ in range(h)]
    out = []
    for y in range(h):
        x = 0
        while x < w:
            if mask[y][x] and not used[y][x]:
                x1 = x
                while x1 + 1 < w and mask[y][x1 + 1] and not used[y][x1 + 1]:
                    x1 += 1
                y1 = y
                while y1 + 1 < h and all(mask[y1 + 1][xx] and not used[y1 + 1][xx] for xx in range(x, x1 + 1)):
                    y1 += 1
                for yy in range(y, y1 + 1):
                    for xx in range(x, x1 + 1):
                        used[yy][xx] = True
                out.append((x, y, x1, y1))
                x = x1 + 1
            else:
                x += 1
    return out


def node_block(text: str, name: str) -> str | None:
    """从 tscn 里取出某个节点的整段(到下一个 [ 之前)。"""
    m = re.search(r'^\[node name="%s"[^\n]*\]\n' % re.escape(name), text, re.M)
    if not m:
        return None
    end = text.find("\n[", m.end())
    return text[m.start(): len(text) if end < 0 else end + 1]


def root_block(text: str) -> str:
    m = re.search(r'^\[node name="[^"]+" type="Node2D"[^\n]*\]\n', text, re.M)
    end = text.find("\n[", m.end())
    return text[m.start(): end + 1]


def prop_lines(block: str, drop=()):
    lines = []
    for line in block.splitlines()[1:]:
        if not line.strip():
            continue
        key = line.split(" = ")[0]
        if key in drop:
            continue
        lines.append(line)
    return lines


def _literal(v) -> str:
    """ROOT 里的值:字符串加引号,布尔写成 true/false,数字原样。"""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return S(v)


def _override(lines, values, quote):
    """把 key = value 行里的 key 换成 values 里的值;没有的 key 加在后面。"""
    out, seen = [], set()
    for line in lines:
        key = line.split(" = ")[0]
        if key in values:
            out.append(f"{key} = {quote(values[key])}")
            seen.add(key)
        else:
            out.append(line)
    out += [f"{k} = {quote(v)}" for k, v in values.items() if k not in seen]
    return out


def write_scene(lv: dsl.Level, scene_path: pathlib.Path, route, route_main=None, mod=None):
    old = scene_path.read_text(encoding="utf-8") if scene_path.exists() else ""
    if old:
        root = root_block(old)
        root_name = re.search(r'name="([^"]+)"', root).group(1)
        root_props = prop_lines(root, drop=("script", "subtitle"))
        backdrop = prop_lines(node_block(old, "Backdrop"), drop=("script", "area", "ground_y"))
        atmo = prop_lines(node_block(old, "Atmosphere"), drop=("script",))
    else:
        root_name, root_props, backdrop, atmo = getattr(mod, "ROOT_NAME"), [], [], []
    root_props = _override(root_props, getattr(mod, "ROOT", {}), _literal)
    backdrop = _override(backdrop, getattr(mod, "BACKDROP", {}), str)
    atmo = _override(atmo, getattr(mod, "ATMOSPHERE", {}), str)
    W, H = lv.w * T, lv.h * T
    out = []
    nodes = []

    def node(header, props=()):
        nodes.append(header + "\n" + "".join(p + "\n" for p in props))

    # ---- 框架
    node(f'[node name="{root_name}" type="Node2D" node_paths=PackedStringArray("subtitle")]',
         ['script = ExtResource("1_lvl")'] + root_props + ['subtitle = NodePath("TowerSubtitle")'])
    node('[node name="DemoState" type="Node" parent="." node_paths=PackedStringArray("ryn", "camera")]',
         ['script = ExtResource("92_demo")', 'ryn = NodePath("../Ryn")', 'camera = NodePath("../FollowCamera")'])
    node('[node name="TowerSubtitle" type="CanvasLayer" parent="."]',
         ['script = ExtResource("21_sub")', 'config = ExtResource("22_subcfg")'])
    ground = max((f for (_, f) in lv.checkpoints), default=lv.h - 4) * T
    sky = getattr(mod, "SKYLINE", {})
    sky_props = [f"level_rect = Rect2(0, 0, {W}, {H})", f"focus_tower = {sky.get('focus_tower', -1)}",
                 f"pan = {float(sky.get('pan', 0.0))}", f"horizon = {float(sky.get('horizon', 0.62))}"] \
        + (["convoy = true"] if sky.get("convoy") else [])
    if getattr(mod, "BACKDROP_KIND", "tower") == "skyline":
        node('[node name="Backdrop" type="Node2D" parent="."]', ['script = ExtResource("36_sky")'] + sky_props)
    else:
        node('[node name="Backdrop" type="Node2D" parent="."]',
             ['script = ExtResource("80_bdrop")', f"area = Rect2(0, -64, {W}, {H + 64})"] + backdrop
             + [f"ground_y = {float(ground)}"])
    for i, (x, row) in enumerate(lv.warm_windows):
        node(f'[node name="WarmWindow{i:02d}" type="Node2D" parent="."]',
             [f"position = {V(x * T + 4, row * T + 3)}", 'script = ExtResource("39_warm")'])
    for i, (x0, y0, x1, y1, kind) in enumerate(lv.windows):
        node(f'[node name="Window{i:02d}" type="Node2D" parent="."]',
             [f"position = {V(x0 * T, y0 * T)}", 'script = ExtResource("37_win")',
              f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)}", f"kind = {1 if kind == 'breach' else 0}"]
             + sky_props)

    # ---- 地形
    solid = [[c == "#" for c in row] for row in lv.g]
    style_ids = {"masonry": 0, "roof": 1, "pipe": 2, "girder": 3, "crate": 4, "plate": 5, "panel": 6, "bunker": 7,
                 "shelf": 8}
    default_style = style_ids[getattr(mod, "BLOCK_STYLE", "masonry")]

    def style_id(x, y):
        st = default_style
        for (sx0, sy0, sx1, sy1, kind) in lv.styles:
            if sx0 <= x <= sx1 and sy0 <= y <= sy1:
                st = style_ids[kind]
        return st

    def style_of(x, y):
        st = style_id(x, y)
        return [f"style = {st}"] if st else []
    # 按样子分开合并:一块只有一种样子(不然箱子会顺着地面一路合并下去,整块地面都画成箱子)
    grid = [[style_id(x, y) if solid[y][x] else -1 for x in range(lv.w)] for y in range(lv.h)]
    i = 0
    for st in sorted({v for row in grid for v in row if v >= 0}):
        mask = [[v == st for v in row] for row in grid]
        for (x0, y0, x1, y1) in rects(mask, lv.w, lv.h):
            node(f'[node name="Block{i:03d}" parent="." instance=ExtResource("2_blk")]',
                 [f"position = {V(x0 * T, y0 * T)}", f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)}"]
                 + ([f"style = {st}"] if st else []))
            i += 1
    low = [[c == "^" for c in row] for row in lv.g]
    for i, (x0, y0, x1, y1) in enumerate(rects(low, lv.w, lv.h)):
        node(f'[node name="LowCeiling{i:02d}" parent="." instance=ExtResource("2_blk")]',
             [f"position = {V(x0 * T, y0 * T)}", f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T + 8)}"]
             + style_of(x0, y0))
    ladders = [[c == "H" for c in row] for row in lv.g]
    for i, (x0, y0, x1, y1) in enumerate(rects(_columns(ladders, lv.w, lv.h), lv.w, lv.h)):
        for x in range(x0, x1 + 1):
            node(f'[node name="Ladder{i:02d}_{x}" parent="." instance=ExtResource("3_lad")]',
                 [f"position = {V(x * T, y0 * T)}", f"size = {V(T, (y1 - y0 + 1) * T)}"])
    hatches = [[c == "D" for c in row] for row in lv.g]
    for i, (x0, y0, x1, y1) in enumerate(rects(hatches, lv.w, lv.h)):
        node(f'[node name="Hatch{i:02d}" parent="." instance=ExtResource("19_dmz")]',
             [f"position = {V(x0 * T, y0 * T)}", f"size = {V((x1 - x0 + 1) * T, T)}",
              "kind = 0", 'config = ExtResource("20_dmcfg")'])
    fences = [[c == "F" for c in row] for row in lv.g]
    for i, (x0, y0, x1, y1) in enumerate(rects(_columns(fences, lv.w, lv.h), lv.w, lv.h)):
        node(f'[node name="Fence{i:02d}" parent="." instance=ExtResource("19_dmz")]',
             [f"position = {V(x0 * T, y0 * T)}", f"size = {V(T, (y1 - y0 + 1) * T)}",
              "kind = 1", 'config = ExtResource("20_dmcfg")'])
    for i, (x0, y0, x1, y1) in enumerate(rects(lv.sh, lv.w, lv.h)):
        node(f'[node name="Shadow{i:03d}" parent="." instance=ExtResource("16_shz")]',
             [f"position = {V(x0 * T, y0 * T)}", f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)}"])
    if lv.decor_props:
        for i, part in enumerate(decor.chunks(lv.decor_props, lv.h)):
            kinds = ", ".join(S(k) for (k, *_r) in part)
            nums = ", ".join(f"{x}, {y}, {w}, {h}" for (_k, x, y, w, h) in part)
            node(f'[node name="Decor{i:02d}" type="Node2D" parent="."]',
                 ['script = ExtResource("41_decor")', f"kinds = PackedStringArray({kinds})",
                  f"rects = PackedFloat32Array({nums})"])
    if getattr(lv, "lamps", None):
        L = lv.lamps
        node('[node name="Lamps" type="Node2D" parent="."]',
             ['script = ExtResource("49_lamps")',
              "points = PackedVector2Array(" + ", ".join(f"{cx}, {cy}" for (cx, cy, *_r) in L) + ")",
              "radii = PackedFloat32Array(" + ", ".join(str(float(r)) for (_x, _y, r, *_r) in L) + ")",
              "colors = PackedStringArray(" + ", ".join(S(c) for (_x, _y, _r, c, *_q) in L) + ")",
              "flickers = PackedStringArray(" + ", ".join(S(f) for (_x, _y, _r, _c, f, *_q) in L) + ")",
              "squashes = PackedFloat32Array(" + ", ".join(str(float(q)) for (*_a, q, _f) in L) + ")",
              "fuses = PackedStringArray(" + ", ".join(S(f"Fuse{k:02d}" if k >= 0 else "") for (*_a, k) in L) + ")"])
    node('[node name="ShadowRegistry" type="Node" parent="."]',
         ['script = ExtResource("17_shr")', 'config = ExtResource("18_shcfg")'])

    # ---- 物件
    for i, (x, f) in enumerate(lv.checkpoints):
        node(f'[node name="Checkpoint{i:02d}" parent="." instance=ExtResource("9_cp")]',
             [f"position = {V(x * T + 8, f * T)}"])
    for i, (x, f, word, t0, t1) in enumerate(lv.terminals):
        ox, oy = x * T, f * T
        extra = []
        if i in lv.terminal_records:
            rec, (sw, sh) = lv.terminal_records[i]
            extra = [f"highlight = {S(word)}", "lines = PackedStringArray(" + ", ".join(S(r) for r in rec) + ")",
                     f"screen_size = {V(sw, sh)}"]
        node(f'[node name="Terminal{i:02d}" type="Node2D" parent="."]',
             [f"position = {V(ox, oy)}", 'script = ExtResource("29_term")', f"word = {S(word)}",
              f"trigger_rect = Rect2({t0 * T - ox}, -48, {(t1 - t0 + 1) * T}, 48)",
              'font_config = ExtResource("22_subcfg")'] + extra)
    for i, (x, row, text, (x0, y0, x1, y1)) in enumerate(lv.broadcasts):
        px, py = x * T + 2, row * T + 8
        node(f'[node name="Broadcast{i:02d}" type="Node2D" parent="." node_paths=PackedStringArray("subtitle")]',
             [f"position = {V(px, py)}", 'script = ExtResource("42_pa")', f"text = {S(text)}",
              f"trigger_rect = Rect2({x0 * T - px}, {y0 * T - py}, {(x1 - x0 + 1) * T}, {(y1 - y0 + 1) * T})",
              'subtitle = NodePath("../TowerSubtitle")'])
    for i, (x, f, text) in enumerate(lv.pickups):
        node(f'[node name="Pickup{i:02d}" type="Area2D" parent="." node_paths=PackedStringArray("subtitle")]',
             [f"position = {V(x * T + 8, f * T)}", 'script = ExtResource("28_pick")', f"text = {S(text)}",
              'subtitle = NodePath("../TowerSubtitle")'])
    for i, (x0, x1, row, rise) in enumerate(lv.steams):
        node(f'[node name="Steam{i:02d}" type="Node2D" parent="."]',
             [f"position = {V(x0 * T, row * T)}", 'script = ExtResource("30_wind")',
              f"width = {float((x1 - x0 + 1) * T)}", f"rise = {float(rise * T)}", "draw_grate = false",
              "wisps = 12", "speed = 30.0",
              "core_color = Color(0.72, 0.76, 0.82, 0.16)", "rim_color = Color(0.82, 0.86, 0.9, 0.12)",
              "haze_color = Color(0.7, 0.75, 0.82, 0.06)", "streak_color = Color(0.85, 0.88, 0.92, 0.12)"])
    for i, (x, f) in enumerate(lv.bolts):
        node(f'[node name="Bolt{i:02d}" type="Area2D" parent="."]',
             [f"position = {V(x * T + 8, f * T)}", 'script = ExtResource("35_bolt")'])
    for i, (x0, x1, row, rise, grate) in enumerate(lv.winds):
        node(f'[node name="PitWind{i:02d}" type="Node2D" parent="."]',
             [f"position = {V(x0 * T, row * T)}", 'script = ExtResource("30_wind")',
              f"width = {float((x1 - x0 + 1) * T)}", f"rise = {float(rise * T)}"]
             + ([] if grate else ["draw_grate = false"]))
    sx, sf = lv.start_at
    node('[node name="Ryn" parent="." instance=ExtResource("4_ryn")]', [f"position = {V(sx * T + 8, sf * T)}"])
    for gd in lv.guards:
        x0, x1 = gd.x0 * T + 8, gd.x1 * T + 8
        if gd.facing >= 0:
            pos, off = x0, x1 - x0
        else:
            pos, off = x1, x0 - x1
        if gd.spawn is not None:
            # 出生在巡逻线中间:巡逻区间仍是 [x0, x1],用出生点算偏移
            pos = gd.spawn * T + 8
            off = (x1 - pos) if gd.facing >= 0 else (x0 - pos)
        node(f'[node name="{gd.name}" parent="." instance=ExtResource("7_guard")]',
             ['groups = ["guard_audio"]', f"position = {V(pos, gd.floor * T)}", 'config = ExtResource("8_gcfg")',
              f"patrol_offset = {float(off)}", f"initial_facing = {1 if gd.facing >= 0 else -1}",
              f"sense = {SENSE[gd.sense]}"])
        node(f'[node name="Pursuit" type="Node" parent="{gd.name}"]',
             ['script = ExtResource("87_pur")', "chase_enabled = false", f"hearing_scale = {gd.hearing}"])
        node(f'[node name="ResetAdapter" type="Node" parent="{gd.name}"]', ['script = ExtResource("15_gra")'])
        node(f'[node name="Behaviour" type="Node" parent="{gd.name}"]',
             ['script = ExtResource("86_beh")', f"style = {STYLE[gd.style]}",
              f"speed_scale = {gd.speed}", f"range_scale = {gd.range}"])
    for i, (x, f) in enumerate(lv.lockers):
        node(f'[node name="Locker{i:02d}" parent="." instance=ExtResource("95_hide")]',
             [f"position = {V(x * T - 4, f * T - 48)}"])
    covers = {m.data["mouth"]: m.panel for m in lv.mechs if m.kind == "cover"}
    for i, (a, b) in enumerate(lv.vent_pairs):
        na, nb = f"Vent{i:02d}A", f"Vent{i:02d}B"
        for me, other, (x, f) in ((na, nb, a), (nb, na, b)):
            props = [f"position = {V(x * T - 2, f * T - 14)}", "kind = 1", "size = Vector2(20, 14)",
                     f'link = NodePath("../{other}")', "enter_noise = 60.0"]
            paths = '"link"'
            if (x, f) in covers:
                paths += ', "cover"'
                props.append(f'cover = NodePath("../Panel{covers[(x, f)]:02d}")')
            node(f'[node name="{me}" parent="." node_paths=PackedStringArray({paths}) instance=ExtResource("95_hide")]',
                 props)
    # ---- 谜题房的机关(2026-10-12)
    looks = {"plain": 0, "chain": 1, "valve": 2, "fuse": 3, "control": 4, "vent_cover": 5}
    for i, (look, _x, _f, (rx, ry, rw, rh)) in enumerate(lv.panels):
        node(f'[node name="Panel{i:02d}" parent="." instance=ExtResource("19_dmz")]',
             [f"position = {V(rx, ry)}", f"size = {V(rw, rh)}", "kind = 2", f"look = {looks[look]}",
              'config = ExtResource("20_dmcfg")'])
    n_shut = n_bridge = n_steam = n_fuse = n_drain = n_fold = 0
    for m in lv.mechs:
        _look, _x, _f, (rx, ry, rw, rh) = lv.panels[m.panel]
        pname = f'"../Panel{m.panel:02d}"'
        if m.kind == "shutter":
            d = m.data
            node(f'[node name="Shutter{n_shut:02d}" type="Node2D" parent="." node_paths=PackedStringArray("panel")]',
                 [f"position = {V(d['x'] * T, d['top'] * T)}", 'script = ExtResource("44_shut")',
                  f"size = {V(T, (d['bottom'] - d['top'] + 1) * T)}", f"panel = NodePath({pname})"])
            n_shut += 1
        elif m.kind == "bridge":
            d = m.data
            left = d["hinge"] == "left"
            hx = d["x0"] * T if left else (d["x1"] + 1) * T
            node(f'[node name="Bridge{n_bridge:02d}" type="Node2D" parent="." node_paths=PackedStringArray("panel")]',
                 [f"position = {V(hx, d['row'] * T)}", 'script = ExtResource("45_bridge")',
                  f"length = {float((d['x1'] - d['x0'] + 1) * T)}", f"hinge_left = {'true' if left else 'false'}",
                  f"anchor = {V(rx + rw * 0.5, ry + rh * 0.5)}", f"noise_radius = {float(d['noise'])}",
                  f"panel = NodePath({pname})"])
            n_bridge += 1
        elif m.kind == "ladder":
            d = m.data
            node(f'[node name="FoldLadder{n_fold:02d}" type="Area2D" parent="." node_paths=PackedStringArray("panel")]',
                 [f"position = {V(d['x'] * T, d['top'] * T)}", 'script = ExtResource("46_fold")',
                  f"size = {V(T, (d['bottom'] - d['top']) * T)}", f"slab_px = {float(d['slab'] * T)}",
                  f"anchor = {V(rx + rw * 0.5, ry + rh * 0.5)}", f"noise_radius = {float(d['noise'])}",
                  f"panel = NodePath({pname})"])
            n_fold += 1
        elif m.kind == "steam":
            x0, y0, x1, y1 = m.data["cloud"]
            node(f'[node name="Steam{n_steam:02d}" type="Node2D" parent="." node_paths=PackedStringArray("panel")]',
                 ['script = ExtResource("46_steam")', f"panel = NodePath({pname})",
                  f"cloud_rect = Rect2({x0 * T}, {y0 * T}, {(x1 - x0 + 1) * T}, {(y1 - y0 + 1) * T})",
                  f"duration = {float(m.data['duration'])}"])
            n_steam += 1
        elif m.kind == "fuse":
            d = m.data
            x0, y0, x1, y1 = d["blackout"]
            lights = [f"Sweep{k:02d}" for k in d["sweeps"]] + [f"Gate{k:02d}" for k in d["gates"]]
            rx_, rf_ = d["repair"]
            node(f'[node name="Fuse{n_fuse:02d}" type="Node2D" parent="." node_paths=PackedStringArray("panel", "technician")]',
                 ['script = ExtResource("47_fuse")', f"panel = NodePath({pname})",
                  "light_names = PackedStringArray(" + ", ".join(S(l) for l in lights) + ")",
                  f"blackout_rect = Rect2({x0 * T}, {y0 * T}, {(x1 - x0 + 1) * T}, {(y1 - y0 + 1) * T})",
                  f'technician = NodePath("../{d["technician"]}")', f"repair_point = {V(rx_ * T + 8, rf_ * T)}",
                  f"repair_time = {float(d['repair_time'])}", f"backup_time = {float(d['backup'])}"])
            n_fuse += 1
        elif m.kind == "drain":
            d = m.data
            pool_rows = [lv.corrosions[k][2] for k in d["pools"]]
            node(f'[node name="Drain{n_drain:02d}" type="Node2D" parent="." node_paths=PackedStringArray("panel")]',
                 ['script = ExtResource("48_drain")', f"panel = NodePath({pname})",
                  "zone_names = PackedStringArray(" + ", ".join(S(f"Corrosion{k:02d}") for k in d["pools"]) + ")",
                  f"grate_x = {float(d['grate'] * T + 8)}", f"floor_y = {float(pool_rows[0] * T)}",
                  f"drain_time = {float(d['drain_time'])}", f"noise_radius = {float(d['noise'])}"])
            n_drain += 1
    for i, gt in enumerate(lv.gates):
        node(f'[node name="Gate{i:02d}" type="Node2D" parent="." node_paths=PackedStringArray("detection_reset", "ryn")]',
             [f"position = {V(gt.x0 * T, gt.floor * T)}", 'script = ExtResource("24_gate")',
              f"size = {V((gt.x1 - gt.x0 + 1) * T, gt.h_tiles * T)}", f"red_time = {gt.red}",
              f"green_time = {gt.green}", f"phase_offset = {gt.phase}",
              'detection_reset = NodePath("../DetectionReset")', 'ryn = NodePath("../Ryn")'])
    for i, sw in enumerate(lv.sweeps):
        node(f'[node name="Sweep{i:02d}" type="Node2D" parent="." node_paths=PackedStringArray("detection_reset", "ryn")]',
             [f"position = {V(sw.x * T + 8, sw.row * T)}", 'script = ExtResource("25_sweep")',
              f"beam_width = {float(sw.width)}", f"beam_length = {float(sw.length_tiles * T)}",
              f"sweep_span = {float(sw.span_tiles * T)}", f"period = {sw.period}", f"phase_offset = {sw.phase}",
              'detection_reset = NodePath("../DetectionReset")', 'ryn = NodePath("../Ryn")'])
    if lv.corrosions:
        node('[node name="CorrosionHaze" type="CanvasLayer" parent="." node_paths=PackedStringArray("subtitle")]',
             ['script = ExtResource("33_haze")', f"deep_line = {S(lv.haze_text or '')}",
              'subtitle = NodePath("../TowerSubtitle")'])
        for i, (x0, x1, f, drag, haze) in enumerate(lv.corrosions):
            node(f'[node name="Corrosion{i:02d}" type="Area2D" parent="." node_paths=PackedStringArray("haze")]',
                 [f"position = {V(x0 * T, (f - 3) * T)}", 'script = ExtResource("32_corr")',
                  f"size = {V((x1 - x0 + 1) * T, 3 * T)}", f"drag = {drag}", f"haze_strength = {haze}",
                  'haze = NodePath("../CorrosionHaze")']
                 + ([f"pool_depth = {float(lv.pool_depths[i])}"] if i in lv.pool_depths else []))
    for i, (x0, y0, x1, y1, text) in enumerate(lv.stories):
        node(f'[node name="Story{i:02d}" type="Area2D" parent="." node_paths=PackedStringArray("subtitle")]',
             [f"position = {V(x0 * T, y0 * T)}", 'script = ExtResource("27_story")',
              f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)}", f"text = {S(text)}",
              'subtitle = NodePath("../TowerSubtitle")'])
    for i, (x0, y0, x1, y1, zoom, off, text) in enumerate(lv.vistas):
        node(f'[node name="Vista{i:02d}" type="Area2D" parent="." node_paths=PackedStringArray("camera", "subtitle")]',
             [f"position = {V(x0 * T, y0 * T)}", 'script = ExtResource("38_vista")',
              f"size = {V((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)}", f"zoom_level = {float(zoom)}",
              f"offset = {V(off[0], off[1])}", f"text = {S(text)}",
              'camera = NodePath("../FollowCamera")', 'subtitle = NodePath("../TowerSubtitle")'])
    if lv.fall_text:
        node('[node name="GuardFallLine" type="Node" parent="." node_paths=PackedStringArray("subtitle")]',
             ['script = ExtResource("31_fall")', f"text = {S(lv.fall_text)}", 'subtitle = NodePath("../TowerSubtitle")'])
    for i, ch in enumerate(lv.chats):
        (ax0, ay0, ax1, ay1) = ch["approach"]
        node(f'[node name="GuardChat{i:02d}" type="Node2D" parent="." '
             'node_paths=PackedStringArray("guard_a", "guard_b", "ryn", "detection_reset")]',
             ['script = ExtResource("43_chat")', f'guard_a = NodePath("../{ch["a"]}")',
              f'guard_b = NodePath("../{ch["b"]}")', f"meet_a_x = {float(ch['meet'][0] * T + 8)}",
              f"meet_b_x = {float(ch['meet'][1] * T + 8)}",
              f"approach_rect = Rect2({ax0 * T}, {ay0 * T}, {(ax1 - ax0 + 1) * T}, {(ay1 - ay0 + 1) * T})",
              "lines = PackedStringArray(" + ", ".join(S(l) for l in ch["lines"]) + ")",
              f"hear_radius = {float(ch['hear'])}", 'ryn = NodePath("../Ryn")',
              'detection_reset = NodePath("../DetectionReset")', 'font_config = ExtResource("22_subcfg")'])
    ex, ef = lv.exit_at
    node('[node name="TowerExit" type="Area2D" parent="." node_paths=PackedStringArray("level")]',
         [f"position = {V(ex * T - 16, ef * T)}", 'script = ExtResource("23_exit")', "size = Vector2(48, 56)",
          'level = NodePath("..")'])

    # ---- 系统
    node('[node name="RynStealthVisual" type="Node" parent="." node_paths=PackedStringArray("ryn", "shadows")]',
         ['script = ExtResource("81_stealth")', 'ryn = NodePath("../Ryn")', 'shadows = NodePath("../ShadowRegistry")'])
    node('[node name="RynResetAdapter" type="Node" parent="." node_paths=PackedStringArray("ryn")]',
         ['script = ExtResource("14_rra")', 'ryn = NodePath("../Ryn")'])
    node('[node name="CheckpointManager" type="Node" parent="." node_paths=PackedStringArray("ryn")]',
         ['script = ExtResource("10_cpm")', 'ryn = NodePath("../Ryn")'])
    node('[node name="FailOverlay" type="CanvasLayer" parent="."]',
         ['script = ExtResource("13_ovl")', 'config = ExtResource("12_drcfg")'])
    node('[node name="DetectionReset" type="Node" parent="." node_paths=PackedStringArray("ryn", "overlay", "checkpoints")]',
         ['script = ExtResource("11_dr")', 'config = ExtResource("12_drcfg")', 'ryn = NodePath("../Ryn")',
          'overlay = NodePath("../FailOverlay")', 'checkpoints = NodePath("../CheckpointManager")'])
    node('[node name="FollowCamera" type="Camera2D" parent="." node_paths=PackedStringArray("target")]',
         ["zoom = Vector2(2, 2)", "limit_left = 0", "limit_top = -64", f"limit_right = {W}", f"limit_bottom = {H}",
          'script = ExtResource("5_cam")', 'target = NodePath("../Ryn")', 'config = ExtResource("6_ccfg")'])
    node('[node name="CameraShake" type="Node" parent="FollowCamera"]', ['script = ExtResource("83_shake")'])
    node('[node name="GameplayAudio" type="Node" parent="." node_paths=PackedStringArray("ryn", "detection_reset", "checkpoints", "shake", "particles")]',
         ['script = ExtResource("82_ga")', 'particles = NodePath("../ParticleBurst")', 'ryn = NodePath("../Ryn")',
          'shake = NodePath("../FollowCamera/CameraShake")', 'detection_reset = NodePath("../DetectionReset")',
          'checkpoints = NodePath("../CheckpointManager")'])
    node('[node name="SceneTransition" type="CanvasLayer" parent="."]', ['script = ExtResource("85_trans")'])
    node('[node name="PauseMenu" type="CanvasLayer" parent="."]',
         ['script = ExtResource("84_pause")', 'font = ExtResource("22_subcfg")'])
    node('[node name="Atmosphere" type="CanvasLayer" parent="."]', ['script = ExtResource("89_atmo")'] + atmo)
    node('[node name="ParticleBurst" type="Node2D" parent="."]', ['script = ExtResource("90_part")'])
    music = getattr(mod, "MUSIC", None)
    if music:
        node('[node name="Music" type="Node" parent="." node_paths=PackedStringArray("detection_reset")]',
             ['script = ExtResource("40_music")', f'track = &"{music}"', 'detection_reset = NodePath("../DetectionReset")'])
    ambient = getattr(mod, "AMBIENT", None)
    if ambient:
        node('[node name="Ambient" type="Node" parent="." node_paths=PackedStringArray("detection_reset")]',
             ['script = ExtResource("34_amb")', f"profile = {AMBIENT[ambient]}",
              'detection_reset = NodePath("../DetectionReset")'])
    node('[node name="Minimap" type="CanvasLayer" parent="." node_paths=PackedStringArray("ryn", "camera")]',
         ['script = ExtResource("91_map")', 'ryn = NodePath("../Ryn")', 'camera = NodePath("../FollowCamera")'])
    if route:
        steps = collapse(route)
        pts = ", ".join(f"{s.x * T + 8}, {s.floor * T}" for s in steps)
        acts = ", ".join(f'"{s.action}"' for s in steps)
        node('[node name="DevRoute" type="Node" parent="."]',
             ['script = ExtResource("26_route")', f"points = PackedVector2Array({pts})",
              f"actions = PackedStringArray({acts})"])
    if route_main:
        steps = collapse(route_main)
        pts = ", ".join(f"{s.x * T + 8}, {s.floor * T}" for s in steps)
        acts = ", ".join(f'"{s.action}"' for s in steps)
        node('[node name="DevRouteNoVent" type="Node" parent="."]',
             ['script = ExtResource("26_route")', f"points = PackedVector2Array({pts})",
              f"actions = PackedStringArray({acts})"])

    out.append(f"[gd_scene load_steps={len(EXT) + 1} format=3]\n")
    for typ, path, rid in EXT:
        out.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]\n')
    out.append("\n")
    out.append("\n".join(nodes))
    scene_path.write_text("".join(out), encoding="utf-8")


def collapse(route):
    """连续的走路/蹲行(同一层、同一个动作)只留最后一步,机器人一口气走过去。"""
    out = []
    for st in route:
        if out and st.action in ("walk", "crawl") and out[-1].action == st.action and out[-1].floor == st.floor:
            out[-1] = st
        else:
            out.append(st)
    return out


def _columns(mask, w, h):
    """只让矩形竖着合并(梯子、栅栏是一列一列的)。"""
    return mask


COLORS = {"#": (40, 58, 88), "^": (70, 96, 130), "H": (120, 170, 210), "K": (230, 170, 90), "D": (200, 140, 60), "F": (200, 120, 60)}


def preview(lv: dsl.Level, route, reach, path: pathlib.Path, scale=4):
    img = Image.new("RGB", (lv.w * scale, lv.h * scale), (12, 16, 26))
    d = ImageDraw.Draw(img)
    for y in range(lv.h):
        for x in range(lv.w):
            if lv.sh[y][x] and lv.g[y][x] == " ":
                d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=(22, 30, 54))
    for (x, f) in reach:
        d.rectangle([x * scale, (f - 1) * scale, x * scale + scale - 1, f * scale - 1], fill=(26, 46, 40))
    for y in range(lv.h):
        for x in range(lv.w):
            c = lv.g[y][x]
            if c in COLORS:
                d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=COLORS[c])
    for gd in lv.guards:
        y = (gd.floor - 2) * scale
        col = {"sight": (220, 80, 60), "hearing": (230, 200, 70), "tracking": (170, 110, 230)}[gd.sense]
        d.line([gd.x0 * scale, y, (gd.x1 + 1) * scale, y], fill=col, width=2)
        sx = (gd.spawn if gd.spawn is not None else (gd.x0 if gd.facing >= 0 else gd.x1)) * scale
        d.rectangle([sx, (gd.floor - 3) * scale, sx + scale, gd.floor * scale - 1], fill=(240, 90, 70))
    for sw in lv.sweeps:
        d.line([sw.x * scale, sw.row * scale, (sw.x + sw.span_tiles) * scale, sw.row * scale], fill=(230, 230, 200), width=2)
    for gt in lv.gates:
        d.rectangle([gt.x0 * scale, (gt.floor - gt.h_tiles) * scale, (gt.x1 + 1) * scale, gt.floor * scale],
                    outline=(230, 200, 60))
    for (x, f) in lv.lockers:
        d.rectangle([x * scale, (f - 3) * scale, x * scale + scale + 1, f * scale - 1], fill=(90, 110, 150))
    for a, b in lv.vent_pairs:
        for (x, f) in (a, b):
            d.rectangle([x * scale, (f - 1) * scale, x * scale + scale, f * scale - 1], fill=(160, 200, 120))
        d.line([a[0] * scale, a[1] * scale, b[0] * scale, b[1] * scale], fill=(90, 120, 70))
    for (x, f) in lv.checkpoints:
        d.rectangle([x * scale, (f - 2) * scale, x * scale + scale - 1, f * scale - 1], fill=(80, 200, 220))
    for (x0, x1, f, _, haze) in lv.corrosions:
        c = (150, 60, 220) if haze >= 0.8 else (100, 50, 150)
        d.rectangle([x0 * scale, (f - 1) * scale + scale // 2, (x1 + 1) * scale - 1, f * scale - 1], fill=c)
    story_c = (230, 90, 200)
    for (x0, y0, x1, y1, _) in lv.stories:
        d.rectangle([x0 * scale, y0 * scale, (x1 + 1) * scale - 1, (y1 + 1) * scale - 1], outline=story_c)
    for (x, f, _) in lv.pickups:
        d.rectangle([x * scale, (f - 1) * scale, x * scale + scale - 1, f * scale - 1], fill=story_c)
    for (x, f) in lv.bolts:
        d.rectangle([x * scale, (f - 1) * scale, x * scale + scale - 1, f * scale - 1], fill=(200, 210, 220))
    for (x, f, _, t0, t1) in lv.terminals:
        d.rectangle([x * scale, (f - 3) * scale, (x + 3) * scale - 1, (f - 1) * scale], fill=story_c)
        d.line([t0 * scale, f * scale + 1, (t1 + 1) * scale, f * scale + 1], fill=story_c)
    for (x0, x1, row, rise, _) in lv.winds:
        d.rectangle([x0 * scale, (row - rise) * scale, (x1 + 1) * scale - 1, row * scale - 1], outline=story_c)
    for (_k, x, y, w, h) in lv.decor_props:
        d.rectangle([x * scale // T, y * scale // T, (x + w) * scale // T, (y + h) * scale // T], outline=(70, 80, 96))
    for (x, row, _, (x0, y0, x1, y1)) in lv.broadcasts:
        d.rectangle([x * scale, row * scale, x * scale + scale, row * scale + scale], fill=story_c)
        d.rectangle([x0 * scale, y0 * scale, (x1 + 1) * scale - 1, (y1 + 1) * scale - 1], outline=story_c)
    for (_look, x, f, (rx, ry, rw, rh)) in lv.panels:
        d.rectangle([rx * scale // T, ry * scale // T, (rx + rw) * scale // T, (ry + rh) * scale // T], fill=(240, 240, 240))
    for m in lv.mechs:
        for (x, y) in m.cells:
            col = (230, 130, 40) if m.kind == "shutter" else (230, 210, 60)
            d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], outline=col)
        if m.kind in ("steam", "fuse"):
            x0, y0, x1, y1 = m.data["cloud"] if m.kind == "steam" else m.data["blackout"]
            d.rectangle([x0 * scale, y0 * scale, (x1 + 1) * scale - 1, (y1 + 1) * scale - 1],
                        outline=(200, 220, 240) if m.kind == "steam" else (120, 120, 200))
    for ch in lv.chats:
        gds = {gd.name: gd for gd in lv.guards}
        if ch["a"] in gds and ch["b"] in gds:
            ya, yb = (gds[ch["a"]].floor - 3) * scale, (gds[ch["b"]].floor - 3) * scale
            d.line([ch["meet"][0] * scale, ya, ch["meet"][1] * scale, yb], fill=story_c, width=2)
    if route:
        pts = [(s.x * scale + scale // 2, (s.floor - 1) * scale) for s in route]
        d.line(pts, fill=(250, 220, 90), width=1)
    sx, sf = lv.start_at
    ex, ef = lv.exit_at
    d.rectangle([sx * scale, (sf - 3) * scale, sx * scale + scale, sf * scale], fill=(120, 255, 120))
    d.rectangle([ex * scale - scale, (ef - 4) * scale, ex * scale + 2 * scale, ef * scale], outline=(120, 255, 120), width=2)
    img.save(path)


def build(key: str):
    spec = importlib.util.spec_from_file_location(key, HERE / "levels" / f"{key}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    lv: dsl.Level = mod.make().finish()
    scene = ROOT / "src" / "levels" / f"{mod.SCENE}.tscn"
    issues = dsl.check(lv)
    route, reach = dsl.find_route(lv)
    issues += dsl.story_reach_issues(lv, reach)
    issues += dsl.sweep_timing_issues(lv, route, reach)   # 趁机关还是路线拆开后的样子
    issues += dsl.double_jump_bypass_issues(lv)           # 二段跳会不会让谜题被跳过(2026-10-14)
    lv.mech_open = set()   # 摆道具、写场景都按「机关都还关着」的样子
    theme = getattr(mod, "DECOR", None)
    lv.decor_props = (decor.place(lv, theme, seed=lv.w * 7919 + lv.h) if theme else []) + list(lv.props)
    if theme:
        lv.decor_props += decor.shade_causes(lv, theme, lv.decor_props)
    lv.lamps = []
    if theme:
        lv.decor_props, lv.lamps = decor.lamps(lv, lv.decor_props, theme, seed=lv.w * 7919 + lv.h)
    issues += decor.lamp_issues(lv, lv.lamps)
    route_main = None
    if lv.vent_pairs:
        route_main, _ = dsl.find_route(lv, allow_vents=False)
    issues += dsl.checkpoint_route_issues(lv, route, route_main)
    out_dir = ROOT / "design" / "levels"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{key}.txt").write_text(lv.ascii() + "\n", encoding="utf-8")
    preview(lv, route, reach, out_dir / f"{key}.png")
    write_scene(lv, scene, route, route_main, mod)
    print(f"== {key} → {scene.relative_to(ROOT)}  {lv.w}x{lv.h} 格 ({lv.w * T}x{lv.h * T}px)")
    senses = {k: sum(1 for g in lv.guards if g.sense == k) for k in ("sight", "hearing", "tracking")}
    print(f"   守卫:看 {senses['sight']} · 听 {senses['hearing']} · 追 {senses['tracking']}")
    print(f"   守卫 {len(lv.guards)} · 柜子 {len(lv.lockers)} · 通风管 {len(lv.vent_pairs)} 对 · "
          f"存档点 {len(lv.checkpoints)} · 门禁 {len(lv.gates)} · 探照灯 {len(lv.sweeps)}")
    if lv.mechs:
        kinds = {}
        for m in lv.mechs:
            kinds[m.kind] = kinds.get(m.kind, 0) + 1
        names = {"ladder": "收折梯", "shutter": "铁卷门", "bridge": "吊桥", "cover": "通风口盖板", "steam": "蒸汽阀门", "fuse": "配电箱",
                 "drain": "蚀池排放阀"}
        n_panel = sum(1 for st in (route or []) if st.action == "panel")
        print("   谜题机关:" + " · ".join(f"{names[k]} {v}" for k, v in kinds.items())
              + f"  (路线上拆了 {n_panel} 块面板)")
    if lv.decor_props:
        kinds = {}
        for (k, *_r) in lv.decor_props:
            kinds[k] = kinds.get(k, 0) + 1
        print(f"   背景道具({theme}){len(lv.decor_props)} 件:" + " ".join(f"{k}×{v}" for k, v in sorted(kinds.items())))
        n_lamp = sum(1 for (k, *_r) in lv.decor_props if k.split(":")[0] in decor.LAMPS)
        n_cause = sum(1 for (k, *_r) in lv.decor_props if k.endswith(":dead"))
        print(f"   暗处的坏灯:{n_cause} 盏(暗区顶上,告诉玩家这里为什么暗)")
        print(f"   灯:{n_lamp} 盏,亮 {len(lv.lamps)} 盏(碰到暗区的、本来就坏的不亮;"
              f"接配电箱 {sum(1 for l in lv.lamps if l[6] >= 0)} 盏)")
    beats = len(lv.stories) + len(lv.pickups) + len(lv.terminals) + len(lv.winds) + (1 if lv.fall_text else 0) \
        + len(lv.corrosions) + len(lv.broadcasts) + len(lv.chats)
    if beats:
        print(f"   剧情:旁白 {len(lv.stories)} · 道具 {len(lv.pickups)} · 终端 {len(lv.terminals)} · "
              f"格栅黑雾 {len(lv.winds)} · 摔守卫一句 {'有' if lv.fall_text else '无'} · 蚀 {len(lv.corrosions)} 滩 · "
              f"广播 {len(lv.broadcasts)} · 守卫聊天 {len(lv.chats)}")
    if route is None:
        print(f"   路线:**走不到出口**(能到达 {len(reach)} 个落脚点)")
    else:
        acts = {}
        for s in route:
            acts[s.action] = acts.get(s.action, 0) + 1
        print(f"   路线:{len(route)} 步可达  " + " ".join(f"{k}×{v}" for k, v in sorted(acts.items())))
    if lv.vent_pairs:
        print(f"   不走通风管:{'可达,' + str(len(route_main)) + ' 步' if route_main else '**走不到出口**'}")
    for i in issues:
        print("   问题:", i)
    return route is not None and not issues


def main():
    keys = sys.argv[1:] or sorted(p.stem for p in (HERE / "levels").glob("*.py") if not p.stem.startswith("_"))
    ok = all([build(k) for k in keys])
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
