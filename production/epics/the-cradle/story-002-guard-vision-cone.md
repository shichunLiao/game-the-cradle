# Story 002: 守卫巡逻与视野锥（巡逻／疑心／发现 三态）

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2

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

- [x] 守卫沿预设路径巡逻，到端点转身，循环稳定
- [x] 视野锥为半透明冷青，随守卫朝向旋转（`美术规格.md` §3）
- [x] 三态视觉可区分：巡逻（正常）／疑心（锥变窄变黄）／发现（锥变红 + rust-red 闪）
- [x] Ryn 进入视野锥且视线无遮挡时判定为**发现**
- [x] 墙体遮挡视线：锥被几何体阻断，守卫看不到遮挡物之后的 Ryn
- [x] 疑心态有明确时长，超时回到巡逻，不会永久卡在疑心
- [x] 视野参数（锥角、距离、疑心时长、巡逻速度）为外部配置，不硬编码

---

## Implementation Notes

- 发现**只**产生一个信号；由 Story 003 接收并执行台词与重置。本故事不实现重置。
- 判定逻辑要能脱离场景单测：把「锥内 + 无遮挡」做成纯函数或可注入依赖的方法。
- 三态只是视野锥的表现与参数差异，不是三套 AI —— 不要做成行为树。
- 无战斗：守卫发现 Ryn 后不追击、不攻击，只触发发现信号。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 发现之后的台词、压暗、检查点重置
- Story 004: 暗处让 Ryn 在锥内仍然安全
- Story 005: 拆解改变守卫导航（坠落／改道）
- Story 006: 具体关卡里的巡逻路线布置

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Automated test `tests/unit/guard/guard_vision_cone_test.gd` — **advisory** at
  `qa.level: minimal` (waived; gdUnit4 is not installed until `/test-setup` runs,
  so `commands.test` cannot run yet).
- **Retained screenshot in `production/qa/evidence/` — BLOCKING.** The three cone
  states are player-observable.

> **Why a Logic story still needs the screenshot.**
> `.claude/docs/coding-standards.md` requires a retained screenshot for *every*
> story that changes something player-observable, and explicitly says this is not
> waived at `qa.level: minimal` — "tests are, the look is not." The cone's colour
> states are exactly that. Procedure: `.claude/docs/run-and-observe.md`.

**Status**: [x] Created 2026-10-03 — 5 screenshots in `production/qa/evidence/guard-vision-cone/`, record in `production/qa/evidence/guard-vision-cone-evidence.md`

---

## Dependencies

- Depends on: Story 001 (Ryn must exist and move to be detected)
- Unlocks: Story 003, Story 004, Story 005

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 7/7 passing（无 DEFERRED）
**Deviations**:
- **已修正** —— 疑心锥初次实现用了 `--accent-warm #C4A574`，违反 `美术规格.md` §2「暖色只出现在照片／吊坠／旧屋／结局门口」的独占规则。已改为非色板警示黄 `#D6B53C` 并重拍证据 05。暖色独占性是终局情感落点的手段，不能被守卫状态稀释。
- **ADVISORY** —— spotted 锥用 `#C4453A`，非色板色（由 rust-red 派生）。与警示黄同理：警示态刻意跳出环境色板，`#8B3A2F` rust-red 仍用于闪烁。
- **ADVISORY（视觉局限）** —— 锥是单个多边形，`z_index = -1` 让世界几何盖在它上面，所以遮挡物在锥上切出缺口，但多边形仍绘制到障碍之后。遮挡的**判定**是正确的（射线，日志 `can_see_ryn=false`），只是锥的**绘制**不自裁剪。要让锥在障碍处整体截断需改成射线扇，本故事刻意不做。
**Test Evidence**: Logic —— 5 张留存截图 + 记录文档。自动化测试：无（`qa.level: minimal` 下 advisory；gdUnit4 未装）。`GuardVision` 写成纯静态可注入形式，`/test-setup` 之后可直接单测。
**Code Review**: Skipped（Solo 模式）

**留给后续故事的接口**：
- `signal player_spotted(player: Node2D, guard: Guard)` —— Story 003 接收它做台词+重置。目前无人消费，这是正确状态。
- `GuardVision.can_see(..., is_occluded: Callable, is_hidden: Callable)` —— `is_hidden` 是 Story 004 暗处否决的预留注入点，接上去不用改本类。
- `Guard.report_disturbance()` —— Story 005 拆解噪音的公开钩子。
- `PhysicsLayers.GUARD_VISION = 16`（layer 5）。守卫本体 `collision_layer = 0`，Ryn 撞不到守卫（无战斗）。
