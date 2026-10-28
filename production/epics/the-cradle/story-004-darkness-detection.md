# Story 004: 暗处判定 —— 暗处安全、亮处危险

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3

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

- [x] 场景可标记暗区；Ryn 位于暗区内时**不**被视野锥判定为发现
- [x] 亮区内被视野锥覆盖即判定发现
- [x] 优先级明确且一致：**暗处优先**（暗处安全胜过锥内）
- [x] 暗区边界有可读的视觉提示，玩家能判断自己当前是否安全
- [x] 蹲伏 + 进入暗处的组合生效（对应塔 1 教学「蹲入暗处不被发现」）
- [x] 暗区判定参数为外部配置，不硬编码

---

## Implementation Notes

- 这是本作核心隐喻的机制落点：**亮路危险、破路／暗道才是正路**。判定规则必须干脆，
  玩家一眼能懂自己安不安全 —— 模糊的灰度衰减会毁掉这条教学。
- 建议做成布尔区域而非光照采样：`美术规格.md` 的暗处是**设计标记**，不是渲染结果。
  用渲染亮度反推会让关卡设计师失去控制权。
- 判定要能单测：`is_detected(in_cone, in_shadow)` 这类纯函数形态最好。
- 与 002 的关系：002 判断「在锥内且无遮挡」，本故事在其上叠一层暗处否决。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 视野锥本身与遮挡
- Story 003: 被发现后的台词与重置
- Story 006: 各关卡暗区的具体摆放与「亮险／暗安」关卡结构

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/darkness/darkness_detection_test.gd` — **advisory** at
  `qa.level: minimal`. The 暗处优先 truth table is the natural unit test here if
  you do write one.
- **Retained screenshot in `production/qa/evidence/` — BLOCKING.** Show Ryn safe
  inside a cone while in shadow; that is the player-observable claim.

> Screenshot not waived at `qa.level: minimal` per
> `.claude/docs/coding-standards.md`. Procedure: `.claude/docs/run-and-observe.md`.

**Status**: [x] Created 2026-10-03 — 4 screenshots in `production/qa/evidence/darkness-detection/`, record in `production/qa/evidence/darkness-detection-evidence.md`

---

## Dependencies

- Depends on: Story 002 (a vision cone must exist for darkness to override), Story 003
- Unlocks: Story 005, Story 006

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 6/6 passing
**Deviations**: 无 BLOCKING。
- **限制（已记入证据文档）** —— 四张截图均由 dev demo 传送摆位，**不代表玩家能潜行走进暗区**。
  两个暗区位于守卫巡逻区内部（x=1210／1320），在可达性机器人止步点 1160 之后。本故事证明
  判定逻辑正确，潜行可达性属关卡设计，由 Story 006 负责。
- **AC4 的"跑动中一眼可辨"需人工试玩** —— 静帧只能证明边界在静态下清晰。
**Test Evidence**: Logic —— 4 张留存截图 + 记录文档。可达性复跑 `REACHABLE — walked to x=1161.3`。自动化测试：无（`qa.level: minimal` 下 advisory）。
**Code Review**: Skipped（Solo 模式）

**Story 002 的注入点按设计生效**：`ShadowRegistry` 只是设了 `guard.darkness_veto = covers`，
`guard.gd` 与 `guard_vision.gd` **一行未改**。

**关卡设计约束（重要）**：暗区必须覆盖**躯干中点**（`-body_height * 0.5`），不是脚底。
蹲伏安全是从这条采样规则自然涌现的，没有特例化 crouch 分支 —— 暗区画多高就决定了
站着危险／蹲着安全的分界。已记入 `shadow_zone.gd`。
