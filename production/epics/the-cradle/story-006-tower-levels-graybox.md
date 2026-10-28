# Story 006: 四塔 + 坑底灰盒关卡（亮险／暗安结构）

> **Epic**: The Cradle
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: XL — spans Build order steps 3–5 (schedule weeks W3–W5)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6

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

- [x] 四座塔各有一个灰盒关卡，均可从入口走到出口完整通关
- [x] 每关结构体现「亮路危险、破路／暗道才是正路」
- [x] 塔 1 用场景教三件事，**无弹窗**：暗处安全、等背身再过、破路更安全
- [x] 塔 2 至少一处关键拆解；塔 3 纯窗口时机、无拆或极少拆；塔 4 灯扫 + 平台敏捷
- [x] 坑底关卡可进入，含 Vera 一次致死攻击（只能躲，**不可反击**）—— 接线于 2026-10-04 修复，见上方修正说明
- [x] 每关入塔／出塔各一句字幕，取自 `叙事脚本.md`，不扩写
- [x] 全程无战斗、无支线；失败仅重置、不扣资源
- [x] 五个场景按 `美术规格.md` §4 的色调分区区分
- [x] 序章→四塔可连续串关，含主菜单入口

---

## Implementation Notes

- **这是全 epic 最大的一条**（XL，覆盖排期 W3–W5）。如果做起来发现想拆，用
  `/create-stories` 回访按塔拆成 006a–006d，编号从 007 往后续 —— 不要改写本文件。
- 塔 1 是垂直切片，`里程碑排期.md` W3 有完整的灰盒验收清单，照它做：
  入口 → 教学区（暗处／蹲）→ 巡逻段 → 破路暗道 → 出口。
- **先纸面草图对齐「亮险／暗安」再摆灰盒** —— 排期文末的「本周立即下一步」第 3 条明确要求。
- 灰盒就是色块几何，**不接终稿美术**。美术替换是 Build order 第 7 步，本故事不碰。
- 排期 W3 明确「明确不做（留给后塔）」：精炼塔级拆解链、登记塔灯号窗口、军事塔灯扫加压 ——
  这些属于本故事后段（塔 2–4），但塔 1 阶段不要提前做。
- 坑底的 Vera 只需要能进入 + 一次致死攻击可躲；完整演出在 Story 007。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–005: 所有被本关卡使用的机制（移动、守卫、暗处、拆解、重置）
- Story 007: 照片唤醒、切断、结局字卡的完整演出
- Build order step 7: 像素美术替换、色板落地、打磨冻结（尚无故事）

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

> QL-STORY-READY was skipped (`review_mode: solo`).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/levels/levels_traversal_test.gd` **OR** a documented
  playtest — **advisory** at `qa.level: minimal`. A documented playtest is the
  more honest fit here: 「通关即过」 is the brief's own acceptance bar.
- **Retained screenshot in `production/qa/evidence/` — BLOCKING, one per tower.**
  Five scenes with deliberately distinct palettes; a single screenshot does not
  evidence five levels.

> Screenshot not waived at `qa.level: minimal` per
> `.claude/docs/coding-standards.md`. Procedure: `.claude/docs/run-and-observe.md`.

**Status**: [ ] 由用户自行试玩验证 —— 本故事未由 Claude 捕获截图（用户 2026-10-03 要求停止自动验证以节省 token）
> **2026-10-04 修正**：上方 AC 列表中「坑底关卡可进入，含 Vera 一次致死攻击」一条此前被标记完成，但 `VeraSweep.ryn_caught` 无任何监听者，攻击实际无效果。已接入 `DetectionReset` 并通过无头功能验证，记录见 `production/qa/evidence/vera-sweep-wiring-evidence.md`。**「只能躲」是否躲得掉仍未试玩，且修复后坑底才第一次真的有危险 —— 请优先试玩这里。**

---

## Dependencies

- Depends on: Story 001, 002, 003, 004, 005 — all five mechanics must work first
- Unlocks: Story 007

---

## Completion Notes
**Completed**: 2026-10-04
**Criteria**: 9/9 **已实现（built）**，**未验证（not verified）** —— 见下方说明。

### 验证状态：刻意未做
用户 2026-10-03 要求「你只管开发，测试的事情就交给我自己吧，以防浪费一堆 token」。
因此本故事**没有截图证据、没有跑通关、没有可达性检查**。只做了两项静态检查：

1. `--import` 无 error；7 个新脚本解析全过，**exit=0**
2. 自写静态核对：15 个 `.tscn` 的 `ExtResource` 引用全部有对应声明，`load_steps` 均足够，**BROKEN: none**
3. `grep` 确认四塔与菜单**无 `--accent-warm #C4A574`**（暖色仍独占给照片／吊坠／旧屋／结局）

