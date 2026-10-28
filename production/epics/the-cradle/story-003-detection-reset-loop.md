# Story 003: 发现 → 台词 → 检查点重置 失败循环

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

> Risk is HIGH per `docs/engine-reference/godot/VERSION.md` (4.6 post-cutoff row).
> `/dev-story` spawns `godot-specialist` as a mandatory secondary review.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

Project-wide standards still apply (`.claude/docs/coding-standards.md`):
- Gameplay values are data-driven (external config), never hardcoded
- Public methods unit-testable — dependency injection over singletons

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] 发现触发后 Ryn 立即失去控制，玩家不能继续移动
- [x] 屏幕边缘收束并压暗（`美术规格.md` §5）
- [x] 显示固定台词「不行，这样会被发现。」—— 文本取自 `叙事脚本.md`「系统台词（固定）」表，**不改写**
- [x] 淡入最近已激活的检查点，Ryn 恢复可控
- [x] 重置**不扣任何资源**：无血量、无命数、无死亡计数惩罚
- [x] 守卫位置与可拆物件状态一并回到检查点时的状态
- [x] 关卡可放置多个检查点，重生取最近已激活的那个

---

## Implementation Notes

- 这条串起 001（Ryn）和 002（发现信号），是本作**唯一**的失败反馈路径 —— 没有死亡、没有战斗。
- 台词是固定单句，不要做成对话系统。整作每塔只有入塔／出塔各一句（Story 006）。
- `叙事脚本.md` 提到连续失败第 3 次起「呼吸更重」是**可选**项，且明确「仍起身，无新剧情」——
  不在本故事范围，想做放到打磨阶段。
- 重置要可靠：状态回滚不干净会让后面 005 的拆解故事出现幽灵通路。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 发现的判定本身
- Story 004: 暗处让 Ryn 不被发现
- Story 005: 可拆物件的拆解逻辑（本故事只负责回滚它的状态）
- Story 006: 各关卡检查点的具体摆放

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/detection/detection_reset_test.gd` **OR** a documented
  playtest — **advisory** at `qa.level: minimal`.
- **Retained screenshot in `production/qa/evidence/` — BLOCKING.** Capture the
  台词 + 压暗 frame; that is the whole player-facing payload of this story.

> Screenshot not waived at `qa.level: minimal` per
> `.claude/docs/coding-standards.md`. Procedure: `.claude/docs/run-and-observe.md`.

**Status**: [x] Created 2026-10-03 — 6 screenshots in `production/qa/evidence/detection-reset/`, record in `production/qa/evidence/detection-reset-evidence.md`

---

## Dependencies

- Depends on: Story 001, Story 002 (needs a controllable Ryn and a detection signal)
- Unlocks: Story 004

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 7/7 passing（无 DEFERRED）
**Deviations**:
- **ADVISORY（技术债）** —— `GuardResetAdapter` 用 `guard.set(&"_state_time", 0.0)` 戳了 `Guard` 的私有变量。`guard.gd` 在本故事只读，而只还原 `state` 不清相位时钟会让守卫拿到立刻到期的陈旧 SUSPICIOUS 计时器。干净修法：给 `Guard` 加公开的 `reset_phase_clock()`。
- **未实现（已标注，未擅自加）** —— `美术规格.md` §1 的「被发现时短震动」。它在美术规格里但不在本故事任何 AC 中，且需改 `follow_camera.gd`。
- **路径偏差** —— 子系统放在 `src/reset/` 而非 brief 里建议的 `src/level/`，因为 `src/levels/` 已存在，近似目录名是陷阱。架构与指定一致。
**Test Evidence**: Integration —— 6 张留存截图 + 记录文档。自动化测试：无（`qa.level: minimal` 下 advisory）。`FailSequence` 与两个适配器的时序核心无节点依赖，可直接单测。
**Code Review**: Skipped（Solo 模式）

**AC6 的验证缺口已补**：初版 demo 把守卫钉死（`patrol_offset = 0`），守卫从未移动，"位置回滚"无从验证。补做 `--demo=reset-fail-patrol` 让守卫真实巡逻重测：捕获时 x=1209.1 → 被发现时 x=1369.5 → 重置后 x=1210.7。走出 160px 后回到原位。**截图在此条上不构成证据**（镜头跟随 Ryn，世界坐标变化在屏幕上读不出），证据是日志数值。

**留给 Story 005 的接缝**：
- 组 `&"resettable"` + 契约 `capture_state() -> Dictionary` / `restore_state(state: Dictionary) -> void`
- 参与者在每次捕获时现扫组成员，中途生成的物件会被下一个检查点纳入
- 可拆物件实现这两个方法并入组即可，**协调者一行不用改**

**引擎参考新增并随即更正** `docs/engine-reference/godot/modules/ui-canvaslayer.md`：
初版记录「`Control` 挂 `CanvasLayer` 时 `PRESET_FULL_RECT` 不足，须显式设 position/size」——
**此结论为误诊，已更正**。用户正常启动游戏时引擎报出真因（`scene/gui/control.cpp:1487`
的 non-equal opposite anchors 警告）：anchors 本来就够，layout pass 在 `_ready` 之后才跑，
手动赋的 `size` 会被丢弃。`edge_closure.gd` 已改为只设 anchors + 接 `resized`，
警告消失且画面完全不变（01／02 截图已用修复后的帧重拍）。文件保留了「这条曾经写反」的记录。
另含一批 runtime-verified 但 doc-unverified 的 UI API 清单。
