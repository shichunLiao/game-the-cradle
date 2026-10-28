"""爬梯 v5 姿势草稿(2026-10-15,用户:「爬楼梯的动作不满意,请学习行业水准」)。还没进游戏。

方案见 docs/ladder-climb-research.md:循环 8 帧、一轮往上 16px(2 档)、手脚钉在横档上、对侧手脚一起动;
挂着 3 帧;抓梯 2 帧 + 空中抓住 1 帧;翻上梯顶 4 帧(全程背面)。爬速 40px/s → 每帧 50ms。

部件:背面上半身(`ryn_back_climb.base` 的第 0–33 行)+ 披风(下摆跟着身体速度甩)+ 两节手臂(按手的位置算手肘)
+ 两条腿 + 靴子。颜色全部取自 ryn_source.png。

    python3 assets/art/src/drafts/ryn_climb_v5_draft.py <输出目录>

出 ryn_climb_v5_sheet.png(逐帧放大,画了横档参考线)和 ryn_climb_v5_preview.gif(梯子上按真速度播)。
"""
import math
import pathlib
import sys
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import ryn_back_climb as rb  # noqa: E402

LW, LH = rb.W, rb.Hh                 # 部件坐标:24x44,脚底在第 43 行
PAD = 4                              # 手肘会伸出 24 格外,画布左右各留 4
O, P, R, Bk, s, e, K, SK2, A = rb.O, rb.P, rb.R, rb.Bk, rb.s, rb.e, rb.K, rb.SK2, rb.A
SCARF = (rb.k, rb.H)
RUNG = 8
SHOULDER = {"L": (6, 20), "R": (17, 20)}
HIP = {"L": (9, 33), "R": (14, 33)}
ARM = 8                              # 上臂、前臂各 8px
UPPER = rb.base.crop((0, 0, LW, 34))     # 头发、头、外套(腿另画)


