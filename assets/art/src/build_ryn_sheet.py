"""从 ryn_source.png 生成 Ryn 的完整精灵表 assets/art/ryn_sprites.png。

    python3 assets/art/src/build_ryn_sheet.py

## 不动角色建模

每一帧都只用原立绘自己的像素:立绘收成 24x44 的工作图后按色块切成部件
(头发、脸、外套躯干、远/近手臂、远/近大腿、远/近小腿含靴……),每帧只做**整像素平移**
(可以只取部件的一段行,例如只抬前臂;外套前襟的手单独拆出来,原处补外套里衬色),
不缩放、不旋转、不插值、不重画。例外只有三处,
都只用立绘里已有的颜色:
  - 眨眼:眼睛两行换成肤色与睫毛线的颜色;
  - 「藏住」时的眼睛高光:另存一份只有眼睛像素的表(见下),游戏里叠在压暗的身体上;
  - 举照片时手里那张 4x5 的小照片(道具,不是角色);
  - 丢扣件蓄力时手里那颗 3x3 的扣件(道具;领口浅灰 + 瞳孔深灰)。
静止待机第 0 帧拼回去与工作图逐像素一致 —— 脚本末尾自检。

## 动作清单从哪来

见 docs/ryn-animation-research.md。主干照 Celeste(开源的 Player.cs)的选帧规则:
待机 / 待机久了的小动作 / 走 / 跑 / 急停 / 转身 / 顶墙 / 站在边缘 / 抬头 / 蹲 / 跳(起跳、
上升、顶点、下落、落地轻重两种)/ 爬梯与翻上梯顶;潜行游戏另加:蹲行、藏身(与蹲姿
**同一个姿势**,只改颜色 —— Mark of the Ninja 的做法)、拆东西、被发现的惊吓、举照片。

## 表的布局

每格 40x56,脚底中心在格内 (20, 55)。8 列 x 26 行:上半 13 行是动作,下半 13 行是同样
位置的「眼睛高光」(只有眼睛像素,藏身时叠在压暗的身体上)。

     0 待机呼吸 8                       7 跳:起跳 上升快 上升 顶点 下落 下落快 轻落地 重落地
     1 小动作(抬头张望)8             8 爬梯 0-3(背面) / 翻上梯顶 4-5
     2 走 8                             9 顶墙 0-3 / 边缘晃 4-7
     3 跑 6                            10 拆东西 0-5
     4 起跑 0-1 / 急停 2-4 / 转身 5-6  11 被发现 0-3 / 举照片 4-7
     5 蹲下 0-1 过渡 / 2-7 蹲姿呼吸    12 带速度的跳:上升 顶点 下落 下落快
     6 蹲着走 8                        12 带速度的跳 0-3 / 丢扣件 4-7:蓄力 出手 随势 收

待机/走/跑/蹲着走/跳/爬梯这 6 个动作的做法见 docs/ryn-animation-research.md §6;
每帧停留时间不等长,在 ryn_sprite_visual.gd 的 *_WEIGHTS。

行号、帧数必须与 src/player/ryn_sprite_visual.gd 的 ROW_* / 常量一致。

源图只读,开头和结尾各核对一次 SHA-256。
"""
import hashlib
import pathlib
import sys
from collections import Counter

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ART = HERE.parent
SOURCE = HERE / "ryn_source.png"
SOURCE_SHA = (HERE / "ryn_source.sha256").read_text().split()[0]
OUT = ART / "ryn_sprites.png"

CELL_W, CELL_H = 40, 56
COLS = 8
FOOT = (20, 55)                 # 格内脚底中心
LAYER_W, LAYER_H = 24, 44
LAYER_X0 = FOOT[0] - 12         # 部件层在格内的左上角
LAYER_Y0 = FOOT[1] - LAYER_H
THIGH_BOTTOM_ROW = 38
HAND_BOX = (16, 31, 19, 34)     # 手在工作图里的位置 (x0, y0, x1, y1),不含右/下边
BODY_SPLIT = 27                 # 前倾时,外套从这一行分成上下两截
BREATH_SPLIT = 24               # 吸气时,这一行以上随胸口上抬
FOREARM_ROW = 26                # 只抬前臂时,从这一行往下算前臂

# ---------------------------------------------------------------- 立绘 → 部件

HAIR_RGB = {(0xD4, 0x3A, 0x53), (0xFF, 0xBF, 0xC8), (0xD2, 0x6D, 0x7A)}
NEAR_BACKING = (0x37, 0x07, 0x06, 255)
FAR_BACKING = (0x26, 0x1A, 0x12, 255)
SKIN = (0xFF, 0xE1, 0xC2, 255)
LASH = (0x37, 0x07, 0x06, 255)
# 眼睛的颜色:瞳孔深灰与高光白(取自工作图第 12-13 行)
EYE_RGB = {(0x49, 0x58, 0x5B), (0xFF, 0xFF, 0xFF), (0xE3, 0xDD, 0xE0)}
# 照片道具只用立绘里已有的颜色:相纸边 = 领口浅灰,画面 = 外套里的暖粉,一点吊坠黄
PHOTO_EDGE = (0xDF, 0xD9, 0xDC, 255)
PHOTO_FILL = (0xB9, 0x7A, 0x81, 255)
PHOTO_GLOW = (0xFF, 0xC9, 0x6F, 255)
PHOTO_W, PHOTO_H = 4, 5
# 扣件道具:3x3,外圈领口浅灰、中间瞳孔深灰(螺母的孔)
BOLT_EDGE = PHOTO_EDGE
BOLT_HOLE = (0x49, 0x58, 0x5B, 255)
BOLT_W = 3


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def work_image():
    """裁边 → 脚底贴网格最后一行 → 2x2 按 RGB 取众数、全不透明。"""
    src = Image.open(SOURCE).convert("RGBA")
    bbox = src.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()
    crop = src.crop(bbox)
    w, h = crop.size
    hw, hh = (w + 1) // 2, (h + 1) // 2
    pad = Image.new("RGBA", (hw * 2, hh * 2), (0, 0, 0, 0))
    pad.paste(crop, (0, hh * 2 - h))
    out = Image.new("RGBA", (hw, hh), (0, 0, 0, 0))
    for y in range(hh):
        for x in range(hw):
            block = [pad.getpixel((2 * x + dx, 2 * y + dy)) for dy in (0, 1) for dx in (0, 1)]
            opaque = [p[:3] for p in block if p[3] >= 128]
            if len(opaque) >= 2:
                out.putpixel((x, y), Counter(opaque).most_common(1)[0][0] + (255,))
    return out


