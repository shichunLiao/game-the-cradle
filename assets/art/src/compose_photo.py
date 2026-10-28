import sys, random
from PIL import Image, ImageChops, ImageFilter, ImageDraw, ImageOps

ROOT = "/Users/shihtsun/2-创作/05-代码工具/Claude code/the cradle/assets/art"
OUT  = sys.argv[1] if len(sys.argv) > 1 else f"{ROOT}/photo_sisters.png"

def figure(path):
    """裁到人物外框。背景是纯白,用『非白』的包围盒裁。"""
    im = Image.open(path).convert("RGB")
    ink = ImageOps.invert(im.convert("L")).point(lambda v: 255 if v > 18 else 0)
    return im.crop(ink.getbbox())

ryn, vera = figure(f"{ROOT}/src/ryn_full.jpg"), figure(f"{ROOT}/src/vera_full.jpg")

# ---- 画布:4:5 竖幅,外加相纸白边 ----
W, H = 600, 750
BORDER, BOTTOM = 20, 34
iw, ih = W - 2 * BORDER, H - BORDER - BOTTOM

# 暖色底:上亮下暗,像屋里一盏灯从上方照下来
bg = Image.new("RGB", (iw, ih))
d = ImageDraw.Draw(bg)
top, bot = (236, 214, 178), (176, 146, 108)
for y in range(ih):
    t = y / ih
    d.line([(0, y), (iw, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)))
floor_y = int(ih * 0.93)
d.rectangle([0, floor_y, iw, ih], fill=(150, 120, 86))         # 地面
d.line([(0, floor_y), (iw, floor_y)], fill=(128, 100, 70), width=2)

# ---- 身高:姐姐 1.0,妹妹矮一截 ----
vera_h = int(ih * 0.92)
ryn_h  = int(vera_h * 0.88)
def scale(im, h): return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
ryn_s, vera_s = scale(ryn, ryn_h), scale(vera, vera_h)

# 并排站近:中线两侧,轻微靠拢
gap = -int(iw * 0.10)
total = ryn_s.width + vera_s.width + gap
x0 = (iw - total) // 2
rx, vx = x0, x0 + ryn_s.width + gap
feet = floor_y + 6
ry, vy = feet - ryn_h, feet - vera_h

# 脚下的软阴影
sh = Image.new("L", (iw, ih), 0)
sd = ImageDraw.Draw(sh)
for x, w in ((rx, ryn_s.width), (vx, vera_s.width)):
    cx = x + w // 2
    sd.ellipse([cx - w * 0.38, feet - 9, cx + w * 0.38, feet + 9], fill=110)
sh = sh.filter(ImageFilter.GaussianBlur(7))
bg = Image.composite(Image.new("RGB", bg.size, (92, 70, 48)), bg, sh)

# 正片叠底:白底直接变成相纸的暖色,没有抠图白边
def multiply_at(base, fig, x, y):
    layer = Image.new("RGB", base.size, (255, 255, 255))
    layer.paste(fig, (x, y))
    return ImageChops.multiply(base, layer)
def silhouette(fig):
    """人物轮廓遮罩:从外圈泛洪填充白底。四周先垫 2px 白边,
    这样双腿之间、贴着裁切边的白也连得到外面,不会被当成人物。"""
    pad = ImageOps.expand(fig, 2, fill=(255, 255, 255))
    ImageDraw.floodfill(pad, (0, 0), (255, 0, 255), thresh=40)
    key = pad.crop((2, 2, pad.width - 2, pad.height - 2))
    r, g, b = key.split()
    bgpx = ImageChops.multiply(ImageChops.multiply(
        r.point(lambda v: 255 if v == 255 else 0),
        g.point(lambda v: 255 if v == 0 else 0)),
        b.point(lambda v: 255 if v == 255 else 0))
    return ImageOps.invert(bgpx)

# 姐姐在后,妹妹在前:先叠姐姐,再把「叠在干净底上的妹妹」按她的轮廓盖上去。
# 直接两层正片叠底会让重叠处的线条叠印在一起发脏。
img = multiply_at(bg, vera_s, vx, vy)
front = multiply_at(bg, ryn_s, rx, ry)
mask = Image.new("L", bg.size, 0)
mask.paste(silhouette(ryn_s), (rx, ry))
img = Image.composite(front, img, mask)

# ---- 相片处理:暖调、褪色、颗粒、暗角 ----
gray = ImageOps.grayscale(img)
sepia = ImageOps.colorize(gray, black=(40, 28, 22), white=(250, 236, 208), mid=(170, 132, 92))
img = Image.blend(img, sepia, 0.42)                              # 留一半原色,不全做成单色
img = img.point(lambda v: int(22 + v * (236 - 22) / 255))        # 抬黑压白 = 褪色

random.seed(7)
noise = Image.effect_noise((iw, ih), 22).convert("RGB")
img = Image.blend(img, ImageChops.overlay(img, noise), 0.18)

vig = Image.new("L", (iw, ih), 0)
ImageDraw.Draw(vig).ellipse([-iw * 0.2, -ih * 0.15, iw * 1.2, ih * 1.15], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(70))
img = Image.composite(img, Image.blend(img, Image.new("RGB", img.size, (60, 42, 30)), 0.45), vig)

# ---- 相纸白边 ----
paper = Image.new("RGB", (W, H), (238, 228, 208))
paper.paste(img, (BORDER, BORDER))
pn = Image.effect_noise((W, H), 10).convert("RGB")
paper = Image.blend(paper, ImageChops.multiply(paper, pn.point(lambda v: 200 + v // 5)), 0.5)
paper.paste(img, (BORDER, BORDER))
paper.save(OUT)
print("saved", OUT, paper.size)
