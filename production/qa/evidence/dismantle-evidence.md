# Test Evidence: 拆解交互 —— 活动盖板与栅栏

> **Story**: `production/epics/the-cradle/story-005-dismantle-interaction.md`
> **Story Type**: Visual/Feel + Logic（混合）
> **Capture Date**: 2026-10-03
> **Record Date**: 2026-10-04（**补写** —— 见下方「本文件为何是补写的」）
> **Tester**: Claude（实现 + 捕获）。**用户未试玩本故事**
> **Build**: 未提交 · Godot 4.6.2.stable.official.71f334935

## 本文件为何是补写的

story-005 的 Status 行从 2026-10-03 起就指向
`production/qa/evidence/dismantle-evidence.md`，**但该文件当时没有被写出来**。
14 张截图（7 个时刻 × 全帧 + 4x 裁切）一直在 `dismantle/` 里，缺的只是这份记录。
2026-10-04 的静态核查发现了这个悬空指针，本文件补上它。

**补写的边界说清楚：** 下表把 7 个时刻按文件名映射到它对应的 AC，这部分是确定的
（命名本身就是捕获时写入的断言）。但**这些图像在本次补写中没有被重新逐张打开核对**
—— 与 `darkness-detection-evidence.md` 里那句「均由 orchestrator 用 `Read` 逐张
打开核对，非转述」不同，本文件不作该声明。下表的 Result 列因此一律记为 CAPTURED
而不是 PASS。

## Acceptance Criteria ↔ 截图映射

| # | Criterion | Result | Evidence |
|---|---|---|---|
| AC-1 | 靠近出现 1px 亮边或「E 拆」提示 | CAPTURED | `01-prompt-e-chai-and-progress-bar`, `02-hatch-panel-1px-edge-highlighted` |
| AC-2 | 按 E 触发，过程有可见反馈 | CAPTURED | `01-…-progress-bar`, `03-hatch-mid-dismantle-progress` |
| AC-3 | 拆后几何改变，产生新通路 | CAPTURED | `04-hatch-opened-guard-fell-suspicious` |
| AC-4 | 守卫导航改变：坠落**或**改道 | CAPTURED | 两者皆有：`04-…-guard-fell-suspicious`（坠落）、`05-fence-opened-guard-rerouted-past-old-max`（改道） |
| AC-5 | 至少两类可拆物件 | CAPTURED | 盖板 `02`–`04`；栅栏 `05` |
| AC-6 | 检查点重置时正确回滚 | CAPTURED | `06-before-checkpoint-reset-hatch-gone` → `07-after-checkpoint-reset-hatch-back`（成对，含 4x 裁切） |
| AC-7 | 耗时／步骤外部配置 | 检视 | 配置资源，非截图可证；由代码检视覆盖 |

每个时刻都有 `-zoom4x` 裁切版，因为 1px 亮边在全帧缩放下不可判读 —— 这是捕获时
就做出的选择，与 `guard-vision-cone` 的做法一致。

## Sign-Off

Visual/Feel 与 UI 类型按 `.claude/docs/coding-standards.md` 是 BLOCKING 且要求
lead sign-off。**本文件不提供 sign-off**：截图是 Claude 捕获的，没有任何人
（包括用户）试玩过拆解手感。此处如实留空，而不是代签。

若需要真正的 sign-off，两条路：
1. 用户试玩塔 2（教「按住」的那一关）与任一有栅栏的关卡，补签；
2. 要求 Claude 逐张打开这 14 张图复核，把上表 CAPTURED 升级为 PASS —— 这只能
   证明「静帧符合规格」，仍然证明不了手感。