def classify(x, y, rgb):
    if y <= 23 and rgb in HAIR_RGB:
        return "hair"
    if y <= 16:
        return "head"
    if y >= 34 and 6 <= x <= 9:
        return "far_thigh" if y <= 38 else "far_shin"
    if y >= 39 and x <= 10:
        return "far_shin"
    if y >= 35 and x >= 15:
        return "near_thigh" if y <= 38 else "near_shin"
    if x <= 5 and 22 <= y <= 33:
        return "far_arm"
    if x >= 19 and 19 <= y <= 33:
        return "near_arm"
    return "torso"


NAMES = ["backing_far", "far_thigh", "far_shin", "far_arm", "torso", "head", "hair",
         "near_thigh", "near_shin", "near_arm"]
HEAD_LAYERS = ("head", "head_blink")


def make_layers(work):
    L = {n: Image.new("RGBA", (LAYER_W, LAYER_H), (0, 0, 0, 0)) for n in NAMES}
    for y in range(LAYER_H):
        for x in range(LAYER_W):
            p = work.getpixel((x, y))
            if p[3] == 0:
                continue
            part = classify(x, y, p[:3])
            L[part].putpixel((x, y), p)
            if part == "far_arm":
                L["backing_far"].putpixel((x, y), FAR_BACKING)
            elif part == "near_arm":
                L["torso"].putpixel((x, y), NEAR_BACKING)
    # 手:外套前襟那团白色(第 31-33 行、x 16-18)单独拆出来,原处用外套里衬色补上,
    # 这样跑步挥拳、爬梯往上够才动得了手。不动时画回原处,与立绘逐像素一致。
    hand = Image.new("RGBA", (LAYER_W, LAYER_H), (0, 0, 0, 0))
    x0, y0, x1, y1 = HAND_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = L["torso"].getpixel((x, y))
            if p[3]:
                hand.putpixel((x, y), p)
                L["torso"].putpixel((x, y), NEAR_BACKING)
    L["hand"] = hand
    # 拖尾层:头发与外套下摆的复制,画在最底下,只在轮廓外露出来
    L["hair_trail"] = L["hair"].copy()
    hem = Image.new("RGBA", (LAYER_W, LAYER_H), (0, 0, 0, 0))
    hem.paste(L["torso"].crop((0, 29, LAYER_W, 39)), (0, 29))
    hem.alpha_composite(L["hand"].crop((0, 29, LAYER_W, 39)), (0, 29))   # 拖尾里的手也要在
    L["hem_trail"] = hem
    # 眨眼用的头:眼睛两行(12、13)里的眼色换成肤色/睫毛线
    blink = L["head"].copy()
    for x in range(LAYER_W):
        for y, fill in ((12, SKIN), (13, LASH)):
            p = blink.getpixel((x, y))
            if p[3] and p[:3] in EYE_RGB:
                blink.putpixel((x, y), fill)
    L["head_blink"] = blink
    # 照片道具,放在层坐标 (0,0),用的时候平移到手上
    photo = Image.new("RGBA", (LAYER_W, LAYER_H), (0, 0, 0, 0))
    for y in range(PHOTO_H):
        for x in range(PHOTO_W):
            edge = x in (0, PHOTO_W - 1) or y in (0, PHOTO_H - 1)
            photo.putpixel((x, y), PHOTO_EDGE if edge else PHOTO_FILL)
    photo.putpixel((2, 2), PHOTO_GLOW)
    L["photo"] = photo
    bolt = Image.new("RGBA", (LAYER_W, LAYER_H), (0, 0, 0, 0))
    for y in range(BOLT_W):
        for x in range(BOLT_W):
            bolt.putpixel((x, y), BOLT_HOLE if (x, y) == (1, 1) else BOLT_EDGE)
    L["bolt"] = bolt
    return L


# ---------------------------------------------------------------- 一帧怎么画

