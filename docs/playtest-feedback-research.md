# 试玩反馈五项:参考了谁、怎么定的(2026-10-14)

用户试玩后的五条反馈:爬梯要背面、字幕 AI 味太重、要二段跳、家里照片不清楚、螺母牵制守卫太短。
这里记下参考的已上市游戏 / 资料,和据此定下来的数值。实现见 `design/ideas-backlog.md`「试玩反馈(2026-10-14)」。

## 1. 螺母:守卫走过去、低头看、捡起来

**参考**

- 《杀手》系列的硬币:丢在 NPC 附近,他会转身去查看声音;NPC 会把硬币捡起来,放在地上不丢也一样能引人
  ([Kotaku: Hitman's Deadliest Weapon Is A Coin](https://kotaku.com/hitman-s-deadliest-weapon-is-a-coin-1830384113)、
  [Steam 社区讨论](https://steamcommunity.com/app/863550/discussions/0/1743353798878585128))。Kotaku 那篇里,保镖去捡硬币的那几秒,
  玩家从他身边跑过去完成了刺杀;保镖捡完硬币走回岗位,「觉得一切正常」—— **捡东西的那几秒是玩家的窗口**,这正是用户要的「安全感」。
  多人看见你丢的时候不算引开([HITMAN 论坛](https://www.hitmanforum.com/t/question-about-tossing-coins/9400),社区说法)。
- 《忍者印记》的飞镖 / 噪音环:扔出去「伤不了人,但引开非常好用」;噪音环画在场上,和守卫重叠就会被听到,
  他会离开巡逻路线去查看(设计师 Nels Anderson:把系统做得看得懂,让玩家马上进入主动规划)
  ([GamesBeat 预览](https://gamesbeat.com/mark-of-the-ninja-preview/)、
  [Game Developer: Reinventing stealth in 2D](https://gamedeveloper.com/design/reinventing-stealth-in-2d-with-i-mark-of-the-ninja-i-)、
  [GDC 2013: Of Choice and Breaking New](https://gdcvault.com/play/1017791/Of-Choice-and-Breaking-New))。
  本作 2026-10-10 已经照它做了噪音环。

**定下来的**

- 原来:走到落点站 2.2 秒、每 1.1 秒左右转身一次(用户说的「原地打转」)。
- 现在(`GuardPursuit` 的 Inspect):快步走到扣件前 12px → **蹲下低头看 4 秒**(视线往下压 50°、只看 32px:身后、头上都看不到,
  直接踩到他眼前 8–26px 才会被看到)→ **捡起来**(扣件没了)→ 站起来张望 2 秒、只转一次身 → 照原来的规则冷静 2.5 秒 → 走回去。
  在落点前后一共约 8.5 秒。
- 低头的时候走路声(70px)听不见,跑步 / 落地 / 拆东西(≥ 100px)会把他叫起来 —— 「走过去,别跑」。
- 扣件被守卫认领后不会先消失。别的声音(落地、拆东西)不蹲,只是站着看、一半的时候转一次身。

## 2. 二段跳

**参考**

- 《空洞骑士》帝王之翼:空中再按一次跳,「扇一下翅膀」;高度和普通跳一样随按住的时间变化
  ([社区 wiki](https://hollowknight.wiki/w/Monarch_Wings)、[Fextralife wiki](https://hollowknight.wiki.fextralife.com/Monarch+Wings))。
  第二段到底比第一段矮多少,各家说法不一,没有可靠数据 —— 我们自己定。

**定下来的**

- 第二段 34px(第一段 56px 的 6 成左右),也随按住的时间变化;空中只能跳一次;落地、从梯子跳开都补满。
  游戏里实测:一段 53px + 二段 32px = 85px。
- 快落地时(跳跃缓冲 0.1 秒内会踩到地)按的那一下留给落地后的普通跳,不吃掉二段跳。
- 关卡还是照「一段跳 3 格」设计;生成器另查「二段跳会不会让谜题被跳过 / 必经守卫被绕开」:9 关都没有。

## 3. 爬梯背面

**参考**

- 像素素材作者给平台跳跃角色补「背对镜头爬梯」是常见需求:适合梯子、绳子、藤蔓;买家专门留言要背面爬梯
  ([16x16 骑士素材的更新日志](https://thepixelgame.itch.io/knight-16x16-platformer-character-sprite-sheet/devlog/1110435/-devlog-new-animations-added-wall-slide-climb)、
  [侧面 + 背面爬梯素材](https://zegley.itch.io/2d-platformermetroidvania-asset-pack/devlog/539176/ladder-climb-side-facing-back-facing)、
  [买家留言](https://rvros.itch.io/animated-pixel-hero/comments?before=33))。
- 有作者发现角色宽过梯子,要把梯子每边加宽 1px([itch.io 帖子](https://itch.io/post/15498226))—— 我们的梯子 16px,
  背面草稿肩宽约 14px,刚好。
- 通行做法是 4 帧循环:左右手交替往上够、脚交替踩,身体一直对准梯子中线(这一条是归纳,不是哪个出处的原话)。

**定下来的(草稿,等用户点头)**

- 从 `ryn_source.png` 的 24x44 工作图出发:左右翻成背面朝向 → 脸的位置全填成头发(加发丝暗部、头顶亮面、发夹)→
  前襟的扣子、徽章换成外套背面(肩线、两道褶、后开衩、下摆里衬)→ 原图垂在两侧的手臂从轮廓拿掉、换成举起来抓横档的袖子。
  颜色全取自原图,只多一档压暗的发色。4 帧:左手上 / 半途 / 右手上 / 半途。

## 4. 照片

- 游戏里用的是 150x141 的旧占位图,全屏显示时放大到将近 5 倍,所以糊。
- 仓库根目录的 `Snipaste_2026-10-04_13-26-24.png` 里是同一张拥抱合影、约 6 倍分辨率:裁出来、相纸外面透明,
  换掉 `assets/art/photo_sisters.png`(870x769)。画师的新插画到了再换。

## 5. 字幕

- 见 `design/subtitle-rewrite-draft.md`:AI 味的五种来源(省略号太多、金句、替玩家讲机制、书面腔、呼应太工整)和 38 句逐句改写。
  等用户逐句挑,还没改进游戏。
