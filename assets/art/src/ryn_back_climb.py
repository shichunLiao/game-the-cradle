"""爬梯背面 4 帧(2026-10-15 用户定稿 v4:背面 + 披风,下摆到膝上)。颜色全部取自 ryn_source.png。

`build_ryn_sheet.row_climb()` 取 `frames` 放进爬梯行 0-3;直接跑本文件只出预览:

    python3 assets/art/src/ryn_back_climb.py <预览输出目录>
"""
import pathlib
import sys
from PIL import Image, ImageDraw
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build_ryn_sheet as b
O, R, P, Bk, s = (55, 7, 6), (212, 58, 83), (123, 104, 138), (38, 26, 18), (68, 23, 22)
H, k, K, e = (144, 150, 152), (223, 217, 220), (255, 225, 194), (89, 57, 73)
HL, CLIP, SK2 = (210, 109, 122), (255, 191, 200), (242, 176, 161)
W, Hh = 24, 44
A = 255

work = b.work_image().transpose(Image.FLIP_LEFT_RIGHT)    # 背面:左右翻过来
wp = work.load()
mask = [[wp[x, y][3] > 0 for x in range(W)] for y in range(Hh)]
# 原图两只垂着的手臂(翻过来以后:x ≥ 18 的 22-33 行、x ≤ 4 的 19-33 行)从外套轮廓拿掉
for y in range(19, 34):
    for x in range(W):
        if (x >= 19 and y >= 22) or (x <= 3 and y >= 19):
            mask[y][x] = False
def solid(x, y): return 0 <= x < W and 0 <= y < Hh and mask[y][x]
def edge(x, y): return solid(x, y) and any(not solid(x + dx, y + dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))

base = Image.new("RGBA", (W, Hh), (0, 0, 0, 0)); bp = base.load()
top = {x: next((y for y in range(Hh) if solid(x, y)), Hh) for x in range(W)}
for y in range(Hh):
    for x in range(W):
        if not solid(x, y): continue
        c = wp[x, y][:3]
        if y <= 17:
            col = R
            if y - top[x] in (1, 2) and 4 <= y <= 8:
                col = HL                                   # 头顶一圈亮面
            bp[x, y] = col + (A,)
        elif y <= 33:
            bp[x, y] = (O if edge(x, y) else P) + (A,)
        else:
            bp[x, y] = (c if c in (O, s, Bk) else s) + (A,)