class Frame:
    """一帧的绘制指令。每条: (层名, 起始行, 结束行, dx, dy)。"""

    def __init__(self):
        self.ops = []

    def add(self, layer, dx, dy, r0=0, r1=LAYER_H):
        self.ops.append((layer, r0, r1, int(dx), int(dy)))

    def leg(self, prefix, thigh, shin):
        """大腿 + 小腿。被拉开时用整像素重复补:竖向补膝盖,横向补小腿前段。"""
        tl, sl = prefix + "_thigh", prefix + "_shin"
        self.add(tl, *thigh)
        gap = shin[1] - thigh[1]
        for k in range(1, gap + 1):
            x = thigh[0] if k * 2 <= gap else shin[0]
            self.add(tl, x, thigh[1] + k, THIGH_BOTTOM_ROW, THIGH_BOTTOM_ROW + 1)
        reach = shin[0] - thigh[0]
        if abs(reach) >= 2:
            self.add(sl, thigh[0] + int(reach / 2), shin[1], THIGH_BOTTOM_ROW + 1, THIGH_BOTTOM_ROW + 3)
        self.add(sl, *shin)

    def render(self, L, eyes_only=False):
        """eyes_only:只画头部层,并且只留眼睛像素(藏身时的高光表)。"""
        img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        for name, r0, r1, dx, dy in self.ops:
            if eyes_only and name not in HEAD_LAYERS:
                continue
            part = L[name].crop((0, r0, LAYER_W, r1))
            img.alpha_composite(part, (LAYER_X0 + dx, LAYER_Y0 + r0 + dy))
        if eyes_only:
            px = img.load()
            for y in range(CELL_H):
                for x in range(CELL_W):
                    if px[x, y][3] and px[x, y][:3] not in EYE_RGB:
                        px[x, y] = (0, 0, 0, 0)
        return img


def _arm(f, layer, arm, by, upper_dx, breath, split_breath):
    """手臂。arm = (dx, dy) 或 (dx, dy, 前臂dx, 前臂dy):后两项只移动前臂。"""
    dx, dy = arm[0] + upper_dx, by + arm[1]
    fx, fy = (arm[2], arm[3]) if len(arm) > 2 else (0, 0)
    if fx or fy:
        f.add(layer, dx, dy - breath, 0, FOREARM_ROW + 1)
        f.add(layer, dx + fx, dy + fy - breath, FOREARM_ROW, LAYER_H)
    elif breath and split_breath:
        f.add(layer, dx, dy, BREATH_SPLIT, LAYER_H)
        f.add(layer, dx, dy - breath, 0, BREATH_SPLIT + 1)
    else:
        f.add(layer, dx, dy - breath)


def standing(near=((0, 0), (0, 0)), far=((0, 0), (0, 0)), near_arm=(0, 0), far_arm=(0, 0),
             bob=0, lean=0, trail=(0, 0), head="head", breath=0, lift=0,
             upper=0, lower=0, head_dy=0, prop=None, hand=(0, 0), hem=None):
    """站立类姿势(待机/走/跑/跳/爬梯/顶墙/急停……)。

    bob    身体上下(正 = 下沉)。大腿跟着髋走,小腿踩地。
    lift   整个人离地(跑步腾空、跳跃),小腿也一起抬。
    breath 吸气:胸口以上抬 1px,下摆不动。
    lean   头和头发的水平偏移(正 = 朝前)。
    upper  上半截外套与手臂的水平偏移(前倾/后仰);lower = 下半截外套。
    head_dy 头和头发额外的上下偏移(负 = 抬头)。
    trail  头发拖尾层的偏移 (dx, dy):头发慢一拍(随动)。
    hem    外套下摆拖尾层的偏移;不给就跟 trail 一样。下摆比头发更晚、甩得更开。
    hand   手相对原处的偏移(挥拳、往上够)。(0,0) 时按原来的叠放次序画回原处。
    near_arm/far_arm (dx, dy[, 前臂dx, 前臂dy])。
    prop   (层名, dx, dy):画在最上面的道具。
    """
    f = Frame()
    by = bob - lift
    hem = trail if hem is None else hem
    if trail != (0, 0):
        f.add("hair_trail", lean + trail[0], by + trail[1] + head_dy)
    if hem != (0, 0):
        f.add("hem_trail", lower + hem[0], by + hem[1])
    f.leg("far", (far[0][0], far[0][1] + by), (far[1][0], far[1][1] - lift))
    plain = upper == lower == 0
    split = BREATH_SPLIT if upper == lower else BODY_SPLIT
    for layer in ("backing_far", "torso"):
        if plain and not breath:
            f.add(layer, 0, by)
        else:
            f.add(layer, lower, by, split, LAYER_H)
            f.add(layer, upper, by - breath, 0, split + 1)
        if layer == "backing_far":
            _arm(f, "far_arm", far_arm, by, upper, breath, plain)
    moved_hand = hand != (0, 0)
    if not moved_hand:
        f.add("hand", lower, by)            # 原处、原叠放次序 —— 与立绘一致
    f.add(head, lean, by - breath + head_dy)
    f.add("hair", lean, by - breath + head_dy)
    f.leg("near", (near[0][0], near[0][1] + by), (near[1][0], near[1][1] - lift))
    _arm(f, "near_arm", near_arm, by, upper, breath, plain)
    if moved_hand:
        f.add("hand", upper + hand[0], by + hand[1])   # 手跟着上半身走,画在最前面
    if prop:
        f.add(prop[0], prop[1], prop[2] + by, 0, PHOTO_H)
    return f


# 蹲姿(潜行半蹲)。参考见 docs/ryn-animation-research.md:
#   - 整个人都在,腿弯下去、外套中段被压扁,不是把身体切掉;
#   - 前倾:上半截外套前移、头再多前探一点;臀部往后坐(下摆后移 1px);
#   - 高度约站姿的 84%(44 → 37px)。上一版蹲到 75%,用户反馈「蹲太低」。
CROUCH = dict(squish=4, hem_drop=3, lean=2, head_lean=3, knee=2, hem_back=1)


