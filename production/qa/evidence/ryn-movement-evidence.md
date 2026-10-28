# Test Evidence: Ryn 移动组 —— 走、跳、蹲、爬

> **Story**: `production/epics/the-cradle/story-001-ryn-movement.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-10-03
> **Tester**: 项目开发者（用户，亲自试玩）；截图由 Claude 逐张打开核对
> **Build / Commit**: 未提交（用户暂不使用 git 提交）· Godot 4.6.2.stable.official.71f334935

---

## What Was Tested

灰盒测试场 `src/levels/movement_testbed.tscn`（已设为 `run/main_scene`）里 Ryn 的走、跳、蹲、爬，以及 640×360 整数缩放与镜头跟随。用户在 1280×720 窗口模式下实际试玩，随后对每条行为类验收条件逐一确认。

**Acceptance criteria covered**: AC-1 至 AC-7（全部）

试玩命令：

```
"/Users/shihtsun/Downloads/Godot.app/Contents/MacOS/Godot" --path . --windowed --resolution 1280x720
```

启动日志：Forward+ / Metal 4.0 / Apple M3 Max，无 `SCRIPT ERROR`。

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Ryn 可左右行走，有明确的加减速起停，不瞬时满速 | PASS | 用户试玩确认手感；日志速度 0→21→43→64→85→105 px/s，松手 105→75→45→15→0 |
| AC-2 | 跳跃弧线可控；同一按键时长产生同一跳跃高度 | PASS | 用户试玩确认；日志：按住 60 tick 三次均为 53.4px，1/6/12 tick 分别 16.1/31.7/44.9px |
| AC-3 | 蹲伏时碰撞体与精灵轮廓同时收矮；切换无卡顿或穿模 | PASS | 用户试玩确认；截图 01 vs 03 / 04 vs 05 可见矮/高对比；日志 `body_height` 14↔28，`can_stand=false` 时保持蹲姿 |
| AC-4 | 可攀爬梯子／管道，攀爬中四肢姿态可读 | PASS | 用户试玩确认；截图 02；登顶后站上 192px 平台 |
| AC-5 | 窗口以 640×360 逻辑分辨率整数倍放大，像素无插值模糊 | PASS | 用户目视确认清晰；日志 viewport(640,360)、stretch mode 2、aspect 1、scale(2,2)；1000×600 窗口降为 1.0 倍 |
| AC-6 | 镜头横向跟随 Ryn，带轻微朝向预判 | PASS | 用户试玩确认（子代理仅做到代码层，此条的实测来自用户） |
| AC-7 | 移动参数外部配置，不硬编码 | PASS | 自动核对：手感数值全在 `assets/data/ryn_movement.tres` 与 `follow_camera.tres`；`src/` 内仅余结构性常量（见 Observations） |

---

## Screenshots / Video

全部在 `production/qa/evidence/ryn-movement/`，`--write-movie` 在 640×360 视口下捕获（取末帧）。**五张均已被 Claude 用 `Read` 逐张打开核对。**

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `01-crouched-under-low-ceiling.png` | 蹲姿 Ryn 位于低矮平台正下方（x≈376），轮廓明显矮于站姿 | AC-3 |
| 2 | `02-climbing-ladder.png` | Ryn 挂在梯子上，姿态与站姿不同 | AC-4 |
| 3 | `03-standing-mid-jump.png` | 站立姿态的 Ryn 在空中，用作与蹲姿的高度对比 | AC-2, AC-3 |
| 4 | `04-crouch-early.png` | 蹲姿 Ryn 在低矮平台前方的地面（x≈337），与 01 位置不同 | AC-3 |
| 5 | `05-walk.png` | 站立的 Ryn 在地面（x≈160） | AC-1 |

配色符合 `美术规格.md` §2：墨蓝底、钢蓝块体、冷青描边，无暖色。

*一张静态截图证明不了手感（加减速、重量、响应）—— 那部分由用户试玩确认，见上表 Notes。*

---

## Test Conditions

- **Game state at start**: 灰盒测试场，Ryn 在出生点；含地面、三段台阶、低矮平台、一架梯子
- **Platform / hardware**: macOS (Darwin 25.6.0)，Apple M3 Max，Metal 4.0，Forward+
- **Framerate during test**: 未测量
- **Any special setup required**: 截图使用 dev-only 脚本 `src/dev/demo_state.gd`（`--demo=walk|jump|crouch|climb` 用户参数）强制进入状态；用户试玩使用真实键盘输入

---

## Observations

- 跳跃实际顶点 53.4px，低于配置 `jump_height = 56`：60Hz 积分误差，未调参掩盖。用户试玩判定可接受。
- 爬梯边界容差 `ladder.top_y() + 2.0` / `bottom_y() - 2.0` 是 `ryn.gd` 里的字面量（2 像素），未外置。不是手感数值，记为轻微 ADVISORY。
- 输入阈值 `0.5` / `0.01` 为输入判定常量，未外置，属结构性。
- 梯子感应区过短导致顶部反复抓梯抖动 —— 已在实现期间修复（`ryn.tscn` 感应区 size(4,24) @ y=-12）。
- 自动化测试：无。`qa.level: minimal` 下 advisory；gdUnit4 尚未安装。

---

## Sign-Off

**Solo developer**：由开发者本人以 lead 身份签字。

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) | 项目开发者 | 2026-10-03 | [x] Approved |

---

*Template: `.claude/docs/templates/test-evidence.md`*
*Used for: Visual/Feel and UI story type evidence records*
*Location: `production/qa/evidence/ryn-movement-evidence.md`*
