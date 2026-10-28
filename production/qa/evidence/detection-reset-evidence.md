# Test Evidence: 发现 → 台词 → 检查点重置 失败循环

> **Story**: `production/epics/the-cradle/story-003-detection-reset-loop.md`
> **Story Type**: Integration
> **Date**: 2026-10-03
> **Tester**: Claude（实现 + 验证）。**用户未试玩本故事** —— Integration 类型不要求 lead sign-off。
> **Build**: 未提交 · Godot 4.6.2.stable.official.71f334935

---

## What Was Tested

两次 windowed 运行：`--demo=reset-fail`（守卫钉住，确定性帧号，用于画面证据）与 `--demo=reset-fail-patrol`（守卫真实巡逻，用于 AC6 的位置回滚数值证据）。后一个模式是本次补做的 —— 见下方 AC6。

**Acceptance criteria covered**: AC-1 至 AC-7（全部）

---

## Acceptance Criteria Results

| # | Criterion | Result | Evidence |
|---|---|---|---|
| AC-1 | 发现后立即失去控制 | PASS | 日志：发现当帧即 `input_enabled=false ryn_vx=0.0`，整段序列 Ryn 停在 x=1150 不动。**无截图**（"不能动"拍不出来），证据为日志 + 代码 |
| AC-2 | 屏幕边缘收束并压暗 | PASS | 截图 01（收束中，四边黑条内收，场景变暗）、02（完全闭合） |
| AC-3 | 固定台词「不行，这样会被发现。」 | PASS | 截图 02。字符串与 `叙事脚本.md`「系统台词（固定）」表**逐字节比对一致**，中文字形正常无豆腐块 |
| AC-4 | 淡入最近已激活检查点，恢复可控 | PASS | 重生落点：截图 03。控制恢复：截图 04（真实 `move_right` 按键后 Ryn 移出门框，日志 `ryn_vx=105.0 input_enabled=true`）。渐变过程本身为代码+日志，未单独留帧 |
| AC-5 | 不扣任何资源 | PASS（构造性） | 新代码中不存在血量、命数、计数器或惩罚字段；`DetectionResetConfig` 无惩罚旋钮，`DetectionReset` 不记失败次数。**无可观测物，故无截图** |
| AC-6 | 守卫位置与可拆物件状态一并回滚 | PASS（守卫）／接口就绪（拆物件） | **见下方专节** |
| AC-7 | 多检查点，重生取最近已激活的 | PASS | 截图 03 + 日志：`CheckpointStart (64,320)` 于 tick 1 激活，`CheckpointMid (1000,320)` 于 tick 41 激活，重生 `respawn=(1000.0, 320.0)` —— 取后者 |

---

## AC-6 专节：守卫位置回滚

初版实现的 demo 把守卫钉死（`patrol_offset = 0`），**守卫从未移动，因此"把它移回去"无从验证**。子代理如实标注了这个缺口，随后补做 `--demo=reset-fail-patrol`（守卫正常巡逻）重测：

| 时刻 | tick | 守卫世界 x | 守卫状态 |
|---|---|---|---|
| 检查点捕获 | 40 | **1209.1** | PATROL |
| 被发现 | 505 | **1369.5** | SPOTTED |
| 重置执行后 | 597 | **1210.7** | PATROL |

守卫巡逻走出 160 px，重置后回到捕获位置。1210.7 与 1209.1 相差 1.6 px，是 restore 之后守卫又正常巡逻了一帧才打的日志，**不是回滚误差**。位置与状态均回滚。

**截图在此条上不构成证据，故意不这样标注。** 镜头跟随 Ryn，Ryn 自身从 1150 回到 1000，所以守卫的世界坐标变化在屏幕上读不出来 —— 05／06 两张只是重置前后的场景对照，文件名已相应修改以免误导。本条的证据是上表的日志数值。

**可拆物件**：Story 005 尚不存在，仅交付接口（见下）。

---

## Screenshots

全部在 `production/qa/evidence/detection-reset/`，640×360，windowed 1280×720 捕获，从未 headless。**六张均由 orchestrator 用 `Read` 逐张打开核对。**

