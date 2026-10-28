# Test Evidence: 暗处判定 —— 暗处安全、亮处危险

> **Story**: `production/epics/the-cradle/story-004-darkness-detection.md`
> **Story Type**: Logic
> **Date**: 2026-10-03
> **Tester**: Claude（实现 + 验证）。**用户未试玩本故事** —— Logic 类型不要求 lead sign-off。
> **Build**: 未提交 · Godot 4.6.2.stable.official.71f334935

## Acceptance Criteria Results

| # | Criterion | Result | Evidence |
|---|---|---|---|
| AC-1 | 暗区内不被判定发现 | PASS | 截图 01；日志 `in_shadow=true in_cone=true can_see=false guard_state=PATROL` |
| AC-2 | 亮区内被锥覆盖即发现 | PASS | 截图 02；日志 `in_shadow=false in_cone=true can_see=true guard_state=SPOTTED` |
| AC-3 | 暗处优先，规则一致 | PASS | 布尔判定无渐变。真值表即 `ShadowQuery.is_detected(in_cone, in_shadow) = in_cone and not in_shadow` |
| AC-4 | 暗区边界可读 | PASS（静态） | 截图 01–04：ink-deep 填充 + 冷青虚线边框 + 实心角标，在冷青锥与红锥下都清晰。**"跑动中能否一眼辨认"需人工试玩，静帧证明不了** |
| AC-5 | 蹲伏 + 暗处组合生效 | PASS | 截图 03（蹲着在薄暗区内，未发现）vs 04（同位置站起，身体高出暗区顶边，被发现） |
| AC-6 | 判定参数外部配置 | PASS（检视） | 全部在 `assets/data/shadow_default.tres`；shadow 相关 `.gd` 内无玩法常量 |

**四张截图均由 orchestrator 用 `Read` 逐张打开核对，非转述。** 每张的 `in_cone=true` 都在日志中确认 —— 这些不是"在锥外所以没看见"的假阳性。

## 重要限制：截图是传送摆位的，不代表玩家能走到暗区

四张证据都由 dev demo 直接设置 Ryn 坐标摆位，**不是玩家走过去的**。两个暗区位于
`ShadowZoneDeep (1210, 288)` 与 `ShadowZoneLow (1320, 308)`，都在守卫巡逻区
（1180–1440）**内部**，而可达性机器人的目标点是 x=1160，走到那里就停。

**所以本故事证明的是"判定逻辑正确"，不是"玩家能潜行进入暗区"。** 后者需要等守卫背对
的时机，属于关卡设计，由 Story 006 负责。暗区 `collision_mask = 0`，不阻挡移动，
不会造成断路 —— 可达性检查复跑仍为 `REACHABLE — walked to x=1161.3`。

这条限制被明确写出来，是因为 Story 002／003 正是栽在"传送摆位的验证掩盖了可达性问题"上。

## 设计要点：暗区必须覆盖躯干中点，不是脚

`Guard.sight_point()` 采样 `-body_height * 0.5`：站立时 y−14，蹲伏时 y−7。
`ShadowZoneLow` 高 12px（y 308..320），覆盖蹲伏采样点（313）而不覆盖站立采样点（306）——
**「蹲入暗处不被发现」是从既有的采样规则自然涌现的，没有特例化 crouch 分支**，
关卡设计师只靠暗区画多高就能调。已记入 `shadow_zone.gd` 文档注释。

## 接缝

- 组名 `ShadowZone.GROUP = &"shadow_zone"`
- 纯函数：`ShadowQuery.covers(point, zones, margin) -> bool` / `ShadowQuery.is_detected(in_cone, in_shadow) -> bool`，无节点依赖，可直接单测
- `ShadowRegistry` 把 `guard.darkness_veto = covers` —— **`guard.gd` 与 `guard_vision.gd` 一行未改**，Story 002 预留的注入点按设计生效
- 暗区矩形首次查询时惰性缓存，守卫每 tick 的判定不分配、不碰物理空间状态

## 验证

- Import：无 error
- Parse check：6 个脚本，未经管道，全 `ok`，**exit=0**
- **可达性（因改动测试场而强制）**：`[demo] TRAVERSE RESULT: REACHABLE — walked to x=1161.3`，exit 0
- 4 次 windowed 捕获，从未 headless

## Observations

- Ryn 的占位图形在暗区内仍以全亮度绘制（画在填充之上）。对 AC4 无妨（玩家看得见自己），但
  美术规格的 `hide-in-shadow` 动画若要"Ryn 在暗处变暗"，那是表现层钩子，本故事未实现。
- 自动化测试：无（`qa.level: minimal` 下 advisory）。两个纯函数已为单测就绪。
- 未经文档查证的 API：`Area2D`、`add_to_group`/`get_nodes_in_group`、`Rect2.abs`/`grow`、
  `draw_rect`/`queue_redraw`。均为 **runtime-verified on 4.6.2 / doc-unverified**，
  且用法与代码库既有写法一致（`checkpoint.gd`、`gray_block.gd`）。未使用任何后截止期 API。

## Sign-Off

Logic 类型按 `.claude/docs/coding-standards.md` 不要求 lead sign-off。此处不设签字表，
以免产生「有人验过手感」的错误印象：**用户未试玩本故事**。
