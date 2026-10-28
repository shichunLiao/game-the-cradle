"""侧面爬梯草稿(2026-10-15,用户看过背面 v5 草稿:「还是太丑」→ 选「改回侧面爬梯」)。还没进游戏。

只用原立绘部件平移(`build_ryn_sheet.standing`),不新画。方案照 docs/ladder-climb-research.md:
循环 8 帧、一轮往上 16px(2 档)、身体每帧上去 [1,1,3,3](伸手慢、拉的时候快);
近侧手伸上去抓 → 抓着的时候按身体上升量往下补(手钉在横档上);背后那只手反相;腿和手对侧交替高抬膝;
伸手时抬头 1px;拉得快的那帧头发、下摆落后 1px。另有挂着 3 帧、抓梯 1 帧。爬速 40px/s → 每帧 50ms。

    python3 assets/art/src/drafts/ryn_climb_side_draft.py <输出目录>
"""
import pathlib
import sys
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_ryn_sheet as b  # noqa: E402

CUM = [0, 1, 2, 5, 8, 9, 10, 13]
VEL = [3, 1, 1, 3, 3, 1, 1, 3]
HAND_DY = [-4, -6, -10, -13, -12, -11, -10, -7]      # 近侧手:0-3 伸上去(-13 伸过头一点),4-7 抓着往下补
HAND_DX = [1, 1, 2, 2, 1, 1, 1, 1]
FAR_DY = [-8, -7, -6, -3, 0, -2, -5, -9]             # 背后那只手:反相
NEAR_SHIN = [-8, -7, -6, -3, 0, -1, -4, -7]          # 近侧腿:0-4 踩着,4-7 抬上去
FAR_SHIN = [0, -1, -4, -7, -8, -7, -6, -3]           # 背后腿:0-3 抬上去,4-7 踩着


def leg(shin):
    knee = 1 if shin <= -4 else 0                     # 抬起来的腿膝盖往前顶
    return ((knee, round(shin * 0.5)), (knee, shin))


def loop_frame(i):
    hd = HAND_DY[i]
    return b.standing(near=leg(NEAR_SHIN[i]), far=leg(FAR_SHIN[i]),
                      near_arm=(0, -2 if hd <= -10 else (-1 if hd <= -6 else 0), HAND_DX[i], round(hd * 0.75)),
                      far_arm=(0, FAR_DY[i]), hand=(HAND_DX[i], hd),
                      head_dy=-1 if i in (2, 3) else 0,
                      trail=(0, 1) if VEL[i] >= 3 else (0, 0), hem=(0, 1) if VEL[i] >= 3 else (0, 0))


def frames():
    loop = [loop_frame(i) for i in range(8)]
    hang = dict(near=leg(-8), far=leg(0), near_arm=(0, 0, 1, -3), far_arm=(0, -8), hand=(1, -4))
    idle = [b.standing(**hang), b.standing(breath=1, **hang), b.standing(hem=(0, 1), **hang)]
    grab = [b.standing(near_arm=(0, -2, 2, -9), hand=(2, -12), far=leg(-3), bob=1)]
    return loop, idle, grab


if __name__ == "__main__":
    OUT = pathlib.Path(sys.argv[1])
    L = b.make_layers(b.work_image())
    loop, idle, grab = frames()
    R = lambda fs: [f.render(L) for f in fs]          # noqa: E731
    LOOP, IDLE, GRAB = R(loop), R(idle), R(grab)
    over = b.row_climb()[4:]                          # 翻上梯顶:沿用现有侧面 2 帧(行 8 第 4-5 格)
    OVER = R(over)
    cw, ch, z = b.CELL_W, b.CELL_H, 6
    # 逐帧表:第一排循环(画横档参考线),第二排挂着 / 抓梯 / 翻顶
    sheet = Image.new("RGB", (cw * 8 * z, ch * 2 * z + 6 * z), (24, 22, 30))
    d = ImageDraw.Draw(sheet)
    hand_row = b.LAYER_Y0 + 32
    for i, f in enumerate(LOOP):
        for k in range(7):                            # 横档:第 4 帧抓住的那一档,跟着身体往下补
            r = (hand_row - 12 + CUM[i] - CUM[4]) % 8 + 8 * k
            d.rectangle([i * cw * z, r * z, (i + 1) * cw * z - 1, r * z + z - 1], fill=(46, 58, 80))
        sheet.paste(f.resize((cw * z, ch * z), Image.NEAREST), (i * cw * z, 0), f.resize((cw * z, ch * z), Image.NEAREST))
    for i, f in enumerate(IDLE + GRAB + OVER):
        big = f.resize((cw * z, ch * z), Image.NEAREST)
        sheet.paste(big, (i * cw * z, (ch + 6) * z), big)
    sheet.save(OUT / "ryn_climb_side_sheet.png")
    # 预览:梯子在 x=24,横档 y ≡ 4 (mod 8),梯顶地面 y=60,地上 y=186
    SW, SH, FLOOR, GROUND, LX = 48, 190, 60, 186, 24
    bg = Image.new("RGBA", (SW, SH), (14, 18, 28, 255))
    g = ImageDraw.Draw(bg)
    for y in range(0, SH, 8):
        g.line([(0, y), (SW, y)], fill=(19, 24, 36))
    for x0, x1 in ((0, LX - 9), (LX + 8, SW)):
        g.rectangle([x0, FLOOR, x1, FLOOR + 7], fill=(40, 52, 70)); g.line([(x0, FLOOR), (x1, FLOOR)], fill=(80, 100, 130))
    g.rectangle([0, GROUND, SW, SH], fill=(40, 52, 70)); g.line([(0, GROUND), (SW, GROUND)], fill=(80, 100, 130))
    g.rectangle([LX - 8, FLOOR, LX - 7, GROUND], fill=(60, 90, 120)); g.rectangle([LX + 6, FLOOR, LX + 7, GROUND], fill=(60, 90, 120))
    for y in range(FLOOR + 4, GROUND, 8):
        g.rectangle([LX - 6, y, LX + 5, y + 1], fill=(70, 104, 138))
    fx = LX - b.FOOT[0]
    # 抓着的手(格内第 hand_row-12 行)要落在横档上:o + hand_row - 12 ≡ 4 (mod 8) 在第 4 帧
    o4 = None
    seq = [(b.standing().render(L), GROUND - b.FOOT[1] - 1, 300), (GRAB[0], GROUND - b.FOOT[1] - 1, 120)]
    base = GROUND - b.FOOT[1] - 1 - 6
    base -= (base - 8 + hand_row - 12 - 4) % 8
    for c in range(6):
        for i in range(8):
            o = base - 16 * c - CUM[i]
            if o + b.FOOT[1] < FLOOR + 30:
                break
            seq.append((LOOP[i], o, 50))
            if c == 2 and i == 0:
                seq += [(IDLE[k % 3], o, 280) for k in range(6)]
    top = FLOOR - b.FOOT[1] - 1
    seq += [(OVER[0], top, 90), (OVER[1], top, 90), (b.standing().render(L), top, 700)]
    out = []
    for img, oy, _ms in seq:
        f = bg.copy()
        f.alpha_composite(img, (fx, max(oy, 0)), (0, max(-oy, 0)))
        out.append(f.convert("RGB").resize((SW * 4, SH * 4), Image.NEAREST))
    out[0].save(OUT / "ryn_climb_side_preview.gif", save_all=True, append_images=out[1:],
                duration=[s[2] for s in seq], loop=0)
    print("ok")