| # | Filename | What It Shows | AC |
|---|---|---|---|
| 1 | `01-edges-closing-in.png` | 视口被四边黑条挤成小矩形，地面条被切断；残余窗口里守卫的锥呈被压暗的暗红 | AC-2 |
| 2 | `02-subtitle-on-closed-screen.png` | 全黑屏，下三分之一处一行浅灰蓝文字「不行，这样会被发现。」清晰可读 | AC-3 |
| 3 | `03-respawned-at-checkpoint.png` | 画面已淡回，Ryn 站在 CheckpointMid 门框标记内；守卫的锥已回落为平静的冷青 | AC-4, AC-7 |
| 4 | `04-control-restored-walking.png` | 同场景，Ryn 已移出门框右侧，镜头随之轻微平移 | AC-4 |
| 5 | `05-scene-before-reset-guard-patrolled-out.png` | 重置前：Ryn 在柱子右侧，守卫在远处，冷青锥覆盖 Ryn（发现前一瞬） | 场景对照 |
| 6 | `06-scene-after-reset-respawned-at-checkpoint.png` | 重置后：Ryn 回到门框内，守卫继续巡逻 | 场景对照 |

---

## Story 005 接缝（本故事交付的接口）

- **组名** `CheckpointManager.RESETTABLE_GROUP` = `&"resettable"`
- **契约**（鸭子类型，无基类、无注册调用）：`capture_state() -> Dictionary` / `restore_state(state: Dictionary) -> void`
- 参与者在**每次捕获时**现扫组成员，而非关卡加载时缓存 —— 所以中途生成的物件会被下一个检查点纳入
- Story 005 的可拆物件只需实现这两个方法并 `add_to_group()`，**协调者一行不用改**
- Ryn 与 Guard 通过适配器（`ryn_reset_adapter.gd` / `guard_reset_adapter.gd`）参与，二者对称无特例 —— 这样 `ryn.gd` / `guard.gd` 不必知道检查点系统的存在

---

## Observations / 技术债

- **`guard.set(&"_state_time", 0.0)` 戳了私有变量。** `guard.gd` 在本故事是只读的，而只还原 `state` 不清相位时钟会让守卫拿到一个立刻到期的陈旧 SUSPICIOUS 计时器。适配器里有注释说明。**干净的修法是给 `Guard` 加一个公开的 `reset_phase_clock()`** —— 留作技术债，不在本故事范围。
- **美术规格 §1 的「被发现时短震动」未实现。** 它在美术规格里，但不在本故事任何一条 AC 中，且需要改 `follow_camera.gd`。如实标注，未擅自加。
- **连续失败第 3 次起呼吸加重**：`叙事脚本.md` 明确标为可选且「仍起身，无新剧情」，属打磨，未做。
- 色板：收束用 `--ink-deep #0B1220`，字幕用 `--tower-white #C8D4E0`，全冷色。**`--accent-warm #C4A574` 未出现在本故事任何代码中**（已 grep 确认）。
- 自动化测试：无。`FailSequence` 与两个适配器的时序核心无节点／引擎依赖，`/test-setup` 之后可直接单测。

---

## 未经文档查证的引擎 API

以下均来自训练数据，**运行时可用且产出正确画面，但 `docs/engine-reference/` 无依据** —— 记为 runtime-verified / doc-unverified，不等于"已验证"：

`CanvasLayer.layer`；`Control.set_anchors_preset` / `PRESET_FULL_RECT`；`MOUSE_FILTER_IGNORE`；`CanvasItem._draw` / `draw_rect` / `queue_redraw`；`SystemFont.font_names`；`add_theme_font_override` 及同族；`Label.horizontal_alignment` / `vertical_alignment`；`Viewport.size_changed`；`Engine.get_frames_drawn`。

已查证的只有 `TextServer.AUTOWRAP_WORD_SMART`（`modules/ui.md` 第 73 行）。

**一条曾被误诊的 4.6 行为，已更正。** 子代理报告称 `Control` 挂在 `CanvasLayer` 下时
`PRESET_FULL_RECT` 不足、必须显式设 `position`/`size`，我据此写进了引擎参考。**那是错的。**
用户正常启动游戏时引擎直接报出真因：

```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
     at: _set_size (scene/gui/control.cpp:1487)
```

anchors 本来就够；layout pass 在 `_ready` **之后**才跑，所以 `_ready` 里读到的 `size` 是陈旧值，
误导人以为 anchors 没生效。手动赋的 `size` 随后被 layout 丢弃 —— 它从来不是画面能出来的原因。
`edge_closure.gd` 已改为只设 anchors + 接 `resized` 信号，警告消失，**收束与字幕画面完全不变**
（01／02 两张截图已用修复后的帧重新捕获并逐张核对）。`docs/engine-reference/godot/modules/ui-canvaslayer.md`
已连同"这条曾经写反"一并更正，未静默改写。

---

## Sign-Off

Integration 类型按 `.claude/docs/coding-standards.md` 的证据表不要求 lead sign-off。此处不设签字表，以免产生「有人验过手感」的错误印象：**用户未试玩本故事**。

---

*Location: `production/qa/evidence/detection-reset-evidence.md`*