# ---------------------------------------------------------------- 小工具
def stamp_line(px, w, h, a, b, size, col):
    """像素粗线:沿 Bresenham 每点盖一个 size×size 方块。"""
    (x0, y0), (x1, y1) = (round(a[0]), round(a[1])), (round(b[0]), round(b[1]))
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    r0 = -(size // 2)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for dy in range(r0, r0 + size):
            for dx in range(r0, r0 + size):
                if 0 <= x + dx < w and 0 <= y + dy < h:
                    px[x + dx, y + dy] = col + (A,)


def elbow(sh, hand, out):
    """两节一样长的手臂,手在 hand;手肘往外(out = -1 左 / +1 右)弯。"""
    dx, dy = hand[0] - sh[0], hand[1] - sh[1]
    d = math.hypot(dx, dy)
    if d >= 2 * ARM - 0.01 or d < 0.01:
        return ((sh[0] + hand[0]) / 2, (sh[1] + hand[1]) / 2)
    h = math.sqrt(ARM * ARM - (d / 2) ** 2)
    px_, py_ = -dy / d, dx / d
    if px_ * out < 0:
        px_, py_ = -px_, -py_
    return (sh[0] + dx / 2 + px_ * h, sh[1] + dy / 2 + py_ * h)


def cape(img, ox, oy, sway, hem, flick, lift=(0, 0)):
    """v4 的披风,多三个参数:hem 下摆往下拖几格(身体拉得快时落后)、sway 往哪边甩、
    lift 左右两半下摆被抬起的膝盖顶上去几格(露出靴子)。"""
    cp = img.load()
    m = set()
    bottom = 34 + hem
    for y in range(19, bottom + 3):
        t = min(1.0, (y - 19) / 15)
        xl, xr = round(5 - 3 * t + sway * t), round(18 + 3 * t + sway * t)
        for x in range(xl, xr + 1):
            if y <= bottom - (lift[0] if x <= 11 else lift[1]) + (1 if (x + flick) % 4 < 2 else 0):
                m.add((x, y))
        if y >= bottom and sway and y <= bottom + 2:
            m.add((xr if sway > 0 else xl, y))
    for (x, y) in m:
        t = min(1.0, (y - 19) / 15)
        xr = round(18 + 3 * t + sway * t)
        edge = any((x + dx, y + dy) not in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        cp[x + ox, y + oy] = (O if edge else (e if x == xr - 1 else P)) + (A,)
    for (x0, y0, x1, y1) in ((9, 23, 8 + sway, 32 + hem), (12, 24, 12 + sway, 33 + hem), (15, 23, 16 + sway, 32 + hem)):
        for i in range(y1 - y0 + 1):
            x = round(x0 + (x1 - x0) * i / (y1 - y0)); y = y0 + i
            if (x, y) in m and cp[x + ox, y + oy][:3] == P:
                cp[x + ox, y + oy] = e + (A,)


# ---------------------------------------------------------------- 一帧
def pose(hands, feet, bx=0, by=0, tilt=0, sway=0, hem=0, flick=0, height=LH):
    """hands / feet:{"L": (x, y), "R": (x, y)},部件坐标(24x44,脚底第 43 行;y 可以超过 43,画布跟着加高)。
    bx, by:上半身(含肩、胯)平移;tilt:头往哪边歪 1px。返回 (24+2*PAD) × height 的 RGBA。"""
    img = Image.new("RGBA", (LW + 2 * PAD, height), (0, 0, 0, 0))
    px = img.load()
    w, h = img.size
    ox, oy = PAD + bx, by
    # 腿(在外套、披风后面)
    for side in ("L", "R"):
        hx, hy = HIP[side][0] + ox, HIP[side][1] + oy
        fx, fy = feet[side][0] + PAD, feet[side][1]
        top = (fx, fy - 3)
        bend = max(0, min(2, round((hy + 10 - fy) / 3)))          # 脚抬得越高,膝盖越往外拐
        knee = ((hx + top[0]) / 2 + (-bend if side == "L" else bend), (hy + top[1]) / 2)
        for a, b in ((( hx, hy), knee), (knee, top)):
            stamp_line(px, w, h, a, b, 3, O)
            stamp_line(px, w, h, a, b, 1, s)
        for y in range(fy - 2, fy + 1):                           # 靴子 3x3,鞋底一行深色
            for x in range(fx - 1, fx + 2):
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = (O if y == fy else Bk) + (A,)
    # 上半身:头往伸手那边歪 1px(第 0–12 行)
    up = UPPER.copy()
    if tilt:
        head = up.crop((0, 0, LW, 13))
        up.paste((0, 0, 0, 0), (0, 0, LW, 13))
        up.alpha_composite(head, (tilt, 0))
    img.alpha_composite(up, (ox, oy))
    lift = tuple(max(0, (41 - feet[s_][1]) // 2) for s_ in "LR")      # 脚抬到 39 以上,那半边下摆被膝盖顶起来
    cape(img, ox, oy, sway, hem, flick, lift)
    upx = up.load()
    for y in range(17, 25):                                       # 发尾、围巾压在披风上面
        for x in range(LW):
            if upx[x, y][3] and upx[x, y][:3] in (R,) + SCARF and 0 <= y + oy < h:
                px[x + ox, y + oy] = upx[x, y]
    # 手臂:袖子 4px(描边 + 中间 2px 外套色),拳头 3x2 抓在横档上
    for side, out in (("L", -1), ("R", 1)):
        sh = (SHOULDER[side][0] + ox, SHOULDER[side][1] + oy)
        hd = (hands[side][0] + PAD, hands[side][1])
        el = elbow(sh, hd, out)
        wrist = (hd[0], hd[1] + (1 if hd[1] < sh[1] else -1))
        for a, b in ((sh, el), (el, wrist)):
            stamp_line(px, w, h, a, b, 4, O)
        for a, b in ((sh, el), (el, wrist)):
            stamp_line(px, w, h, a, b, 2, P)
        hx, hy = round(hd[0]), round(hd[1])
        for (x, y, c) in ((hx - 1, hy - 1, K), (hx, hy - 1, K), (hx + 1, hy - 1, K),
                          (hx - 1, hy, SK2), (hx, hy, SK2), (hx + 1, hy, SK2)):
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = c + (A,)
    return img


# ---------------------------------------------------------------- 动作表
# 循环:一轮 8 帧往上 16px。身体每帧上去 [1,1,3,3] —— 伸手时慢、拉的时候快(有重量)。
CUM = [0, 1, 2, 5, 8, 9, 10, 13]
HAND_Y = {"L": [12, 10, 6, 3, 4, 5, 6, 9], "R": [4, 5, 6, 9, 12, 10, 6, 3]}    # 3 = 伸过头一点再抓
FOOT_Y = {"L": [35, 36, 37, 40, 43, 42, 39, 36], "R": [43, 42, 39, 36, 35, 36, 37, 40]}
HAND_X = {"L": [6, 5, 5, 6, 6, 6, 6, 6], "R": [17, 17, 17, 17, 17, 18, 18, 17]}  # 伸手那条往外绕 1px
FOOT_X = {"L": 9, "R": 15}
BX = [0, 1, 1, 0, 0, -1, -1, 0]       # 身体往挂着的那只手那边偏
TILT = [0, 0, -1, -1, 0, 0, 1, 1]     # 头往伸手那边歪
VEL = [3, 1, 1, 3, 3, 1, 1, 3]        # 进这一帧时身体的速度


def loop_frame(i):
    return pose({s_: (HAND_X[s_][i], HAND_Y[s_][i]) for s_ in "LR"},
                {s_: (FOOT_X[s_], FOOT_Y[s_][i]) for s_ in "LR"},
                bx=BX[i], tilt=TILT[i], sway=-BX[(i - 1) % 8], hem=1 if VEL[i] >= 3 else 0, flick=i)


LOOP = [loop_frame(i) for i in range(8)]
# 挂着不动:手脚都钉着,上半身吸气抬 1px,披风慢慢垂
H0 = {"L": (6, 12), "R": (17, 4)}
F0 = {"L": (9, 35), "R": (15, 43)}
IDLE = [pose(H0, F0, flick=0), pose(H0, F0, by=-1, flick=1), pose(H0, F0, hem=1, flick=2)]
# 抓梯(站在地上):右手先伸上去,再抓住、左脚抬起;空中抓住:两手同一档、往下沉 2px、脚还晃着
GRAB = [pose({"L": (4, 31), "R": (17, 14)}, {"L": (9, 43), "R": (15, 43)}, flick=0),
        pose({"L": (6, 22), "R": (17, 6)}, {"L": (9, 39), "R": (15, 43)}, bx=1, hem=1, flick=1)]
CATCH = pose({"L": (6, 6), "R": (17, 6)}, {"L": (9, 43), "R": (15, 41)}, by=2, hem=2, flick=2)
# 翻上梯顶(以「站在梯顶上」为准,地面在第 44 行;by 是身体还在下面多少):
# 两手撑住梯顶往上拉 → 右膝跨上去 → 站起来 → 站直。画布加高 32 行,身体还在洞里的部分画得出来。
TOP_H = LH + 32
TOP = [pose({"L": (3, 43), "R": (20, 43)}, {"L": (9, 74), "R": (15, 70)}, by=30, hem=1, flick=0, height=TOP_H),
       pose({"L": (4, 43), "R": (19, 43)}, {"L": (9, 60), "R": (16, 43)}, by=17, hem=1, flick=1, height=TOP_H),
       pose({"L": (5, 34), "R": (18, 34)}, {"L": (9, 43), "R": (15, 43)}, by=5, flick=2, height=TOP_H),
       pose({"L": (4, 33), "R": (19, 33)}, {"L": (9, 43), "R": (15, 43)}, flick=3, height=TOP_H)]


# ---------------------------------------------------------------- 预览
def contact_sheet(out):
    z = 6
    cw, ch = LW + 2 * PAD, TOP_H
    groups = [("循环 8 帧", LOOP, [[(4 + CUM[i]) % RUNG + RUNG * k for k in range(6)] for i in range(8)]),
              ("挂着 3 / 抓梯 2 / 空中抓住 1", IDLE + GRAB + [CATCH], None),
              ("翻上梯顶 4", TOP, None)]
    sheet = Image.new("RGB", (cw * 8 * z, (ch + 6) * 3 * z), (24, 22, 30))
    d = ImageDraw.Draw(sheet)
    for gi, (_name, frames, rungs) in enumerate(groups):
        for i, f in enumerate(frames):
            x0, y0 = i * cw * z, gi * (ch + 6) * z
            if rungs:                                             # 横档参考线(手、鞋底该落在线上)
                for r in rungs[i]:
                    d.rectangle([x0, y0 + r * z, x0 + cw * z - 1, y0 + r * z + z - 1], fill=(46, 58, 80))
            if gi == 2:
                d.rectangle([x0, y0 + 44 * z, x0 + cw * z - 1, y0 + 44 * z + z - 1], fill=(80, 100, 130))
            big = f.resize((cw * z, f.height * z), Image.NEAREST)
            sheet.paste(big, (x0, y0), big)
    sheet.save(out / "ryn_climb_v5_sheet.png")


def preview_gif(out):
    """场景 48x190:梯顶地面在 y=60,地上 y=186;横档在 y ≡ 4 (mod 8)。"""
    SW, SH, FLOOR, GROUND, LX = 48, 190, 60, 186, 24
    bg = Image.new("RGBA", (SW, SH), (14, 18, 28, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, SH, 8):
        d.line([(0, y), (SW, y)], fill=(19, 24, 36))
    d.rectangle([0, FLOOR, LX - 9, FLOOR + 7], fill=(40, 52, 70)); d.line([(0, FLOOR), (LX - 9, FLOOR)], fill=(80, 100, 130))
    d.rectangle([LX + 8, FLOOR, SW, FLOOR + 7], fill=(40, 52, 70)); d.line([(LX + 8, FLOOR), (SW, FLOOR)], fill=(80, 100, 130))
    d.rectangle([0, GROUND, SW, SH], fill=(40, 52, 70)); d.line([(0, GROUND), (SW, GROUND)], fill=(80, 100, 130))
    d.rectangle([LX - 8, FLOOR, LX - 7, GROUND], fill=(60, 90, 120)); d.rectangle([LX + 6, FLOOR, LX + 7, GROUND], fill=(60, 90, 120))
    for y in range(FLOOR + 4, GROUND, RUNG):
        d.rectangle([LX - 6, y, LX + 5, y + 1], fill=(70, 104, 138))
    seq = []                                                      # (图, 画布左上 y, 毫秒)
    ox = LX - 12 - PAD
    seq += [(GRAB[0], GROUND - LH, 300), (GRAB[1], GROUND - LH, 90)]
    o0 = 136
    for c in range(5):
        for i in range(8):
            o = o0 - 16 * c - CUM[i]
            if o < FLOOR + 4 - 4 - 12:
                break
            seq.append((LOOP[i], o, 50))
            if c == 2 and i == 0:
                seq += [(IDLE[k % 3], o, 280) for k in range(6)]
    top_o = FLOOR - LH
    seq += [(TOP[0], top_o, 90), (TOP[1], top_o, 90), (TOP[2], top_o, 90), (TOP[3], top_o, 700)]
    frames, durs = [], []
    for img, oy, ms in seq:
        f = bg.copy()
        f.alpha_composite(img, (ox, oy) if oy >= 0 else (ox, 0), (0, 0 if oy >= 0 else -oy))
        frames.append(f.convert("RGB").resize((SW * 4, SH * 4), Image.NEAREST))
        durs.append(ms)
    frames[0].save(out / "ryn_climb_v5_preview.gif", save_all=True, append_images=frames[1:], duration=durs, loop=0)


if __name__ == "__main__":
    OUT = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    contact_sheet(OUT)
    preview_gif(OUT)
    print("ok")
