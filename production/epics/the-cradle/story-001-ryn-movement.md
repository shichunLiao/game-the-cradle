# Story 001: Ryn 移动组 —— 走、跳、蹲、爬

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

> Risk is HIGH per `docs/engine-reference/godot/VERSION.md` (4.6 post-cutoff row).
> `/dev-story` spawns `godot-specialist` as a mandatory secondary review.
> The pinned reference is 4.6; the installed editor is 4.6.2.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

Project-wide standards still apply (`.claude/docs/coding-standards.md`):
- Gameplay values are data-driven (external config), never hardcoded
- Public methods unit-testable — dependency injection over singletons

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] Ryn 可左右行走，有明确的加减速起停，不瞬时满速
- [ ] 跳跃弧线可控；同一按键时长产生同一跳跃高度（可重复、可预测）
- [ ] 蹲伏时碰撞体与精灵轮廓**同时**收矮；站立／蹲伏切换无卡顿或穿模
- [ ] 可攀爬梯子／管道，攀爬中四肢姿态可读（`美术规格.md`：剪影优先）
- [ ] 窗口以 640×360 逻辑分辨率整数倍放大，像素无插值模糊
- [ ] 镜头横向跟随 Ryn，带轻微朝向预判
- [ ] 移动参数（速度、加速度、跳跃高度、重力）为外部配置，不硬编码

---

## Implementation Notes

- 这是**整个游戏的地基**：002–007 全部依赖它。先把手感调对，再往上加东西。
- Build order 第 1 步的原话是「验潜行手感」——本故事的交付标准是手感对，不是功能全。
- 640×360 + 整数缩放的具体项目设置键**不要凭记忆写**：`project.godot` 目前只有
  `config_version` / `config/name` / `config/features` / `renderer/rendering_method`，
  分辨率与缩放键留空是故意的。照 `docs/engine-reference/godot/` 查证后再写。
- 无战斗，所以不需要任何受击、血量或击退逻辑。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 守卫、视野锥、任何被发现的判定
- Story 003: 失败后的台词与重置
- Story 004: 暗处是否安全
- Story 005: 拆物件交互

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`), so no `qa-lead` specs were
> authored. Run `/qa-plan` if you later want formal cases.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- **Retained screenshot in `production/qa/evidence/` — BLOCKING.** Plus sign-off in
  `production/qa/evidence/ryn-movement-evidence.md`.
- Automated tests: **advisory** at `qa.level: minimal` (waived, not required to pass).

> **The screenshot is not waived.** `.claude/docs/coding-standards.md`: "A parse
> check is not a run. Every story that changes something player-observable is
> launched and observed before it closes… Not waived at `qa.level: minimal` —
> tests are, the look is not." Procedure: `.claude/docs/run-and-observe.md`.
>
> `commands.run` is set and works. `commands.smoke` will **hang** until
> `run/main_scene` is set in `project.godot` — setting it is part of this story,
> since this is the first story to create a scene.

**Status**: [x] Created 2026-10-03 — 5 screenshots in `production/qa/evidence/ryn-movement/`, lead sign-off in `production/qa/evidence/ryn-movement-evidence.md`

---

## Dependencies

- Depends on: None — this is the first story
- Unlocks: Story 002, Story 003, Story 004

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 7/7 passing（无 DEFERRED）
**Deviations**: 无 BLOCKING。ADVISORY 一条 —— `src/player/ryn.gd` 爬梯边界容差 `2.0`（像素）是字面量，未外置；非手感数值，不影响通过。
**Test Evidence**: Visual/Feel —— 5 张留存截图 `production/qa/evidence/ryn-movement/` + 签字文件 `production/qa/evidence/ryn-movement-evidence.md`（`[x] Approved`）。自动化测试：无（`qa.level: minimal` 下 advisory；gdUnit4 未装）。
**Code Review**: Skipped（Solo 模式；QL-TEST-COVERAGE 因 `qa.level: minimal` 同样跳过）

**已知事实**：
- 跳跃实测顶点 53.4px，低于配置 `jump_height = 56`（60Hz 积分误差），未调参掩盖；用户试玩判定可接受。
- 实现期间修复 1 个 bug：梯子感应区过短导致顶部反复抓梯抖动（`ryn.tscn` 感应区改为 size(4,24) @ y=-12）。
- `project.godot` 的 `run/main_scene` 现指向灰盒测试场 `res://src/levels/movement_testbed.tscn`，等 Story 006 有真关卡后需更换。
- 2D 默认贴图过滤的项目设置键名 NOT SOURCEABLE（见 `docs/engine-reference/godot/modules/display-2d.md`）；本故事全是纯色块无贴图，未涉及。首个用到贴图的故事必须先在编辑器里确认该键。
- `src/dev/demo_state.gd` 是 dev-only 截图辅助脚本（`--demo=...` 用户参数），不含玩家可见内容，可从场景移除。
