# Story 007: 终局演出 —— 照片唤醒 → 切断 → 旧屋字卡

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-04

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7

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

- [x] 坑底 Vera 认不出 Ryn，播「入侵。……排除。」
- [x] 举起合影触发**静帧**演出，吊坠微光
- [x] Vera 瞳孔聚焦 → 「……别来找我。我说了……」→ Ryn「我找到了。」
- [x] 切断节点为手巧演出，复用 Story 005 的拆解交互
- [x] 方舟停止 → 大陆「睡着」表现：呼吸变慢，**非死亡**
- [x] 旧屋门口结局镜：高塔灯灭、天空安静、两人坐在门口
- [x] 黑屏字卡「大陆睡着了。它累了很久。」
- [x] 暖色（`--accent-warm`）仅出现在照片、吊坠、旧屋暖光，关卡其余部分保持冷色

---

## Implementation Notes

- 全部台词逐字取自 `叙事脚本.md`「终局」与「结局」两节，**不改写、不扩写**。
- 照片是**唯一记忆锚点**：整作只在序章持有 + 终局使用各一次（`叙事脚本.md`「刻意不写」）。
  不要做成可反复使用的道具。
- Vera 那次致死攻击，`叙事脚本.md` 建议「失败仍用统一重开句，保持简单」——
  即复用 Story 003 的「不行，这样会被发现。」，不写专属失败台词。
- 「休眠非死亡」是本作的情感落点，表现上要克制：呼吸变慢、灯灭、安静，不要做成毁灭演出。
- 多结局在 `design/game-brief.md` 的 Out of scope 内 —— 只有这一个结局。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: 拆解交互本体（本故事复用它，不重写）
- Story 006: 坑底关卡的可进入性与 Vera 的致死攻击判定
- Build order step 7: 照片静帧与吊坠高光的终稿美术（尚无故事；先用占位）

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`).

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- **Retained screenshot in `production/qa/evidence/` — BLOCKING.** Plus sign-off in
  `production/qa/evidence/ending-sequence-evidence.md`. Capture the four beats:
  Vera 不认人、照片静帧、切断、旧屋字卡.
- Automated tests: **advisory** at `qa.level: minimal`.

> Screenshot not waived at `qa.level: minimal` per
> `.claude/docs/coding-standards.md` — "tests are, the look is not." For a scripted
> ending sequence the look *is* the deliverable. Procedure:
> `.claude/docs/run-and-observe.md`.

**Status**: [ ] 由用户自行试玩验证 —— 本故事未由 Claude 捕获截图（用户要求停止自动验证以省 token）

---

## Dependencies

- Depends on: Story 005 (dismantle interaction is reused), Story 006 (坑底关卡可进入)
- Unlocks: None — this is the last MVP story

---

## Completion Notes
**Completed**: 2026-10-04
**Criteria**: 8/8 **已实现（built）**，**未验证（not verified）**。

### 验证状态：刻意未做
与 Story 006 同样，按用户要求停止截图与试玩验证。只做静态检查：
- `--import` 无 error；4 个新脚本解析全过，**exit=0**
- 16 个 `.tscn` 的 `ExtResource` 引用与 `load_steps` 全部完整，**BROKEN: none**
- **暖色独占精确核验**：`#C4A574` 在全仓只出现 4 处 —— `ending.tres`、旧屋门口、旧屋吊坠、坑底吊坠。
  四座塔一处没有。（`guard_default.tres` 曾命中是误报：spotted 锥的红 `#C4453A` R 分量碰巧相同。）

**这是一段线性演出，最需要人眼判断节奏。** 时长（静帧 1.6s、台词间隔 2.6s、睡着淡出 4.5s）全是估的，没人看过。

### 交付物
| 文件 | 作用 |
|---|---|
| `src/ending/ending_sequence.gd` | 终局状态流（await 写法，因为它确实是线性的 —— 不像失败循环随时可能触发，那个才需要状态机） |
| `src/ending/photo_trigger.gd` | 举起照片的触发区。**只响应一次**，且必须等 Vera 说完才 arm —— 对应「照片只在序章持有 + 终局使用各一次」 |
| `src/ending/ending_config.gd` + `assets/data/ending.tres` | 台词与时长 |
| `src/ending/old_house_ending.gd` + `src/levels/old_house_ending.tscn` | 旧屋门口结局镜 + 黑屏字卡 |

### 流程（对应 叙事脚本.md 终局 B/C/D）
1. **B** 进坑底 → `VeraSweep`（Story 006 建的）活跃 → 「入侵。……排除。」→「姐姐！是我！Ryn！」→ 照片触发区 arm
2. **C** 玩家躲过扫掠靠近 → 按 E 举照片 → **静帧**（全屏压暗 + 吊坠暖光亮起）→「……别来找我。我说了……」→「我找到了。」
3. **D** 扫掠停止 → 切断节点出现 → **复用 Story 005 的 `Dismantlable`**（按住 E 拆）
4. 拆完 →「不是结束。是终于被允许休息。」→ 4.5 秒均匀淡出（**无震动、无闪白、无音效刺激** —— 是睡着不是毁灭）
5. 切到旧屋：高塔灯灭（两座深色剪影）、两人并排坐门口、暖光门廊
6. 黑屏字卡「大陆睡着了。它累了很久。」

### 台词
全部逐字取自 `叙事脚本.md`，未改写未扩写。失败仍用统一重开句 —— 叙事脚本原文建议「保持简单」，未写专属失败台词。

### 已知风险（因未试玩而无法排除）
- **演出节奏全靠估**。静帧停多久、台词间隔、淡出速度，都需要人看一遍才知道对不对。
- **`PhotoTrigger` 的位置（x=930）与 `VeraSweep` 的致命区（x=900..1140）重叠** —— 玩家要在扫掠间隙冲进去按 E。设计上是对的（紧张感），但**是否真能做到没验证过**；若太难，把触发区左移或延长 `period` 即可。
- 切断节点 `CutNode` 在 x=1060，同样落在扫掠范围内 —— 但此时扫掠已停，应该安全。**未验证。**
