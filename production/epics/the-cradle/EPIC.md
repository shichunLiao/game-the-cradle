# Epic: The Cradle

> **Status**: Ready
> **Layer span**: Foundation → Presentation
> **Created**: 2026-10-03
> **Tier**: `workflow: minimal` — this epic is **synthesized from
> `design/game-brief.md`**, not authored by `/create-epics`. There is no GDD, ADR,
> TR registry, or control manifest at this tier, and stories are traced to brief
> MVP features rather than TR-IDs.

## Goal

贫民窟少女 Ryn 不靠一次战斗，只凭敏捷、手巧和耐心，潜入高塔找回被接入方舟核心的姐姐。

## Scope — the brief's MVP features

| # | MVP feature | Story |
|---|---|---|
| 1 | Ryn 移动组：走、跳、蹲、爬 | 001 |
| 2 | 守卫巡逻 + 视野锥（三态） | 002 |
| 3 | 暗处判定 —— 暗处安全，亮处危险 | 004 |
| 4 | 手巧拆物件，拆后改变导航 | 005 |
| 5 | 发现 → 台词 → 检查点重置 失败循环 | 003 |
| 6 | 四塔 + 坑底关卡，灰盒可通关 | 006 |
| 7 | 终局演出：照片唤醒 → 切断 → 结局字卡 | 007 |

## Ordering

Story order follows the brief's **Build order**, which front-loads the core fun
(潜行手感) so it is proven before anything is polished:

1. 一屏灰盒验潜行手感 → stories 001, 002, 003
2. 三件套齐 → stories 004, 005
3–5. 塔 1 切片 → 塔 2–3 → 塔 4 + 串关 → story 006
6. 终局 + 叙事 → story 007

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Ryn 移动组 —— 走、跳、蹲、爬 | Visual/Feel | Ready | N/A (minimal) |
| 002 | 守卫巡逻与视野锥（巡逻／疑心／发现 三态） | Logic | Ready | N/A (minimal) |
| 003 | 发现 → 台词 → 检查点重置 失败循环 | Integration | Ready | N/A (minimal) |
| 004 | 暗处判定 —— 暗处安全、亮处危险 | Logic | Ready | N/A (minimal) |
| 005 | 手巧拆物件，且拆后改变守卫导航 | Integration | Ready | N/A (minimal) |
| 006 | 四塔 + 坑底灰盒关卡（亮险／暗安结构） | Integration | Ready | N/A (minimal) |
| 007 | 终局演出 —— 照片唤醒 → 切断 → 旧屋字卡 | Visual/Feel | Ready | N/A (minimal) |

## Not in this epic

**Build order step 7（美术替换 + 打磨冻结）has no story** — it is a phase, not an
MVP feature. Revisit with `/create-stories` once the gray-box levels are
completable; a return visit numbers on from 007 and never rewrites these files.

Out-of-scope list is the brief's own, which defers to
`design/game-brief.md` 的 Out of scope 与 `美术规格.md`「不做」。
（`里程碑排期.md` 的「明确砍掉」一节已于 2026-10-04 由作者删除。）
