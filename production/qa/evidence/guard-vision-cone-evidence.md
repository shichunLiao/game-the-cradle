# Test Evidence: 守卫巡逻与视野锥（巡逻／疑心／发现 三态）

> **Story**: `production/epics/the-cradle/story-002-guard-vision-cone.md`
> **Story Type**: Logic
> **Date**: 2026-10-03
> **Tester**: Claude（实现 + 验证）。**用户未试玩本故事** —— Logic 类型不需要 lead sign-off，证据为截图 + 运行日志。
> **Build**: 未提交（用户暂不使用 git 提交）· Godot 4.6.2.stable.official.71f334935

---

## What Was Tested

灰盒测试场 `src/levels/movement_testbed.tscn` 里新增的守卫：巡逻循环、视野锥三态、射线遮挡判定。四次 windowed 运行 + 一次 3000 帧巡逻日志。

**Acceptance criteria covered**: AC-1 至 AC-7（全部）

---

## Acceptance Criteria Results

| # | Criterion | Result | Evidence |
|---|---|---|---|
| AC-1 | 巡逻、端点转身、循环稳定 | PASS | 截图 01 + 3000 帧日志：朝向翻转于 tick 20→360→760→1180，x 在 1180↔1440 之间，每段约 400 tick（339 走 + 72 等）。实测速度 46 px/s，与配置一致 |
| AC-2 | 半透明冷青，随朝向旋转 | PASS | 截图 01（锥向右）vs 04（同一守卫锥向左），颜色 `#3D6B8A` cold-cyan |
| AC-3 | 三态视觉可区分 | PASS | 01 宽冷青 / 05 窄警示黄 / 02–03 红。闪烁经像素确认：帧哈希每 ~10–11 帧交替一次（0.18 s） |
| AC-4 | 锥内 + 无遮挡 ⇒ 发现 | PASS | 截图 02、03；日志 `state=SPOTTED can_see_ryn=true`，`player_spotted` 在 110 帧内只发射一次 |
| AC-5 | 墙体遮挡视线 | PASS | 截图 04：Ryn 完全处于冷青锥内（距守卫 120px，远小于 220px 射程），柱子介于两者之间，守卫保持 PATROL，日志 `can_see_ryn=false` |
| AC-6 | 疑心有时长、超时回巡逻 | PASS | 日志：tick 5 `report_disturbance()` → SUSPICIOUS（13°/170px）持续至 tick 140 → tick 160 回 PATROL（28°/220px）。2.5 s 与配置一致；超时无条件，不可能卡死 |
| AC-7 | 参数外部配置 | PASS | 全部在 `assets/data/guard_default.tres`；`.gd` 内仅余占位美术比例常量与 `COINCIDENT_EPSILON_SQ` |

---

## Screenshots

全部在 `production/qa/evidence/guard-vision-cone/`，640×360（movie writer 按视口分辨率录制），windowed 1280×720 捕获，从未 headless。**五张均由 orchestrator 用 `Read` 逐张打开核对，非转述。**

| # | Filename | What It Shows | AC |
|---|---|---|---|
| 1 | `01-patrol-cone-cold-cyan.png` | 守卫在右侧，宽的半透明冷青锥向右扇出；Ryn 白色剪影在左，柱子居中 | AC-1, AC-2 |
| 2 | `02-spotted-cone-red.png` | 守卫朝左，大片红锥覆盖 Ryn；守卫剪影为深钢蓝（闪烁的暗半） | AC-3, AC-4 |
| 3 | `03-spotted-flash-alternate-frame.png` | 同场景另一帧：锥转为更暗的 rust-red，**守卫剪影填充 rust-red**（闪烁的亮半） | AC-3 |
| 4 | `04-sight-blocked-by-wall-stays-patrol.png` | 守卫朝左，冷青 PATROL 锥覆盖 Ryn，柱子实心横亘其间 —— 未发现 | AC-5 |
| 5 | `05-suspicious-cone-narrow-yellow.png` | 明显更窄的警示黄锥（`#D6B53C`），Ryn 在其 170px 射程之外 | AC-3, AC-6 |

---

## Test Conditions

- **Platform**: macOS (Darwin 25.6.0)，Apple M3 Max，Metal 4.0，Forward+
- **Setup**: dev-only `src/dev/demo_state.gd` 新增 `guard-patrol` / `guard-blocked` / `guard-spotted` / `guard-suspicious` 四个模式。它们不按键（绕过窗口焦点门），静态模式用 `patrol_offset=0 / initial_facing=-1` 钉住守卫以便确定性捕获
- **Import**: 无 error/warning
- **Parse check**: 9 个 `.gd`，一次未经管道的调用，全部 `ok`，**exit=0**

---

## Observations

- **疑心锥颜色已修正。** 初次实现用 `--accent-warm #C4A574`，违反 `美术规格.md` §2 的暖色独占规则（暖色只给照片／吊坠／旧屋／结局）。守卫疑心态频繁出现会稀释终局照片暖光的独占性 —— 那是叙事落点的手段。已改为 `#D6B53C` 并**重新捕获** 05，截图与代码一致。
- **spotted 锥 `#C4453A` 不在色板内**（由 rust-red 派生）。与警示黄同理：警示态刻意跳出环境色板。闪烁仍用色板内的 `#8B3A2F`。
- **锥的绘制不自裁剪。** 遮挡**判定**正确（射线 + 日志），但锥是单个多边形，`z_index=-1` 只让世界几何盖在其上，多边形仍画到障碍之后。整体截断需改射线扇，本故事刻意不做。
- **`PhysicsRayQueryParameters2D` 的 `.from` / `.to` 可写属性未被参考文档覆盖。** 子代理预分配查询对象并每帧改写这两个属性以避免分配。参考文档只记录了 `.create(from, to)` 工厂。此用法经四次运行实证可用，但**文档层面未经查证** —— 若要依赖它，先补证。
- 自动化测试：无。`GuardVision` 为纯静态函数 + Callable 注入，`/test-setup` 装好 gdUnit4 后可直接单测，无需改动。

---

## Sign-Off

Logic 类型按 `.claude/docs/coding-standards.md` 的证据表不要求 lead sign-off —— 留存截图即满足。此处不设签字表，以免产生「有人看过手感」的错误印象：**用户未试玩本故事**。

---

*Location: `production/qa/evidence/guard-vision-cone-evidence.md`*
