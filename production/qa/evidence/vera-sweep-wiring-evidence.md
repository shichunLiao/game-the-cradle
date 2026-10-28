# Test Evidence: 坑底 Vera 致死扫掠 —— 接线修复

> **Story**: `production/epics/the-cradle/story-006-tower-levels-graybox.md`（AC 第 42 行）
> **Story Type**: Logic
> **Date**: 2026-10-04
> **Tester**: Claude（静态发现 + 无头功能验证）。**用户未试玩**
> **Build**: 未提交 · Godot 4.6.2.stable.official.71f334935

## 缺陷

story-006 的 AC「坑底关卡可进入，含 Vera 一次致死攻击（只能躲，**不可反击**）」
在 2026-10-03 被标记为 `[x]`，**但这次攻击此前没有任何效果**。

`src/levels/vera_sweep.gd` 命中时 `ryn_caught.emit(body)`，而：

- `pit_bottom.tscn` 的 `[connection]` 段数量为 **0**；
- `DetectionReset` 的自动接线只认 `GuardResetAdapter` ——
  `register_spotter(adapter: GuardResetAdapter)`，且 `_connect_spotters()` 对
  `SPOTTER_GROUP` 成员做 `as GuardResetAdapter` 强转。`VeraSweep` 是 `Area2D`，
  既不在该组、也通不过该强转。

全仓库 `grep ryn_caught` 的三处命中全在 `vera_sweep.gd` 自身（文档注释、signal
声明、emit）。**没有监听者。** Ryn 可以站在红色致命区内不动，什么都不会发生。

这是「已实现未验证」里典型的那一类：解析通过、场景加载通过、截图也能拍出红色矩形，
但行为是空的。

## 修复

`VeraSweep` 新增 `@export var detection_reset: DetectionReset`，命中时在 emit
之后调用 `detection_reset.trigger(body, self)` —— 即 `DetectionReset` 文档里
写明的「same path a real sighting takes」。`pit_bottom.tscn` 的 `VeraSweep`
节点加 `detection_reset = NodePath("../DetectionReset")`。

选择显式 NodePath 导出而非 `[connection]`，是为了跟同场景 `GameplayAudio` 的
既有写法一致（它同样以 `detection_reset = NodePath("../DetectionReset")` 取用）。

附带修一个先前就存在的问题：`_physics_process` 现在在 `detection_reset.is_failing()`
为真时提前返回。此前失败序列进行中扫掠仍在推进相位、且会对已被抓住的 Ryn 每物理帧
重复 emit 一次。

## 无头功能验证

不是解析检查 —— 实例化 `pit_bottom.tscn`、入树、把 Ryn 放进致命矩形、把周期
拨到致命相位，然后观察失败循环是否真的接管：

```
1. sweep.detection_reset resolved = true  (same node as DetectionReset: true)
2. before hit: is_failing = false
3. sweep phase at _elapsed=2.9 -> 2 (2 = lethal)
4. ryn_caught emitted = true
5. after hit: is_failing = true  phase = 1
6. ryn.input_enabled = false (false = control taken away)
7. _elapsed frozen during fail = true
```

第 5、6 行是修复前**必定**失败的两行：`is_failing` 会停在 false，`input_enabled`
会停在 true。第 7 行覆盖上面那个附带修复。

验证脚本保留在本次会话的 scratchpad（`verify_sweep.gd`），未留在 `src/` 内，以免
在代码根里留下一个一次性 harness。

## 本次验证证明了什么，没证明什么

**证明了**：命中致命区 → 失败循环接管 → 控制权被收回。AC 的「失败则重开」成立。

**没证明**：
- 「只能躲」是否躲得掉 —— 安全窗口在纸面上是 3.2s 周期里的 2.5s（1.7s 静默 +
  0.8s 预警），但玩家能否在实际跑动中读到预警并退出，是手感，静态算不出来；
- 举照片的 `PhotoTrigger`（x=930，整体落在扫掠 x∈[900,1140] 内）在**现在扫掠
  真的会伤人之后**，按下去是否仍然从容。`ending_sequence.gd` 在照片举起瞬间即
  `PROCESS_MODE_DISABLED` 掉扫掠，所以之后的 `CutNode`（x=1060）是安全的；但
  举照片**那一刻之前**玩家需要站在致命区内等提示，这一段的紧张度从未被试玩过。
  修复之前这个问题不存在（扫掠无害），**修复之后它才第一次真实存在** —— 这是
  本次改动唯一可能让手感变坏的地方，优先试玩这里。

## Sign-Off

Logic 类型按 `.claude/docs/coding-standards.md` 不要求 lead sign-off，此处不设
签字表。坑底的手感（躲避窗口、举照片的从容度）仍未经任何人试玩。
