class_name DevRoute
extends Node
## DEV ONLY:关卡生成器(`tools/level_builder/`)按 Ryn 的能力搜出来的一条路线。
##
## `--demo=route` 的机器人沿着它走,用真实物理验证「这条路真的走得通」。
## 每一步是一个落脚点(Ryn 脚底的世界坐标)和到达它要做的动作:
##   walk / crawl / jump / gap / drop / climb_up / climb_down / vent /
##   dismantle_hatch / dismantle_fence
## 不影响游戏;只是数据。

@export var points: PackedVector2Array = PackedVector2Array()
@export var actions: PackedStringArray = PackedStringArray()
