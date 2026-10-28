class_name EndingConfig
extends Resource
## Tuning + the ending's lines.
##
## The LINES are content, copied byte-for-byte from `叙事脚本.md` 终局/结局. They
## sit in a resource (not hardcoded) so a typo can be fixed without touching
## code, but they must never be re-worded.
##
## 美术规格.md §2: `--accent-warm #C4A574` is reserved for 照片／吊坠／旧屋／结局.
## This is the ONE place in the project where it is allowed.

@export_group("Lines — 叙事脚本.md 终局, verbatim")
## Vera（空）, on first contact.
@export var vera_hostile: String = "「入侵者。排除。」"
## Ryn, answering.
@export var ryn_plead: String = "「姐姐！是我啊，是Ryn你的妹妹啊！」"
## Vera, as her pupils focus.
@export var vera_waking: String = "「不是叫你别来吗……」"
## Ryn, closing it.
@export var ryn_found: String = "「我就知道肯定阻止不了你的。」"
## 「我找到了」之后 Vera 那一句(2026-10-12 用户定稿,线索链 C6):接住塔4 守卫说的「一路上都说会有人来找她」
## 和塔2 那件叠好的工装 —— 嘴上说别来,心里一直知道。为空就不说。
@export var vera_knew: String = "「就知道你会来。」"
## 旁白（可无声字）after the Ark stops.
@export var narration_rest: String = "可以睡了。"

@export_group("Prompts")
@export var photo_prompt: String = "E 举起照片"

@export_group("Timings")
## 静帧 hold — the frame stops, the pendant glows.
@export var freeze_time: float = 1.6
@export var line_gap: float = 2.6
## 大陆「睡着」: the slow-down. Breathing, not dying.
@export var sleep_fade_time: float = 4.5
@export var before_scene_change: float = 1.2

@export_group("Colours — warm is legal HERE and nowhere else")
## 照片 / 吊坠 / 旧屋暖光.
@export var warm: Color = Color("C4A574")
@export var freeze_dim: Color = Color("0B1220")
@export var freeze_dim_alpha: float = 0.55