def squat(squish=CROUCH["squish"], hem_drop=CROUCH["hem_drop"], lean=CROUCH["lean"],
          head_lean=CROUCH["head_lean"], knee=CROUCH["knee"], hem_back=CROUCH["hem_back"],
          boots=(-1, 1), breath=0, trail=(0, 0), near_arm=(0, 0), head_dy=0,
          lift=(0, 0), hand=(0, 0), hem=None):
    """蹲姿:外套第 BODY_SPLIT 行起压掉 squish 行;上半身下沉 squish+hem_drop、前移 lean;
    下摆下沉 hem_drop、后移 hem_back;靴子从下摆两侧露出来,近侧膝盖从外套前面顶出。

    near_arm (dx, dy[, 手dx, 手dy]) —— 拆东西时手往前伸。
    lift     (远, 近) 靴子离地几 px,膝盖跟着抬一半 —— 潜行时脚要抬起来再放下。
    hand     手相对下摆的偏移;(0,0) 时按原叠放次序画回原处。
    hem      下摆拖尾层偏移,不给就跟 trail 一样。
    """
    s0 = BODY_SPLIT
    s1 = s0 + squish
    drop = squish + hem_drop       # 上半身下沉量
    up = drop - breath
    lo0 = s1 - 2                   # 下半截多画 2 行,与上半截重叠,吸气时不漏缝
    hem = trail if hem is None else hem
    f = Frame()
    if trail != (0, 0):
        f.add("hair_trail", head_lean + trail[0], up + trail[1] + head_dy)
    if hem != (0, 0):
        f.add("hem_trail", -hem_back + hem[0], hem_drop + hem[1], lo0, LAYER_H)
    f.add("far_shin", boots[0], -lift[0], 39, LAYER_H)
    f.add("far_thigh", knee - 1 + boots[0], -((lift[0] + 1) // 2))
    for layer in ("backing_far", "far_arm", "torso"):
        f.add(layer, -hem_back, hem_drop, lo0, LAYER_H)
    if hand == (0, 0):
        f.add("hand", -hem_back, hem_drop)      # 原处、原叠放次序(上半截会盖住它的第一行)
    for layer in ("backing_far", "far_arm", "torso"):
        f.add(layer, lean, up, 0, s0)
    f.add("head", head_lean, up + head_dy)
    f.add("hair", head_lean, up + head_dy)
    f.add("near_shin", boots[1], -lift[1], 39, LAYER_H)
    f.add("near_thigh", knee + boots[1], -((lift[1] + 1) // 2))
    ax, ay = near_arm[0], near_arm[1]
    fx, fy = (near_arm[2], near_arm[3]) if len(near_arm) > 2 else (0, 0)
    f.add("near_arm", -hem_back + ax + fx, hem_drop + ay + fy, lo0, LAYER_H)
    f.add("near_arm", lean + ax, up + ay, 0, s0)
    if hand != (0, 0):
        f.add("hand", -hem_back + hand[0], hem_drop + hand[1])
    return f


# ---------------------------------------------------------------- 各行

def row_idle():
    """待机呼吸(Celeste / Hollow Knight 的做法:身体几乎不动,活的是头发和衣服)。

    吸气时胸口以上抬 1px;头发晚一拍往后飘 1px,下摆再晚一拍跟着摆 —— 跟随动作
    (follow-through):「头发不是跟着头一起动,而是拖在后面,再追上来」。第 6 帧眨眼。
    帧停留不等长在 ryn_sprite_visual.gd 的 IDLE_WEIGHTS:吸满、呼尽两处停久一点。
    """
    breath = [0, 0, 1, 1, 1, 1, 0, 0]
    hair_dx = [0, 0, 0, -1, -1, -1, 0, 0]      # 头发往后飘,晚于吸气一拍
    hem_dx = [0, 0, 0, 0, -1, -1, -1, 0]       # 下摆再晚一拍
    out = []
    for i in range(8):
        lag = breath[i - 1] - breath[i]        # 头发停在上一帧的高度
        out.append(standing(breath=breath[i], trail=(hair_dx[i], lag), hem=(hem_dx[i], 0),
                            head="head_blink" if i == 6 else "head"))
    return out


def row_fidget():
    """待机久了的小动作(Celeste:idleTimer > 3 秒换一个待机动作)。

    重心移到后脚 → 抬头张望 → 吸一口气 → 放下 → 眨眼 → 回正。第 2 帧兼作「按上抬头」。
    """
    return [
        standing(upper=-1, lower=-1, lean=-1, trail=(1, 0)),                  # 重心后移
        standing(upper=-1, lower=-1, lean=-1, head_dy=-1, trail=(0, 1)),     # 抬头
        standing(upper=-1, lower=-1, lean=0, head_dy=-1),                     # 抬头张望(按上)
        standing(upper=-1, lower=-1, lean=0, head_dy=-1, breath=1, trail=(0, 1)),
        standing(lean=0, head_dy=-1, breath=1, trail=(-1, 0)),
        standing(breath=1, trail=(0, -1)),                                    # 放下
        standing(head="head_blink", trail=(0, -1)),                           # 眨眼
        standing(),
    ]


# 走:8 个不同的姿势。腿 = (大腿偏移, 小腿偏移)
W_FRONT = ((1, 0), (3, 0))
W_FRONT_DOWN = ((1, 0), (2, 0))
W_BACK = ((-1, 0), (-2, 0))
W_BACK_TOE = ((-1, 0), (-3, -1))
W_PASS_SUPPORT = ((0, 0), (0, 0))
W_PASS_SWING = ((1, -2), (0, -2))
W_UP_PUSH = ((-1, 0), (-1, 0))
W_UP_REACH = ((1, -1), (2, -1))


def row_walk():
    """走:触地 → 下沉 → 换步 → 上升,两侧各一遍(SLYNYRD:关键帧要强,换步帧四肢收拢)。

    比上一版多了:手跟着近侧手臂前后摆(往前摆时略抬);外套下摆在换步时往后甩 1px;
    头发、下摆的拖尾按上一帧的高度走(跟随)。帧停留:触地帧略长、下沉帧略短(WALK_WEIGHTS)。
    """
    #            近腿            远腿            近臂 远臂  起伏 下摆
    poses = [(W_FRONT,        W_BACK,         -1, 1, 0, 0),     # 触地
             (W_FRONT_DOWN,   W_BACK_TOE,     -1, 1, 1, 0),     # 下沉
             (W_PASS_SUPPORT, W_PASS_SWING,    0, 0, 0, -1),    # 换步
             (W_UP_PUSH,      W_UP_REACH,      1, -1, -1, -1),  # 上升
             (W_BACK,         W_FRONT,         1, -1, 0, 0),
             (W_BACK_TOE,     W_FRONT_DOWN,    1, -1, 1, 0),
             (W_PASS_SWING,   W_PASS_SUPPORT,  0, 0, 0, -1),
             (W_UP_REACH,     W_UP_PUSH,      -1, 1, -1, -1)]
    out = []
    for i, (n, f, na, fa, bob, low) in enumerate(poses):
        prev_bob = poses[i - 1][4]
        hand = (na, -1 if na > 0 else 0)       # 手随近臂前后摆,往前时抬 1px
        out.append(standing(near=n, far=f, near_arm=(na, 0), far_arm=(fa, 0), bob=bob,
                            lower=low, hand=hand, trail=(-1, prev_bob - bob),
                            hem=(-1 + low, prev_bob - bob)))
    return out


# 跑:步幅更大,2 帧腾空,头前倾 1px
R_FRONT = ((2, 0), (5, 0))
R_FRONT_DOWN = ((1, 0), (3, 0))
R_BACK = ((-2, 0), (-4, -1))
R_BACK_HIGH = ((-2, -1), (-4, -2))
R_PUSH = ((-1, 0), (-2, 0))
R_KNEE_UP = ((2, -3), (1, -3))
R_TRAIL = ((-2, -1), (-4, -2))
R_REACH = ((2, -2), (3, -2))


def row_run():
    """跑:6 帧(SLYNYRD:6 帧最好控制、最有「奔腾感」;帧多了反而泄力)。

    触地(步子跨满)→ 下沉(屈膝吸收)→ 腾空(后腿蹬直、前腿伸出,整个人离地)× 两侧。
    整个人前倾:上半身 +2、头 +3;手像出拳一样往前上方挥,另一侧往后垂;
    头发与外套下摆往后甩 3px,腾空时下摆被风掀起来。帧停留:腾空最长(RUN_WEIGHTS)。
    """
    #  近腿                  远腿                  近臂 远臂  手        起伏 腾空 下摆dy
    poses = [
        (((2, 0), (5, 0)),   ((-2, -1), (-4, -2)), -2, 2, (-2, 1),   0, 0, 0),    # 触地
        (((1, 0), (1, 0)),   ((1, -3), (0, -3)),    0, 0, (0, 0),    2, 0, 1),    # 下沉
        (((-2, -1), (-4, -1)), ((2, -2), (4, -2)),  2, -2, (3, -3),  0, 3, -2),   # 腾空:出拳
        (((-2, -1), (-4, -2)), ((2, 0), (5, 0)),    2, -2, (2, -2),  0, 0, 0),    # 触地(另一侧)
        (((1, -3), (0, -3)), ((1, 0), (1, 0)),      0, 0, (0, 0),    2, 0, 1),    # 下沉
        (((2, -2), (4, -2)), ((-2, -1), (-4, -1)), -2, 2, (-1, 1),   0, 3, -2),   # 腾空
    ]
    out = []
    for i, (n, f, na, fa, hand, bob, lift, hem_dy) in enumerate(poses):
        p = poses[i - 1]
        lag = (p[5] - p[6]) - (bob - lift)     # 头发停在上一帧的高度
        out.append(standing(near=n, far=f, near_arm=(na, 0), far_arm=(fa, 0), bob=bob,
                            lift=lift, upper=2, lean=3, hand=hand,
                            trail=(-3, lag), hem=(-3, lag + hem_dy)))
    return out


def row_moves():
    """起跑 0-1 / 急停 2-4 / 转身 5-6。

    起跑:先压低、身体前倾,再蹬出去(预备动作)。
    急停(Celeste 的 skid):上身后仰、前脚往前撑、后膝弯;头发和下摆借惯性往前甩。
    转身(Celeste 的 flip):双脚并拢、略往下沉,头发和下摆还甩在旧方向(新朝向的身后)。
    """
    return [
        standing(near=((1, 0), (1, 0)), far=((-1, 0), (-3, 0)), near_arm=(-1, 0), far_arm=(1, 0),
                 bob=1, upper=1, lean=2, trail=(-1, 0)),                                # 起跑:压低
        standing(near=R_PUSH, far=R_KNEE_UP, near_arm=(-2, 0), far_arm=(2, 0),
                 upper=1, lean=2, trail=(-2, 1)),                                       # 起跑:蹬出
        standing(near=((2, 0), (4, 0)), far=((-1, 0), (-1, 0)), near_arm=(1, 0), far_arm=(1, -1),
                 bob=1, upper=-1, lean=-2, trail=(2, 0)),                               # 急停 1
        standing(near=((2, 0), (5, 0)), far=((-1, 0), (-2, 0)), near_arm=(1, -1), far_arm=(2, -1),
                 bob=2, upper=-1, lean=-2, trail=(2, -1)),                              # 急停 2:最低
        standing(near=((1, 0), (2, 0)), near_arm=(0, 0), far_arm=(1, 0),
                 bob=1, lean=-1, trail=(1, 0)),                                         # 急停 3:回正
        standing(near_arm=(-1, 0), far_arm=(1, 0), bob=1, lower=-1, lean=-1,
                 trail=(-3, 0)),                                                        # 转身 1
        standing(lower=-1, trail=(-2, 0)),                                              # 转身 2
    ]


def row_crouch():
    """0-1 下蹲过渡(屈膝 → 半蹲);2-7 蹲姿呼吸,上抬 3 帧、落下 1 帧。"""
    out = [standing(bob=2, near=((1, 0), (0, 0)), far=((1, 0), (0, 0)), trail=(0, -1)),
           squat(squish=2, hem_drop=2, lean=1, head_lean=2, knee=1, trail=(0, -1))]
    breath = [0, 1, 1, 1, 0, 0]
    for i in range(6):
        out.append(squat(breath=breath[i], trail=(0, breath[i - 1] - breath[i])))
    return out


def row_crouch_walk():
    """蹲着走 = 潜行(Oddworld 的 Abe 踮脚、Little Nightmares 的蹲行):

    - 脚要**抬起来再放下**:往前迈的那只靴子离地 1-2px、膝盖跟着抬,落地再踩实;
    - **头保持水平**:身体随步子起伏时头往反方向补,眼睛一直盯着前面;
    - 落脚的那一帧停得最久(小心放下),迈脚的帧快(SNEAK_WEIGHTS);
    - 蹲姿本身(高度、前倾)与蹲下/藏身一模一样,用户已认可,不动。
    """
    near_dx = [2, 1, 0, -1, -2, -1, 0, 1]      # 近脚:0→4 踩在地上往后,4→8 抬起往前
    near_lift = [0, 0, 0, 0, 0, 1, 2, 1]
    far_lift = [0, 1, 2, 1, 0, 0, 0, 0]
    bob = [0, 0, 1, 0, 0, 0, 1, 0]             # 迈到一半身体略抬
    out = []
    for i in range(8):
        lag = bob[i - 1] - bob[i]
        out.append(squat(boots=(-near_dx[i], near_dx[i]), lift=(far_lift[i], near_lift[i]),
                         breath=bob[i], head_dy=bob[i], trail=(-1, lag),
                         hem=(-1 - (1 if i in (2, 6) else 0), lag)))
    return out


def row_jump():
    """原地/慢速的跳(Celeste 的 jumpSlow / fallSlow;Saint11 Jump 教程的姿势顺序)。

    起跳:身体拉长 1px、手往上 —— 头发和下摆被甩在下面(拖尾往下 3px);
    上升:膝盖开始收;顶点:双膝收到最高、手往外;
    下落:腿伸下去、手往上抬,头发和外套下摆被风往上掀(拖尾往上 2-3px);
    落地:压扁一下,头发还在往下落(跟随);重落地蹲一下缓冲。
    """
    return [
        standing(near=((0, 0), (0, 1)), far=((0, 0), (0, 1)), near_arm=(0, -2), far_arm=(0, -2),
                 hand=(0, -2), bob=-1, trail=(0, 3), hem=(0, 2)),                  # 起跳
        standing(near=((1, -2), (-1, -3)), far=((1, -2), (-1, -3)), near_arm=(0, -1),
                 far_arm=(0, -1), hand=(0, -2), trail=(0, 2), hem=(0, 2)),         # 上升快
        standing(near=((1, -3), (-1, -4)), far=((1, -2), (0, -3)), near_arm=(0, -1),
                 hand=(1, -1), trail=(0, 1), hem=(0, 1)),                          # 上升
        standing(near=((2, -3), (1, -3)), far=((1, -2), (0, -2)), near_arm=(1, -1),
                 far_arm=(-1, -1), hand=(1, -1), trail=(0, 0), hem=(-1, -1)),      # 顶点:收腿
        standing(near=((0, 0), (0, 1)), far=((0, -1), (-1, 0)), near_arm=(0, -1),
                 far_arm=(0, -1), hand=(0, -2), trail=(0, -2), hem=(-1, -2)),      # 下落
        standing(near=((0, 0), (0, 1)), far=((0, 0), (0, 1)), near_arm=(0, -2),
                 far_arm=(0, -2), hand=(0, -3), trail=(0, -3), hem=(-1, -3)),      # 下落快
        standing(near=((0, 1), (0, 0)), far=((0, 1), (0, 0)), bob=2, trail=(0, 2),
                 hem=(0, 1)),                                                      # 轻落地
        squat(squish=3, hem_drop=3, lean=1, head_lean=2, knee=2, hem_back=0,
              trail=(0, 2), hem=(0, 1)),                                           # 重落地
    ]


def row_air_move():
    """带水平速度的跳(Celeste 的 jumpFast / fallFast):两腿一前一后跨开,身体前倾,
    头发和下摆往后上方甩。上升 / 顶点 / 下落 / 下落快,共 4 帧。"""
    return [
        standing(near=((2, -2), (4, -1)), far=((-2, -1), (-4, -1)), near_arm=(1, -1),
                 far_arm=(-1, 0), hand=(2, -2), upper=1, lean=2, trail=(-2, 2), hem=(-3, 1)),
        standing(near=((2, -3), (2, -3)), far=((-2, -1), (-3, -1)), near_arm=(1, -1),
                 far_arm=(-1, -1), hand=(2, -1), upper=1, lean=2, trail=(-2, 0), hem=(-3, -1)),
        standing(near=((1, 0), (2, 1)), far=((-1, -1), (-2, 0)), near_arm=(0, -1),
                 far_arm=(0, -1), hand=(1, -2), upper=1, lean=1, trail=(-2, -2), hem=(-3, -2)),
        standing(near=((1, 0), (1, 1)), far=((0, 0), (-1, 1)), near_arm=(0, -2),
                 far_arm=(0, -2), hand=(0, -3), upper=1, lean=1, trail=(-2, -3), hem=(-3, -3)),
    ]


class _Whole:
    """一整张画好的 24x44 图(不是部件拼的),放在格子里和部件层同一个位置。没有眼睛高光。"""

    def __init__(self, im):
        self.im = im

    def render(self, L, eyes_only=False):
        img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        if not eyes_only:
            img.alpha_composite(self.im, (LAYER_X0, LAYER_Y0))
        return img


def row_climb():
    """爬梯 0-3:手交替往上够(爬梯动画的要点是手要伸到上面去),腿与手相反,够上去的
    那一下身体被拉起 1px。翻上梯顶 4-5:先抬近侧膝盖踩上去,再落重心。

    只有侧面立绘、手臂短:近侧前臂往上抬 7px、手抬到下巴的高度(再高就会盖住脸),
    远侧(背后那片外套)与它交替上下。

    2026-10-15 起 0-3 换成背面(用户:「爬楼梯需要个角色背面的样子」,定稿 v4 带披风),
    画法见 `ryn_back_climb.py`;翻上梯顶 4-5 还是侧面。
    """
    import ryn_back_climb as back             # 它要 import 本文件,放这里免得循环
    return [_Whole(f) for f in back.frames] + [
        standing(near=((1, -4), (1, -4)), near_arm=(0, 1), far_arm=(0, 1),
                 bob=1, upper=1, lean=1, trail=(0, -1)),                            # 翻上:抬膝
        standing(near=((1, 0), (1, 0)), far=((0, 0), (-1, 0)), bob=1, trail=(0, -1)),  # 落重心
    ]


def row_push_edge():
    """顶墙 0-3(Celeste 的 push:走进墙里时)/ 站在边缘 4-7(Celeste 的 edge)。

    顶墙:整个人前倾,两只前臂往前顶,后脚往后蹬,两脚慢慢交替。
    边缘:身体往前探又往回收,两臂上下乱划保持平衡,头发跟着晃。
    """
    push = (1, 0, 2, -3)           # 上臂前移 1,前臂再往前 2、往上 3:手掌顶在墙上
    return [
        standing(near=((1, 0), (1, 0)), far=((-1, 0), (-3, 0)), near_arm=push, far_arm=push,
                 bob=1, upper=2, lean=3, trail=(-1, 0)),
        standing(near=((1, 0), (1, 0)), far=((-1, 0), (-3, 0)), near_arm=push, far_arm=push,
                 bob=2, upper=2, lean=3, trail=(-1, -1)),
        standing(near=((-1, 0), (-3, 0)), far=((1, 0), (1, 0)), near_arm=push, far_arm=push,
                 bob=1, upper=2, lean=3, trail=(-1, 1)),
        standing(near=((-1, 0), (-3, 0)), far=((1, 0), (1, 0)), near_arm=push, far_arm=push,
                 bob=2, upper=2, lean=3, trail=(-1, -1)),
        standing(near=((0, -1), (1, -1)), near_arm=(1, -1, 1, -4), far_arm=(0, -1, 0, -2),
                 upper=2, lean=3, trail=(-1, 0)),                                   # 往前探
        standing(near=((0, -1), (1, -1)), near_arm=(1, -1, 1, -2), far_arm=(0, -1, 0, -4),
                 upper=2, lean=3, trail=(-1, 1)),
        standing(near_arm=(0, -1, 1, -4), far_arm=(0, -1, 0, -2),
                 upper=1, lean=1, trail=(1, 0)),                                    # 往回收
        standing(near_arm=(0, -1, 1, -2), far_arm=(0, -1, 0, -4), trail=(1, -1)),
    ]


def row_work():
    """拆东西:蹲着,手往前伸。「拧三下,再撬」—— 0-3 拧(手前后小幅交替),4 撬(手往上
    一抬、上身后仰),5 回到起手。"""
    twist = [(1, 0, 2, 0), (1, 0, 3, -1), (1, 0, 2, 0), (1, 0, 3, -1)]
    out = [squat(near_arm=a) for a in twist]
    out.append(squat(near_arm=(0, -1, 2, -3), lean=1, head_lean=2, trail=(1, -1)))   # 撬
    out.append(squat(near_arm=(1, 0, 2, 0), trail=(0, 1)))
    return out


# 举照片时照片相对层原点的位置:贴在抬起的前臂末端(手)前上方
PHOTO_AT = (21, 19)


def row_caught_photo():
    """被发现 0-3:一惊 —— 整个人一跳、双臂缩起、头发甩起来,然后僵住。
    举照片 4-7:前臂一点点抬到胸前,手里一张照片,最后抬头看对方。"""
    px, py = PHOTO_AT
    return [
        standing(lift=2, near_arm=(-1, -2), far_arm=(1, -2), trail=(0, 3)),                  # 惊
        standing(lift=1, near_arm=(-1, -2), far_arm=(1, -2), trail=(0, 1)),
        standing(breath=1, near_arm=(-1, -1), far_arm=(1, -1), lean=-1, trail=(0, -1)),      # 僵住
        standing(breath=1, near_arm=(-1, -1), far_arm=(1, -1), lean=-1),
        standing(near_arm=(0, 0, 1, -2)),
        standing(near_arm=(0, 0, 2, -5), prop=("photo", px, py + 2)),
        standing(near_arm=(0, 0, 2, -7), prop=("photo", px, py)),
        standing(near_arm=(0, 0, 2, -7), prop=("photo", px, py), head_dy=-1, trail=(0, 1)),   # 抬头
    ]


def row_throw():
    """丢扣件(2026-10-11,用户看过预览后定稿):过肩轻抛。
    4 蓄力 —— 瞄准时一直停在这一格:重心微后坐,近手举到耳边捏着扣件,两脚前后错开;
    5 出手 —— 上身前送、头前探,手往前上方甩出(扣件已经离手);
    6 随势 —— 手顺着往前下;7 收 —— 回到站姿,头发晚一拍落下。"""
    legs = dict(near=((1, 0), (2, 0)), far=((-1, 0), (-2, 0)))
    return [
        standing(**legs, upper=-1, lean=-1, near_arm=(-1, -2, 0, -10), hand=(0, -16),
                 prop=("bolt", 17, 13), trail=(1, 0)),                                      # 蓄力
        standing(**legs, upper=1, lean=2, near_arm=(2, -1, 3, -6), hand=(5, -10),
                 trail=(-1, 0), hem=(-1, 0)),                                               # 出手
        standing(**legs, upper=1, lean=1, near_arm=(2, 0, 3, -2), hand=(5, -4),
                 trail=(-1, 1), hem=(-1, 1)),                                               # 随势
        standing(near_arm=(1, 0), hand=(1, -1), trail=(0, 1)),                              # 收
    ]


ROWS = [("待机呼吸", row_idle), ("小动作", row_fidget), ("走", row_walk), ("跑", row_run),
        ("起跑/急停/转身", row_moves), ("蹲下", row_crouch), ("蹲着走", row_crouch_walk),
        ("跳", row_jump), ("爬梯/翻上", row_climb), ("顶墙/边缘", row_push_edge),
        ("拆东西", row_work), ("被发现/举照片", row_caught_photo),
        ("带速度的跳/丢扣件", lambda: row_air_move() + row_throw())]


def build(L):
    """返回 (表, 每行帧数)。上半是动作,下半是同位置的眼睛高光。"""
    rows = len(ROWS)
    sheet = Image.new("RGBA", (CELL_W * COLS, CELL_H * rows * 2), (0, 0, 0, 0))
    counts = []
    for r, (name, fn) in enumerate(ROWS):
        frames = fn()
        assert len(frames) <= COLS, name
        counts.append(len(frames))
        for c, fr in enumerate(frames):
            body = fr.render(L)
            eyes = fr.render(L, eyes_only=True)
            # 只留身体上真正露出来的眼睛(被头发、手臂、道具盖住的不要)
            bp, ep = body.load(), eyes.load()
            for y in range(CELL_H):
                for x in range(CELL_W):
                    if ep[x, y][3] and bp[x, y] != ep[x, y]:
                        ep[x, y] = (0, 0, 0, 0)
            sheet.alpha_composite(body, (c * CELL_W, r * CELL_H))
            sheet.alpha_composite(eyes, (c * CELL_W, (r + rows) * CELL_H))
    return sheet, counts


def main():
    if sha(SOURCE) != SOURCE_SHA:
        print("ryn_source.png 哈希不符 —— 源图被改过,停止。")
        return 1
    work = work_image()
    L = make_layers(work)

    # 自检:待机第 0 帧拼回去 == 工作图(人物模型没动)
    rest = standing().render(L).crop((LAYER_X0, LAYER_Y0, LAYER_X0 + LAYER_W, LAYER_Y0 + LAYER_H))
    diff = sum(1 for a, b in zip(rest.getdata(), work.getdata()) if a != b)
    print(f"待机第 0 帧 vs 原立绘工作图:不同像素 {diff}")
    if diff:
        return 1

    sheet, counts = build(L)
    for r, (name, _fn) in enumerate(ROWS):
        print(f"  行 {r:2} {name}: {counts[r]} 帧")
    sheet.save(OUT)
    print("输出", OUT.relative_to(ART.parent.parent), sheet.size)

    if sha(SOURCE) != SOURCE_SHA:
        print("构建结束时源图哈希变了,停止。")
        return 1
    print("源图 SHA-256 前后一致:", SOURCE_SHA[:16], "…")
    return 0


if __name__ == "__main__":
    sys.exit(main())