d = ImageDraw.Draw(base)
# 发丝:从头顶往下散开的几道深线,只画在头发里
RS = (168, 40, 64)   # 头发暗部:原图发色压暗一档
for line in ([(12, 10), (11, 14)], [(8, 11), (7, 15)], [(16, 11), (17, 15)]):
    for (x0, y0), (x1, y1) in zip(line, line[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
            if solid(x, y) and y <= 17: bp[x, y] = RS + (A,)
for (x, y) in [(6, 7), (6, 8)]:
    if solid(x, y): bp[x, y] = CLIP + (A,)                 # 发夹(原图右边那个粉色十字,翻到这边)
# 发尾盖住领口:中间一撮垂到第 19 行
for (x, y) in [(11, 18), (12, 18), (12, 19), (13, 18)]:
    bp[x, y] = R + (A,)
bp[12, 20] = O + (A,)
# 围巾:脖子一圈 + 右边垂下来一截
for x in range(7, 17):
    for y in (17, 18):
        if solid(x, y) and bp[x, y][:3] != R:
            bp[x, y] = (k if (y == 17 and x % 2) else H) + (A,)
for i, y in enumerate(range(19, 25)):
    x = 15 + (1 if i >= 3 else 0)
    if solid(x, y): bp[x, y] = (k if i % 2 == 0 else H) + (A,)
    if solid(x + 1, y): bp[x + 1, y] = H + (A,)
# 外套:肩线、两道褶、下摆里衬、后开衩
for x in range(5, 19):
    if solid(x, 20) and not edge(x, 20) and bp[x, 20][:3] == P: bp[x, 20] = e + (A,)
for (x, y0, y1) in ((8, 23, 31), (16, 23, 31)):
    for y in range(y0, y1):
        if solid(x, y) and not edge(x, y): bp[x, y] = e + (A,)
for y in range(28, 34):
    if solid(12, y) and not edge(12, y): bp[12, y] = O + (A,)
for x in range(W):
    if solid(x, 33) and not edge(x, 33): bp[x, 33] = Bk + (A,)

def sleeve(img, shoulder, hand):
    dd = ImageDraw.Draw(img)
    dd.line([shoulder, hand], fill=O + (A,), width=4)
    dd.line([shoulder, hand], fill=P + (A,), width=2)
    hx, hy = hand
    dd.rectangle([hx - 1, hy - 2, hx, hy - 1], fill=K + (A,))
    img.putpixel((hx - 1, hy - 1), SK2 + (A,))

def cape(img, sway: int, flick: int):
    """披风(v3,用户:「披风效果要出来」):肩下垂到膝上(v4 改短露脚)、下摆往外张,每帧跟着爬的节奏左右摆,外角飘起来。"""
    cp = img.load()
    m = set()
    for y in range(19, 37):
        t = min(1.0, (y - 19) / 15)
        xl, xr = round(5 - 3 * t + sway * t), round(18 + 3 * t + sway * t)
        for x in range(max(0, xl), min(W - 1, xr) + 1):
            if y <= 34 + (1 if (x + flick) % 4 < 2 else 0):    # 波浪下摆
                m.add((x, y))
        if y >= 34 and sway:                                  # 甩出去的那一角多飘两格
            tip = xr if sway > 0 else xl
            if y <= 36: m.add((max(0, min(W - 1, tip)), y))
    for (x, y) in m:
        t = min(1.0, (y - 19) / 15)
        xr = round(18 + 3 * t + sway * t)
        col = O if any((x + dx, y + dy) not in m for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) else (e if x == xr - 1 else P)
        cp[x, y] = col + (A,)
    for (x0, y0, x1, y1) in ((9, 23, 8 + sway, 32), (12, 24, 12 + sway, 33), (15, 23, 16 + sway, 32)):   # 三道褶
        for i in range(y1 - y0 + 1):
            x = round(x0 + (x1 - x0) * i / (y1 - y0)); y = y0 + i
            if (x, y) in m and cp[x, y][:3] == P: cp[x, y] = e + (A,)
    for y in range(17, 25):                                   # 发尾、围巾压在披风上面
        for x in range(W):
            if bp[x, y][3] and bp[x, y][:3] in (R, k, H): cp[x, y] = bp[x, y]

def frame(up_left: bool, mid: bool, sway: int = 0, flick: int = 0):
    img = base.copy()
    legs = img.crop((0, 34, W, Hh)); img.paste((0, 0, 0, 0), (0, 34, W, Hh))
    lift = 2 if mid else 4
    img.alpha_composite(legs.crop((0, 0, 12, 10)), (0, 34 - (0 if up_left else lift)))
    img.alpha_composite(legs.crop((12, 0, W, 10)), (12, 34 - (lift if up_left else 0)))
    cape(img, sway, flick)
    hi = 6 if not mid else 9
    if up_left:
        sleeve(img, (6, 21), (5, hi)); sleeve(img, (17, 21), (19, 16))
    else:
        sleeve(img, (17, 21), (18, hi)); sleeve(img, (6, 21), (4, 16))
    # 从背后看,手在脸前面(用户 2026-10-15:「手应该要在头的后面」):头和头发盖回手臂上面
    ip = img.load()
    for y in range(0, 19):
        for x in range(W):
            if bp[x, y][3]:
                ip[x, y] = bp[x, y]
    return img

frames = [frame(True, False, -1, 0), frame(True, True, 0, 1), frame(False, False, 1, 2), frame(False, True, 0, 3)]
if __name__ == "__main__":
    OUT = sys.argv[1]
    z = 8
    sheet = Image.new("RGB", ((W + 4) * 5 * z, (Hh + 4) * z), (24, 22, 30))
    front = b.work_image().resize((W * z, Hh * z), Image.NEAREST)
    sheet.paste(front, (2 * z, 2 * z), front)
    for i, f in enumerate(frames):
        big = f.resize((W * z, Hh * z), Image.NEAREST)
        sheet.paste(big, ((i + 1) * (W + 4) * z + 2 * z, 2 * z), big)
    sheet.save(f"{OUT}/ryn_back_draft_x8.png")
    scene = Image.new("RGB", (120, 90), (14, 18, 28))
    dd = ImageDraw.Draw(scene)
    for y in range(0, 90, 8):
        dd.line([(0, y), (120, y)], fill=(20, 26, 38))
    for cx in (30, 90):
        dd.line([(cx - 8, 0), (cx - 8, 90)], fill=(60, 90, 120), width=2)
        dd.line([(cx + 7, 0), (cx + 7, 90)], fill=(60, 90, 120), width=2)
        for y in range(4, 90, 7):
            dd.line([(cx - 8, y), (cx + 7, y)], fill=(70, 104, 138))
    scene = scene.convert("RGBA")
    scene.alpha_composite(frames[0], (30 - 12, 32))
    scene.alpha_composite(frames[2], (90 - 12, 28))
    scene.convert("RGB").resize((360, 270), Image.NEAREST).save(f"{OUT}/ryn_back_draft_ingame.png")
    for i, f in enumerate(frames): f.save(f"{OUT}/ryn_back_f{i}.png")
    x8, ig = Image.open(f"{OUT}/ryn_back_draft_x8.png"), Image.open(f"{OUT}/ryn_back_draft_ingame.png")
    out = Image.new("RGB", (x8.width, x8.height + ig.height + 20), (24, 22, 30))
    out.paste(x8, (0, 0)); out.paste(ig, ((x8.width - ig.width) // 2, x8.height + 20))
    out.save(str(pathlib.Path(__file__).resolve().parent / "drafts" / "ryn_back_draft_sheet.png"))
    print("ok")