**这意味着：代码能加载，关卡能打开，但「入口→出口可通关」这条 AC 没有任何人验证过。**
`docs/level-reachability-check.md` 明确写着本故事的验收原文「入口 → 出口可完整通关」要当真 ——
那份验证现在由用户试玩完成。**不要把本故事读作"已验证通关"。**

### 交付物
五个关卡 + 一个菜单，均在 `src/levels/` 与 `src/ui/`：

| 场景 | 设计要点 |
|---|---|
| `tower_1_birthplace.tscn` | 教学塔。**「亮路危险、破路才是正路」做成了结构**：x1000 处分叉，上层亮路（`UpperFloor`，有 `GuardUpper` 巡逻、无暗区）vs 下层暗道（`LowerShadowA/B` 连续暗区）。进下层要先拆 `BrokenHatch`。另有 `TeachCeiling`+`TeachShadow`（蹲行教学，12px 暗区只罩蹲姿）与 `PatrolPillar`+`PatrolShadow`（等背身教学） |
| `tower_2_refinery.tscn` | `CriticalHatch` 拆了让 `GuardCatwalk` 从栈桥坠落；`FenceGrate` 拆了开横向通路。rust-red 锈带配色 |
| `tower_3_registry.tscn` | **无拆解**，纯时机：`GuardWest`／`GuardEast` 相向巡逻形成窗口，三处 alcove 暗区作等待点，出口 `LowGate` 需蹲行。tower-white 灯管配色 |
| `tower_4_military.tscn` | 四名守卫、高低平台、梯子上下、窄道蹲行。惨白 + 深墨 |
| `pit_bottom.tscn` | 坑底房间：Vera 在场，`VeraSweep` 周期性致死扫掠（0.8s 预警 → 0.7s 致命），**只能躲、不能反击、无血量**。violet-haze + slime-black |
| `src/ui/main_menu.tscn` | 序章文本 + 五关选关。`run/main_scene` 已指向它 |

### 台词
全部逐字取自 `叙事脚本.md`，未改写未扩写：塔1「亮的那边……反而更危险。」／「姐姐以前修过这种门。……门禁我撬不开，但缝我钻得过。」；塔2「这种扣件……她教过我。拧三下，再撬。」／「她还在下面。一定是。」；塔3「登记的时候他们漏了我。……这次我也漏过去。」／「……缓蚀者。那是什么。」；塔4「别出声。别出声。」／「坑底……禁止靠近。可她就在禁止的里面。」；坑底「头好沉。……我还记得照片。我还记得她。」；菜单序章「她说别来找我。……那我更得去。」＋「潜入高塔。别被看见。」

### 新增脚本
`tower_level.gd`（关卡根，入塔句+出塔句+切关）、`tower_exit.gd`（出口 Area2D）、`tower_subtitle.gd`+`tower_subtitle_config.gd`（独立字幕系统 —— `FailOverlay` 的字幕写死了失败台词，无法复用）、`level_sequence.gd`（序章→四塔→坑底 顺序）、`vera_sweep.gd`（坑底危险）、`main_menu.gd`。

### 已知风险（因未试玩而无法排除）
- **跳跃高度与平台间距未实测**。按 Ryn 实测跳跃顶点 53px 设计，>48px 的高度都配了梯子，但没跑过。塔4 平台最密集，最可能出问题。
- **守卫巡逻区间与暗区位置未实测**，可能出现「窗口根本等不到」或「暗区白给」。
- **塔1 的教学是否真能教会，只有人能判断。** 结构做出来了，说服力要看玩。
